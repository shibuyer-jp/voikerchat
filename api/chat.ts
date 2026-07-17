import { VercelRequest, VercelResponse } from '@vercel/node';
import { createClient, SupabaseClient } from '@supabase/supabase-js';
import Anthropic from '@anthropic-ai/sdk';

/**
 * 環境変数（名前ゆれ・新旧キーに両対応）
 * - SUPABASE_SERVICE_KEY を優先、無ければ SUPABASE_KEY
 * - ANTHROPIC_API_KEY を優先、無ければ CLAUDE_API_KEY
 * JWT 検証は supabase.auth.getUser(token) で行うため
 * SUPABASE_JWT_SECRET / jsonwebtoken は不要。
 */
const supabaseUrl = process.env.SUPABASE_URL || '';
const supabaseKey =
  process.env.SUPABASE_SERVICE_KEY || process.env.SUPABASE_KEY || '';
const claudeApiKey =
  process.env.ANTHROPIC_API_KEY || process.env.CLAUDE_API_KEY || '';

// revenuecat-webhook.ts の daily_limit 付与値と一致させること
const PREMIUM_DAILY_LIMIT = 50;
const FREE_DAILY_LIMIT = 5;

/**
 * POST /api/chat
 *
 * Server-side rate limiting + Claude Haiku integration
 *
 * Request body:
 * {
 *   "token": "supabase access token (JWT)",
 *   "messages": [{ "role": "user", "content": "..." }],
 *   "sceneId": "scene_123",
 *   "maxTokens": 500
 * }
 */
export default async function handler(req: VercelRequest, res: VercelResponse) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  // 0. 設定チェック（不足は原因不明クラッシュにせず、明示エラーで返す）
  const missing: string[] = [];
  if (!supabaseUrl) missing.push('SUPABASE_URL');
  if (!supabaseKey) missing.push('SUPABASE_SERVICE_KEY (or SUPABASE_KEY)');
  if (!claudeApiKey) missing.push('ANTHROPIC_API_KEY (or CLAUDE_API_KEY)');
  if (missing.length > 0) {
    return res.status(500).json({
      error: 'Server misconfiguration',
      message: `Missing environment variable(s): ${missing.join(', ')}`,
    });
  }

  // クライアントは関数内で生成（モジュール読込時クラッシュを防ぐ）
  const supabase = createClient(supabaseUrl, supabaseKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  // maxRetries: 529 (overloaded) 等の一時エラーはSDKが指数バックオフで自動再試行する
  // （デフォルト2回 → 4回に増加。x-should-retry対象のみ再試行されるため安全）
  const anthropic = new Anthropic({ apiKey: claudeApiKey, maxRetries: 4 });

  try {
    const {
      token,
      messages,
      sceneId,
      maxTokens = 500,
      furiganaEnabled = true,
    } = req.body || {};

    // 1. トークン検証（getUser はHS256/非対称鍵いずれの署名でも検証可能）
    if (!token) {
      return res.status(401).json({ error: 'Missing authentication token' });
    }

    const { data: userData, error: userErr } = await supabase.auth.getUser(token);
    if (userErr || !userData?.user) {
      return res.status(401).json({ error: 'Invalid or expired token' });
    }
    const userId = userData.user.id;

    // 2. Premium ステータス取得
    let isPremium = false;
    try {
      const { data, error } = await supabase
        .from('rate_limits')
        .select('is_premium')
        .eq('user_id', userId)
        .single();
      if (!error && data) {
        isPremium = data.is_premium === true;
      } else if (error) {
        console.error('rate_limits select (is_premium) failed:', error.code, error.message, error.details);
      }
    } catch (err) {
      console.error('Error checking premium status:', err);
    }

    // 3. サーバー側レート制限（Premiumも daily_limit=50 を適用。無料は5）
    const canCall = await checkAndIncrementRateLimit(supabase, userId, isPremium);
    if (!canCall) {
      // 上限到達を分析イベントとして記録（強制はしない・書込み失敗は無視）
      await logUsage(supabase, {
        userId,
        event: 'quota_reached',
        isPremium,
        metadata: sceneId ? { scene: sceneId } : {},
      });
      return res.status(429).json({
        error: 'Daily limit reached',
        message: isPremium
          ? 'Daily limit reached. Resets tomorrow.'
          : 'Go Premium to unlock more daily conversations',
      });
    }

    // 4. messages 検証
    if (!Array.isArray(messages) || messages.length === 0) {
      return res.status(400).json({ error: 'Invalid messages format' });
    }

    // 5. Claude Haiku 呼び出し
    const response = await anthropic.messages.create({
      model: 'claude-haiku-4-5-20251001',
      max_tokens: Math.min(maxTokens, 500),
      system: buildSystemPrompt(sceneId, furiganaEnabled === true),
      messages: sanitizeMessages(messages),
    });

    // 6. 使用ログ（成功）— usage_logs 新スキーマ準拠（event ベース）
    await logUsage(supabase, {
      userId,
      event: 'message_sent',
      model: 'claude-haiku-4-5-20251001',
      isPremium,
      inputTokens: response.usage.input_tokens,
      outputTokens: response.usage.output_tokens,
      metadata: sceneId ? { scene: sceneId } : {},
    });

    // 7. 成功レスポンス
    const content = response.content[0];
    const assistantMessage =
      content.type === 'text' ? content.text : 'Unable to generate response';

    return res.status(200).json({
      success: true,
      content: assistantMessage,
      tokensUsed: response.usage.output_tokens,
      inputTokens: response.usage.input_tokens,
    });
  } catch (error: any) {
    console.error('Chat API error:', error);

    // Anthropic側の一時的な混雑/障害（リトライ切れ）→ ユーザー向け文言で503を返す
    // 注意: クライアントは response body の 'error' フィールドをそのまま表示するため、
    // ここに分かりやすい文言を入れる。429は使わない（クライアントが日次上限と誤認するため）。
    const status = error?.status;
    const isOverloaded =
      status === 529 ||
      error?.type === 'overloaded_error' ||
      error?.error?.error?.type === 'overloaded_error';
    if (isOverloaded || status === 503) {
      return res.status(503).json({
        error: 'The assistant is busy right now. Please try again in a moment.',
        message: error?.message || 'Upstream overloaded',
      });
    }

    return res.status(500).json({
      error: 'Internal server error',
      message: error?.message || 'Unknown error',
    });
  }
}

/**
 * サーバー側レート制限チェック＆インクリメント
 * 許可なら true、上限到達なら false
 */
async function checkAndIncrementRateLimit(
  supabase: SupabaseClient,
  userId: string,
  isPremium: boolean
): Promise<boolean> {
  try {
    const { data: rateLimit, error: fetchError } = await supabase
      .from('rate_limits')
      .select('used_today, daily_limit, last_reset_utc')
      .eq('user_id', userId)
      .single();

    if (fetchError || !rateLimit) {
      if (fetchError) {
        console.error('rate_limits select failed:', fetchError.code, fetchError.message, fetchError.details);
      }
      // レコードなし → デフォルト作成（Premium: 50回/日、無料: 5回/日）
      const { error: insertError } = await supabase.from('rate_limits').insert({
        user_id: userId,
        used_today: 1,
        daily_limit: isPremium ? PREMIUM_DAILY_LIMIT : FREE_DAILY_LIMIT,
        is_premium: isPremium,
        last_reset_utc: new Date().toISOString(),
      });
      if (insertError) {
        console.error('rate_limits insert failed:', insertError.code, insertError.message, insertError.details);
      }
      return true;
    }

    const lastReset = new Date(rateLimit.last_reset_utc);
    const today = new Date();
    const daysPassed = Math.floor(
      (today.getTime() - lastReset.getTime()) / (1000 * 60 * 60 * 24)
    );

    if (daysPassed >= 1) {
      const { error: resetError } = await supabase
        .from('rate_limits')
        .update({ used_today: 1, last_reset_utc: today.toISOString() })
        .eq('user_id', userId);
      if (resetError) {
        console.error('rate_limits reset update failed:', resetError.code, resetError.message, resetError.details);
      }
      return true;
    }

    if (rateLimit.used_today >= rateLimit.daily_limit) {
      return false;
    }

    const { error: incrementError } = await supabase
      .from('rate_limits')
      .update({ used_today: rateLimit.used_today + 1 })
      .eq('user_id', userId);
    if (incrementError) {
      console.error('rate_limits increment update failed:', incrementError.code, incrementError.message, incrementError.details);
    }
    return true;
  } catch (err) {
    console.error('Rate limit check error:', err);
    // 失敗時はフェイルオープン（呼び出しを許可）
    return true;
  }
}

/**
 * シーン別システムプロンプト
 * 出典: docs/Persona-Design-v1.0.md（確定版、シーン1〜13）
 *       + docs/tasks/T-34_premium-pro-scenes.md（シーン14〜18、実用プレミアム）
 * キーはアプリの数値 sceneId（"1"〜"18"）。
 */
const COMMON_RULES = `You are a helpful Japanese language conversation partner for a Filipino learner. Your role is to:

1. Engage naturally in realistic, everyday Japanese conversations
2. Match the difficulty level (Beginner/Intermediate/Advanced) set by the user
3. Correct politely when errors occur; offer explanations if needed
4. Generate original dialogue (no copyrighted material)
5. Use the assigned character name, age, personality, and speaking style consistently
6. Teach implicitly - let grammar and expressions emerge naturally from conversation
7. Encourage interaction - ask follow-up questions to maintain engagement
8. Maintain context - remember what was said earlier in the conversation
9. Use voice-friendly language - clear, natural pacing (avoid complex written-only constructs)
10. Tailor to learner - be aware this learner may have Filipino/Tagalog as primary language
11. Keep responses SHORT - 1 to 3 sentences per reply, like real spoken conversation. One question at most per reply.
12. Output plain text only - NEVER use Markdown formatting (no **bold**, no bullet points, no headers). Your replies are displayed as plain text and read aloud by TTS.

Do not:
- Break character
- Use extremely formal or overly casual speech without reason
- Translate to English/Tagalog unless explicitly asked
- Generate hateful, explicit, or inappropriate content
- Use copyrighted materials or characters`;

// T-36: 全漢字にふりがなを「漢字(かんじ)」形式で付与する指示(Web版と同方式)。
// 設定画面のトグル(デフォルトON)でクライアントが furiganaEnabled を送る。
const FURIGANA_INSTRUCTION = `

Furigana requirement: For EVERY word containing kanji in your reply, immediately follow it with its hiragana reading in parentheses, like 漢字(かんじ). Apply this to all kanji compounds and single kanji, including names. Do not add furigana to hiragana/katakana-only words or to text already in parentheses.`;

function buildSystemPrompt(
  sceneId: string | number,
  furiganaEnabled: boolean,
): string {
  const scenePrompts: { [key: string]: string } = {
    '1': 'You are Sakura, a friendly 22-year-old woman meeting a friend at a cafe. You speak cheerfully and naturally. Topics include: weekend plans, school/work, favorite foods, music, recent experiences. Use simple, conversational Japanese (Beginner level acceptable). Ask questions to keep the conversation flowing. Encourage your friend to share their thoughts.',
    '2': 'You are Takuya, a 28-year-old restaurant waiter. You help customers order food, answer questions about dishes, and provide recommendations. Speak politely with appropriate honorific language (敬語). Topics: menu items, ingredients, dietary preferences, recommendations, payment. Use clear, moderate-speed Japanese suitable for Intermediate learners. Be attentive and friendly.',
    '3': 'You are Yumi, a 25-year-old fashion shop assistant. Help customers find clothing, discuss styles, sizes, colors, and prices. Speak politely with occasional casual elements. Topics: fashion preferences, color choices, sizing, sales, seasonal items. Use clear Japanese at Intermediate level. Be enthusiastic about helping.',
    '4': 'You are Kouki, a 30-year-old commuter on a train. Chat with a traveler about directions, train routes, neighborhoods, and daily commute. Speak naturally with mix of polite and casual forms. Topics: train schedules, stations, directions, local areas, travel tips. Use practical, conversational Japanese at Intermediate level. Be helpful with navigation.',
    '5': 'You are Akari, a 35-year-old hospital receptionist. Assist patients with registration, symptoms, medical history, and appointment scheduling. Speak with formal politeness (keigo). Topics: health symptoms, medical conditions, appointment times, insurance information. Use clear, careful Japanese suitable for Intermediate learners discussing health topics.',
    '6': 'You are Kenji, a 32-year-old businessman introducing yourself in a formal setting. Discuss your background, education, career, family, hobbies, and ambitions. Speak with sophisticated politeness and business Japanese. Topics: work experience, educational background, career goals, cultural background, family, interests. Use advanced vocabulary and complex sentence structures suitable for Advanced learners.',
    '7': 'You are Minato, a 26-year-old relaxed cafe-goer. Chat casually about hobbies, books, art, favorite drinks, dreams. Speak in friendly, casual Japanese suitable for Beginner learners. No pressure, just enjoyable conversation. Topics: interests, favorite books/movies, travel dreams, hobbies, favorite seasons. Be warm and encouraging.',
    '8': 'You are Eiko, a 29-year-old friendly companion for open conversation. Adapt your speech level based on user proficiency. Engage in any appropriate topic: daily life, dreams, opinions, questions about Japan, personal interests, current thoughts. Be genuinely interested, ask follow-up questions, encourage expression. Speak naturally without forcing grammar lesson. Make it feel like talking to a good friend.',
    '9': 'You are Raiki, a 19-year-old passionate fighter. Engage in motivational, action-packed dialogue about challenges, determination, and friendship. Use energetic, dynamic language with some dramatic expressions. Topics: courage, rivalry, improvement, teamwork, dreams. Speak in enthusiastic but grammatically appropriate Japanese (Intermediate). Encourage the user with fighting spirit.',
    '10': 'You are Hana, an 18-year-old cheerful girl who loves helping friends. Talk about teamwork, supporting each other, gratitude, and cooperation. Speak in warm, encouraging language suitable for Beginner learners. Topics: helping a friend, appreciation, working together, celebrating successes. Be sincere and kind.',
    '11': 'You are Luna, a 21-year-old with deep emotional awareness. Discuss feelings, meaningful moments, dreams, memories, and growth. Speak with sincerity and vulnerability. Use poetic but clear language (Intermediate level). Topics: emotions, life lessons, personal growth, meaningful experiences, dreams, connections. Be empathetic and real.',
    '12': 'You are Taro, a 17-year-old high school student. Chat about school life, subjects, friends, tests, lunch, after-school activities, crushes, dreams. Speak in casual Intermediate Japanese with youthful energy. Topics: school subjects, clubs, daily events, homework, exams, friend drama, future plans. Be relatable and fun.',
    '13': 'You are Jiro, a 24-year-old funny guy who loves making people laugh. Use puns, wordplay, exaggeration, and silly scenarios. Keep language appropriate but playful. Topics: funny stories, ridiculous situations, harmless jokes, absurd observations. Adapt language level to user. Make conversation light and entertaining. Be creative with humor.',
    // 実用プレミアム5シーン(T-34)。「日本で働く外国人」視点: ユーザーが介護士/医療スタッフ/求職者/
    // 住民/部下役、AIキャラクターがその相手役(利用者/医師/面接官/窓口職員/上司)を演じる。
    '14': 'You are Haruko, an 82-year-old resident at a Japanese elderly care facility (介護施設). The user is a foreign care worker (介護士) speaking to you during daily care. Respond as an elderly care recipient would: morning greetings, meal assistance (食事介助), health checks (体調確認・バイタル確認), and requests for help (トイレ、着替えなど). Speak slowly and simply, sometimes needing things repeated, as elderly patients often do. Occasionally mention minor complaints (痛い、疲れた、眠い) so the learner practices care-work vocabulary. Use warm, appreciative language when helped well. Use natural, moderate-paced Japanese (Intermediate level). Be kind and patient.',
    '15': 'You are Dr. Mori, a 45-year-old physician at a Japanese hospital or care facility. The user is a foreign nursing assistant or care staff member giving you a shift handover report (申し送り) on a patient. Ask clarifying questions about vital signs (バイタル、体温、血圧), symptoms, meals (食事摂取量), elimination (排泄), and medication. Speak with professional, formal Japanese (敬語・医療現場の言葉遣い). Politely point out if a report is unclear or incomplete, the way a real doctor reviewing a handover would. Use Advanced-level Japanese with natural medical/care vocabulary.',
    '16': 'You are Sato, a 40-year-old hiring manager interviewing a foreign candidate for a job under Japan’s Specified Skilled Worker (特定技能) visa program. Ask standard interview questions: self-introduction (自己紹介), motivation for applying (志望動機), past work experience (経歴), strengths, and availability. Speak with polite, professional Japanese (敬語) typical of a job interview. Keep a professional but encouraging tone, and ask natural follow-up questions. Use Intermediate-level Japanese with business/formal vocabulary.',
    '17': 'You are Mizuki, a 34-year-old city hall (役所) counter clerk. The user is a foreign resident handling paperwork: residence card renewal (在留カード), certificate of residence (住民票), or national health insurance (国民健康保険) procedures. Ask what procedure they need, request necessary documents, explain forms and fees, and answer questions politely and precisely. Speak with clear, formal but approachable Japanese (丁寧語) typical of government office staff. Use Intermediate-level Japanese with practical administrative vocabulary.',
    '18': 'You are Tanaka, a 50-year-old department manager (部長) at a Japanese company. The user is your foreign subordinate practicing workplace communication: status reports (報告), consultations (相談), requests (依頼・お願い), and apologies (謝罪) using proper business keigo. Respond as a busy but fair manager: ask for clarification, give brief feedback, and occasionally note when the learner’s language is too casual for the workplace. Expect and model sophisticated business Japanese (謙譲語・尊敬語). Use Advanced-level Japanese suitable for real workplace keigo practice.',
  };

  const persona =
    scenePrompts[String(sceneId)] ||
    'You are a helpful Japanese language conversation partner. Respond naturally in Japanese.';

  const furigana = furiganaEnabled ? FURIGANA_INSTRUCTION : '';
  return `${COMMON_RULES}\n\n---\n\n${persona}${furigana}`;
}

/**
 * Anthropic Messages API 用にメッセージ列を正規化する。
 * - 連続する完全同一メッセージを除去（クライアント側の二重付与対策）
 * - 同一ロールの連続を結合（APIのロール交互要件対策）
 * - 先頭が assistant の場合（シーン別オープニング第一声）、user のシード発話を先頭に補う
 */
function sanitizeMessages(
  messages: Array<{ role: string; content: string }>,
): Array<{ role: 'user' | 'assistant'; content: string }> {
  const result: Array<{ role: 'user' | 'assistant'; content: string }> = [];
  for (const msg of messages) {
    const role = msg.role === 'assistant' ? 'assistant' : 'user';
    const content = typeof msg.content === 'string' ? msg.content : String(msg.content ?? '');
    if (!content.trim()) continue;
    const last = result[result.length - 1];
    if (last && last.role === role) {
      if (last.content === content) continue; // 完全同一の連続は捨てる
      last.content = `${last.content}\n${content}`; // 同一ロール連続は結合
      continue;
    }
    result.push({ role, content });
  }
  if (result.length > 0 && result[0].role === 'assistant') {
    result.unshift({ role: 'user', content: '（会話を始めてください）' });
  }
  return result;
}

/**
 * usage_logs への記録（失敗しても本処理は止めない）
 */
type UsageEvent =
  | 'session_start'
  | 'message_sent'
  | 'ad_reward'
  | 'quota_reached'
  | 'upsell_shown'
  | 'upsell_clicked'
  | 'upsell_converted';

async function logUsage(
  supabase: SupabaseClient,
  params: {
    userId: string;
    event: UsageEvent;
    sessionId?: string;
    model?: string;
    isPremium?: boolean;
    inputTokens?: number;
    outputTokens?: number;
    locale?: string;
    platform?: string;
    metadata?: Record<string, unknown>;
  }
): Promise<void> {
  try {
    // locale / platform は CHECK 制約付き。許容値以外は null に落とす（書込み失敗を防ぐ）
    const ALLOWED_LOCALES = ['ja', 'en', 'fil'];
    const ALLOWED_PLATFORMS = ['ios', 'android', 'web'];
    const locale =
      params.locale && ALLOWED_LOCALES.includes(params.locale) ? params.locale : null;
    const platform =
      params.platform && ALLOWED_PLATFORMS.includes(params.platform)
        ? params.platform
        : null;

    // 注意: scene_id 列は smallint(1..13)。アプリの sceneId は文字列のため列には入れず、
    // metadata.scene に格納する（数値ID対応表が整うまでの暫定）。created_at は DB 既定 now() に委ねる。
    const { error } = await supabase.from('usage_logs').insert({
      user_id: params.userId,
      event: params.event,
      session_id: params.sessionId ?? null,
      model: params.model ?? null,
      platform,
      locale,
      is_premium: params.isPremium ?? false,
      input_tokens: params.inputTokens ?? null,
      output_tokens: params.outputTokens ?? null,
      metadata: params.metadata ?? {},
    });
    if (error) {
      console.error('usage_logs insert failed:', error.code, error.message, error.details);
    }
  } catch (err) {
    console.error('Failed to log usage:', err);
  }
}

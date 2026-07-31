import { VercelRequest, VercelResponse } from '@vercel/node';
import { createClient } from '@supabase/supabase-js';
import { sanitizeLocale, sanitizePlatform } from './_validation';

const supabaseUrl = process.env.SUPABASE_URL || '';
const supabaseKey =
  process.env.SUPABASE_SERVICE_KEY || process.env.SUPABASE_KEY || '';
const openaiApiKey = process.env.OPENAI_API_KEY || '';

// キャラクター(sceneId)ごとの音声プロファイル(gpt-4o-mini-tts)。
// voice: 13声(alloy/ash/ballad/coral/echo/fable/nova/onyx/sage/shimmer/verse/marin/cedar)から選択。
// instructions: 話し方の指示。キャラの年齢・性別・トーンを反映し「シーンキャラと声の
// イメージ不一致」(Build 6検証NG)を解消する。すべて "native Japanese speaker" を明示し
// 外国語訛りを抑制する。出典: docs/Persona-Design-v1.0.md / T-34_premium-pro-scenes.md
type VoiceProfile = { voice: string; instructions: string };

const JP = 'You are a native Japanese speaker with natural, fluent Japanese pronunciation and pitch accent. ';

const CHARACTER_VOICE_MAP: { [sceneId: string]: VoiceProfile } = {
  // 基本8シーン
  '1': { voice: 'nova', instructions: JP + 'Speak as Sakura, a cheerful friendly 22-year-old woman chatting with a friend at a cafe. Bright, warm, casual tone.' },
  '2': { voice: 'echo', instructions: JP + 'Speak as Takuya, a polite 28-year-old restaurant waiter. Courteous, clear, professional service tone at a moderate pace.' },
  '3': { voice: 'shimmer', instructions: JP + 'Speak as Yumi, an enthusiastic 25-year-old fashion shop assistant. Upbeat, helpful, friendly retail tone.' },
  '4': { voice: 'ash', instructions: JP + 'Speak as Kouki, a relaxed 30-year-old commuter on a train. Natural, casual, helpful everyday tone.' },
  '5': { voice: 'sage', instructions: JP + 'Speak as Akari, a calm 35-year-old hospital receptionist. Gentle, careful, reassuring formal tone at a measured pace.' },
  '6': { voice: 'onyx', instructions: JP + 'Speak as Kenji, a confident 32-year-old businessman in a formal setting. Polished, articulate, professional business tone.' },
  '7': { voice: 'ballad', instructions: JP + 'Speak as Minato, a laid-back 26-year-old at a cafe. Soft, relaxed, unhurried conversational tone.' },
  '8': { voice: 'shimmer', instructions: JP + 'Speak as Eiko, a warm 29-year-old friend in open conversation. Genuine, curious, comfortable friendly tone.' },
  // アニメ5シーン
  '9': { voice: 'verse', instructions: JP + 'Speak as Raiki, a passionate 19-year-old fighter. Energetic, dynamic, youthful voice full of fighting spirit — but keep speech clear.' },
  '10': { voice: 'nova', instructions: JP + 'Speak as Hana, a bright 18-year-old girl who loves helping friends. Sweet, encouraging, youthful cheerful tone.' },
  '11': { voice: 'coral', instructions: JP + 'Speak as Luna, a thoughtful 21-year-old with deep emotional awareness. Soft, sincere, gently expressive tone with tender pacing.' },
  '12': { voice: 'echo', instructions: JP + 'Speak as Taro, a lively 17-year-old high school boy. Light, youthful, casual energetic tone — clearly a teenager, not an adult.' },
  '13': { voice: 'fable', instructions: JP + 'Speak as Jiro, a funny 24-year-old who loves making people laugh. Playful, animated, comedic timing with lively intonation.' },
  // 実用プレミアム5シーン(T-34)
  '14': { voice: 'marin', instructions: JP + 'Speak as Haruko, an 82-year-old woman at a care facility. Slow, slightly frail but warm elderly voice, kind and appreciative, with natural pauses.' },
  '15': { voice: 'onyx', instructions: JP + 'Speak as Dr. Mori, a 45-year-old physician. Composed, authoritative, precise professional medical tone.' },
  '16': { voice: 'cedar', instructions: JP + 'Speak as Sato, a 40-year-old hiring manager conducting a job interview. Professional, courteous, encouraging formal tone.' },
  '17': { voice: 'sage', instructions: JP + 'Speak as Mizuki, a 34-year-old city hall counter clerk. Clear, precise, formal but approachable public-service tone.' },
  '18': { voice: 'onyx', instructions: JP + 'Speak as Tanaka, a 50-year-old department manager. Firm, dignified, busy-but-fair senior manager tone with mature gravitas.' },
};
const DEFAULT_VOICE: VoiceProfile = {
  voice: 'alloy',
  instructions: JP + 'Speak in a clear, friendly, natural conversational tone.',
};

const MAX_TEXT_LENGTH = 1000;

/**
 * POST /api/tts
 *
 * 高品質クラウドTTS(OpenAI、T-35)。Premium、または本日リワード広告を
 * 視聴済み(usage_logs.ad_reward)のユーザーのみサーバー側で許可し、mp3を返す。
 * クライアントのローカルフラグだけでは解放しない(API直叩き対策)。
 *
 * Request body:
 * {
 *   "token": "supabase access token (JWT)",
 *   "text": "読み上げるテキスト",
 *   "sceneId": "1"
 * }
 *
 * Response: audio/mpeg(mp3バイナリ)
 */
export default async function handler(req: VercelRequest, res: VercelResponse) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const missing: string[] = [];
  if (!supabaseUrl) missing.push('SUPABASE_URL');
  if (!supabaseKey) missing.push('SUPABASE_SERVICE_KEY (or SUPABASE_KEY)');
  if (!openaiApiKey) missing.push('OPENAI_API_KEY');
  if (missing.length > 0) {
    return res.status(500).json({
      error: 'Server misconfiguration',
      message: `Missing environment variable(s): ${missing.join(', ')}`,
    });
  }

  const supabase = createClient(supabaseUrl, supabaseKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  try {
    const { token, text, sceneId, locale, platform } = req.body || {};

    if (!token) {
      return res.status(401).json({ error: 'Missing authentication token' });
    }
    if (typeof text !== 'string' || !text.trim()) {
      return res.status(400).json({ error: 'Invalid text' });
    }
    if (text.length > MAX_TEXT_LENGTH) {
      return res.status(400).json({ error: 'Text too long' });
    }

    const { data: userData, error: userErr } = await supabase.auth.getUser(token);
    if (userErr || !userData?.user) {
      return res.status(401).json({ error: 'Invalid or expired token' });
    }
    const userId = userData.user.id;

    // Premium 判定
    let isPremium = false;
    try {
      const { data, error } = await supabase
        .from('rate_limits')
        .select('is_premium')
        .eq('user_id', userId)
        .single();
      if (!error && data) {
        isPremium = data.is_premium === true;
      }
    } catch (err) {
      console.error('Error checking premium status:', err);
    }

    if (!isPremium) {
      // Premiumでなければ「本日 ad_reward イベントがあるか」をサーバー側で検証。
      // rate_limits の日次リセットと同じUTC日付基準を使う。
      const startOfDayUtc = new Date();
      startOfDayUtc.setUTCHours(0, 0, 0, 0);
      const { count, error: countError } = await supabase
        .from('usage_logs')
        .select('id', { count: 'exact', head: true })
        .eq('user_id', userId)
        .eq('event', 'ad_reward')
        .gte('created_at', startOfDayUtc.toISOString());

      if (countError) {
        console.error('usage_logs ad_reward count failed:', countError.code, countError.message);
      }

      if ((count ?? 0) === 0) {
        return res.status(403).json({
          error: 'Cloud TTS not unlocked today',
          message: 'Watch a rewarded ad or upgrade to Premium to unlock high-quality voice.',
        });
      }
    }

    const profile = CHARACTER_VOICE_MAP[String(sceneId)] || DEFAULT_VOICE;

    // gpt-4o-mini-tts: tts-1と同水準の料金($0.60/1M入力トークン + $12/1M音声トークン
    // ≒ $0.015/分)で、instructionsにより年齢・性別・トーンを制御できる。
    // レスポンス形式(音声バイナリ)はtts-1と同一のため、クライアント変更は不要。
    const openaiResponse = await fetch('https://api.openai.com/v1/audio/speech', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${openaiApiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: 'gpt-4o-mini-tts',
        voice: profile.voice,
        instructions: profile.instructions,
        input: text,
        response_format: 'mp3',
      }),
    });

    if (!openaiResponse.ok) {
      const errorBody = await openaiResponse.text();
      console.error('OpenAI TTS error:', openaiResponse.status, errorBody);
      return res.status(502).json({ error: 'Cloud TTS provider error' });
    }

    const audioBuffer = Buffer.from(await openaiResponse.arrayBuffer());

    // 使用ログ(失敗しても本処理は止めない)。既存の event 種別のみ使用し、
    // metadata.feature で識別する(usage_logs のスキーマ変更はしない)。
    try {
      const { error: logError } = await supabase.from('usage_logs').insert({
        user_id: userId,
        event: 'message_sent',
        is_premium: isPremium,
        platform: sanitizePlatform(platform),
        locale: sanitizeLocale(locale),
        metadata: { feature: 'cloud_tts', scene: sceneId ?? null, chars: text.length },
      });
      if (logError) {
        console.error('usage_logs insert failed:', logError.code, logError.message);
      }
    } catch (err) {
      console.error('Failed to log cloud_tts usage:', err);
    }

    res.setHeader('Content-Type', 'audio/mpeg');
    return res.status(200).send(audioBuffer);
  } catch (error: any) {
    console.error('TTS API error:', error);
    return res.status(500).json({
      error: 'Internal server error',
      message: error?.message || 'Unknown error',
    });
  }
}

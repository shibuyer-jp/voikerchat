import { VercelRequest, VercelResponse } from '@vercel/node';
import { createClient } from '@supabase/supabase-js';
import Anthropic from '@anthropic-ai/sdk';
import * as jwt from 'jsonwebtoken';

const supabaseUrl = process.env.SUPABASE_URL || '';
const supabaseKey = process.env.SUPABASE_KEY || '';
const jwtSecret = process.env.SUPABASE_JWT_SECRET || '';
const claudeApiKey = process.env.ANTHROPIC_API_KEY || '';

const supabase = createClient(supabaseUrl, supabaseKey);
const anthropic = new Anthropic({ apiKey: claudeApiKey });

interface AuthPayload {
  sub: string;
  iat: number;
  exp: number;
}

/**
 * POST /api/chat
 * 
 * Server-side rate limiting + Claude Haiku integration
 * 
 * Request body:
 * {
 *   "token": "jwt_token",
 *   "messages": [{ "role": "user", "content": "..." }],
 *   "sceneId": "scene_123"
 * }
 */
export default async function handler(req: VercelRequest, res: VercelResponse) {
  // Only POST allowed
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  try {
    const { token, messages, sceneId, maxTokens = 500 } = req.body;

    // 1. JWT 検証
    if (!token) {
      return res.status(401).json({ error: 'Missing authentication token' });
    }

    let userId: string;
    try {
      const payload = jwt.verify(token, jwtSecret) as AuthPayload;
      userId = payload.sub;
    } catch (err) {
      return res.status(401).json({ error: 'Invalid or expired token' });
    }

    // 2. Premium ステータスを Supabase から取得
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
      // Continue with non-premium assumption
    }

    // 3. サーバー側レート制限チェック
    if (!isPremium) {
      const canCall = await checkAndIncrementRateLimit(userId);
      if (!canCall) {
        return res.status(429).json({
          error: 'Daily limit reached',
          message: 'Go Premium to unlock unlimited calls',
        });
      }
    }

    // 4. Messages 検証
    if (!Array.isArray(messages) || messages.length === 0) {
      return res.status(400).json({ error: 'Invalid messages format' });
    }

    // 5. Claude Haiku API 呼び出し
    const response = await anthropic.messages.create({
      model: 'claude-3-5-haiku-20241022',
      max_tokens: Math.min(maxTokens, 500),
      system: buildSystemPrompt(sceneId),
      messages: messages.map((msg: any) => ({
        role: msg.role as 'user' | 'assistant',
        content: msg.content,
      })),
    });

    // 6. 成功レスポンス
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
    return res.status(500).json({
      error: 'Internal server error',
      message: error.message || 'Unknown error',
    });
  }
}

/**
 * Check rate limit and increment counter (server-side)
 * Returns true if call allowed, false if limit reached
 */
async function checkAndIncrementRateLimit(userId: string): Promise<boolean> {
  try {
    // Get current rate limit
    const { data: rateLimit, error: fetchError } = await supabase
      .from('rate_limits')
      .select('used_today, daily_limit, last_reset_utc')
      .eq('user_id', userId)
      .single();

    if (fetchError) {
      // No record: create default (5 calls/day)
      await supabase.from('rate_limits').insert({
        user_id: userId,
        used_today: 1,
        daily_limit: 5,
        is_premium: false,
        last_reset_utc: new Date().toISOString(),
      });
      return true;
    }

    // Check if day has passed (reset if needed)
    const lastReset = new Date(rateLimit.last_reset_utc);
    const today = new Date();
    const daysPassed = Math.floor(
      (today.getTime() - lastReset.getTime()) / (1000 * 60 * 60 * 24)
    );

    if (daysPassed >= 1) {
      // Reset counter
      await supabase
        .from('rate_limits')
        .update({
          used_today: 1,
          last_reset_utc: today.toISOString(),
        })
        .eq('user_id', userId);
      return true;
    }

    // Check if within limit
    if (rateLimit.used_today >= rateLimit.daily_limit) {
      return false;
    }

    // Increment counter
    await supabase
      .from('rate_limits')
      .update({ used_today: rateLimit.used_today + 1 })
      .eq('user_id', userId);

    return true;
  } catch (err) {
    console.error('Rate limit check error:', err);
    // Fail-open: allow call on error
    return true;
  }
}

/**
 * Build system prompt based on scene
 */
function buildSystemPrompt(sceneId: string): string {
  const scenePrompts: { [key: string]: string } = {
    friends: '友達同士の会話をシミュレートしてください。自然で親友のような会話のトーンを使います。',
    restaurant:
      'レストランでのウェイターとお客さんの会話をシミュレートしてください。敬語を使いながらも親切です。',
    shopping:
      '店員と客の会話をシミュレートしてください。商品について質問されて説明します。',
    train:
      '電車での乗客同士または駅員との会話をシミュレートしてください。',
    hospital:
      '医者と患者の会話をシミュレートしてください。医学用語を使いながらも分かりやすく説明します。',
    introduction:
      '自己紹介の場面をシミュレートしてください。丁寧で専門的です。',
    cafe: 'カフェでのウェイターと客の会話をシミュレートしてください。',
    freetalk:
      'どのようなトピックの日本語会話でもシミュレートしてください。自然なトーンで。',
    hotblooded:
      '熱血系キャラのトーンで、日本語会話をシミュレートしてください。情熱的で元気です！',
    friendship:
      '友情系キャラのトーンで、日本語会話をシミュレートしてください。温かみのある応答をしてください。',
    emotional:
      '感動系シーンの日本語会話をシミュレートしてください。感情的で心に訴える返答をしてください。',
    school:
      '学園系シーンの日本語会話をシミュレートしてください。学生らしいトーンで。',
    comedy:
      'ギャグ系シーンの日本語会話をシミュレートしてください。ユーモア溢れた返答をしてください。',
  };

  return (
    scenePrompts[sceneId] ||
    'You are a helpful Japanese language conversation partner. Respond naturally in Japanese.'
  );
}

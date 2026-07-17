import { VercelRequest, VercelResponse } from '@vercel/node';
import { createClient } from '@supabase/supabase-js';

const supabaseUrl = process.env.SUPABASE_URL || '';
const supabaseKey =
  process.env.SUPABASE_SERVICE_KEY || process.env.SUPABASE_KEY || '';
const openaiApiKey = process.env.OPENAI_API_KEY || '';

// キャラクター(sceneId)ごとのOpenAI音声ID割当(lib/constants/character_voice_map.dart と同一)。
const CHARACTER_VOICE_MAP: { [sceneId: string]: string } = {
  '1': 'nova',
  '2': 'echo',
  '3': 'shimmer',
  '4': 'onyx',
  '5': 'nova',
  '6': 'onyx',
  '7': 'echo',
  '8': 'shimmer',
  '9': 'onyx',
  '10': 'nova',
  '11': 'shimmer',
  '12': 'echo',
  '13': 'fable',
  '14': 'shimmer',
  '15': 'onyx',
  '16': 'echo',
  '17': 'nova',
  '18': 'onyx',
};
const DEFAULT_VOICE = 'alloy';

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
    const { token, text, sceneId } = req.body || {};

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

    const voice = CHARACTER_VOICE_MAP[String(sceneId)] || DEFAULT_VOICE;

    const openaiResponse = await fetch('https://api.openai.com/v1/audio/speech', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${openaiApiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: 'tts-1',
        voice,
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

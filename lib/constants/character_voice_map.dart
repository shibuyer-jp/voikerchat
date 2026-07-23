/// キャラクター(sceneId)ごとの OpenAI TTS 音声ID割当表(T-35)。
///
/// OpenAI の標準音声(alloy/echo/fable/onyx/nova/shimmer)の範囲で、
/// docs/Persona-Design-v1.0.md / docs/tasks/T-34_premium-pro-scenes.md の
/// キャラクター性別・トーンに合わせて割り当てる。声の数よりキャラクターが
/// 多いため一部重複するが、キャラごとの明確な描写に影響はない。
///
/// 【注意】音声の正(source of truth)は api/tts.ts の CHARACTER_VOICE_MAP。
/// gpt-4o-mini-tts 移行後、サーバー側は voice + instructions(話し方指示)の
/// プロファイルを持ち、一部キャラの voice はこの表と異なる(ash/sage/ballad等)。
/// クライアントは sceneId を送るだけでよく、この表は参照用に残している。
const Map<String, String> characterVoiceMap = {
  '1': 'nova', // Sakura
  '2': 'echo', // Takuya
  '3': 'shimmer', // Yumi
  '4': 'onyx', // Kouki
  '5': 'nova', // Akari
  '6': 'onyx', // Kenji
  '7': 'echo', // Minato
  '8': 'shimmer', // Eiko
  '9': 'onyx', // Raiki
  '10': 'nova', // Hana
  '11': 'shimmer', // Luna
  '12': 'echo', // Taro
  '13': 'fable', // Jiro
  '14': 'shimmer', // Haruko
  '15': 'onyx', // Mori
  '16': 'echo', // Sato
  '17': 'nova', // Mizuki
  '18': 'onyx', // Tanaka
};

/// 未知のsceneId向けフォールバック音声。
const String defaultVoiceId = 'alloy';

String voiceIdForScene(String sceneId) =>
    characterVoiceMap[sceneId] ?? defaultVoiceId;

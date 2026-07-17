/// TtsEngine: 読み上げエンジンの共通インターフェース(T-35)。
///
/// [DeviceTtsEngine](端末内蔵、常時利用可) と [CloudTtsEngine]
/// (OpenAI TTS、Premiumまたは広告視聴日のみ)を同じ形で扱えるようにする。
abstract class TtsEngine {
  Future<void> speak(String text, {required String sceneId});
  Future<void> stop();
  bool get isSpeaking;
}

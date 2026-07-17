import 'text_to_speech_service.dart';
import 'tts_engine.dart';

/// DeviceTtsEngine: 端末内蔵TTS(コスト0、常時利用可)を [TtsEngine] として包む(T-35)。
class DeviceTtsEngine implements TtsEngine {
  final TextToSpeechService _service;

  DeviceTtsEngine(this._service);

  @override
  bool get isSpeaking => _service.isSpeaking;

  @override
  Future<void> speak(String text, {required String sceneId}) {
    // 端末TTSはキャラクター音声を選べない(OS標準の日本語音声のみ)。
    return _service.speak(text);
  }

  @override
  Future<void> stop() => _service.stop();
}

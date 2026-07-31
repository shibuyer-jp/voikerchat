import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'tts_engine.dart';

import '../../utils/platform_code.dart';
import '../locale_service.dart';

/// CloudTtsEngine: OpenAI TTS(api/tts.ts)によるクラウド読み上げ(T-35)。
///
/// Premium、または本日リワード広告を視聴済みのユーザーのみ利用可(サーバー側検証)。
/// 取得・再生に失敗した場合は例外を投げ、呼び出し側(ChatScreen)が
/// [DeviceTtsEngine] へフォールバックする(会話を止めないため、ここでは
/// 復旧は行わずログのみ)。
class CloudTtsEngine implements TtsEngine {
  final logger = Logger('CloudTtsEngine');
  static const String _baseUrl = 'https://voikerchat.com';

  final AudioPlayer _player = AudioPlayer();

  @override
  bool get isSpeaking => _player.playing;

  @override
  Future<void> speak(String text, {required String sceneId}) async {
    final token = Supabase.instance.client.auth.currentSession?.accessToken;
    if (token == null) {
      throw Exception('No auth token for cloud TTS');
    }

    final response = await http
        .post(
          Uri.parse('$_baseUrl/api/tts'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'token': token,
            'text': text,
            'sceneId': sceneId,
            'locale': LocaleService.resolveLocaleCodeForLogging(),
            'platform': currentPlatformCode(),
          }),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception('Cloud TTS request failed: ${response.statusCode}');
    }

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/voikerchat_cloud_tts.mp3');
    await file.writeAsBytes(response.bodyBytes, flush: true);

    await _player.setFilePath(file.path);
    await _player.play();
  }

  @override
  Future<void> stop() async {
    try {
      await _player.stop();
    } catch (e) {
      logger.info('CloudTtsEngine stop error: $e');
    }
  }

  void dispose() {
    _player.dispose();
  }
}

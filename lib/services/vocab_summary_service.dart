import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/platform_code.dart';
import 'locale_service.dart';

/// VocabSummaryService: セッション終了時に「今日の単語」を最大8個抽出する(T-36)。
///
/// 会話回数(rate_limits)は消費しない。セッション終了/リセット時に1回だけ呼ばれる想定。
class VocabSummaryService {
  final logger = Logger('VocabSummaryService');
  static const String _baseUrl = 'https://voikerchat.com';

  /// 戻り値: `{'success': true, 'words': [{'word':..., 'reading':..., 'meaning_en':...}]}` または
  /// `{'success': false, 'error': 'network'|'server_error'|'no_auth'}`
  Future<Map<String, dynamic>> getSummary({
    required String conversation,
    String? sceneId,
    String? sessionId,
  }) async {
    final token = Supabase.instance.client.auth.currentSession?.accessToken;
    if (token == null) {
      return {'success': false, 'error': 'no_auth'};
    }

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/api/vocab-summary'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'token': token,
              'conversation': conversation,
              'sceneId': sceneId,
              'locale': LocaleService.resolveLocaleCodeForLogging(),
              'platform': currentPlatformCode(),
              'sessionId': sessionId,
            }),
          )
          // Vercelコールドスタート+モデル応答を考慮して長め(15秒で失敗報告あり)
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        logger.info(
          '[VocabSummaryService] getSummary failed: ${response.statusCode} ${response.body}',
        );
        return {'success': false, 'error': 'server_error'};
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return {'success': true, 'words': data['words'] ?? []};
    } catch (e) {
      logger.info('[VocabSummaryService] getSummary error: $e');
      return {'success': false, 'error': 'network'};
    }
  }
}

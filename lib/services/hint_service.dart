import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/platform_code.dart';
import 'locale_service.dart';

/// HintService: 会話の続き方に迷った時のヒント(次に言えそうな例文+英訳)を取得する(T-36)。
///
/// 会話回数(rate_limits)は消費しない。T-31の辞書機能と合算の軽い日次上限を
/// api/hint.ts側でサーバー検証する。
class HintService {
  final logger = Logger('HintService');
  static const String _baseUrl = 'https://voikerchat.com';

  /// 戻り値: `{'success': true, 'data': {'example_ja': ..., 'example_en': ...}}` または
  /// `{'success': false, 'error': 'network'|'quota_reached'|'server_error'|'no_auth'}`
  Future<Map<String, dynamic>> getHint({
    required String context,
    String? sceneId,
  }) async {
    final token = Supabase.instance.client.auth.currentSession?.accessToken;
    if (token == null) {
      return {'success': false, 'error': 'no_auth'};
    }

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/api/hint'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'token': token,
              'context': context,
              'sceneId': sceneId,
              'locale': LocaleService.resolveLocaleCodeForLogging(),
              'platform': currentPlatformCode(),
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 429) {
        return {'success': false, 'error': 'quota_reached'};
      }
      if (response.statusCode != 200) {
        logger.info('[HintService] getHint failed: ${response.statusCode} ${response.body}');
        return {'success': false, 'error': 'server_error'};
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return {'success': true, 'data': data};
    } catch (e) {
      logger.info('[HintService] getHint error: $e');
      return {'success': false, 'error': 'network'};
    }
  }
}

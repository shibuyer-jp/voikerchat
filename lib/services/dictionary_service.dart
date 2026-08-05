import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/platform_code.dart';
import 'locale_service.dart';

/// DictionaryService: AIメッセージ内の語句の意味を調べる(T-31)。
///
/// 会話回数(rate_limits)は消費せず、api/define.ts 側で辞書専用の
/// 軽い日次上限を判定する。
class DictionaryService {
  final logger = Logger('DictionaryService');
  static const String _baseUrl = 'https://voikerchat.com';

  /// 語句の意味を調べる。
  /// 戻り値: `{'success': true, 'data': {...}}` または
  /// `{'success': false, 'error': 'network'|'quota_reached'|'server_error'|'no_auth'}`
  Future<Map<String, dynamic>> lookup({
    required String term,
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
            Uri.parse('$_baseUrl/api/define'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'token': token,
              'term': term,
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
        logger.info('[DictionaryService] lookup failed: ${response.statusCode} ${response.body}');
        return {'success': false, 'error': 'server_error'};
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return {'success': true, 'data': data};
    } catch (e) {
      logger.info('[DictionaryService] lookup error: $e');
      return {'success': false, 'error': 'network'};
    }
  }

  /// メッセージ全文を渡し、AIに「学習者にとって難しい語」を最大3つ選ばせて
  /// まとめて詳細を取得する(施策②、ふりがな抽出方式の廃止に伴う置き換え)。
  /// 戻り値: `{'success': true, 'data': {'words': [...]}}` または
  /// `{'success': false, 'error': 'network'|'quota_reached'|'server_error'|'no_auth'}`
  Future<Map<String, dynamic>> lookupSentence({
    required String context,
    String? sceneId,
    String? sceneLevel,
  }) async {
    final token = Supabase.instance.client.auth.currentSession?.accessToken;
    if (token == null) {
      return {'success': false, 'error': 'no_auth'};
    }

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/api/define'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'token': token,
              'mode': 'sentence',
              'context': context,
              'sceneId': sceneId,
              'sceneLevel': sceneLevel,
              'locale': LocaleService.resolveLocaleCodeForLogging(),
              'platform': currentPlatformCode(),
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 429) {
        return {'success': false, 'error': 'quota_reached'};
      }
      if (response.statusCode != 200) {
        logger.info(
          '[DictionaryService] lookupSentence failed: ${response.statusCode} ${response.body}',
        );
        return {'success': false, 'error': 'server_error'};
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return {'success': true, 'data': data};
    } catch (e) {
      logger.info('[DictionaryService] lookupSentence error: $e');
      return {'success': false, 'error': 'network'};
    }
  }
}

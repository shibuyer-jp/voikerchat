import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// RecapService: セッション終了時の「今日の言い直し」を最大3件取得する。
///
/// 競合分析(Speakの "Made for You")を参考にした個別化復習の簡易版。
/// 会話回数(rate_limits)は消費しない。VocabSummaryService と同じタイミングで
/// (セッション終了/リセット時に1回だけ)呼ばれる想定。
class RecapService {
  final logger = Logger('RecapService');
  static const String _baseUrl = 'https://voikerchat.com';

  /// 戻り値: `{'success': true, 'corrections': [{'original':..., 'improved':..., 'tip_en':...}]}`
  /// または `{'success': false, 'error': 'network'|'server_error'|'no_auth'}`
  Future<Map<String, dynamic>> getRecap({
    required String conversation,
    String? sceneId,
  }) async {
    final token = Supabase.instance.client.auth.currentSession?.accessToken;
    if (token == null) {
      return {'success': false, 'error': 'no_auth'};
    }

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/api/recap'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'token': token,
              'conversation': conversation,
              'sceneId': sceneId,
            }),
          )
          // vocab-summary と同様、Vercelコールドスタート+モデル応答を考慮して長め
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        logger.info(
          '[RecapService] getRecap failed: ${response.statusCode} ${response.body}',
        );
        return {'success': false, 'error': 'server_error'};
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return {'success': true, 'corrections': data['corrections'] ?? []};
    } catch (e) {
      logger.info('[RecapService] getRecap error: $e');
      return {'success': false, 'error': 'network'};
    }
  }
}

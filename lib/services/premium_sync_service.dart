import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

import '../utils/platform_code.dart';
import 'locale_service.dart';

/// クライアント側RevenueCatとサーバー側 rate_limits.is_premium の判定不整合
/// (2026-08-07、再インストール時にRevenueCatは復元されるがサーバー側は
/// 取り残される不具合。internal-docs/reports/premium_state_mismatch_20260807.md
/// 参照)を解消するための再照合サービス。
///
/// クライアントは「同期が必要そうか」の判断のみ行い(main.dart参照)、
/// 実際のPremium真偽判定はサーバー側がRevenueCat REST APIへ直接問い合わせて
/// 行う(api/premium-sync.ts)。クライアントの自己申告は一切信用されない設計。
class PremiumSyncService {
  final logger = Logger('PremiumSyncService');
  static const String _baseUrl = 'https://voikerchat.com';

  /// 戻り値: サーバー側 rate_limits.is_premium が実際に更新されたか(synced)。
  Future<bool> reconcile({required String accessToken}) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/api/premium-sync'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'token': accessToken,
              'locale': LocaleService.resolveLocaleCodeForLogging(),
              'platform': currentPlatformCode(),
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        logger.info(
          '[PremiumSyncService] reconcile failed: ${response.statusCode} ${response.body}',
        );
        return false;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final synced = data['synced'] == true;
      logger.info(
        '[PremiumSyncService] reconcile result: synced=$synced isPremium=${data['isPremium']}',
      );
      return synced;
    } catch (e) {
      logger.info('[PremiumSyncService] reconcile error: $e');
      return false;
    }
  }
}

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/rate_limit_constants.dart';
import '../models/rate_limit.dart';

class RateLimitService {
  final logger = Logger('RateLimitService');
  static const String _baseUrl = 'https://voikerchat.com';

  final SupabaseClient _supabase;

  RateLimitService(this._supabase);

  /// Fetch current rate limit status for user
  Future<RateLimit> getRateLimit(String userId) async {
    try {
      final response = await _supabase
          .from('rate_limits')
          .select()
          .eq('user_id', userId)
          .single();

      return RateLimit.fromJson(response);
    } catch (e) {
      // If no record exists, return default (free tier)
      return RateLimit(
        userId: userId,
        dailyLimit: RateLimitConstants.freeDailyLimit,
        usedToday: 0,
        lastResetUtc: DateTime.now(),
        isPremium: false,
      );
    }
  }

  /// Reset daily counter (called by scheduled job or manually)
  Future<void> resetDailyLimit(String userId) async {
    try {
      await _supabase.from('rate_limits').update({
        'used_today': 0,
        'last_reset_utc': DateTime.now().toUtc().toIso8601String(),
      }).eq('user_id', userId);
    } catch (e) {
      logger.info('RateLimitService reset error: $e');
    }
  }

  /// Get remaining calls for display (handles both free and premium)
  Future<int> getRemainingCalls(String userId) async {
    final rateLimit = await getRateLimit(userId);
    return rateLimit.remainingCalls;
  }

  /// Get usage percentage for progress indicator
  Future<double> getUsagePercentage(String userId) async {
    final rateLimit = await getRateLimit(userId);
    return rateLimit.usagePercentage;
  }

  /// 広告視聴の報酬として当日の利用上限を +5（最大 10）引き上げる。
  ///
  /// サーバー(api/ad-reward.ts、service role)経由で更新する。クライアントから
  /// rate_limits を直接書き換える経路は廃止済み(RLSで禁止、
  /// docs/migrations/2026-07-17_lock_rate_limits_client_write.sql 参照)。
  /// これにより usage_logs.ad_reward の記録とセットで、偽装・改ざんを防ぐ。
  Future<void> grantAdBonus(String userId) async {
    final token = _supabase.auth.currentSession?.accessToken;
    if (token == null) {
      logger.info('[RateLimitService] grantAdBonus skipped: no auth token');
      return;
    }

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/api/ad-reward'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'token': token}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        logger.info(
          '[RateLimitService] grantAdBonus failed: ${response.statusCode} ${response.body}',
        );
        return;
      }

      logger.info('[RateLimitService] Ad bonus granted: ${response.body}');
    } catch (e) {
      logger.info('[RateLimitService] grantAdBonus error: $e');
    }
  }

  /// 広告在庫切れフォールバック時のクラウドTTS解放をサーバーに記録する(T-35バグ修正)。
  ///
  /// api/tts.ts は「本日の usage_logs.ad_reward イベント有無」でクラウドTTSを
  /// 許可するため、ローカルフラグだけではサーバーに拒否され端末TTSに落ちる。
  /// mode=tts_fallback は +5回を付与せず ad_reward イベントのみ記録する。
  /// 戻り値: サーバー記録に成功したか(失敗時はクラウドTTSは使えない)。
  Future<bool> recordTtsFallbackUnlock() async {
    final token = _supabase.auth.currentSession?.accessToken;
    if (token == null) {
      logger.info('[RateLimitService] recordTtsFallbackUnlock skipped: no auth token');
      return false;
    }

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/api/ad-reward'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'token': token, 'mode': 'tts_fallback'}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        logger.info(
          '[RateLimitService] recordTtsFallbackUnlock failed: ${response.statusCode} ${response.body}',
        );
        return false;
      }
      logger.info('[RateLimitService] TTS fallback unlock recorded: ${response.body}');
      return true;
    } catch (e) {
      logger.info('[RateLimitService] recordTtsFallbackUnlock error: $e');
      return false;
    }
  }
}

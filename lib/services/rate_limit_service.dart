import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/rate_limit.dart';

class RateLimitService {
  final logger = Logger('RateLimitService');

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
      // If no record exists, return default (free tier: 5 calls/day)
      return RateLimit(
        userId: userId,
        dailyLimit: 5,
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
  /// プレミアム/上限到達済みの場合は何もしない。
  Future<void> grantAdBonus(String userId) async {
    try {
      final rateLimit = await getRateLimit(userId);
      if (rateLimit.isPremium) return;

      final newLimit = (rateLimit.dailyLimit + 5).clamp(0, 10);
      if (newLimit == rateLimit.dailyLimit) return;

      await _supabase.from('rate_limits').update({
        'daily_limit': newLimit,
      }).eq('user_id', userId);

      logger.info('[RateLimitService] Ad bonus granted: daily_limit=$newLimit');
    } catch (e) {
      logger.info('[RateLimitService] grantAdBonus error: $e');
    }
  }
}

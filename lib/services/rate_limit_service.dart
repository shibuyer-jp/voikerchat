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

  /// Check and increment rate limit after API call
  /// Returns true if call succeeded within limits, false if limited
  Future<bool> checkAndIncrement(String userId) async {
    try {
      final rateLimit = await getRateLimit(userId);

      // Premium users have no limit
      if (rateLimit.isPremium) {
        return true;
      }

      // Check if within daily limit
      if (!rateLimit.canMakeCall) {
        return false;
      }

      // Increment counter
      await _supabase.from('rate_limits').update({
        'used_today': rateLimit.usedToday + 1,
      }).eq('user_id', userId);

      return true;
    } catch (e) {
      logger.info('RateLimitService error: $e');
      // On error, allow call (fail-open approach)
      return true;
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
}

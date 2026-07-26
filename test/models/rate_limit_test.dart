import 'package:flutter_test/flutter_test.dart';
import 'package:voikerchat/constants/rate_limit_constants.dart';
import 'package:voikerchat/models/rate_limit.dart';

void main() {
  group('RateLimit.fromJson daily_limit fallback', () {
    test('falls back to RateLimitConstants.freeDailyLimit when daily_limit is missing', () {
      final model = RateLimit.fromJson({
        'user_id': 'u1',
        'used_today': 0,
        'last_reset_utc': '2026-07-26T00:00:00.000Z',
        'is_premium': false,
      });

      expect(model.dailyLimit, RateLimitConstants.freeDailyLimit);
    });

    test('uses server-provided daily_limit when present (e.g. ad-bonus applied)', () {
      final model = RateLimit.fromJson({
        'user_id': 'u1',
        'daily_limit': RateLimitConstants.freeDailyCap,
        'used_today': 5,
        'last_reset_utc': '2026-07-26T00:00:00.000Z',
        'is_premium': false,
      });

      expect(model.dailyLimit, RateLimitConstants.freeDailyCap);
    });
  });
}

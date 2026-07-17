import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voikerchat/services/voice/cloud_tts_unlock_service.dart';

void main() {
  group('CloudTtsUnlockService (T-35)', () {
    test('isUnlockedToday is false before markUnlockedToday is called', () async {
      SharedPreferences.setMockInitialValues({});
      final service = CloudTtsUnlockService();

      expect(await service.isUnlockedToday(), isFalse);
    });

    test('isUnlockedToday is true after markUnlockedToday is called', () async {
      SharedPreferences.setMockInitialValues({});
      final service = CloudTtsUnlockService();

      await service.markUnlockedToday();

      expect(await service.isUnlockedToday(), isTrue);
    });

    test('isUnlockedToday is false for a stale (yesterday) date', () async {
      SharedPreferences.setMockInitialValues({
        'cloud_tts_unlocked_date': '2000-01-01',
      });
      final service = CloudTtsUnlockService();

      expect(await service.isUnlockedToday(), isFalse);
    });
  });
}

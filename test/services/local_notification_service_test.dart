import 'package:flutter_test/flutter_test.dart';
import 'package:voikerchat/services/local_notification_service.dart';

void main() {
  group('LocalNotificationService', () {
    late LocalNotificationService service;

    setUp(() {
      service = LocalNotificationService();
    });

    test('singleton pattern', () {
      final service1 = LocalNotificationService();
      final service2 = LocalNotificationService();
      expect(identical(service1, service2), true);
    });

    test('isInitialized is false before initialization', () {
      expect(service.isInitialized, false);
    });

    test('NotificationIds constants are defined', () {
      expect(NotificationIds.dailyReminder8, 1001);
      expect(NotificationIds.dailyReminder12, 1002);
      expect(NotificationIds.dailyReminder19, 1003);
      expect(NotificationIds.milestone3Days, 2001);
      expect(NotificationIds.milestone7Days, 2002);
      expect(NotificationIds.milestone14Days, 2003);
      expect(NotificationIds.milestone30Days, 2004);
      expect(NotificationIds.premiumUpsellStage1, 3001);
      expect(NotificationIds.premiumUpsellStage2, 3002);
      expect(NotificationIds.premiumUpsellStage3, 3003);
      expect(NotificationIds.featureUpdate, 4001);
    });

    test('NotificationIds values are unique', () {
      final ids = [
        NotificationIds.dailyReminder8,
        NotificationIds.dailyReminder12,
        NotificationIds.dailyReminder19,
        NotificationIds.milestone3Days,
        NotificationIds.milestone7Days,
        NotificationIds.milestone14Days,
        NotificationIds.milestone30Days,
        NotificationIds.premiumUpsellStage1,
        NotificationIds.premiumUpsellStage2,
        NotificationIds.premiumUpsellStage3,
        NotificationIds.featureUpdate,
      ];

      final uniqueIds = ids.toSet();
      expect(ids.length, uniqueIds.length);
    });
  });
}

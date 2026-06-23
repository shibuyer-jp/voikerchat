import 'package:flutter_test/flutter_test.dart';
import 'package:voikerchat/models/notification_data_model.dart';

void main() {
  group('NotificationDataModel', () {
    const testData = {
      'id': '12345',
      'type': 'daily_reminder',
      'title': 'Test Title',
      'body': 'Test Body',
      'imageUrl': 'https://example.com/image.png',
    };

    test('fromJson creates model correctly', () {
      final model = NotificationDataModel.fromJson(testData);
      expect(model.id, '12345');
      expect(model.type, 'daily_reminder');
      expect(model.title, 'Test Title');
      expect(model.body, 'Test Body');
      expect(model.imageUrl, 'https://example.com/image.png');
      expect(model.isRead, false);
    });

    test('toJson converts model correctly', () {
      final model = NotificationDataModel(
        id: '12345',
        type: 'daily_reminder',
        title: 'Test Title',
        body: 'Test Body',
      );
      final json = model.toJson();
      expect(json['id'], '12345');
      expect(json['type'], 'daily_reminder');
      expect(json['title'], 'Test Title');
      expect(json['body'], 'Test Body');
    });

    test('fromFirebaseMap creates model from Firebase data', () {
      const firebaseData = {
        'notification_id': 'fb-123',
        'notification_type': 'milestone',
        'title': 'Milestone Achievement',
        'body': '7 days streaks!',
        'image_url': 'https://example.com/badge.png',
      };

      final model = NotificationDataModel.fromFirebaseMap(firebaseData);
      expect(model.id, 'fb-123');
      expect(model.type, 'milestone');
      expect(model.title, 'Milestone Achievement');
      expect(model.body, '7 days streaks!');
      expect(model.imageUrl, 'https://example.com/badge.png');
    });

    test('copyWith updates fields correctly', () {
      final original = NotificationDataModel(
        id: '123',
        type: 'daily_reminder',
        title: 'Original',
        body: 'Original Body',
      );

      final updated = original.copyWith(
        title: 'Updated',
        isRead: true,
      );

      expect(updated.id, '123');
      expect(updated.title, 'Updated');
      expect(updated.isRead, true);
      expect(updated.body, 'Original Body');
    });

    test('equality comparison works', () {
      final model1 = NotificationDataModel(
        id: '123',
        type: 'daily_reminder',
        title: 'Test',
        body: 'Body',
      );

      final model2 = NotificationDataModel(
        id: '123',
        type: 'daily_reminder',
        title: 'Test',
        body: 'Body',
      );

      expect(model1 == model2, true);
    });

    test('NotificationTypes constants are defined', () {
      expect(NotificationTypes.dailyReminder, 'daily_reminder');
      expect(NotificationTypes.milestone, 'milestone');
      expect(NotificationTypes.premiumUpsell, 'premium_upsell');
      expect(NotificationTypes.featureUpdate, 'feature_update');
      expect(NotificationTypes.unknown, 'unknown');
    });

    test('toString includes key information', () {
      final model = NotificationDataModel(
        id: 'test-id',
        type: 'milestone',
        title: 'Test Title',
        body: 'Test Body',
      );

      final str = model.toString();
      expect(str.contains('test-id'), true);
      expect(str.contains('milestone'), true);
      expect(str.contains('Test Title'), true);
    });

    test('createdAt defaults to current time if not provided', () {
      final model = NotificationDataModel(
        id: '123',
        type: 'daily_reminder',
        title: 'Test',
        body: 'Body',
      );

      expect(model.createdAt.isBefore(DateTime.now().add(Duration(seconds: 1))), true);
    });
  });

  group('NotificationDataModel JSON Serialization', () {
    test('round-trip serialization preserves data', () {
      final original = NotificationDataModel(
        id: 'round-trip-test',
        type: 'premium_upsell',
        title: 'Premium Available',
        body: 'Unlock premium features',
        imageUrl: 'https://example.com/premium.png',
      );

      final json = original.toJson();
      final restored = NotificationDataModel.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.type, original.type);
      expect(restored.title, original.title);
      expect(restored.body, original.body);
      expect(restored.imageUrl, original.imageUrl);
    });

    test('handles missing optional fields gracefully', () {
      final minimal = {
        'id': 'minimal-123',
        'type': 'feature_update',
        'title': 'New Feature',
        'body': 'Check it out',
      };

      final model = NotificationDataModel.fromJson(minimal);
      expect(model.id, 'minimal-123');
      expect(model.imageUrl, null);
      expect(model.customData, null);
    });
  });
}

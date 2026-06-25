// Stub implementation for Firebase Messaging (Web compatibility)
import 'dart:async';

enum AuthorizationStatus {
  authorized,
  denied,
  notDetermined,
  provisional,
}

class NotificationSettings {
  final AuthorizationStatus authorizationStatus;
  NotificationSettings({required this.authorizationStatus});
}

class Notification {
  final String? title;
  final String? body;
  Notification({this.title, this.body});
}

class RemoteMessage {
  final Notification? notification;
  final Map<String, dynamic> data;
  RemoteMessage({this.notification, this.data = const {}});
}

class FirebaseMessaging {
  static final FirebaseMessaging instance = FirebaseMessaging._();
  FirebaseMessaging._();
  
  static Stream<RemoteMessage> get onMessage => Stream.empty();
  static Stream<RemoteMessage> get onMessageOpenedApp => Stream.empty();
  static Stream<String> get onTokenRefresh => Stream.empty();
  
  static Future<void> onBackgroundMessage(
    Future<void> Function(RemoteMessage) handler,
  ) async {
    // Web では使用できない
  }
  
  Future<String?> getToken() async => null;
  Future<String?> getInitialMessage() async => null;
  Future<void> deleteToken() async {}
  Future<void> requestPermission({
    bool alert = true,
    bool announcement = false,
    bool badge = true,
    bool carPlay = false,
    bool criticalAlert = false,
    bool provisional = false,
    bool sound = true,
  }) async {}
  Future<String?> getAPNSToken() async => null;
  Future<NotificationSettings> getNotificationSettings() async {
    return NotificationSettings(
      authorizationStatus: AuthorizationStatus.authorized,
    );
  }
  Future<void> subscribeToTopic(String topic) async {}
  Future<void> unsubscribeFromTopic(String topic) async {}
}

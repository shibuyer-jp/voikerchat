// Stub implementation for Firebase Messaging (Web compatibility)

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

class FirebaseMessaging {
  static final FirebaseMessaging instance = FirebaseMessaging._();
  FirebaseMessaging._();
  
  Stream get onMessage => Stream.empty();
  Stream get onMessageOpenedApp => Stream.empty();
  Stream get onTokenRefresh => Stream.empty();
  
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

class RemoteMessage {
  final String? notification;
  final Map<String, dynamic> data;
  RemoteMessage({this.notification, this.data = const {}});
}

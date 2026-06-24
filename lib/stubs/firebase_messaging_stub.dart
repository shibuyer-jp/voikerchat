// Stub implementation for Firebase Messaging (Web compatibility)
class FirebaseMessaging {
  static final FirebaseMessaging instance = FirebaseMessaging._();
  FirebaseMessaging._();
  Stream get onMessage => Stream.empty();
  Stream get onMessageOpenedApp => Stream.empty();
  Future<String?> getToken() async => null;
  Future<String?> getInitialMessage() async => null;
  Future<void> deleteToken() async {}
}

class RemoteMessage {
  final String? notification;
  RemoteMessage({this.notification});
}

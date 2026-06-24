import 'package:logging/logging.dart';
import 'package:firebase_core/firebase_core.dart'
  if (dart.library.html) 'package:voikerchat/stubs/firebase_core_stub.dart';
import 'package:firebase_messaging/firebase_messaging.dart'
  if (dart.library.html) 'package:voikerchat/stubs/firebase_messaging_stub.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voikerchat/models/notification_data_model.dart';
import 'local_notification_service.dart';

/// RemoteNotificationService
/// Firebase Cloud Messaging (FCM) を使用したリモート通知管理
class RemoteNotificationService {
  final logger = Logger('RemoteNotificationService');

  static final RemoteNotificationService _instance = RemoteNotificationService._internal();

  factory RemoteNotificationService() {
    return _instance;
  }

  RemoteNotificationService._internal();

  late FirebaseMessaging _fcm;
  late LocalNotificationService _localNotificationService;
  late SharedPreferences _prefs;
  bool _isInitialized = false;

  /// 初期化状態確認
  bool get isInitialized => _isInitialized;

  /// FCM トークン取得（キャッシュ済み）
  String? _cachedToken;

  /// コールバック関数
  void Function(NotificationDataModel)? _onMessageHandler;
  void Function(NotificationDataModel)? _onTerminatedHandler;

  /// RemoteNotificationService の初期化
  /// [firebaseInitialized] Firebase 初期化済みの場合 true を渡す
  Future<void> initialize({
    required LocalNotificationService localNotificationService,
    bool firebaseInitialized = false,
  }) async {
    if (_isInitialized) return;

    _localNotificationService = localNotificationService;
    _prefs = await SharedPreferences.getInstance();

    // Firebase 初期化（Web では失敗を許容）
    try {
      if (!firebaseInitialized) {
        try {
          await Firebase.initializeApp();
        } catch (e) {
          logger.info('[RemoteNotificationService] Firebase already initialized: $e');
        }
      }

      _fcm = FirebaseMessaging.instance;

      // 通知権限リクエスト（iOS）
      await _fcm.requestPermission(
        alert: true,
        announcement: true,
        badge: true,
        carPlay: false,
        criticalAlert: true,
        provisional: false,
        sound: true,
      );

      // FCM トークン取得
      await _refreshFCMToken();

      // メッセージハンドラー設定
      _setupMessageHandlers();

      _isInitialized = true;
      logger.info('[RemoteNotificationService] Initialized successfully');
    } catch (e) {
      logger.warning('[RemoteNotificationService] Firebase initialization skipped (Web/non-mobile): $e');
      // Web では通知機能なしで継続
      _isInitialized = true;
    }
  }

  /// FCM トークンをリフレッシュ
  Future<String?> _refreshFCMToken() async {
    try {
      final token = await _fcm.getToken();
      if (token != null) {
        _cachedToken = token;
        await _prefs.setString('fcm_token', token);
        logger.info('[RemoteNotificationService] FCM token refreshed: ${token.substring(0, 20)}...');
      }
      return token;
    } catch (e) {
      logger.info('[RemoteNotificationService] Error getting FCM token: $e');
      return null;
    }
  }

  /// FCM トークン取得
  Future<String?> getFCMToken() async {
    if (_cachedToken != null) {
      return _cachedToken;
    }
    return await _refreshFCMToken();
  }

  /// キャッシュ済み FCM トークン取得（同期的）
  String? getCachedFCMToken() {
    return _cachedToken ?? _prefs.getString('fcm_token');
  }

  /// FCM トークンリセット（ログアウト時など）
  Future<void> deleteFCMToken() async {
    try {
      await _fcm.deleteToken();
      _cachedToken = null;
      await _prefs.remove('fcm_token');
      logger.info('[RemoteNotificationService] FCM token deleted');
    } catch (e) {
      logger.info('[RemoteNotificationService] Error deleting FCM token: $e');
    }
  }

  /// メッセージハンドラー設定
  void _setupMessageHandlers() {
    // Web では notification 機能がないため、スキップ
    try {
      // フォアグラウンド通知
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        logger.info('[RemoteNotificationService] Message received in foreground');
        _handleMessage(message, isForeground: true);
      });

      // バックグラウンド/終了状態での通知タップ
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        logger.info('[RemoteNotificationService] App opened via notification');
        _handleMessage(message, isFromTerminated: true);
      });

      // 終了状態での初期メッセージ取得
      FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
        if (message != null) {
          logger.info('[RemoteNotificationService] App launched via notification');
          _handleMessage(message, isFromTerminated: true);
        }
      });

      // トークンリフレッシュリスナー
      _fcm.onTokenRefresh.listen((String newToken) {
        _cachedToken = newToken;
        _prefs.setString('fcm_token', newToken);
        logger.info('[RemoteNotificationService] FCM token refreshed: ${newToken.substring(0, 20)}...');
      });
    } catch (e) {
      // Web では使用できない API → 無視
      logger.info('[RemoteNotificationService] Message handlers setup skipped (Web environment): $e');
    }
  }

  /// メッセージハンドリング
  void _handleMessage(
    RemoteMessage message, {
    bool isForeground = false,
    bool isFromTerminated = false,
  }) async {
    try {
      final notificationData = NotificationDataModel.fromFirebaseMap(
        message.data,
      );

      // フォアグラウンドの場合、ローカル通知を表示
      if (isForeground && message.notification != null) {
        await _localNotificationService.showNotification(
          id: notificationData.id.hashCode % 10000,
          title: message.notification!.title ?? notificationData.title,
          body: message.notification!.body ?? notificationData.body,
          payload: notificationData.id,
        );
      }

      // コールバック関数を呼び出し
      if (isFromTerminated && _onTerminatedHandler != null) {
        _onTerminatedHandler!(notificationData);
      } else if (_onMessageHandler != null) {
        _onMessageHandler!(notificationData);
      }

      // 通知を既読マーク（任意）
      _markNotificationAsRead(notificationData.id);
    } catch (e) {
      logger.info('[RemoteNotificationService] Error handling message: $e');
    }
  }

  /// メッセージハンドラーを設定
  void setMessageHandler(
    void Function(NotificationDataModel) onMessage, {
    void Function(NotificationDataModel)? onTerminated,
  }) {
    _onMessageHandler = onMessage;
    _onTerminatedHandler = onTerminated;
  }

  /// 通知を既読マーク
  void _markNotificationAsRead(String notificationId) {
    final readKey = 'notification_read_$notificationId';
    _prefs.setBool(readKey, true);
  }

  /// 通知が既読かどうか確認
  bool isNotificationRead(String notificationId) {
    return _prefs.getBool('notification_read_$notificationId') ?? false;
  }

  /// トピック購読（ユーザーグループ通知用）
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _fcm.subscribeToTopic(topic);
      logger.info('[RemoteNotificationService] Subscribed to topic: $topic');
    } catch (e) {
      logger.info('[RemoteNotificationService] Error subscribing to topic: $e');
    }
  }

  /// トピック購読解除
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _fcm.unsubscribeFromTopic(topic);
      logger.info('[RemoteNotificationService] Unsubscribed from topic: $topic');
    } catch (e) {
      logger.info('[RemoteNotificationService] Error unsubscribing from topic: $e');
    }
  }

  /// 初期化時の推奨トピック購読
  Future<void> subscribeToDefaultTopics() async {
    const topics = [
      'all_users',        // すべてのユーザー
      'premium_users',    // プレミアムユーザー（後で条件付き）
      'japanese_learners', // 日本語学習者
    ];

    for (final topic in topics) {
      await subscribeToTopic(topic);
    }
  }

  /// APNs トークン取得（iOS）
  Future<String?> getAPNsToken() async {
    try {
      final token = await _fcm.getAPNSToken();
      return token;
    } catch (e) {
      logger.info('[RemoteNotificationService] Error getting APNs token: $e');
      return null;
    }
  }

  /// 通知権限確認
  Future<AuthorizationStatus> getAuthorizationStatus() async {
    return await _fcm.getNotificationSettings().then(
          (NotificationSettings settings) => settings.authorizationStatus,
        );
  }
}

/// FCM トピック定数
class FCMTopics {
  static const String allUsers = 'all_users';
  static const String premiumUsers = 'premium_users';
  static const String japaneseContext = 'japanese_learners';
  static const String newFeatures = 'new_features';
  static const String bugFixes = 'bug_fixes';
}

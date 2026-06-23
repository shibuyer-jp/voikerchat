import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;

/// LocalNotificationService
/// ローカル通知の初期化、スケジューリング、キャンセルを一元管理
class LocalNotificationService {
  static final LocalNotificationService _instance = LocalNotificationService._internal();

  factory LocalNotificationService() {
    return _instance;
  }

  LocalNotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  /// 初期化状態を確認
  bool get isInitialized => _isInitialized;

  /// LocalNotificationService の初期化
  /// [onSelectNotification] コールバック関数（通知タップ時）
  Future<void> initialize({
    required Function(String? payload) onSelectNotification,
  }) async {
    if (_isInitialized) return;

    // Timezone データベース初期化
    tzdata.initializeTimeZones();

    // Android設定
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS設定
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      defaultPresentationOptions: {
        DarwinNotificationPresentationOption.badge,
        DarwinNotificationPresentationOption.sound,
        DarwinNotificationPresentationOption.alert,
      },
    );

    final InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        onSelectNotification(response.payload);
      },
      onDidReceiveBackgroundNotificationResponse: _notificationTapBackground,
    );

    _isInitialized = true;
  }

  /// バックグラウンド通知タップ処理（静的メソッド）
  @pragma('vm:entry-point')
  static void _notificationTapBackground(NotificationResponse response) {
    // バックグラウンド/終了状態での通知タップ処理
    // 実装例: ディープリンク処理、アナリティクス記録など
  }

  /// 即座に通知を表示
  /// [id] 通知ID, [title] タイトル, [body] 本文
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_isInitialized) {
      throw Exception('LocalNotificationService is not initialized');
    }

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'voikerchat_channel',
      'Voikerchat',
      channelDescription: 'Voikerchat notifications',
      importance: Importance.max,
      priority: Priority.high,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentSound: true,
      presentBadge: true,
      presentAlert: true,
    );

    final NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(id, title, body, details, payload: payload);
  }

  /// 定時通知をスケジュール
  /// [id] 通知ID, [title] タイトル, [body] 本文
  /// [scheduledTime] 指定日時, [payload] 追加データ
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? payload,
  }) async {
    if (!_isInitialized) {
      throw Exception('LocalNotificationService is not initialized');
    }

    final TZDateTime tzTime = _convertToTZDateTime(scheduledTime);

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'voikerchat_channel',
      'Voikerchat',
      channelDescription: 'Voikerchat notifications',
      importance: Importance.max,
      priority: Priority.high,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentSound: true,
      presentBadge: true,
      presentAlert: true,
    );

    final NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tzTime,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAndAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );
  }

  /// 毎日指定時刻に通知をスケジュール（繰り返し）
  /// [id] 通知ID, [title] タイトル, [body] 本文
  /// [time] 毎日の実行時刻 (例: TimeOfDay(hour: 8, minute: 0))
  /// [payload] 追加データ
  Future<void> scheduleDailyNotification({
    required int id,
    required String title,
    required String body,
    required ({int hour, int minute}) time,
    String? payload,
  }) async {
    if (!_isInitialized) {
      throw Exception('LocalNotificationService is not initialized');
    }

    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );

    // 過去の時刻の場合は翌日にスケジュール
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'voikerchat_channel',
      'Voikerchat',
      channelDescription: 'Voikerchat notifications',
      importance: Importance.max,
      priority: Priority.high,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentSound: true,
      presentBadge: true,
      presentAlert: true,
    );

    final NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduledDate,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAndAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: payload,
    );
  }

  /// 通知をキャンセル
  /// [id] 通知ID
  Future<void> cancelNotification(int id) async {
    await _plugin.cancel(id);
  }

  /// すべての通知をキャンセル
  Future<void> cancelAllNotifications() async {
    await _plugin.cancelAll();
  }

  /// スケジュール済み通知の一覧取得
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _plugin.pendingNotificationRequests();
  }

  /// DateTime を TZDateTime に変換
  TZDateTime _convertToTZDateTime(DateTime dateTime) {
    final tz.TZDateTime tzDateTime = tz.TZDateTime.from(dateTime, tz.local);
    return tzDateTime;
  }
}

/// 通知ID定義（管理用定数）
class NotificationIds {
  /// 毎日のリマインダー通知ID
  static const int dailyReminder8 = 1001;
  static const int dailyReminder12 = 1002;
  static const int dailyReminder19 = 1003;

  /// マイルストーン通知ID
  static const int milestone3Days = 2001;
  static const int milestone7Days = 2002;
  static const int milestone14Days = 2003;
  static const int milestone30Days = 2004;

  /// プレミアム勧導通知ID
  static const int premiumUpsellStage1 = 3001;
  static const int premiumUpsellStage2 = 3002;
  static const int premiumUpsellStage3 = 3003;

  /// 機能更新通知ID
  static const int featureUpdate = 4001;
}

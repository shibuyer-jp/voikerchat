import 'package:shared_preferences/shared_preferences.dart';
import 'local_notification_service.dart';

/// NotificationScheduler
/// 4種類の通知（Daily Reminder, Milestone, Premium Upsell, Feature Update）を一元管理
class NotificationScheduler {
  static final NotificationScheduler _instance = NotificationScheduler._internal();

  factory NotificationScheduler() {
    return _instance;
  }

  NotificationScheduler._internal();

  late LocalNotificationService _notificationService;
  late SharedPreferences _prefs;

  /// 初期化
  Future<void> initialize(LocalNotificationService notificationService) async {
    _notificationService = notificationService;
    _prefs = await SharedPreferences.getInstance();
  }

  /// ===== Daily Reminder Notifications =====

  /// 毎日のリマインダー通知をスケジュール
  /// 時刻: 8:00, 12:00, 19:00 JST
  Future<void> scheduleDailyReminders() async {
    const times = [
      (hour: 8, minute: 0),
      (hour: 12, minute: 0),
      (hour: 19, minute: 0),
    ];

    const ids = [
      NotificationIds.dailyReminder8,
      NotificationIds.dailyReminder12,
      NotificationIds.dailyReminder19,
    ];

    final titles = [
      '朝の学習時間',
      '昼休みの学習',
      '夕方の学習時間',
    ];

    final bodies = [
      'Voikerchatで日本語を学習しましょう！',
      'Voikerchatで日本語会話の練習をしましょう！',
      'Voikerchatで今日の学習を振り返りましょう！',
    ];

    for (int i = 0; i < times.length; i++) {
      try {
        await _notificationService.scheduleDailyNotification(
          id: ids[i],
          title: titles[i],
          body: bodies[i],
          time: times[i],
          payload: 'daily_reminder',
        );
        print('[NotificationScheduler] Daily reminder scheduled: ${times[i].hour}:${times[i].minute.toString().padLeft(2, '0')}');
      } catch (e) {
        print('[NotificationScheduler] Error scheduling daily reminder: $e');
      }
    }
  }

  /// 日間のリマインダーをキャンセル
  Future<void> cancelDailyReminders() async {
    const ids = [
      NotificationIds.dailyReminder8,
      NotificationIds.dailyReminder12,
      NotificationIds.dailyReminder19,
    ];

    for (final id in ids) {
      await _notificationService.cancelNotification(id);
    }
  }

  /// ===== Milestone Notifications =====

  /// マイルストーン通知をスケジュール（3日、7日、14日、30日達成時）
  Future<void> checkAndScheduleMilestoneNotifications(int streakDays) async {
    final milestones = [
      (days: 3, id: NotificationIds.milestone3Days, title: '🎉 3日間連続達成！', body: '継続は力なり！この調子で頑張りましょう'),
      (days: 7, id: NotificationIds.milestone7Days, title: '⭐ 1週間連続達成！', body: 'すごい！習慣が形成されています'),
      (days: 14, id: NotificationIds.milestone14Days, title: '💪 2週間連続達成！', body: 'あなたは確実に成長しています'),
      (days: 30, id: NotificationIds.milestone30Days, title: '🏆 30日連続達成！', body: '素晴らしい！あなたは学習の達人です'),
    ];

    for (final milestone in milestones) {
      final shownKey = 'milestone_${milestone.days}d_shown';
      final alreadyShown = _prefs.getBool(shownKey) ?? false;

      if (streakDays >= milestone.days && !alreadyShown) {
        try {
          await _notificationService.showNotification(
            id: milestone.id,
            title: milestone.title,
            body: milestone.body,
            payload: 'milestone',
          );
          await _prefs.setBool(shownKey, true);
          print('[NotificationScheduler] Milestone notification shown: ${milestone.days}d');
        } catch (e) {
          print('[NotificationScheduler] Error showing milestone notification: $e');
        }
      }
    }
  }

  /// マイルストーン記録をリセット（ストリーク終了時）
  Future<void> resetMilestoneRecords() async {
    const keys = [
      'milestone_3d_shown',
      'milestone_7d_shown',
      'milestone_14d_shown',
      'milestone_30d_shown',
    ];

    for (final key in keys) {
      await _prefs.remove(key);
    }
  }

  /// ===== Premium Upsell Notifications =====

  /// プレミアム勧導通知をスケジュール
  /// Stage 1: 初日（Day 1）, Stage 2: 3日連続後, Stage 3: 7日連続後
  Future<void> schedulePremiumUpsellNotification({
    required int stage,
    required DateTime scheduledTime,
  }) async {
    final Map<int, (int, String, String)> stageConfig = {
      1: (NotificationIds.premiumUpsellStage1, '🎁 プレミアムコースをお試しください', 'より多くの会話練習で上達が加速します'),
      2: (NotificationIds.premiumUpsellStage2, '⭐ プレミアムで学習を加速', '3日間の連続使用で効果を実感！'),
      3: (NotificationIds.premiumUpsellStage3, '🚀 プレミアムで無制限学習', '7日間の成長を次のレベルへ'),
    };

    if (!stageConfig.containsKey(stage)) return;

    final (id, title, body) = stageConfig[stage]!;

    try {
      await _notificationService.scheduleNotification(
        id: id,
        title: title,
        body: body,
        scheduledTime: scheduledTime,
        payload: 'premium_upsell_stage_$stage',
      );
      print('[NotificationScheduler] Premium upsell notification scheduled: Stage $stage');
    } catch (e) {
      print('[NotificationScheduler] Error scheduling premium upsell: $e');
    }
  }

  /// プレミアム勧導通知をキャンセル
  Future<void> cancelPremiumUpsellNotifications() async {
    const ids = [
      NotificationIds.premiumUpsellStage1,
      NotificationIds.premiumUpsellStage2,
      NotificationIds.premiumUpsellStage3,
    ];

    for (final id in ids) {
      await _notificationService.cancelNotification(id);
    }
  }

  /// ===== Feature Update Notifications =====

  /// 機能更新通知を表示
  Future<void> showFeatureUpdateNotification({
    required String featureName,
    required String description,
  }) async {
    try {
      await _notificationService.showNotification(
        id: NotificationIds.featureUpdate,
        title: '✨ 新機能: $featureName',
        body: description,
        payload: 'feature_update',
      );
      print('[NotificationScheduler] Feature update notification shown: $featureName');
    } catch (e) {
      print('[NotificationScheduler] Error showing feature update: $e');
    }
  }

  /// ===== Utility Methods =====

  /// すべての通知をキャンセル
  Future<void> cancelAllNotifications() async {
    await _notificationService.cancelAllNotifications();
  }

  /// スケジュール済み通知の一覧取得
  Future<List<String>> getPendingNotificationSummary() async {
    final pending = await _notificationService.getPendingNotifications();
    return pending
        .map((n) => '[ID: ${n.id}] ${n.title ?? 'No Title'}: ${n.body ?? 'No Body'}')
        .toList();
  }
}

import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voikerchat/l10n/app_localizations.dart';
import 'package:voikerchat/models/notification_history_model.dart';
import 'local_notification_service.dart';
import 'notification_history_service.dart';

/// 端末ロケールを supportedLocales に解決する（アプリに言語切替UIは無く、
/// デバイスロケール駆動のため）。通知はBuildContextを持ちえない経路
/// （バックグラウンド/スケジュール済み通知の発火）でも文言解決が必要。
Locale _resolveLocale() {
  final device = WidgetsBinding.instance.platformDispatcher.locale;
  for (final l in AppLocalizations.supportedLocales) {
    if (l.languageCode == device.languageCode) return l;
  }
  return AppLocalizations.supportedLocales.first;
}

AppLocalizations get _l10n => lookupAppLocalizations(_resolveLocale());

/// NotificationScheduler
/// 4種類の通知（Daily Reminder, Milestone, Premium Upsell, Feature Update）を一元管理
class NotificationScheduler {
  final logger = Logger('NotificationScheduler');

  static final NotificationScheduler _instance = NotificationScheduler._internal();

  factory NotificationScheduler() {
    return _instance;
  }

  NotificationScheduler._internal();

  late LocalNotificationService _notificationService;
  late SharedPreferences _prefs;
  bool _initialized = false;

  /// 初期化済みかどうか（未初期化状態での操作を防ぐガード用）
  bool get isInitialized => _initialized;

  /// 初期化
  Future<void> initialize(LocalNotificationService notificationService) async {
    _notificationService = notificationService;
    _prefs = await SharedPreferences.getInstance();
    _initialized = true;
  }

  /// ===== 通知ON/OFF設定 =====

  static const String _notificationsEnabledKey = 'notifications_enabled';

  /// ローカル通知(毎日リマインダー・マイルストーン)が有効かどうか。デフォルトON。
  bool isNotificationsEnabled() {
    return _prefs.getBool(_notificationsEnabledKey) ?? true;
  }

  /// 通知ON/OFFを永続化する。呼び出し側で scheduleDailyReminders()/
  /// cancelDailyReminders() を続けて呼び、即座に反映させること。
  Future<void> setNotificationsEnabled(bool enabled) async {
    await _prefs.setBool(_notificationsEnabledKey, enabled);
  }

  /// ===== Daily Reminder Notifications =====

  /// 毎日のリマインダー通知をスケジュール
  /// 時刻: 8:00, 12:00, 19:00 JST
  /// 通知がOFF設定の場合は何もしない（起動時の一括呼び出しがOFF状態を
  /// 尊重するため、呼び出し側での分岐は不要）。
  Future<void> scheduleDailyReminders() async {
    if (!isNotificationsEnabled()) return;

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
      _l10n.notifDailyMorningTitle,
      _l10n.notifDailyNoonTitle,
      _l10n.notifDailyEveningTitle,
    ];

    final bodies = [
      _l10n.notifDailyMorningBody,
      _l10n.notifDailyNoonBody,
      _l10n.notifDailyEveningBody,
    ];

    for (int i = 0; i < times.length; i++) {
      try {
        final scheduledAt = await _notificationService.scheduleDailyNotification(
          id: ids[i],
          title: titles[i],
          body: bodies[i],
          time: times[i],
          payload: 'daily_reminder',
        );
        logger.info('[NotificationScheduler] Daily reminder scheduled: ${times[i].hour}:${times[i].minute.toString().padLeft(2, '0')}');
        await _saveScheduledHistory(
          title: titles[i],
          body: bodies[i],
          payload: 'daily_reminder',
          receivedAt: scheduledAt,
        );
      } catch (e) {
        logger.info('[NotificationScheduler] Error scheduling daily reminder: $e');
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

    try {
      await NotificationHistoryService().cancelScheduledByPayload('daily_reminder');
    } catch (e) {
      logger.info('[NotificationScheduler] Failed to clear scheduled history (daily): $e');
    }
  }

  /// status='scheduled'として履歴に先行書き込みする（案B）。
  /// 同一payload・同一予定時刻の行が既にあれば重複INSERTしない
  /// （毎起動時のscheduleDailyReminders呼び出しで同じ枠を再スケジュール
  /// しても履歴が増殖しないようにするため）。
  /// 履歴書き込みの失敗は通知機能そのものに影響させない（best-effort）。
  Future<void> _saveScheduledHistory({
    required String title,
    required String body,
    required String payload,
    required DateTime receivedAt,
  }) async {
    try {
      final historyService = NotificationHistoryService();
      final alreadyExists = await historyService.hasScheduledEntry(
        payload: payload,
        receivedAt: receivedAt,
      );
      if (alreadyExists) return;

      await historyService.saveNotification(
        title: title,
        body: body,
        payload: payload,
        status: NotificationHistoryStatus.scheduled,
        receivedAt: receivedAt,
      );
    } catch (e) {
      logger.info('[NotificationScheduler] Failed to save scheduled history ($payload): $e');
    }
  }

  /// showNotification直後に status='delivered' として即時書き込みする（案C）。
  /// 履歴書き込みの失敗は通知機能そのものに影響させない（best-effort）。
  Future<void> _saveDeliveredHistory({
    required String title,
    required String body,
    required String payload,
  }) async {
    try {
      await NotificationHistoryService().saveNotification(
        title: title,
        body: body,
        payload: payload,
        status: NotificationHistoryStatus.delivered,
      );
    } catch (e) {
      logger.info('[NotificationScheduler] Failed to save delivered history ($payload): $e');
    }
  }

  /// アプリ起動時に呼ぶ: 予定時刻を過ぎたscheduled履歴をdeliveredへ確定する。
  Future<void> reconcileHistoryOnLaunch() async {
    try {
      await NotificationHistoryService().reconcileScheduledNotifications();
    } catch (e) {
      logger.info('[NotificationScheduler] Failed to reconcile history: $e');
    }
  }

  /// ===== Milestone Notifications =====

  /// マイルストーン通知をスケジュール（3日、7日、14日、30日達成時）
  /// 通知がOFF設定の場合は何もしない。
  Future<void> checkAndScheduleMilestoneNotifications(int streakDays) async {
    if (!isNotificationsEnabled()) return;

    final milestones = [
      (days: 3, id: NotificationIds.milestone3Days, title: _l10n.notifMilestone3Title, body: _l10n.notifMilestone3Body),
      (days: 7, id: NotificationIds.milestone7Days, title: _l10n.notifMilestone7Title, body: _l10n.notifMilestone7Body),
      (days: 14, id: NotificationIds.milestone14Days, title: _l10n.notifMilestone14Title, body: _l10n.notifMilestone14Body),
      (days: 30, id: NotificationIds.milestone30Days, title: _l10n.notifMilestone30Title, body: _l10n.notifMilestone30Body),
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
          logger.info('[NotificationScheduler] Milestone notification shown: ${milestone.days}d');
          await _saveDeliveredHistory(
            title: milestone.title,
            body: milestone.body,
            payload: 'milestone',
          );
        } catch (e) {
          logger.info('[NotificationScheduler] Error showing milestone notification: $e');
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
      1: (NotificationIds.premiumUpsellStage1, _l10n.notifUpsellStage1Title, _l10n.notifUpsellStage1Body),
      2: (NotificationIds.premiumUpsellStage2, _l10n.notifUpsellStage2Title, _l10n.notifUpsellStage2Body),
      3: (NotificationIds.premiumUpsellStage3, _l10n.notifUpsellStage3Title, _l10n.notifUpsellStage3Body),
    };

    if (!stageConfig.containsKey(stage)) return;

    final (id, title, body) = stageConfig[stage]!;

    final payload = 'premium_upsell_stage_$stage';

    try {
      await _notificationService.scheduleNotification(
        id: id,
        title: title,
        body: body,
        scheduledTime: scheduledTime,
        payload: payload,
      );
      logger.info('[NotificationScheduler] Premium upsell notification scheduled: Stage $stage');
      await _saveScheduledHistory(
        title: title,
        body: body,
        payload: payload,
        receivedAt: scheduledTime,
      );
    } catch (e) {
      logger.info('[NotificationScheduler] Error scheduling premium upsell: $e');
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

    final historyService = NotificationHistoryService();
    for (final stage in [1, 2, 3]) {
      try {
        await historyService.cancelScheduledByPayload('premium_upsell_stage_$stage');
      } catch (e) {
        logger.info('[NotificationScheduler] Failed to clear scheduled history (upsell $stage): $e');
      }
    }
  }

  /// ===== Feature Update Notifications =====

  /// 機能更新通知を表示
  Future<void> showFeatureUpdateNotification({
    required String featureName,
    required String description,
  }) async {
    try {
      final title = _l10n.notifFeatureUpdateTitle(featureName);
      await _notificationService.showNotification(
        id: NotificationIds.featureUpdate,
        title: title,
        body: description,
        payload: 'feature_update',
      );
      logger.info('[NotificationScheduler] Feature update notification shown: $featureName');
      await _saveDeliveredHistory(
        title: title,
        body: description,
        payload: 'feature_update',
      );
    } catch (e) {
      logger.info('[NotificationScheduler] Error showing feature update: $e');
    }
  }

  /// ロケール変更時に予約通知を現ロケールで貼り直す。
  /// Daily はスケジュール時点のロケールで文言が焼き込まれるため、
  /// 同一時刻で再スケジュールする。Premium upsell の予約時刻は
  /// 呼び出し側が保持し scheduler は持たないため、ここではキャンセルのみ
  /// とし、再予約は通常のアップセル判定フローに委ねる（prefsで二重管理しない）。
  Future<void> rescheduleForLocaleChange() async {
    await cancelDailyReminders();
    await scheduleDailyReminders();
    await cancelPremiumUpsellNotifications();
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

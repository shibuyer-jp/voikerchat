import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:voikerchat/l10n/app_localizations.dart';
import 'package:voikerchat/l10n/label_helpers.dart';
import 'package:voikerchat/models/notification_history_model.dart';
import 'package:voikerchat/services/locale_service.dart';
import 'package:voikerchat/services/notification_history_service.dart';

/// 通知履歴画面
/// 
/// 機能:
/// - 通知一覧表示（最新順）
/// - フィルタータブ（全て / 未読 / 重要）
/// - タップで既読マーク
/// - スワイプで削除
/// - 通知なし時の空状態表示
class NotificationHistoryScreen extends StatefulWidget {
  const NotificationHistoryScreen({super.key});

  @override
  State<NotificationHistoryScreen> createState() =>
      _NotificationHistoryScreenState();
}

class _NotificationHistoryScreenState extends State<NotificationHistoryScreen> {
  final logger = Logger('NotificationHistoryScreen');
  
  late NotificationHistoryService _service;
  late Future<List<NotificationHistory>> _notificationsFuture;

  // フィルター状態
  FilterStatus _filterStatus = FilterStatus.all;

  // リアルタイムリスナー
  dynamic _subscription;

  // 削除処理中の通知ID。Dismissibleは confirmDismiss の完了を待たずに
  // 同じタイルへの再スワイプを受け付けてしまうため、二重にDELETEを
  // 発行しないようここで排他制御する。
  final Set<int> _deletingIds = {};

  @override
  void initState() {
    super.initState();
    _service = NotificationHistoryService();
    _loadNotifications();
    _setupRealtimeListener();
    // 言語切替時、この画面が既にマウント済み(裏タブ等)だと initState が
    // 再実行されず一覧がキャッシュされたままになる(Build 13で発覚)。
    // 予約通知(status='scheduled')はロケール変更時に再スケジュールされ
    // 中身が変わるため、この画面でも変更を検知して再読み込みする。
    LocaleService.currentLocale.addListener(_loadNotifications);
  }

  @override
  void dispose() {
    _subscription?.unsubscribe();
    LocaleService.currentLocale.removeListener(_loadNotifications);
    super.dispose();
  }

  /// 通知一覧を読み込み
  void _loadNotifications() {
    setState(() {
      _notificationsFuture = _service.getHistory(
        isRead: _filterStatus == FilterStatus.unread
            ? false
            : _filterStatus == FilterStatus.read
                ? true
                : null,
      );
    });
  }

  /// リアルタイム更新リスナーをセットアップ（v1.10 では後回し）
  void _setupRealtimeListener() {
    // TODO: Supabase v2.x で Realtime API が改善されたら実装
    // try {
    //   _subscription = _service.listenToNotifications((event) {
    //     _loadNotifications();
    //   });
    // } catch (e) {
    //   logger.info('Realtime listener setup error: $e');
    // }
  }

  /// 通知を既読マーク
  Future<void> _markAsRead(NotificationHistory notification) async {
    final l10n = AppLocalizations.of(context);
    try {
      await _service.markAsRead(notification.id);
      _loadNotifications();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.notifMarkedRead),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.errorWithDetail(e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 通知を削除する（Dismissible.confirmDismiss から呼ばれる）。
  /// 実際に削除できた場合のみ true を返し、そのときだけ Dismissible に
  /// スワイプ除去させる。false を返すとタイルは自動的に元の位置へ戻り、
  /// ローカル表示とサーバー状態が乖離しない（2026-07-31調査）。
  Future<bool> _deleteNotification(NotificationHistory notification) async {
    if (_deletingIds.contains(notification.id)) {
      // 既に削除処理中の同じタイルへの再スワイプ。二重送信を防ぐため
      // 何もせずタイルを元の位置へ戻す。
      return false;
    }
    _deletingIds.add(notification.id);

    final l10n = AppLocalizations.of(context);
    try {
      final deletedCount = await _service.deleteNotification(notification.id);
      if (deletedCount == 0) {
        throw Exception('Notification already deleted');
      }
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.notifDeleteError(e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    } finally {
      _deletingIds.remove(notification.id);
    }
  }

  /// スワイプ削除が確定した（confirmDismiss が true を返した）後に呼ばれる。
  /// 一覧再取得はここで行う。confirmDismiss 内で行うと、削除に失敗して
  /// タイルが元の位置へ戻るアニメーション中にリストごと再構築されて
  /// しまうため。
  void _onNotificationDismissed(NotificationHistory notification) {
    final l10n = AppLocalizations.of(context);
    _loadNotifications();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.notifDeleted),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.notifHistoryTitle),
        elevation: 2,
      ),
      body: Column(
        children: [
          // フィルタータブ
          _buildFilterTabs(),

          // 通知一覧
          Expanded(
            child: FutureBuilder<List<NotificationHistory>>(
              future: _notificationsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error, size: 48, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(l10n.errorWithDetail(
                            snapshot.error.toString())),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadNotifications,
                          child: Text(l10n.retry),
                        ),
                      ],
                    ),
                  );
                }

                final notifications = snapshot.data ?? [];

                if (notifications.isEmpty) {
                  return _buildEmptyState();
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: notifications.length,
                  itemBuilder: (context, index) {
                    final notification = notifications[index];
                    return _buildNotificationTile(notification);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// フィルタータブを構築
  Widget _buildFilterTabs() {
    final l10n = AppLocalizations.of(context);
    return Container(
      color: Colors.grey.shade100,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: FilterStatus.values.map((status) {
            final isSelected = _filterStatus == status;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: FilterChip(
                label: Text(_filterLabel(status, l10n)),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    _filterStatus = status;
                    _loadNotifications();
                  });
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  /// 通知タイルを構築（スワイプ削除対応）
  Widget _buildNotificationTile(NotificationHistory notification) {
    return Dismissible(
      key: Key(notification.id.toString()),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) => _deleteNotification(notification),
      onDismissed: (direction) => _onNotificationDismissed(notification),
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: ListTile(
          leading: _buildLeadingIcon(notification),
          title: Text(
            notification.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                notification.body,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                relativeTimeLabel(
                    AppLocalizations.of(context), notification.secondsSinceReceived),
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
          trailing: _buildTrailingBadge(notification),
          onTap: () {
            if (!notification.isRead) {
              _markAsRead(notification);
            }
          },
        ),
      ),
    );
  }

  /// 前のアイコンを構築（既読状態を表示）
  Widget _buildLeadingIcon(NotificationHistory notification) {
    if (notification.isRead) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.check_circle,
          color: Colors.grey.shade600,
          size: 24,
        ),
      );
    }

    return Container(
      width: 40,
      height: 40,
      decoration: const BoxDecoration(
        color: Colors.blue,
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.notifications_active,
        color: Colors.white,
        size: 20,
      ),
    );
  }

  /// 後ろのバッジを構築（既読/未読）
  Widget? _buildTrailingBadge(NotificationHistory notification) {
    if (notification.isRead) {
      return null;
    }
    final l10n = AppLocalizations.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.blue,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        l10n.notifUnread,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// 通知なし時の空状態を表示
  Widget _buildEmptyState() {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_none,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            l10n.notifEmpty,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadNotifications,
            child: Text(l10n.refresh),
          ),
        ],
      ),
    );
  }

  /// フィルター状態の表示ラベル（多言語対応）
  String _filterLabel(FilterStatus status, AppLocalizations l10n) {
    switch (status) {
      case FilterStatus.all:
        return l10n.notifFilterAll;
      case FilterStatus.unread:
        return l10n.notifUnread;
      case FilterStatus.read:
        return l10n.notifFilterRead;
    }
  }
}

/// フィルター状態の列挙
enum FilterStatus {
  all,
  unread,
  read,
}

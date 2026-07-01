import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:voikerchat/l10n/app_localizations.dart';
import 'package:voikerchat/models/notification_history_model.dart';
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

  @override
  void initState() {
    super.initState();
    _service = NotificationHistoryService();
    _loadNotifications();
    _setupRealtimeListener();
  }

  @override
  void dispose() {
    _subscription?.unsubscribe();
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

  /// 通知を削除
  Future<void> _deleteNotification(NotificationHistory notification) async {
    final l10n = AppLocalizations.of(context);
    try {
      await _service.deleteNotification(notification.id);
      _loadNotifications();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.notifDeleted),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.notifDeleteError(e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
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
      onDismissed: (direction) {
        _deleteNotification(notification);
      },
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
                notification.relativeTime,
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

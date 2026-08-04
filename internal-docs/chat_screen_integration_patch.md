// ============================================================================
// このファイルは既存の ChatScreen に統合するコードパッチです
// 以下の内容を ChatScreen に追加/修正してください
// ============================================================================

// ① 先頭のインポートセクションに追加
import 'notification_history_service.dart';
import 'notification_history_screen.dart';

// ② ChatScreen の State クラスに以下のメンバー変数を追加
class _ChatScreenState extends State<ChatScreen>
    with WidgetsBindingObserver {
  // ... 既存コード ...

  late NotificationHistoryService _notificationHistoryService;

  @override
  void initState() {
    super.initState();
    // ... 既存初期化コード ...

    _notificationHistoryService = NotificationHistoryService();
  }

  // ③ AppBar の trailing に通知履歴アイコンを追加
  // 既존 AppBar build メソッド内で trailing を以下のように修正:
  
  Widget _buildAppBar() {
    return AppBar(
      title: Text(_selectedScene?.sceneName ?? 'Voikerchat'),
      actions: [
        // 既존 actions...
        
        // 通知履歴アイコンを追加
        IconButton(
          icon: const Icon(Icons.history),
          tooltip: '通知履歴',
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const NotificationHistoryScreen(),
              ),
            );
          },
        ),
        
        const SizedBox(width: 8),
      ],
    );
  }

  // ④ メッセージ送信時に通知履歴へ保存
  // 既経 _sendMessage() メソッド内で、メッセージ送信直後に以下を追加:

  Future<void> _sendMessage(String userMessage) async {
    // ... 既存メッセージ送信処理 ...

    // Claude API 呼び出し完了後、通知を保存
    try {
      await _notificationHistoryService.saveNotification(
        title: 'Claude 返信',
        body: _lastAssistantMessage.isNotEmpty
            ? _lastAssistantMessage.substring(0, 100)
            : 'メッセージを受け取りました',
        payload: {
          'scene': _selectedScene?.sceneName,
          'type': 'message_reply',
          'timestamp': DateTime.now().toIso8601String(),
        }.toString(),
      );
    } catch (e) {
      print('NotificationHistory save error: $e');
      // エラーは無視（通知保存失敗がUXを妨害しない）
    }
  }

  // ⑤ ローカル通知受信時に NotificationHistory へ保存
  // 既存の _handleNotificationInteraction() メソッドを修正:

  Future<void> _handleNotificationInteraction(
    ReceivedNotification notification,
  ) async {
    // ... 既存通知処理 ...

    // NotificationHistory へも保存
    try {
      await _notificationHistoryService.saveNotification(
        title: notification.title ?? 'Voikerchat',
        body: notification.body ?? '',
        payload: {
          'payload': notification.payload,
          'type': 'local_notification',
        }.toString(),
      );
    } catch (e) {
      print('NotificationHistory save error: $e');
    }
  }

  // ⑥ 既存 ChatScreen の dispose メソッドをそのまま使用
  // （特に追加処理なし）
}

// ============================================================================
// 統合手順
// ============================================================================
// 
// 1. このファイルを lib/ に保存（参考用）
// 2. 既存 ChatScreen を以下の順序で修正：
//    a) インポート追加（①）
//    b) State クラスにサービス変数追加（②）
//    c) AppBar に通知履歴アイコン追加（③）
//    d) _sendMessage で通知保存処理追加（④）
//    e) _handleNotificationInteraction で履歴保存追加（⑤）
// 3. pubspec.yaml で json_annotation がすでに存在することを確認
// 4. 本体 ChatScreen にコードを統合後、このファイルは削除可
// 
// ============================================================================
// 注意事項
// ============================================================================
//
// - NotificationHistory 保存は非同期で、エラーは無視
// - Supabase 認証状態が不安定な場合はキャッチ処理で保護
// - ローカル通知とリモート通知の両方をサポート
// - 画面遷移後も既存の ChatScreen 機能は変わらない
//
// ============================================================================

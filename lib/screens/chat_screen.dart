import 'package:flutter/material.dart';
import 'package:voikerchat/l10n/app_localizations.dart';
import 'package:voikerchat/l10n/label_helpers.dart';
import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/message.dart';
import '../models/rate_limit.dart';
import '../services/message_service.dart';
import '../services/rate_limit_service.dart';
import '../services/scene_service.dart';
import '../services/revenuecat_service.dart';
import '../services/streak_service.dart';
import '../services/premium_upsell_service.dart';
import '../services/rewarded_ad_service.dart';
import '../services/voice/speech_recognition_service.dart';
import '../services/voice/text_to_speech_service.dart';
import '../services/voice/tts_text_cleaner.dart';
import '../widgets/mic_rationale_dialog.dart';
import '../widgets/rate_limit_widget.dart';
import '../widgets/premium_upsell_widgets.dart';
import 'stats_screen.dart';

/// Chat screen for Voikerchat
/// 
/// Displays conversation with Claude Haiku and saves history to Supabase
class ChatScreen extends StatefulWidget {
  final String sceneId;
  final String sceneName;
  final Map<String, dynamic> sceneData;
  final String? conversationId; // From notification (pattern B)

  const ChatScreen({
    super.key,
    required this.sceneId,
    required this.sceneName,
    required this.sceneData,
    this.conversationId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final logger = Logger('ChatScreen');
  
  late MessageService _messageService;
  late RateLimitService _rateLimitService;
  late RevenueCatService _revenueCatService;
  late StreakService _streakService;
  late PremiumUpsellService _premiumUpsellService;
  final RewardedAdService _rewardedAdService = RewardedAdService();
  bool _isAdLoading = false;
  // 音声（会話）: STT/TTS
  final SpeechRecognitionService _speechService = SpeechRecognitionService();
  final TextToSpeechService _ttsService = TextToSpeechService();
  bool _voiceReady = false;
  bool _ttsReady = false;
  bool _isListening = false;
  // STT は権限プロンプトを伴うため起動時に初期化せず、初回マイクタップ時に
  // 説明ダイアログ(G6)を挟んで遅延初期化する。以下はその状態管理。
  bool _sttInitAttempted = false; // initialize() を一度でも試みたか
  bool _sttUnavailable = false; // 未対応/権限拒否が確定したか（true でマイクボタンを隠す）
  bool _autoRead = true;
  late TextEditingController _inputController;
  late ScrollController _scrollController;

  List<Message> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  String? _userId;
  RateLimit? _rateLimit;
  bool _isPremium = false;
  int _currentStreak = 0;
  // Stage 3 用のインラインバナー表示状態
  PremiumUpsellStage? _activeBannerStage;

  @override
  void initState() {
    super.initState();
    _inputController = TextEditingController();
    _scrollController = ScrollController();
    _revenueCatService = RevenueCatService();
    _streakService = StreakService();
    _premiumUpsellService = PremiumUpsellService();

    // リワード広告を事前ロード（Web では no-op）。
    _rewardedAdService.loadAd();

    // 音声(STT/TTS)を初期化（非同期・非致命）。
    _initVoice();

    // WidgetsBinding オブザーバー登録（通知タップ処理）
    WidgetsBinding.instance.addObserver(this);

    _initializeChat();
  }

  Future<void> _initializeChat() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        _showError('User not authenticated');
        // ローディングを解除しないと画面が無限にぐるぐるし続ける。
        // （Supabase未初期化 = --dart-define 未指定時にこの経路に入る）
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      _userId = user.id;
      _messageService = MessageService.getInstance(Supabase.instance.client);
      _rateLimitService = RateLimitService(Supabase.instance.client);

      // StreakService 初期化
      final prefs = await SharedPreferences.getInstance();
      await _streakService.initialize(
        prefs: prefs,
        supabase: Supabase.instance.client,
      );

      // Get or create session
      await _messageService.getOrCreateSession(
        userId: _userId!,
        sceneId: widget.sceneId,
      );

      // Load existing messages and rate limit status
      await _loadMessages();

      // 初回（履歴なし）はシーン別オープニング第一声をAI発話として挿入。
      // API呼び出し不要（固定スクリプト）＝コスト・遅延ゼロ、利用回数も消費しない。
      await _insertOpeningLineIfNeeded();

      await _loadRateLimit();
      
      // Premium ステータス確認
      await _checkPremiumStatus();

      // ストリーク読み込み
      await _loadStreak();

      setState(() => _isLoading = false);
    } catch (e) {
      _showError('Failed to initialize chat: $e');
      // 初期化に失敗してもローディングを解除し、画面が無限に
      // ぐるぐるし続けないようにする（チャットUI自体は表示する）。
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _checkPremiumStatus() async {
    try {
      _isPremium = await _revenueCatService.checkPremiumStatus();
      setState(() {});
    } catch (e) {
      logger.info('Error checking premium status: $e');
    }
  }

  Future<void> _loadStreak() async {
    if (_userId == null) return;

    try {
      final streak = await _streakService.getCurrentStreak(_userId!, widget.sceneId);
      setState(() => _currentStreak = streak);
    } catch (e) {
      logger.info('Failed to load streak: $e');
    }
  }

  /// 段階的プレミアム勧導の表示判定。
  /// Stage1=トースト / Stage2=ダイアログ / Stage3=インラインバナー。
  /// Premium ユーザーには一切表示しない。各ステージは一度きり。
  Future<void> _maybeShowUpsell() async {
    if (_isPremium || !mounted) return;

    try {
      final stage = await _premiumUpsellService.getNextUpsellStage();
      if (stage == null || !mounted) return;

      switch (stage) {
        case PremiumUpsellStage.stage1:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.transparent,
              elevation: 0,
              duration: const Duration(seconds: 6),
              content: PremiumUpsellToast(
                onDetailsTap: () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  _showPremiumDialog();
                },
                onDismiss: () =>
                    ScaffoldMessenger.of(context).hideCurrentSnackBar(),
              ),
            ),
          );
          break;
        case PremiumUpsellStage.stage2:
          await showDialog(
            context: context,
            builder: (ctx) => PremiumUpsellDialog(
              onSubscribeTap: () {
                Navigator.pop(ctx);
                _purchasePremium();
              },
              onDismiss: () => Navigator.pop(ctx),
            ),
          );
          break;
        case PremiumUpsellStage.stage3:
          setState(() => _activeBannerStage = PremiumUpsellStage.stage3);
          break;
      }

      // 表示したステージは一度きり（再表示しない）
      await _premiumUpsellService.markStageAsShown(stage);
    } catch (e) {
      // 勧導は非致命：失敗してもチャットは止めない
      logger.info('Upsell check failed: $e');
    }
  }

  Future<void> _loadRateLimit() async {
    if (_userId == null) return;
    try {
      final rateLimit = await _rateLimitService.getRateLimit(_userId!);
      setState(() => _rateLimit = rateLimit);
    } catch (e) {
      logger.info('Failed to load rate limit: $e');
    }
  }

  /// 「広告を見て +5回」: 広告を表示し、視聴完了したら当日上限を +5 する。
  Future<void> _watchAdForBonus() async {
    if (_userId == null || _isAdLoading) return;
    setState(() => _isAdLoading = true);
    try {
      // 未ロードなら表示前にロードを試みる。
      if (!_rewardedAdService.isReady) {
        await _rewardedAdService.loadAd();
      }
      if (!_rewardedAdService.isReady) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context).adLoadFailed),
            ),
          );
        }
        return;
      }

      final earned = await _rewardedAdService.showAd();
      if (earned) {
        await _rateLimitService.grantAdBonus(_userId!);
        await _loadRateLimit(); // 残数表示を更新
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context).adBonusGranted)),
          );
        }
      }
    } catch (e) {
      logger.info('Watch-ad bonus failed: $e');
    } finally {
      if (mounted) setState(() => _isAdLoading = false);
    }
  }

  /// 音声(STT/TTS)の初期化。非致命なので失敗してもチャットは継続する。
  Future<void> _initVoice() async {
    // TTS のみ起動時に初期化（マイク権限不要）。STT は権限プロンプトを伴うため、
    // 初回マイクタップ時に説明ダイアログ(G6)→initialize() の順で遅延初期化する。
    try {
      await _ttsService.initialize();
      if (!mounted) return;
      setState(() {
        _ttsReady = _ttsService.isSupported;
      });
    } catch (e) {
      logger.info('Voice init failed: $e');
    }
  }

  /// マイクのトグル（Push-to-Talk）。認識中なら停止、そうでなければ開始する。
  /// iOSは約1分で強制終了・連続再起動でスロットリングされるため自動再起動はしない。
  Future<void> _toggleListening() async {
    if (_isListening) {
      await _speechService.stop(); // onComplete 経由で自動送信される
      return;
    }

    // 初回のみ: OS標準の権限プロンプトを出す「前」に理由を説明する(G6)。
    // 「続ける」を選んだときだけ initialize()（＝OS権限プロンプト）へ進む。
    if (!_sttInitAttempted) {
      final l = AppLocalizations.of(context);
      final proceed = await showMicRationaleDialog(
        context,
        message: l.micRationaleMessage,
        allowLabel: l.micRationaleContinue,
        cancelLabel: l.cancel,
      );
      if (!proceed) return; // 説明ダイアログでキャンセル → 権限要求せず何もしない
      if (!mounted) return;

      final sttOk = await _speechService.initialize(); // ここでOS権限プロンプト
      _sttInitAttempted = true;
      if (!mounted) return;
      setState(() {
        _voiceReady = sttOk;
        _sttUnavailable = !sttOk; // 未対応/拒否ならボタンを隠しテキスト入力へフォールバック
      });
      if (!sttOk) return;
    }

    if (!_voiceReady) return;

    await _ttsService.stop(); // 進行中の読み上げを止めてから録音
    // 前回の認識結果や入力途中のテキストが残っていると、新しい発話と
    // 混ざって送信されてしまうため、録音開始時に必ずクリアする。
    _inputController.clear();
    setState(() => _isListening = true);

    await _speechService.start(
      localeId: 'ja-JP',
      onResult: (transcript, _) {
        // 録音停止/送信後に iOS から遅れて届く最終認識結果を無視する。
        // このガードがないと、_sendMessage でクリアした入力欄に
        // 送信済みの発話テキストが復活してしまう（非同期の競合）。
        if (!_isListening || _isSending) return;
        _inputController.text = transcript;
      },
      onComplete: () {
        if (!mounted) return;
        setState(() => _isListening = false);
        if (_inputController.text.trim().isNotEmpty && !_isSending) {
          _sendMessage();
        }
      },
      onError: (code) {
        if (!mounted) return;
        setState(() => _isListening = false);
        logger.info('Speech recognition error: $code');
      },
    );
  }

  Future<void> _loadMessages() async {
    if (_userId == null) return;

    try {
      final messages = await _messageService.loadMessageHistory(
        userId: _userId!,
        sceneId: widget.sceneId,
      );

      setState(() => _messages = messages);
      _scrollToBottom();
    } catch (e) {
      _showError('Failed to load messages: $e');
    }
  }

  /// 履歴が空のとき、シーン別のオープニング第一声を assistant メッセージとして
  /// 保存・表示する。ユーザーが何を話せばよいか分かるきっかけを作る。
  Future<void> _insertOpeningLineIfNeeded() async {
    if (_userId == null || _messages.isNotEmpty) return;

    final openingLine = SceneService.openingLineFor(widget.sceneId);
    if (openingLine == null) return;

    try {
      final openingMessage = await _messageService.saveMessage(
        userId: _userId!,
        sceneId: widget.sceneId,
        role: 'assistant',
        content: openingLine,
      );
      if (!mounted) return;
      setState(() => _messages.add(openingMessage));
      _scrollToBottom();
    } catch (e) {
      // オープニング挿入の失敗は致命的でないため、ログのみで継続
      logger.warning('Failed to insert opening line: $e');
    }
  }

  Future<void> _sendMessage() async {
    final l = AppLocalizations.of(context);
    final text = _inputController.text.trim();
    if (text.isEmpty || _isSending) return;

    // Check rate limit before sending
    if (_rateLimit != null && !_rateLimit!.canMakeCall) {
      _showRateLimitDialog();
      return;
    }

    setState(() => _isSending = true);
    _inputController.clear();

    // 録音中に手動送信された場合、マイクを確実に止める。
    // 止めないと、この後のTTS読み上げ(スピーカー出力)をマイクが拾い、
    // AIの発話が入力欄に書き起こされる自己ループが発生する。
    if (_speechService.isListening) {
      await _speechService.cancel(); // 確定させず破棄（onCompleteの自動送信も防ぐ）
      if (mounted) setState(() => _isListening = false);
    }

    try {
      // Save user message
      final userMessage = await _messageService.saveMessage(
        userId: _userId!,
        sceneId: widget.sceneId,
        role: 'user',
        content: text,
      );

      setState(() => _messages.add(userMessage));
      _scrollToBottom();

      // Get assistant response (Claude Haiku API)
      final assistantResponse = await _getAssistantResponse(text);

      // Save assistant message
      final assistantMessage = await _messageService.saveMessage(
        userId: _userId!,
        sceneId: widget.sceneId,
        role: 'assistant',
        content: assistantResponse['content'],
        tokensUsed: assistantResponse['tokens_used'],
      );

      setState(() => _messages.add(assistantMessage));
      _scrollToBottom();

      // アシスタント応答を自動読み上げ（ONかつTTS利用可能なとき）。
      if (_autoRead && _ttsReady) {
        final reply = assistantResponse['content'] as String? ?? '';
        if (reply.isNotEmpty) {
          await _ttsService.speak(cleanForSpeech(reply));
        }
      }

      // レート制限カウントはサーバー側 (api/chat.ts) で既にインクリメント済み。
      // ここでは表示更新のみ行う（クライアント側で再度加算すると二重カウントになる）。
      await _loadRateLimit(); // Refresh display

      // ストリークをインクリメント（メッセージ送信成功時）
      final newStreak = await _streakService.incrementStreak(_userId!, widget.sceneId);
      setState(() => _currentStreak = newStreak);

      // 段階的プレミアム勧導：会話を記録し、条件を満たせば該当ステージを表示
      await _premiumUpsellService.recordConversation();
      await _maybeShowUpsell();

    } catch (e) {
      _showError(l.failedToSendMessage(e.toString()));
      // Re-insert user input on error
      _inputController.text = text;
    } finally {
      setState(() => _isSending = false);
    }
  }

  /// Call Claude Haiku API for response
  /// Returns map with 'content' and 'tokens_used'
  Future<Map<String, dynamic>> _getAssistantResponse(String userMessage) async {
    try {
      // Build conversation context from stored messages.
      // 注意: 送信中のユーザーメッセージは _sendMessage 側で既に _messages に
      // 追加済みのため、ここで再追加しない（従来は末尾が二重送信されていた）。
      final conversationHistory = _messages
          .map((msg) => {
            'role': msg.role,
            'content': msg.content,
          })
          .toList();

      // Call Claude Haiku API (via Firebase Functions or Vercel)
      // This assumes T-12b already implemented the backend
      final response = await _callClaudeHaikuAPI(
        messages: conversationHistory,
        sceneData: widget.sceneData,
      );

      return response;
    } catch (e) {
      throw Exception('Assistant API error: $e');
    }
  }

  /// Call Claude Haiku API endpoint (via Vercel /api/chat)
  /// Server-side rate limiting enforced
  Future<Map<String, dynamic>> _callClaudeHaikuAPI({
    required List<Map<String, dynamic>> messages,
    required Map<String, dynamic> sceneData,
  }) async {
    try {
      // Get Auth token for secure API call
      final token = Supabase.instance.client.auth.currentSession?.accessToken;
      if (token == null) throw Exception('No auth token');

      // Call server-side API endpoint with server-side rate limiting
      const baseUrl = 'https://voikerchat.com';
      final response = await http.post(
        Uri.parse('$baseUrl/api/chat'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'token': token,
          'messages': messages,
          'sceneId': widget.sceneId,
          'maxTokens': 500,
        }),
      );

      if (response.statusCode == 429) {
        // Rate limit reached - trigger upgrade dialog
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showPremiumDialog();
        });
        throw Exception('Daily limit reached. Upgrade to Premium!');
      }

      if (response.statusCode != 200) {
        final error = jsonDecode(response.body);
        throw Exception(error['error'] ?? 'API error: ${response.statusCode}');
      }

      final result = jsonDecode(response.body);
      return {
        'content': result['content'] ?? '',
        'tokens_used': result['tokensUsed'] ?? 150,
      };
    } catch (e) {
      throw Exception('Assistant API error: $e');
    }
  }

  /// ライフサイクル状態変更時のコールバック（通知タップ処理）
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // アプリがフォアグラウンドに戻ったときに通知状態を確認
      _handleNotificationInteraction();
    }
  }

  /// 通知インタラクション処理
  Future<void> _handleNotificationInteraction() async {
    try {
      // ローカルストレージから通知ペイロードを確認
      // 実装例: NotificationService から最後の通知データを取得
      // ここでシーン遷移やUI更新を実行
    } catch (e) {
      logger.info('[ChatScreen] Error handling notification: $e');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showError(String message) {
    // initState 中（画面構築完了前）に呼ばれると ScaffoldMessenger.of(context)
    // が例外を投げてぐるぐる（無限ローディング）の原因になるため、
    // 描画フレーム完了後に表示するよう遅延させる。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _inputController.dispose();
    _scrollController.dispose();
    _rewardedAdService.dispose();
    _speechService.dispose();
    _ttsService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.sceneName),
            Text(
              l.levelLabel(levelNameFromToken(l, widget.sceneData['level'] as String?)),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          if (!_isPremium)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Center(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _showPremiumDialog,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.amber,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Pro',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (_isPremium)
            IconButton(
              icon: const Icon(Icons.bar_chart),
              tooltip: l.learningStats,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const StatsScreen()),
                );
              },
            ),
          // ストリークバッジ
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '🔥',
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$_currentStreak',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_ttsReady)
            IconButton(
              icon: Icon(_autoRead ? Icons.volume_up : Icons.volume_off),
              tooltip: l.voiceAutoRead,
              onPressed: () => setState(() => _autoRead = !_autoRead),
            ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: _showSessionOptions,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Messages list
                Expanded(
                  child: _messages.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.chat_bubble_outline,
                                size: 48,
                                color: Colors.grey,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                l.chatEmptyState,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final message = _messages[index];
                            final isUser = message.role == 'user';

                            return Align(
                              alignment: isUser
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Container(
                                margin: EdgeInsets.only(
                                  bottom: 12,
                                  left: isUser ? 60 : 0,
                                  right: isUser ? 0 : 60,
                                ),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isUser
                                      ? Theme.of(context).primaryColor
                                      : Colors.grey.shade300,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      message.content,
                                      style: TextStyle(
                                        color: isUser
                                            ? Colors.white
                                            : Colors.black,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      message.formattedTime,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isUser
                                            ? Colors.white70
                                            : Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),

                // Rate limit status + Message input
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 段階的勧導 Stage 3: インラインバナー（Premium 未加入時のみ）
                    if (!_isPremium &&
                        _activeBannerStage == PremiumUpsellStage.stage3)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                        child: PremiumUpsellBanner(
                          onSubscribeTap: () {
                            setState(() => _activeBannerStage = null);
                            _purchasePremium();
                          },
                          onDismiss: () =>
                              setState(() => _activeBannerStage = null),
                        ),
                      ),
                    // Rate Limit Widget
                    RateLimitWidget(
                      rateLimit: _rateLimit,
                      onUpgradePressed: _showPremiumDialog,
                      showWatchAdButton: _rewardedAdService.isSupported &&
                          _rateLimit != null &&
                          !_rateLimit!.isPremium &&
                          _rateLimit!.dailyLimit < 10 &&
                          _rateLimit!.remainingCalls <= 1,
                      isAdLoading: _isAdLoading,
                      onWatchAd: _watchAdForBonus,
                    ),
                    // Message input
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _inputController,
                              decoration: InputDecoration(
                                hintText: l.chatInputHint,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                enabled: !_isSending,
                              ),
                              maxLines: null,
                              textInputAction: TextInputAction.send,
                              onSubmitted: (_) => _isSending ? null : _sendMessage(),
                            ),
                          ),
                          // 起動時はSTT未初期化でも表示（初回タップで説明→権限へ）。
                          // 未対応/拒否が確定した場合のみ隠し、テキスト入力へフォールバック。
                          if (!_sttUnavailable) ...[
                            IconButton(
                              icon: Icon(
                                _isListening ? Icons.stop : Icons.mic,
                                color: _isListening ? Colors.red : null,
                              ),
                              tooltip: _isListening ? l.voiceInputStop : l.voiceInputStart,
                              onPressed: _isSending ? null : _toggleListening,
                            ),
                          ],
                          const SizedBox(width: 8),
                          IconButton(
                            icon: _isSending
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.send),
                            onPressed: _isSending ? null : _sendMessage,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  void _showSessionOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(AppLocalizations.of(context).clearConversation),
              onTap: () async {
                Navigator.pop(context);
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(AppLocalizations.of(context).clearConversationConfirmTitle),
                    content: Text(
                        AppLocalizations.of(context).clearConversationConfirmBody),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(AppLocalizations.of(context).cancel),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: Text(AppLocalizations.of(context).clear),
                      ),
                    ],
                  ),
                );

                if (confirm == true && _userId != null) {
                  await _messageService.clearSessionMessages(
                    userId: _userId!,
                    sceneId: widget.sceneId,
                  );
                  setState(() => _messages.clear());
                }
              },
            ),
            ListTile(
              title: Text(AppLocalizations.of(context).exitConversation),
              onTap: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showRateLimitDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).dailyLimitReachedTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context).dailyLimitReachedBody,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            if (_rateLimit != null)
              Text(
                AppLocalizations.of(context).dailyLimitDetail(_rateLimit!.dailyLimit),
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context).goPremiumUnlockCta,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.blue,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context).later),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showPremiumDialog();
            },
            child: Text(AppLocalizations.of(context).upgrade),
          ),
        ],
      ),
    );
  }

  void _showPremiumDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).premiumSheetTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context).premiumSheetSubtitle,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            _PremiumFeature(
              icon: '🚀',
              title: AppLocalizations.of(context).featureUnlimitedTitle,
              description: AppLocalizations.of(context).featureUnlimitedDesc,
            ),
            const SizedBox(height: 12),
            _PremiumFeature(
              icon: '✨',
              title: AppLocalizations.of(context).featureAnimeTitle,
              description: AppLocalizations.of(context).featureAnimeDesc,
            ),
            const SizedBox(height: 12),
            _PremiumFeature(
              icon: '📊',
              title: AppLocalizations.of(context).featureStatsTitle,
              description: AppLocalizations.of(context).featureStatsDesc,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.local_offer, color: Colors.amber, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    AppLocalizations.of(context).pricePerMonth,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context).maybeLater),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
            ),
            onPressed: () async {
              Navigator.pop(context);
              await _purchasePremium();
            },
            child: Text(AppLocalizations.of(context).subscribeNow),
          ),
        ],
      ),
    );
  }

  Future<void> _purchasePremium() async {
    final l = AppLocalizations.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(AppLocalizations.of(context).processingPurchase),
          ],
        ),
      ),
    );

    try {
      final result = await _revenueCatService.purchasePremium();
      
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog
      
      if (result['success'] == true) {
        setState(() => _isPremium = true);
        _showSuccess(l.welcomePremium);
      } else {
        // エラーハンドリング
        final message = result['message'] as String? ?? l.purchaseFailed;
        final retryable = result['retryable'] as bool? ?? false;
        final userInitiated = result['userInitiated'] as bool? ?? false;

        if (userInitiated) {
          // ユーザーがキャンセルした場合
          logger.info('Purchase cancelled by user');
          return;
        }

        if (retryable) {
          _showRetryDialog(message, () => _purchasePremium());
        } else {
          _showErrorWithAction(
            message,
            actionLabel: l.close,
            onAction: () => Navigator.pop(context),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
      }
      _showError(l.unexpectedError(e.toString()));
    }
  }

  /// リトライ可能なエラーダイアログ
  void _showRetryDialog(String message, VoidCallback onRetry) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).purchaseFailedTitle),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context).cancel),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onRetry();
            },
            child: Text(AppLocalizations.of(context).retry),
          ),
        ],
      ),
    );
  }

  /// アクション付きエラーダイアログ
  void _showErrorWithAction(
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).errorTitle),
        content: Text(message),
        actions: [
          ElevatedButton(
            onPressed: onAction ?? () => Navigator.pop(context),
            child: Text(actionLabel ?? AppLocalizations.of(context).ok),
          ),
        ],
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

}

// Premium 機能表示用ウィジェット
class _PremiumFeature extends StatelessWidget {
  final String icon;
  final String title;
  final String description;

  const _PremiumFeature({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(icon, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}


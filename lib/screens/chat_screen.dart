import 'package:flutter/material.dart';
import 'package:app_settings/app_settings.dart';
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
import '../services/notification_scheduler.dart';
import '../services/locale_service.dart';
import '../utils/platform_code.dart';
import '../services/voice/speech_recognition_service.dart';
import '../services/voice/text_to_speech_service.dart';
import '../services/voice/tts_text_cleaner.dart';
import '../services/voice/tts_engine.dart';
import '../services/voice/device_tts_engine.dart';
import '../services/voice/cloud_tts_engine.dart';
import '../services/voice/cloud_tts_unlock_service.dart';
import '../services/learner_preferences_service.dart';
import '../widgets/mic_rationale_dialog.dart';
import '../widgets/rate_limit_widget.dart';
import '../widgets/premium_upsell_widgets.dart';
import '../widgets/word_lookup_sheet.dart';
import '../widgets/word_list_sheet.dart';
import '../widgets/content_report_sheet.dart';
import '../widgets/hint_sheet.dart';
import '../widgets/vocab_summary_sheet.dart';
import '../widgets/shrink_to_fit_text.dart';
import '../theme/app_colors.dart';
import 'paywall_screen.dart';
import 'stats_screen.dart';

/// Chat screen for Voikerchat
/// 
/// Displays conversation with Claude Haiku and saves history to Supabase
class ChatScreen extends StatefulWidget {
  final String sceneId;
  final String sceneName;
  final Map<String, dynamic> sceneData;
  final String? conversationId; // From notification (pattern B)

  /// チャット画面内(レート制限ダイアログ・段階的アップセル等)から購入が
  /// 成功した場合に呼ばれる。呼び出し元(SceneSelectionScreen経由で
  /// HomeScreen)がPremium状態を再取得し、シーンロック表示に反映するために使う。
  final VoidCallback? onPremiumUnlocked;

  const ChatScreen({
    super.key,
    required this.sceneId,
    required this.sceneName,
    required this.sceneData,
    this.conversationId,
    this.onPremiumUnlocked,
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
  // T-35: 3段構成TTS(端末/広告日解放クラウド/プレミアム常時クラウド)
  late final DeviceTtsEngine _deviceTtsEngine = DeviceTtsEngine(_ttsService);
  final CloudTtsEngine _cloudTtsEngine = CloudTtsEngine();
  final CloudTtsUnlockService _cloudTtsUnlockService = CloudTtsUnlockService();
  bool _cloudTtsUnlockedToday = false;
  // T-36: ふりがな表示設定(設定画面のトグルと同期、デフォルトON)
  final LearnerPreferencesService _learnerPreferencesService =
      LearnerPreferencesService();
  bool _furiganaEnabled = true;
  // 難易度フィードバック('easy'|'good'|'hard'|null)。会話開始時点のスナップショット。
  String? _difficultyFeedback;
  bool _voiceReady = false;
  bool _ttsReady = false;
  bool _isListening = false;
  // STT は権限プロンプトを伴うため起動時に初期化せず、初回マイクタップ時に
  // 説明ダイアログ(G6)を挟んで遅延初期化する。以下はその状態管理。
  bool _sttInitAttempted = false; // initialize() を一度でも試みたか
  // ユーザーが自分でマイクをタップして停止したか。true のときだけ自動送信する。
  // false のまま onComplete が来た場合は OS 側の無音自動停止(Android約5秒/iOS約1分)
  // なので、途中の発話を勝手に送らずテキストを入力欄に残す。
  bool _stopRequestedByUser = false;
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

    // D案: 前回シーンとして記録(シーン一覧の「続きから」バナーで使用)。
    _learnerPreferencesService.setLastSceneId(widget.sceneId);
    // シーン一覧の「最近使ったシーン」セクションで使用(最新順・重複統合)。
    _learnerPreferencesService.recordRecentSceneId(widget.sceneId);

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
      await _checkCloudTtsUnlock();
      await _loadFuriganaPreference();

      // ストリーク読み込み
      await _loadStreak();

      setState(() => _isLoading = false);
      await _maybeShowWordLookupHint();
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

  /// T-35: 本日クラウドTTSが解放済みか(表示・呼び分け用のローカルヒント)。
  /// 実際の許可判定はサーバー(api/tts.ts)が行う。
  Future<void> _checkCloudTtsUnlock() async {
    final unlocked = await _cloudTtsUnlockService.isUnlockedToday();
    if (!mounted) return;
    setState(() => _cloudTtsUnlockedToday = unlocked);
  }

  /// T-36: 設定画面のふりがなトグルを読み込む(会話開始時点のスナップショット)。
  /// B案: 直近の難易度フィードバックも同時に読み込む。
  Future<void> _loadFuriganaPreference() async {
    final enabled = await _learnerPreferencesService.isFuriganaEnabled();
    final difficulty = await _learnerPreferencesService.getDifficultyFeedback();
    if (!mounted) return;
    setState(() {
      _furiganaEnabled = enabled;
      _difficultyFeedback = difficulty;
    });
  }

  /// T-35: Premium/本日広告解放時はクラウドTTS(OpenAI)、それ以外は端末TTS。
  /// クラウド取得・再生に失敗した場合は会話を止めず端末TTSへフォールバックする。
  Future<TtsEngine> _resolveTtsEngine() {
    if (_isPremium || _cloudTtsUnlockedToday) {
      return Future.value(_cloudTtsEngine);
    }
    return Future.value(_deviceTtsEngine);
  }

  Future<void> _speak(String text) async {
    final engine = await _resolveTtsEngine();
    if (engine is CloudTtsEngine) {
      try {
        await engine.speak(text, sceneId: widget.sceneId);
        return;
      } catch (e) {
        logger.info('Cloud TTS failed, falling back to device TTS: $e');
      }
    }
    await _deviceTtsEngine.speak(text, sceneId: widget.sceneId);
  }

  /// 現在再生中かもしれない両エンジンをまとめて停止する(呼び分けの追跡コストを避ける)。
  Future<void> _stopSpeaking() async {
    await _deviceTtsEngine.stop();
    await _cloudTtsEngine.stop();
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
                  _openPaywall();
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
                _openPaywall();
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

  /// 「広告を見て +5回」: 広告を表示し、視聴完了したら当日上限を +5 し、
  /// 本日いっぱいクラウドTTS(高品質ボイス)も解放する(T-35)。
  /// 広告在庫切れ時は「穴対策」としてクラウドTTSのみ無償解放する(+5回は付与しない)。
  Future<void> _watchAdForBonus() async {
    if (_userId == null || _isAdLoading) return;
    setState(() => _isAdLoading = true);
    try {
      // 未ロードなら表示前にロードを試みる。
      if (!_rewardedAdService.isReady) {
        await _rewardedAdService.loadAd();
      }
      if (!_rewardedAdService.isReady) {
        // 広告在庫切れフォールバック: ユーザーに理不尽を与えないよう、
        // +5回は付与しないがクラウドTTSはその日いっぱい無償解放する。
        // サーバー(api/tts.ts)は usage_logs.ad_reward の有無で許可判定するため、
        // ローカルフラグだけでなくサーバー記録も必須(記録失敗時は解放を諦める)。
        final recorded = await _rateLimitService.recordTtsFallbackUnlock();
        if (recorded) {
          await _cloudTtsUnlockService.markUnlockedToday();
        }
        if (mounted) {
          if (recorded) {
            setState(() => _cloudTtsUnlockedToday = true);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(AppLocalizations.of(context).adLoadFailedTtsUnlocked),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(AppLocalizations.of(context).adLoadFailed),
              ),
            );
          }
        }
        return;
      }

      final earned = await _rewardedAdService.showAd();
      if (earned) {
        await _rateLimitService.grantAdBonus(_userId!);
        await _cloudTtsUnlockService.markUnlockedToday();
        await _loadRateLimit(); // 残数表示を更新
        if (mounted) {
          setState(() => _cloudTtsUnlockedToday = true);
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
      _stopRequestedByUser = true;
      await _speechService.stop(); // onComplete 経由で自動送信される
      return;
    }

    // 初回のみ: OS標準の権限プロンプトを出す「前」に理由を説明する(G6)。
    // Guideline 5.1.1(iv)対応: このダイアログを閉じたら必ず initialize()
    // （＝OS権限プロンプト）へ進む。離脱できるボタンは置かない。
    if (!_sttInitAttempted) {
      final l = AppLocalizations.of(context);
      await showMicRationaleDialog(
        context,
        message: l.micRationaleMessage,
        continueLabel: l.micRationaleContinue,
      );
      if (!mounted) return;

      final sttOk = await _speechService.initialize(); // ここでOS権限プロンプト
      _sttInitAttempted = true;
      if (!mounted) return;
      setState(() => _voiceReady = sttOk);
      if (!sttOk) {
        await _showMicDeniedDialog();
        return;
      }
    }

    // 過去に拒否された場合もボタンは隠さず、タップで復帰導線（設定画面）を案内する。
    // 注意: iOSは設定アプリで権限を変更すると本アプリを強制終了する（OS仕様）ため、
    // 変更後はアプリが再起動され、次回の初期化で新しい権限状態が反映される。
    if (!_voiceReady) {
      await _showMicDeniedDialog();
      return;
    }

    // iOSではマイク権限と音声認識権限が別管理で、initialize() 成功でも
    // マイクだけOFFのことがある（無音で空振りする）。開始前に毎回確認する。
    final micOk = await _speechService.hasPermission();
    logger.info('Mic permission check before listen: $micOk');
    if (!micOk) {
      await _showMicDeniedDialog();
      return;
    }

    await _stopSpeaking(); // 進行中の読み上げを止めてから録音
    // 入力欄に残っているテキスト（無音自動停止で保持された前回の発話や、
    // 手入力の途中文）は破棄せず接頭辞として保持し、新しい認識結果を後ろに連結する。
    // これにより「考え込み→無音自動停止→マイク再タップ」で発話の続きを追記できる。
    final prefix = _inputController.text.trim();
    _stopRequestedByUser = false;
    setState(() => _isListening = true);

    await _speechService.start(
      localeId: 'ja-JP',
      onResult: (transcript, _) {
        // 録音停止/送信後に iOS から遅れて届く最終認識結果を無視する。
        // このガードがないと、_sendMessage でクリアした入力欄に
        // 送信済みの発話テキストが復活してしまう（非同期の競合）。
        if (!_isListening || _isSending) return;
        _inputController.text = prefix.isEmpty ? transcript : '$prefix$transcript';
      },
      onComplete: () {
        if (!mounted) return;
        setState(() => _isListening = false);
        // 自動送信はユーザー自身がマイクタップで停止したときのみ。
        // OS の無音自動停止（Android約5秒/iOS約1分上限）で終了した場合は、
        // 発話途中の可能性があるため送信せず、入力欄にテキストを残す。
        // ユーザーはマイク再タップで続きを話すか、送信ボタンで確定できる。
        if (_stopRequestedByUser &&
            _inputController.text.trim().isNotEmpty &&
            !_isSending) {
          _sendMessage();
        }
        _stopRequestedByUser = false;
      },
      onError: (code) {
        if (!mounted) return;
        setState(() => _isListening = false);
        logger.info('Speech recognition error: $code');
      },
    );
  }

  /// マイク/音声認識が拒否・未対応のときに表示する復帰導線ダイアログ。
  Future<void> _showMicDeniedDialog() async {
    if (!mounted) return;
    final l = AppLocalizations.of(context);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.micDeniedTitle),
        content: Text(l.micDeniedMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              AppSettings.openAppSettings();
            },
            child: Text(l.openSettings),
          ),
        ],
      ),
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

    // 進行中のAI読み上げを止める(ユーザーが次の発話をした=前の読み上げは不要)。
    await _stopSpeaking();

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
          await _speak(cleanForSpeech(reply));
        }
      }

      // レート制限カウントはサーバー側 (api/chat.ts) で既にインクリメント済み。
      // ここでは表示更新のみ行う（クライアント側で再度加算すると二重カウントになる）。
      await _loadRateLimit(); // Refresh display

      // ストリークをインクリメント（メッセージ送信成功時）
      final newStreak = await _streakService.incrementStreak(_userId!, widget.sceneId);
      setState(() => _currentStreak = newStreak);

      // マイルストーン（3/7/14/30日）到達時の通知判定。
      // 既に表示済みのマイルストーンは NotificationScheduler 側の
      // SharedPreferences フラグで重複表示をガードしている。
      if (NotificationScheduler().isInitialized) {
        await NotificationScheduler()
            .checkAndScheduleMilestoneNotifications(newStreak);
      }

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
          'furiganaEnabled': _furiganaEnabled,
          // 'good'/null は調整不要のため送らない(サーバー側でも無視されるが通信量節約)。
          if (_difficultyFeedback == 'easy' || _difficultyFeedback == 'hard')
            'difficultyHint': _difficultyFeedback,
          'locale': LocaleService.resolveLocaleCodeForLogging(),
          'platform': currentPlatformCode(),
        }),
      );

      if (response.statusCode == 429) {
        // Rate limit reached - trigger upgrade dialog
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _openPaywall();
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
    _cloudTtsEngine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      // 背景と吹き出しの対比で視認性を出す(AppColors.chatBackground 参照)
      backgroundColor: AppColors.chatBackground,
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShrinkToFitText(widget.sceneName, minScale: 0.85),
            ShrinkToFitText(
              l.levelLabel(levelNameFromToken(l, widget.sceneData['level'] as String?)),
              style: Theme.of(context).textTheme.bodySmall,
              minScale: 0.85,
            ),
          ],
        ),
        actions: [
          if (!_isPremium)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Center(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _openPaywall,
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
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
          // T-35: 高品質ボイス(クラウドTTS)の状態表示は⋮メニュー内へ移動
          // (AppBar省略修正: 会話中に頻繁に使う音量トグルとは異なり
          // 1日1回程度の低頻度操作のため、常設actionsから外してもよい)。
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: _showSessionOptions,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : GestureDetector(
              // 入力欄の枠外タップでキーボードを閉じる（iOS標準的な操作感）
              onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
              behavior: HitTestBehavior.translucent,
              child: Column(
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
                          // メッセージ一覧のスクロール操作でもキーボードを閉じる
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
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
                                      ? AppColors.brand
                                      : AppColors.bubbleAssistant,
                                  // 発話者側の上角だけ小さくして「吹き出し」らしさを出す
                                  borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(isUser ? 16 : 4),
                                    topRight: Radius.circular(isUser ? 4 : 16),
                                    bottomLeft: const Radius.circular(16),
                                    bottomRight: const Radius.circular(16),
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: AppColors.bubbleShadow,
                                      blurRadius: 4,
                                      offset: Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    isUser
                                        ? Text(
                                            message.content,
                                            style: const TextStyle(color: Colors.white),
                                          )
                                        : _buildAssistantMessageText(message),
                                    const SizedBox(height: 4),
                                    isUser
                                        ? Text(
                                            message.formattedTime,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.white70,
                                            ),
                                          )
                                        : _buildAssistantFooterRow(message),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),

                // Rate limit status + Message input
                // (青グレー背景と対比する白い下部バーとしてまとめる)
                Container(
                  color: AppColors.chatInputSurface,
                  child: Column(
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
                            _openPaywall();
                          },
                          onDismiss: () =>
                              setState(() => _activeBannerStage = null),
                        ),
                      ),
                    // Rate Limit Widget
                    RateLimitWidget(
                      rateLimit: _rateLimit,
                      onUpgradePressed: _openPaywall,
                      // T-35: 「枯渇後のみ」から「1日1回、常時表示」に変更
                      // (+5回だけでなく高品質ボイスも解放するため開幕視聴を可能にする)。
                      showWatchAdButton: _rewardedAdService.isSupported &&
                          _rateLimit != null &&
                          !_rateLimit!.isPremium &&
                          !_cloudTtsUnlockedToday,
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
                          // T-36: 次に言えそうな例文+英訳のヒント。会話クォータは消費しない。
                          // 「ひらめき」の定番色=黄色の塗りつぶし電球で視認性を上げる
                          // (TestFlight目視フィードバック: 気づかれにくい)。
                          IconButton(
                            icon: Icon(
                              Icons.lightbulb,
                              color: Colors.amber.shade600,
                            ),
                            tooltip: l.hintButtonTooltip,
                            onPressed: _isSending ? null : _showHint,
                          ),
                          // 起動時はSTT未初期化でも表示（初回タップで説明→権限へ）。
                          // 未対応/拒否が確定した場合のみ隠し、テキスト入力へフォールバック。
                          // マイクボタンは常時表示（拒否時はタップで設定誘導ダイアログを出す）
                          ...[
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
                ),
              ],
            ),
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
            if (_ttsReady)
              ListTile(
                leading: Icon(
                  Icons.headset_mic,
                  color: (_isPremium || _cloudTtsUnlockedToday)
                      ? AppColors.brand
                      : Colors.grey,
                ),
                title: Text(
                  (_isPremium || _cloudTtsUnlockedToday)
                      ? AppLocalizations.of(context).cloudVoiceActiveTooltip
                      : AppLocalizations.of(context).cloudVoiceLockedTooltip,
                ),
                trailing: (_isPremium || _cloudTtsUnlockedToday)
                    ? const Icon(Icons.check, color: AppColors.brand)
                    : null,
                onTap: (_isPremium || _cloudTtsUnlockedToday)
                    ? () => Navigator.pop(context)
                    : () {
                        Navigator.pop(context);
                        _watchAdForBonus();
                      },
              ),
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
                  // T-36: 消去前(3往復以上なら)に「今日の単語」を表示する。
                  await _maybeShowVocabSummary();
                  await _messageService.clearSessionMessages(
                    userId: _userId!,
                    sceneId: widget.sceneId,
                  );
                  setState(() => _messages.clear());
                  // リセット直後もシーン別オープニング第一声を再表示する
                  await _insertOpeningLineIfNeeded();
                }
              },
            ),
            ListTile(
              title: Text(AppLocalizations.of(context).exitConversation),
              onTap: () async {
                // Navigator参照を先に確保しておく(_maybeShowVocabSummaryの
                // await中にこのシートのcontextが破棄されるため、取得済みの
                // NavigatorStateを使い回す)。
                final navigator = Navigator.of(context);
                navigator.pop();
                // T-36: 退出前(3往復以上なら)に「今日の単語」を表示する。
                await _maybeShowVocabSummary();
                if (!mounted) return;
                navigator.pop();
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
              _isPremium
                  ? AppLocalizations.of(context).dailyLimitReachedBodyPremium
                  : AppLocalizations.of(context).dailyLimitReachedBody,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            if (_rateLimit != null)
              Text(
                AppLocalizations.of(context).dailyLimitDetail(_rateLimit!.dailyLimit),
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            // Premium は既にアップグレード済みのため CTA を出さない
            if (!_isPremium) ...[
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
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_isPremium
                ? AppLocalizations.of(context).close
                : AppLocalizations.of(context).later),
          ),
          // Premium は既にアップグレード済みのためアップグレード導線を出さない
          if (!_isPremium)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _openPaywall();
              },
              child: Text(AppLocalizations.of(context).upgrade),
            ),
        ],
      ),
    );
  }

  /// ペイウォールへ遷移。購入/復元成功で戻ってきたら Premium 状態を反映する。
  Future<void> _openPaywall() async {
    final unlocked = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const PaywallScreen()),
    );
    if (unlocked == true && mounted) {
      setState(() => _isPremium = true);
      _showSuccess(AppLocalizations.of(context).welcomePremium);
      // シーン選択画面(呼び出し元)にもPremium状態を伝播し、
      // ロック済みシーンの表示をこの場で更新できるようにする。
      widget.onPremiumUnlocked?.call();
    }
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

  /// 辞書機能(なぞり選択→意味を調べる)の存在を、初回入室時に一度だけ
  /// SnackBarで案内する(Build 17)。2回目以降は表示しない。
  Future<void> _maybeShowWordLookupHint() async {
    final alreadySeen = await _learnerPreferencesService.hasSeenWordLookupHint();
    if (alreadySeen) return;
    await _learnerPreferencesService.setHasSeenWordLookupHint(true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).wordLookupHint),
          duration: const Duration(seconds: 4),
        ),
      );
    });
  }

  /// AIメッセージ本文(T-31): 範囲選択 + コンテキストメニューに
  /// 「意味を調べる」を追加する。会話状態(入力欄・TTS再生)には触れない。
  Widget _buildAssistantMessageText(Message message) {
    return SelectableText(
      message.content,
      style: const TextStyle(color: Colors.black),
      contextMenuBuilder: (context, editableTextState) {
        final buttonItems = editableTextState.contextMenuButtonItems.toList();
        final selection = editableTextState.textEditingValue.selection;
        final selectedText = selection.textInside(editableTextState.textEditingValue.text);

        if (selectedText.trim().isNotEmpty) {
          buttonItems.insert(
            0,
            ContextMenuButtonItem(
              label: AppLocalizations.of(context).lookUpMeaning,
              onPressed: () {
                ContextMenuController.removeAny();
                editableTextState.hideToolbar();
                _showWordLookup(selectedText.trim(), message.content);
              },
            ),
          );
        }

        // Google Play ポリシー必須要件: AI応答をアプリを離れずに報告できる
        // 導線(長押し→コンテキストメニュー→報告シート)。
        buttonItems.add(
          ContextMenuButtonItem(
            label: AppLocalizations.of(context).reportContent,
            onPressed: () {
              ContextMenuController.removeAny();
              editableTextState.hideToolbar();
              _showReportSheet(message);
            },
          ),
        );

        return AdaptiveTextSelectionToolbar.buttonItems(
          anchors: editableTextState.contextMenuAnchors,
          buttonItems: buttonItems,
        );
      },
    );
  }

  /// AIメッセージの時刻表示行。既存の長押し導線に加えて、辞書機能への
  /// もう一つの入口(単語一覧)を常時表示する。ふりがなの有無や漢字の
  /// 有無に関わらず表示する(施策②: サーバー側のAIが難語選定を行うため、
  /// クライアント側で事前に対象語の有無を判定する必要が無くなった)。
  Widget _buildAssistantFooterRow(Message message) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          message.formattedTime,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(width: 10),
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _showWordListSheet(message),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.menu_book_outlined,
                    size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  AppLocalizations.of(context).wordLookupButtonLabel,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// メッセージ全文をサーバーへ送り、AIが選んだ難語最大3件の詳細を
  /// まとめて表示する(施策②)。読み込み中・0件・エラーの表示は
  /// WordListSheet 内部(FutureBuilder)で行う。
  void _showWordListSheet(Message message) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => WordListSheet(
        messageContent: message.content,
        sceneId: widget.sceneId,
        sceneLevel: widget.sceneData['level'] as String?,
      ),
    );
  }

  void _showWordLookup(String term, String messageContent) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => WordLookupSheet(
        term: term,
        context: messageContent,
        sceneId: widget.sceneId,
      ),
    );
  }

  Future<void> _showReportSheet(Message message) async {
    if (_userId == null) return;
    final reported = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => ContentReportSheet(
        userId: _userId!,
        messageId: message.id,
        sceneId: widget.sceneId,
        reportedText: message.content,
      ),
    );
    if (reported == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).reportSubmitSuccess)),
      );
    }
  }

  /// T-36: 直近の会話を要約テキスト化してヒントAPIへ渡す。
  String _buildRecentContext() {
    final recent = _messages.length > 6
        ? _messages.sublist(_messages.length - 6)
        : _messages;
    return recent.map((m) => '${m.role}: ${m.content}').join('\n');
  }

  Future<void> _showHint() async {
    final chosen = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => HintSheet(
        context: _buildRecentContext(),
        sceneId: widget.sceneId,
      ),
    );
    if (chosen != null && chosen.isNotEmpty && mounted) {
      _inputController.text = chosen;
    }
  }

  /// T-36: 会話終了/リセット時、3往復以上あれば「今日の単語」ボトムシートを表示する
  /// (0〜2往復ならスキップ)。
  static const int _vocabSummaryMinUserTurns = 3;

  Future<void> _maybeShowVocabSummary() async {
    final userTurns = _messages.where((m) => m.role == 'user').length;
    if (userTurns < _vocabSummaryMinUserTurns || !mounted) return;

    final conversation =
        _messages.map((m) => '${m.role}: ${m.content}').join('\n');

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => VocabSummarySheet(
        conversation: conversation,
        sceneId: widget.sceneId,
      ),
    );
  }

}


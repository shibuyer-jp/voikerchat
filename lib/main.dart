import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:voikerchat/l10n/app_localizations.dart';
import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_messaging/firebase_messaging.dart'
  if (dart.library.html) 'package:voikerchat/stubs/firebase_messaging_stub.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart'
  if (dart.library.html) 'package:voikerchat/stubs/mobile_ads_stub.dart';
import 'models/diagnostic.dart';
import 'models/onboarding.dart';
import 'screens/ai_data_consent_screen.dart';
import 'screens/onboarding/diagnostic_test_screen_enhanced.dart';
import 'screens/onboarding/level_result_screen.dart';
import 'screens/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/revenuecat_service.dart';
import 'services/local_notification_service.dart';
import 'services/locale_service.dart';
import 'services/notification_scheduler.dart';
import 'services/remote_notification_service.dart';
import 'models/notification_data_model.dart';
import 'theme/app_theme.dart';

final logger = Logger('main');

/// バックグラウンド/終了状態でのメッセージハンドラー
/// iOS/Android でアプリがメモリから削除されている場合でも実行される
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    logger.info('[BackgroundHandler] Message received: ${message.data}');
    
    // Firebase と同じ初期化が必要（バックグラウンドコンテキストでは別プロセス）
    // ここではログのみ記録。UI 更新は必要ない
    
    final notificationData = NotificationDataModel.fromFirebaseMap(message.data);
    logger.info('[BackgroundHandler] Processed notification: ${notificationData.id}');
  } catch (e) {
    logger.warning('[BackgroundHandler] Error: $e');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // logging パッケージの Logger は、リスナーを登録しない限りどこにも
  // 出力されない(これまでアプリ内の Logger.warning/info 呼び出しが
  // 実質すべて握りつぶされていた)。コンソールへ出すリスナーを登録する。
  // リリースビルドではWARNING以上のみに絞る(debug/profileは従来通り全量)。
  Logger.root.level = kReleaseMode ? Level.WARNING : Level.ALL;
  Logger.root.onRecord.listen((record) {
    // ignore: avoid_print
    print('${record.level.name}: ${record.loggerName}: ${record.message}');
  });

  // 保存済みのUI言語設定をロード(runApp前に確定させ、起動時のちらつきを防ぐ)。
  await LocaleService().loadSavedLocale();

  // アプリ内言語切替(LocaleService)でも、OS言語変更時(didChangeLocales,
  // 下記RootScreen参照)と同様に予約通知を現在の言語で貼り直す。
  // NotificationScheduler側からLocaleServiceを参照しているため、循環import
  // を避けるためLocaleService側にこの呼び出しは置かず、ここで結線する。
  // 未初期化(Phase2未着手)の間はno-op。awaitはしない(UI操作をブロックしない)。
  LocaleService.currentLocale.addListener(() {
    if (NotificationScheduler().isInitialized) {
      NotificationScheduler().rescheduleForLocaleChange();
    }
  });

  // AdMob 初期化（できるだけ早期に呼ぶ）。Web は stub で no-op。
  try {
    MobileAds.instance.initialize();
  } catch (e) {
    logger.info('[main] AdMob init skipped: $e');
  }

  // Firebase Cloud Messaging のバックグラウンドメッセージハンドラー登録
  try {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    logger.info('[main] Background message handler registered');
  } catch (e) {
    logger.info('[main] Background handler registration skipped (Web/non-mobile): $e');
  }
  
  // LocalNotificationService 初期化（Web では失敗を許容）
  try {
    final localNotificationService = LocalNotificationService();
    await localNotificationService.initialize(
      onSelectNotification: (String? payload) {
        // ローカル通知タップ時の処理
        // payload は conversationId を含む場合がある
      },
    );

    // NotificationScheduler 初期化 + 毎日リマインダー(8/12/19)を予約。
    // zonedScheduleは同一IDへの再予約で上書きされるため、毎起動時に
    // 呼んでも安全（ロケール変更時の rescheduleForLocaleChange と同様）。
    // この時点ではSupabase(下記)がまだ未初期化のため、内部の履歴書き込み
    // (auth.uid()前提)は失敗して無視される。OS側の通知登録自体は
    // Supabase有無に関わらず確実に行われるよう、ここで一度呼んでおく。
    // 履歴書き込みは Supabase 初期化後に再度呼ぶことで確定させる。
    await NotificationScheduler().initialize(localNotificationService);
    await NotificationScheduler().scheduleDailyReminders();

    // RemoteNotificationService 初期化
    final remoteNotificationService = RemoteNotificationService();
    await remoteNotificationService.initialize(
      localNotificationService: localNotificationService,
    );
    
    // 通知ハンドラー設定（パターンB: conversationId で会話ナビゲーション）
    remoteNotificationService.setMessageHandler(
      (NotificationDataModel notification) {
        // フォアグラウンド通知受信時の処理
        // conversationId がある場合は、ユーザーが通知をタップしたときに
        // ChatScreen がそのシーンを自動ロードする
      },
      onTerminated: (NotificationDataModel notification) {
        // アプリ終了状態から通知タップで起動した場合
        // conversationId を使って目的の会話を開く
        if (notification.conversationId != null) {
          // NavigationService などを使って、
          // 該当 sceneId の ChatScreen に遷移
        }
      },
    );

    // 全ユーザー共通トピックを購読（Firebase Console からの
    // トピック配信・テスト送信がアプリに届くようにする）。
    // premium_users は課金状態に応じて後段で同期する。
    await remoteNotificationService.subscribeToDefaultTopics();
  } catch (e) {
    // Web では通知機能なしで継続
  }
  
  // RevenueCat 初期化
  final revenueCatService = RevenueCatService();
  try {
    await revenueCatService.initialize();
  } catch (e) {
    // RevenueCat initialization error is non-critical
  }

  // 課金状態に応じて premium_users トピックの購読を同期
  // （Premiumなら購読、非Premium/解約済みなら解除）。
  try {
    final isPremium = await revenueCatService.checkPremiumStatus();
    await RemoteNotificationService().updatePremiumTopicSubscription(isPremium);
  } catch (e) {
    logger.info('[main] Premium topic sync skipped: $e');
  }
  
  // Supabase 初期化（URL/publishableKey は --dart-define で注入。
  // 例: flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_PUBLISHABLE_KEY=...）
  // publishableKey はクライアント公開可（sb_publishable_...）。Secret keyは絶対に使わない。
  // 未設定の場合は初期化をスキップし、認証/DBなしでも起動可能にする。
  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabasePublishableKey =
      String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  if (supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty) {
    try {
      await Supabase.initialize(
        url: supabaseUrl,
        publishableKey: supabasePublishableKey,
      );
      logger.info('[main] Supabase initialized');

      // 匿名サインイン（検証段階）。
      // セッションが無ければ匿名ユーザーを作成し、auth.uid を確保する。
      // これにより user 単位のレート制限・RLS・accessToken 付きAPIが機能する。
      // 後日メール/SNS認証へ「同じUIDのまま」昇格でき、データは引き継がれる。
      final auth = Supabase.instance.client.auth;
      if (auth.currentSession == null) {
        await auth.signInAnonymously();
        logger.info('[main] Signed in anonymously');
      }

      // 毎日リマインダー(8/12/19)を予約 + 起動時リコンサイル
      // (予定を過ぎたscheduled履歴をdeliveredへ確定)。
      // zonedScheduleは同一IDへの再予約で上書きされるため、毎起動時に
      // 呼んでも安全（ロケール変更時の rescheduleForLocaleChange と同様）。
      // auth.uid() が必要な履歴書き込みを含むため、認証完了後に行う。
      if (NotificationScheduler().isInitialized) {
        await NotificationScheduler().reconcileHistoryOnLaunch();
        await NotificationScheduler().scheduleDailyReminders();
      }

      // RevenueCat の app_user_id を Supabase の user_id に紐付ける。
      // これにより RevenueCat Webhook が rate_limits.user_id と突合できるようになる。
      final userId = auth.currentUser?.id;
      if (userId != null) {
        final linked = await revenueCatService.loginWithUserId(userId);
        if (linked) {
          final isPremium = await revenueCatService.checkPremiumStatus();
          await RemoteNotificationService().updatePremiumTopicSubscription(isPremium);
        }
      }
    } catch (e) {
      logger.warning('[main] Supabase init / anonymous sign-in failed: $e');
    }
  } else {
    logger.warning(
      '[main] Supabase URL/publishableKey not provided via --dart-define; '
      'auth/DB features disabled',
    );
  }

  runApp(const VoikerchatApp());
}

class VoikerchatApp extends StatefulWidget {
  const VoikerchatApp({super.key});

  @override
  State<VoikerchatApp> createState() => _VoikerchatAppState();
}

class _VoikerchatAppState extends State<VoikerchatApp> {
  Locale? _locale = LocaleService.currentLocale.value;

  @override
  void initState() {
    super.initState();
    LocaleService.currentLocale.addListener(_onLocaleChanged);
  }

  @override
  void dispose() {
    LocaleService.currentLocale.removeListener(_onLocaleChanged);
    super.dispose();
  }

  void _onLocaleChanged() {
    setState(() => _locale = LocaleService.currentLocale.value);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Voikerchat',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: _locale,
      theme: AppTheme.light,
      home: const RootScreen(),
    );
  }
}

/// SharedPreferences キー（オンボーディング完了判定・診断レベル永続化）
const String _kFirstLaunchKey = 'is_first_launch';
const String _kUserLevelKey = 'user_diagnostic_level';

UserDiagnosticLevel _parseLevel(String name) {
  return UserDiagnosticLevel.values.firstWhere(
    (e) => e.name == name,
    orElse: () => UserDiagnosticLevel.beginner,
  );
}

/// RootScreen: 起動時に初回判定し、初回はオンボーディング、
/// 2回目以降は保存済みレベルで HomeScreen を直接表示する。
class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> with WidgetsBindingObserver {
  late final Future<Widget> _initialScreen = _resolveInitialScreen();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeLocales(List<Locale>? locales) {
    // 予約通知はスケジュール時点のロケールで焼き込まれるため、
    // ロケール変更時に貼り直す。scheduler が未初期化（Phase2未着手）
    // の間は no-op。
    if (NotificationScheduler().isInitialized) {
      NotificationScheduler().rescheduleForLocaleChange();
    }
  }

  Future<Widget> _resolveInitialScreen() async {
    final prefs = await SharedPreferences.getInstance();
    final firstLaunch = prefs.getBool(_kFirstLaunchKey) ?? true;
    final levelName = prefs.getString(_kUserLevelKey);
    final consentAccepted = prefs.getBool(kAiDataConsentAcceptedKey) ?? false;

    final Widget nextScreen = (!firstLaunch && levelName != null)
        ? HomeScreen(userLevel: _parseLevel(levelName))
        : const OnboardingFlowScreen();

    // is_first_launch とは独立に判定する。既存ユーザー(consentAccepted=false)
    // にも次回起動時にこの画面を表示するため(App Store Guideline
    // 5.1.1(i)/5.1.2(i)対応、2026-08-03リジェクト)。
    if (!consentAccepted) {
      return AiDataConsentScreen(nextScreen: nextScreen);
    }
    return nextScreen;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _initialScreen,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return snapshot.data ?? const OnboardingFlowScreen();
      },
    );
  }
}

class OnboardingFlowScreen extends StatefulWidget {
  const OnboardingFlowScreen({super.key});

  @override
  State<OnboardingFlowScreen> createState() => _OnboardingFlowScreenState();
}

class _OnboardingFlowScreenState extends State<OnboardingFlowScreen> {
  late OnboardingState currentState;

  @override
  void initState() {
    super.initState();
    currentState = OnboardingState();
  }

  void _handleDiagnosticComplete(DiagnosticResult result) {
    setState(() {
      currentState = currentState.withDiagnosticResult(result);
    });
  }

  Future<void> _handleLevelResultContinue() async {
    final result = currentState.diagnosticResult;
    if (result == null) return;

    // オンボーディング完了・診断レベルを永続化（次回起動はHomeScreen直行）
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUserLevelKey, result.level.name);
    await prefs.setBool(_kFirstLaunchKey, false);

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => HomeScreen(userLevel: result.level),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 診断テスト完了状態
    if (currentState.diagnosisDone && currentState.diagnosticResult != null) {
      return LevelResultScreen(
        result: currentState.diagnosticResult!,
        onContinue: _handleLevelResultContinue,
      );
    }

    // 診断テスト画面（enhanced 版：解説・ヒント・スコア表示付き）
    return DiagnosticTestScreenEnhanced(
      onTestComplete: _handleDiagnosticComplete,
    );
  }
}

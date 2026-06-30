import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_messaging/firebase_messaging.dart'
  if (dart.library.html) 'package:voikerchat/stubs/firebase_messaging_stub.dart';
import 'models/diagnostic.dart';
import 'models/onboarding.dart';
import 'screens/onboarding/diagnostic_test_screen.dart';
import 'screens/onboarding/level_result_screen.dart';
import 'screens/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/revenuecat_service.dart';
import 'services/local_notification_service.dart';
import 'services/remote_notification_service.dart';
import 'models/notification_data_model.dart';

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

class VoikerchatApp extends StatelessWidget {
  const VoikerchatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Voikerchat',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        fontFamily: 'Roboto',
      ),
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

class _RootScreenState extends State<RootScreen> {
  late final Future<Widget> _initialScreen = _resolveInitialScreen();

  Future<Widget> _resolveInitialScreen() async {
    final prefs = await SharedPreferences.getInstance();
    final firstLaunch = prefs.getBool(_kFirstLaunchKey) ?? true;
    final levelName = prefs.getString(_kUserLevelKey);

    if (!firstLaunch && levelName != null) {
      return HomeScreen(userLevel: _parseLevel(levelName));
    }
    return const OnboardingFlowScreen();
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

    // 診断テスト画面（デフォルト）
    return DiagnosticTestScreen(
      onTestComplete: _handleDiagnosticComplete,
    );
  }
}

import 'package:flutter/material.dart';
import 'models/diagnostic.dart';
import 'models/onboarding.dart';
import 'screens/onboarding/diagnostic_test_screen.dart';
import 'screens/onboarding/level_result_screen.dart';
import 'services/revenuecat_service.dart';
import 'services/local_notification_service.dart';
import 'services/remote_notification_service.dart';
import 'models/notification_data_model.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // LocalNotificationService 初期化
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
  
  // RevenueCat 初期化
  final revenueCatService = RevenueCatService();
  try {
    await revenueCatService.initialize();
  } catch (e) {
    // RevenueCat initialization error is non-critical
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
      home: const OnboardingFlowScreen(),
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

  void _handleLevelResultContinue() {
    // シーン選択画面へ遷移（次のステップ）
    // TODO: Scene selection screen implementation
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('シーン選択画面は次のフェーズで実装します')),
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

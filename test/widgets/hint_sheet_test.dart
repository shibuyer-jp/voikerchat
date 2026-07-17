import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voikerchat/l10n/app_localizations.dart';
import 'package:voikerchat/widgets/hint_sheet.dart';

/// ローカライズ対応後のテスト用ラッパー。
Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('ja'),
    home: Scaffold(body: child),
  );
}

void main() {
  group('HintSheet Widget Tests', () {
    // T-36: 未ログイン(テスト環境はSupabaseセッションなし)でも例外を投げず、
    // エラーメッセージへ落ちることを確認する。
    testWidgets('Shows an error message when no auth session is available',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          const HintSheet(
            context: 'user: こんにちは\nassistant: こんにちは、元気ですか?',
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle();

      expect(find.text('ヒント'), findsOneWidget);
      expect(find.text('ヒントを取得できませんでした。もう一度お試しください。'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

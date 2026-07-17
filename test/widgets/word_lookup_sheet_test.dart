import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voikerchat/l10n/app_localizations.dart';
import 'package:voikerchat/widgets/word_lookup_sheet.dart';

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
  group('WordLookupSheet Widget Tests', () {
    // T-31: 未ログイン(テスト環境はSupabaseセッションなし)でも例外を投げず、
    // エラーメッセージへ落ちることを確認する(オフライン/失敗時の文言表示)。
    testWidgets('Shows an error message when no auth session is available',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          const WordLookupSheet(
            term: 'テスト',
            context: 'これはテストの文脈です。',
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle();

      expect(find.text('テスト'), findsOneWidget);
      expect(find.text('意味を取得できませんでした。もう一度お試しください。'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

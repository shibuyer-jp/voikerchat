import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voikerchat/l10n/app_localizations.dart';
import 'package:voikerchat/widgets/content_report_sheet.dart';

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
  group('ContentReportSheet Widget Tests', () {
    testWidgets(
        'Shows reason options and enables submit only after a reason is chosen',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          const ContentReportSheet(
            userId: 'test-user',
            reportedText: 'テストのAI応答',
          ),
        ),
      );

      expect(find.text('このメッセージを報告'), findsOneWidget);
      expect(find.text('不適切な内容'), findsOneWidget);
      expect(find.text('誤った情報'), findsOneWidget);
      expect(find.text('その他'), findsOneWidget);

      final submitButtonFinder = find.widgetWithText(ElevatedButton, '送信');
      expect(submitButtonFinder, findsOneWidget);
      ElevatedButton submitButton = tester.widget(submitButtonFinder);
      expect(submitButton.onPressed, isNull);

      await tester.tap(find.text('不適切な内容'));
      await tester.pump();

      submitButton = tester.widget(submitButtonFinder);
      expect(submitButton.onPressed, isNotNull);
      expect(tester.takeException(), isNull);
    });
  });
}

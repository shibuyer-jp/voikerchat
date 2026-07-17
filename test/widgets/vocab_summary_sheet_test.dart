import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voikerchat/l10n/app_localizations.dart';
import 'package:voikerchat/widgets/vocab_summary_sheet.dart';

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
  group('VocabSummarySheet Widget Tests', () {
    // T-36: 未ログイン(テスト環境はSupabaseセッションなし)でも例外を投げず、
    // エラーメッセージへ落ちることを確認する。
    testWidgets('Shows an error message when no auth session is available',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          const VocabSummarySheet(
            conversation: 'user: こんにちは\nassistant: こんにちは、元気ですか?',
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle();

      expect(find.text('今日の単語'), findsOneWidget);
      expect(find.text('今回は単語をまとめられませんでした。'), findsOneWidget);
      // recap は取得失敗時にセクションごと非表示になる。
      expect(find.text('今日の言い直し'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    // 競合分析B案: 難易度フィードバックの3択チップが表示され、
    // 選択すると確認メッセージが出ること。
    testWidgets('Shows difficulty feedback chips and confirms selection',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          const VocabSummarySheet(
            conversation: 'user: こんにちは\nassistant: こんにちは、元気ですか?',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('今日の会話はどうでしたか？'), findsOneWidget);
      expect(find.text('かんたんすぎた'), findsOneWidget);
      expect(find.text('ちょうどよかった'), findsOneWidget);
      expect(find.text('むずかしかった'), findsOneWidget);
      expect(find.text('わかりました！次の会話で調整します。'), findsNothing);

      await tester.tap(find.text('むずかしかった'));
      await tester.pumpAndSettle();

      expect(find.text('わかりました！次の会話で調整します。'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

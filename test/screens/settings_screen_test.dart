import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voikerchat/l10n/app_localizations.dart';
import 'package:voikerchat/screens/settings_screen.dart';

/// ローカライズ対応後のテスト用ラッパー。
Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('ja'),
    home: child,
  );
}

void main() {
  group('SettingsScreen language picker', () {
    testWidgets('defaults to "follow system" and switches to English',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(_wrap(const SettingsScreen()));
      await tester.pumpAndSettle();

      // デフォルトは「端末設定に従う」
      expect(find.text('言語'), findsOneWidget);
      expect(find.text('端末設定に従う'), findsOneWidget);

      // 言語タイルをタップしてダイアログを開く
      await tester.tap(find.text('言語'));
      await tester.pumpAndSettle();

      expect(find.text('日本語'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);
      expect(find.text('Filipino'), findsOneWidget);

      // English を選択
      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();

      // ダイアログが閉じ、サブタイトルが更新される
      expect(find.text('English'), findsOneWidget);
      expect(find.text('端末設定に従う'), findsNothing);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('app_locale'), 'en');

      expect(tester.takeException(), isNull);
    });
  });
}

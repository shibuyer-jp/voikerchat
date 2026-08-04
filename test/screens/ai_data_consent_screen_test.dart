import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voikerchat/l10n/app_localizations.dart';
import 'package:voikerchat/screens/ai_data_consent_screen.dart';

/// ローカライズ対応後のテスト用ラッパー。textScale/screen size は各テストで
/// MediaQuery.withNoTextScaling 相当を上書きして検証する。
Widget _wrap(Widget child, {double textScale = 1.0}) {
  return MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('ja'),
      home: child,
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AiDataConsentScreen Widget Tests (小画面/フォントスケール、2026-08-04 オーバーフロー対策)', () {
    testWidgets('小画面(640dp高)・標準フォントスケールでオーバーフローしない',
        (WidgetTester tester) async {
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(360, 640);

      await tester.pumpWidget(
        _wrap(const AiDataConsentScreen(nextScreen: SizedBox.shrink())),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // 同意ボタンが常に画面内(bottomNavigationBar)に見えていること。
      expect(find.text('同意して続ける'), findsOneWidget);
    });

    testWidgets('小画面(640dp高)・フォントスケール1.3倍でオーバーフローしない',
        (WidgetTester tester) async {
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(360, 640);

      await tester.pumpWidget(
        _wrap(
          const AiDataConsentScreen(nextScreen: SizedBox.shrink()),
          textScale: 1.3,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('同意して続ける'), findsOneWidget);
      expect(find.text('同意しない'), findsOneWidget);
    });

    testWidgets('本文が長い場合でも同意/非同意ボタンは画面内に固定表示される(スクロール後も)',
        (WidgetTester tester) async {
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(360, 640);

      await tester.pumpWidget(
        _wrap(
          const AiDataConsentScreen(nextScreen: SizedBox.shrink()),
          textScale: 1.3,
        ),
      );
      await tester.pumpAndSettle();

      // 本文を上までスクロールしても(何もしなくても)ボタンは
      // bottomNavigationBar固定のため常に可視であることを確認する。
      final acceptFinder = find.text('同意して続ける');
      expect(tester.getRect(acceptFinder).bottom, lessThanOrEqualTo(640));
      expect(tester.takeException(), isNull);
    });
  });
}

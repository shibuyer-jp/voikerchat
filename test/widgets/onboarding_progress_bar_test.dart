import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voikerchat/l10n/app_localizations.dart';
import 'package:voikerchat/widgets/onboarding_progress_bar.dart';

/// ローカライズ対応後のテスト用ラッパー。
/// AppLocalizations のデリゲートを供給し、日本語ロケール固定で検証する。
Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('ja'),
    home: Scaffold(body: child),
  );
}

void main() {
  group('OnboardingProgressBar Widget Tests', () {
    testWidgets('Renders progress bar with correct initial state',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          const OnboardingProgressBar(
            currentStep: 1,
            completedSteps: [false, false, false, false, false],
          ),
        ),
      );

      expect(find.text('ステップ 1/5'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('Updates progress bar when step changes',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          const OnboardingProgressBar(
            currentStep: 2,
            completedSteps: [true, false, false, false, false],
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('ステップ 2/5'), findsOneWidget);
    });

    testWidgets('Shows completed step indicators correctly',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          const OnboardingProgressBar(
            currentStep: 3,
            completedSteps: [true, true, false, false, false],
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.check), findsWidgets);
    });

    testWidgets('Handles all 5 steps correctly', (WidgetTester tester) async {
      for (int step = 1; step <= 5; step++) {
        await tester.pumpWidget(
          _wrap(
            OnboardingProgressBar(
              currentStep: step,
              completedSteps: List.generate(5, (i) => i < step - 1),
            ),
          ),
        );

        await tester.pumpAndSettle();
        expect(find.text('ステップ $step/5'), findsOneWidget);
      }
    });
  });
}

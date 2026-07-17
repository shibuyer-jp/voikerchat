import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voikerchat/l10n/app_localizations.dart';
import 'package:voikerchat/models/diagnostic.dart';
import 'package:voikerchat/widgets/scene_preview_card.dart';

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
  group('ScenePreviewCard Widget Tests', () {
    // T-32: 画像アセット未生成のシーンでも、Image.asset の errorBuilder で
    // キャライニシャル+アクセント色のプレースホルダーへフォールバックし、
    // 例外を投げずに描画できることを確認する。
    // sceneId は scene_01〜scene_18.webp(全シーン分の画像アセットが揃った、
    // 2026-07-17)のどれとも重複しない範囲外の値を使い、意図的に
    // 「アセットが無いシーン」を再現する。
    testWidgets('Falls back to initial-letter placeholder when image asset is missing',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          ScenePreviewCard(
            sceneId: 99,
            sceneName: '介護のしごと',
            characterName: 'Haruko',
            description: '介護施設での声かけ・体調確認',
            recommendedLevel: UserDiagnosticLevel.intermediate,
            accentColor: const Color(0xFF8FBC8F),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('介護のしごと'), findsOneWidget);
      expect(find.text('H'), findsOneWidget); // characterName先頭文字のプレースホルダー
      expect(find.byType(Image), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    // 実際に配置された画像アセット(scene_14.webp = Haruko)がプレースホルダー
    // ではなく本物の画像として描画されることを確認する(2026-07-17、画像18枚配置)。
    testWidgets('Renders the real character image when the asset exists',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          ScenePreviewCard(
            sceneId: 14,
            sceneName: '介護のしごと',
            characterName: 'Haruko',
            description: '介護施設での声かけ・体調確認',
            recommendedLevel: UserDiagnosticLevel.intermediate,
            accentColor: const Color(0xFF8FBC8F),
          ),
        ),
      );
      await tester.pump();
      // Image.asset のデコードが非同期のため、フレームを追加で進める。
      await tester.pump();

      expect(find.byType(Image), findsOneWidget);
      // プレースホルダー(キャライニシャル)は描画されないはず。
      expect(find.text('H'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Shows lock overlay on the thumbnail when locked',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          ScenePreviewCard(
            sceneId: 9,
            sceneName: '熱血戦闘',
            characterName: 'Raiki',
            description: '意志表明・強い決意表現',
            recommendedLevel: UserDiagnosticLevel.intermediate,
            isPremium: true,
            isLocked: true,
            accentColor: const Color(0xFFFF3333),
          ),
        ),
      );
      await tester.pump();

      // ヘッダーの静的ロックアイコン + サムネイル上のロックオーバーレイの2箇所
      expect(find.byIcon(Icons.lock), findsNWidgets(2));
      expect(find.byType(Opacity), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });
}

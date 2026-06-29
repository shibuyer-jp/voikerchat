import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:voikerchat/main.dart';

void main() {
  testWidgets('VoikerchatApp renders', (WidgetTester tester) async {
    // RootScreen が起動時に SharedPreferences を読むため、テスト用の
    // モック値を注入してプラグイン未登録エラーを防ぐ。
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const VoikerchatApp());
    // RootScreen の FutureBuilder（prefs解決）を1フレーム進める。
    await tester.pump();

    expect(find.byType(VoikerchatApp), findsOneWidget);
  });
}

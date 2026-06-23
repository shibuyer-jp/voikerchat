import 'package:flutter_test/flutter_test.dart';

import 'package:voikerchat/main.dart';

void main() {
  testWidgets('VoikerchatApp renders', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const VoikerchatApp());

    // Verify app launches without error
    expect(find.byType(VoikerchatApp), findsOneWidget);
  });
}

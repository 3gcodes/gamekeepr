import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gamekeepr/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ProviderScope(child: GameKeeprApp()));

    // Verify that the app title is displayed
    expect(find.text('Game Keepr'), findsOneWidget);
  });
}

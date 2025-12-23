import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kare/main.dart';

void main() {
  testWidgets('App starts without crashing', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const AppRoot());

    // Verify that the home screen is displayed (or the PIN screen if configured).
    // This is a basic test to ensure the app initializes.
    expect(find.byType(Scaffold), findsOneWidget);
  });
}

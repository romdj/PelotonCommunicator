// This is a basic Flutter widget test for the Peloton Communicator app.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/main.dart';

void main() {
  testWidgets('PTT app loads correctly smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that the app loads with the expected PTT UI elements
    expect(find.text('READY'), findsOneWidget);
    expect(find.text('PTT Mode'), findsOneWidget);
    expect(find.byIcon(Icons.mic), findsOneWidget);

    // Verify test buttons are present
    expect(find.text('Test Press'), findsOneWidget);
    expect(find.text('Test Release'), findsOneWidget);
  });
}

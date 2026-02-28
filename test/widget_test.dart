import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hflow/app/app.dart';

void main() {
  testWidgets('App loads without crashing', (WidgetTester tester) async {
    // Build app
    await tester.pumpWidget(const HFlowApp());

    // Verify splash screen loads (logo or something on screen)
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
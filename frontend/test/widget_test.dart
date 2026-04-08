import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitlearn/main.dart';

void main() {
  testWidgets('FitLearnApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: FitLearnApp()));
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}

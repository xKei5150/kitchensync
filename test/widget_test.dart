import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/features/home/home_screen.dart';

void main() {
  testWidgets('HomeScreen renders bootstrap milestone copy', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    expect(find.text('Bootstrap milestone complete'), findsOneWidget);
    expect(find.text('Force a test crash'), findsOneWidget);
  });

  testWidgets('HomeScreen exposes Semantics header', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    final semantics = tester.getSemantics(
      find.text('Bootstrap milestone complete'),
    );
    expect(semantics.label, 'Bootstrap milestone complete');
  });
}

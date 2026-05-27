import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/features/home/home_screen.dart';

void main() {
  testWidgets('HomeScreen shows ingredient-picker entry', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    expect(find.text('Pantry'), findsOneWidget);
    expect(find.text('Pick an ingredient'), findsOneWidget);
    expect(find.text('Create custom ingredient'), findsOneWidget);
    expect(find.text('Force a test crash'), findsOneWidget);
  });
}

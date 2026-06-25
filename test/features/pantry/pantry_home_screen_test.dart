import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/app/theme.dart';
import 'package:kitchensync/core/widgets/widgets.dart';
import 'package:kitchensync/features/pantry/domain/entities/pantry_item.dart';
import 'package:kitchensync/features/pantry/presentation/providers/pantry_providers.dart';
import 'package:kitchensync/features/pantry/presentation/screens/pantry_home_screen.dart';

void main() {
  testWidgets('PantryHomeScreen wears the new chrome over the live stream', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pantrySectionStreamProvider.overrideWith(
            (ref) => Stream.value(<PantryItem>[]),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const PantryHomeScreen(),
        ),
      ),
    );
    await tester.pump();

    // Folio chrome from the redesign.
    expect(find.text('On the shelves'), findsOneWidget);
    // The four section tabs are present.
    expect(find.text('Food'), findsOneWidget);
    expect(find.text('Leftovers'), findsOneWidget);
    // Empty section → empty state + the Add affordance.
    expect(find.byType(KsEmptyState), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Add'), findsOneWidget);
  });

  testWidgets('PantryHomeScreen renders in dark theme without error', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pantrySectionStreamProvider.overrideWith(
            (ref) => Stream.value(<PantryItem>[]),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const PantryHomeScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('On the shelves'), findsOneWidget);
  });

  testWidgets('PantryHomeScreen shows a skeleton while the stream is loading', (
    tester,
  ) async {
    // A stream that never emits keeps the section provider in its loading
    // state, so the shelf shows the skeleton rather than a bare spinner.
    final pending = Completer<List<PantryItem>>();
    addTearDown(() => pending.complete(const <PantryItem>[]));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pantrySectionStreamProvider.overrideWith(
            (ref) => Stream.fromFuture(pending.future),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const PantryHomeScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(KsSkeleton), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}

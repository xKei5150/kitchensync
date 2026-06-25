import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/app/theme.dart';
import 'package:kitchensync/core/widgets/widgets.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/entities/pantry_item.dart';
import 'package:kitchensync/features/pantry/domain/entities/waste_event.dart';
import 'package:kitchensync/features/pantry/presentation/providers/pantry_providers.dart';
import 'package:kitchensync/features/pantry/presentation/screens/insights_screen.dart';

PantryItem _item({
  required String id,
  required PantrySection section,
  DateTime? expiry,
}) {
  final now = DateTime.now();
  return PantryItem(
    id: id,
    householdId: 'h1',
    ingredientId: 'ing-$id',
    quantity: 1,
    unit: Unit.piece,
    section: section,
    expiryDate: expiry,
    createdAt: now,
    updatedAt: now,
  );
}

Future<void> _pump(WidgetTester tester, List<PantryItem> items) async {
  tester.view.physicalSize = const Size(400, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        pantryAllItemsStreamProvider.overrideWith((ref) => Stream.value(items)),
        wasteHistoryStreamProvider.overrideWith(
          (ref) => Stream.value(<WasteEvent>[]),
        ),
      ],
      child: MaterialApp(theme: AppTheme.light(), home: const InsightsScreen()),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('Insights counts live items into the freshness donut', (
    tester,
  ) async {
    final now = DateTime.now();
    await _pump(tester, [
      _item(
        id: '1',
        section: PantrySection.food,
        expiry: now.add(const Duration(days: 30)),
      ),
      _item(
        id: '2',
        section: PantrySection.food,
        expiry: now.add(const Duration(days: 1)),
      ),
      _item(
        id: '3',
        section: PantrySection.bulk,
        expiry: now.subtract(const Duration(days: 2)),
      ),
      _item(id: '4', section: PantrySection.leftover),
    ]);

    // Four items measured, named in the donut well.
    expect(find.text('4'), findsOneWidget);
    expect(find.text('items'), findsOneWidget);
    // Freshness legend, each bucket labelled (never colour alone).
    expect(find.text('Fresh'), findsOneWidget);
    expect(find.text('Soon'), findsOneWidget);
    expect(find.text('Expired'), findsOneWidget);
    expect(find.text('No date'), findsOneWidget);
  });

  testWidgets('Insights renders the section balance from live sections', (
    tester,
  ) async {
    await _pump(tester, [
      _item(id: '1', section: PantrySection.food),
      _item(id: '2', section: PantrySection.food),
      _item(id: '3', section: PantrySection.bulk),
      _item(id: '4', section: PantrySection.leftover),
    ]);

    expect(find.text('Section balance'.toUpperCase()), findsOneWidget);
    // 2/4 of the pantry is Food.
    expect(find.text('Food'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
  });

  testWidgets('Insights keeps the premium veil over the working charts', (
    tester,
  ) async {
    await _pump(tester, [_item(id: '1', section: PantrySection.food)]);

    expect(find.byType(KsPremiumLock), findsOneWidget);
    expect(find.text('See your pantry, measured'), findsOneWidget);
  });

  testWidgets('Insights renders in dark theme without error', (tester) async {
    tester.view.physicalSize = const Size(400, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pantryAllItemsStreamProvider.overrideWith(
            (ref) =>
                Stream.value([_item(id: '1', section: PantrySection.food)]),
          ),
          wasteHistoryStreamProvider.overrideWith(
            (ref) => Stream.value(<WasteEvent>[]),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const InsightsScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Insights'), findsOneWidget);
  });
}

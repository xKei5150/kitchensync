import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/app/theme.dart';
import 'package:kitchensync/core/preferences/preferences_providers.dart';
import 'package:kitchensync/core/utils/clock.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/ingredient_dictionary/presentation/providers/ingredient_providers.dart';
import 'package:kitchensync/features/pantry/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/entities/waste_event.dart';
import 'package:kitchensync/features/pantry/presentation/providers/pantry_providers.dart';
import 'package:kitchensync/features/pantry/presentation/screens/waste_log_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<Widget> _wrap({
  required ThemeData theme,
  List<WasteEvent> events = const [],
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      clockProvider.overrideWithValue(FakeClock(DateTime(2026, 7, 17))),
      wasteHistoryStreamProvider.overrideWith((ref) => Stream.value(events)),
    ],
    child: MaterialApp(theme: theme, home: const WasteLogScreen()),
  );
}

void main() {
  testWidgets(
    'WasteLogScreen renders live event totals without savings claims',
    (tester) async {
      tester.view.physicalSize = const Size(400, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        await _wrap(
          theme: AppTheme.light(),
          events: [
            WasteEvent(
              id: 'waste-1',
              householdId: 'h1',
              pantryItemId: 'rice-stock',
              ingredientId: 'rice',
              quantity: 250,
              unit: UnitId.g,
              reason: WasteReason.expired,
              date: DateTime(2026, 7, 16),
            ),
          ],
        ),
      );
      await tester.pump();

      expect(find.text('1'), findsWidgets);
      expect(find.text('waste event recorded this month'), findsOneWidget);
      expect(find.text('WASTE THIS WEEK'), findsOneWidget);
      expect(
        find.text('1 waste event recorded in the last seven days.'),
        findsOneWidget,
      );
      expect(find.textContaining('saved'), findsNothing);
    },
  );

  testWidgets('WasteLogScreen renders in dark theme without error', (
    tester,
  ) async {
    await tester.pumpWidget(await _wrap(theme: AppTheme.dark()));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}

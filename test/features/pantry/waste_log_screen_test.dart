import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/app/theme.dart';
import 'package:kitchensync/core/preferences/preferences_providers.dart';
import 'package:kitchensync/features/pantry/domain/entities/waste_event.dart';
import 'package:kitchensync/features/pantry/presentation/providers/pantry_providers.dart';
import 'package:kitchensync/features/pantry/presentation/screens/waste_log_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<Widget> _wrap({required ThemeData theme}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      wasteHistoryStreamProvider.overrideWith(
        (ref) => Stream.value(<WasteEvent>[]),
      ),
    ],
    child: MaterialApp(theme: theme, home: const WasteLogScreen()),
  );
}

void main() {
  testWidgets('WasteLogScreen renders the savings hero and weekly almanac', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(await _wrap(theme: AppTheme.light()));
    await tester.pump();

    expect(find.text('£42'), findsOneWidget);
    expect(
      find.text('saved this month by shopping what you had'),
      findsOneWidget,
    );
    expect(find.text('WASTE THIS WEEK'), findsOneWidget);
    expect(
      find.text('Three things saved from the bin this week.'),
      findsOneWidget,
    );
  });

  testWidgets('WasteLogScreen renders in dark theme without error', (
    tester,
  ) async {
    await tester.pumpWidget(await _wrap(theme: AppTheme.dark()));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kitchensync/app/router.dart';
import 'package:kitchensync/app/theme.dart';

/// On-device guard for the Navigator page-key collision that crashed the day
/// view: tapping "Recipe" used to `push('/recipes')` — a StatefulShellRoute
/// branch — which re-instantiated the shell as a second root page and tripped
/// `!keyReservation.contains(key)`. The button now opens the recipe detail
/// ("Closer Look") via the root-level `/recipe` route, so no shell is
/// re-instantiated. Runs the real widgets and real taps on the simulator; no
/// Firebase needed since these screens are presentational.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Today → Start cooking → Recipe navigates without crashing', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: container.read(routerProvider),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Today → day view (full-screen route pushed over the shell).
    await tester.tap(find.text('Start cooking'));
    await tester.pumpAndSettle();
    expect(find.text('Wednesday 25'), findsOneWidget);

    // Day view → recipe detail. Previously crashed here.
    await tester.tap(find.widgetWithText(OutlinedButton, 'Recipe'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Tomato & white bean braise'), findsOneWidget);
  });
}

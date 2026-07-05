import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/app/theme.dart';
import 'package:kitchensync/core/widgets/widgets.dart';

Future<void> _pump(WidgetTester tester, ThemeData theme) {
  return tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: const Scaffold(body: OfflineBanner()),
    ),
  );
}

void main() {
  testWidgets('OfflineBanner speaks the house voice, not an alarm', (
    tester,
  ) async {
    await _pump(tester, AppTheme.light());

    expect(find.text("You're offline"), findsOneWidget);
    expect(find.textContaining('Edits are saved here'), findsOneWidget);
    // Informational warm brown, never the error-red of a true failure.
    expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
  });

  testWidgets('OfflineBanner renders in dark theme without error', (
    tester,
  ) async {
    await _pump(tester, AppTheme.dark());
    expect(tester.takeException(), isNull);
    expect(find.text("You're offline"), findsOneWidget);
  });

  testWidgets('OfflineBanner overlays instead of pushing content down', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: Stack(
            fit: StackFit.expand,
            children: [
              Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  key: ValueKey('content-start'),
                  width: 10,
                  height: 10,
                ),
              ),
              Align(alignment: Alignment.topCenter, child: OfflineBanner()),
            ],
          ),
        ),
      ),
    );

    expect(
      tester.getTopLeft(find.byKey(const ValueKey('content-start'))).dy,
      0,
    );
  });

  testWidgets('OfflineBanner can be dismissed to an indicator', (tester) async {
    var dismissed = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => Stack(
              children: [
                if (!dismissed)
                  OfflineBanner(
                    onDismiss: () => setState(() => dismissed = true),
                  )
                else
                  const OfflineIndicator(),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pump();

    expect(find.text("You're offline"), findsNothing);
    expect(find.byType(OfflineIndicator), findsOneWidget);
    expect(find.byType(Tooltip), findsNothing);
    expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);
  });

  testWidgets('OnlineBanner is dismissible and has no persistent indicator', (
    tester,
  ) async {
    var dismissed = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => Stack(
              children: [
                if (!dismissed)
                  OnlineBanner(
                    onDismiss: () => setState(() => dismissed = true),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text("You're back online"), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pump();

    expect(find.text("You're back online"), findsNothing);
    expect(find.byType(OfflineIndicator), findsNothing);
  });
}

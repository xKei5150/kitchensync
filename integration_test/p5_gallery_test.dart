import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kitchensync/app/theme.dart';
import 'package:kitchensync/features/dev_tools/system_states_screen.dart';
import 'package:kitchensync/features/pantry/presentation/screens/insights_screen.dart';

import '_gallery_harness.dart';
import '_helpers.dart';

/// On-device visual walk of the P5 "System States & Intelligence" surfaces: the
/// debug-only system-states gallery and the Premium Insights screen, in light
/// and dark.
///
/// Like P3 this target used to assert nothing, so it passed while photographing
/// the sign-in page five times. It now boots the emulator harness and proves
/// each destination.
///
/// The system-states gallery animates forever (skeleton shimmer, the sync
/// spinner), so it advances fixed frames rather than using
/// [WidgetTester.pumpAndSettle], which would never return.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> verifyP5(
    WidgetTester tester, {
    required ThemeData theme,
    required String mode,
  }) async {
    final light = await bootGallery(
      tester,
      binding,
      theme: theme,
      settle: settleFrames,
      grantPremium: true,
    );
    await light.visit(
      '/dev/system-states',
      expect: find.byType(SystemStatesScreen),
      screenshot: '01-system-states-$mode',
    );
    await light.visit(
      '/insights',
      expect: find.byType(InsightsScreen),
      screenshot: '02-insights-$mode',
    );
  }

  // Each gallery owns a ProviderContainer with live Firebase streams. Keep
  // light and dark capture in separate widget tests so Flutter tears down the
  // first MaterialApp before the next container starts listening. Replacing a
  // live router tree in the same build phase can otherwise synchronously notify
  // the outgoing screen and throw `setState() or markNeedsBuild() called during
  // build` — a gallery harness artefact, not a route being photographed.
  testWidgets('P5 system states render on-device in light mode', (tester) {
    return verifyP5(tester, theme: AppTheme.light(), mode: 'light');
  });

  testWidgets('P5 system states render on-device in dark mode', (tester) {
    return verifyP5(tester, theme: AppTheme.dark(), mode: 'dark');
  });
}

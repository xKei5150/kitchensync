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

  testWidgets('P5 system states render on-device', (tester) async {
    final light = await bootGallery(
      tester,
      binding,
      theme: AppTheme.light(),
      settle: settleFrames,
      grantPremium: true,
    );
    await light.visit(
      '/dev/system-states',
      expect: find.byType(SystemStatesScreen),
      screenshot: '01-system-states-light',
    );
    await light.visit(
      '/insights',
      expect: find.byType(InsightsScreen),
      screenshot: '02-insights-light',
    );

    final dark = await bootGallery(
      tester,
      binding,
      theme: AppTheme.dark(),
      settle: settleFrames,
      grantPremium: true,
    );
    await dark.visit(
      '/dev/system-states',
      expect: find.byType(SystemStatesScreen),
      screenshot: '03-system-states-dark',
    );
    await dark.visit(
      '/insights',
      expect: find.byType(InsightsScreen),
      screenshot: '04-insights-dark',
    );
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kitchensync/app/theme.dart';
import 'package:kitchensync/features/household/presentation/screens/household_screen.dart';
import 'package:kitchensync/features/menu_sets/presentation/screens/menu_set_editor_screen.dart';
import 'package:kitchensync/features/menu_sets/presentation/screens/menu_sets_screen.dart';
import 'package:kitchensync/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:kitchensync/features/onboarding/presentation/screens/sign_in_screen.dart';
import 'package:kitchensync/features/settings/presentation/screens/premium_screen.dart';
import 'package:kitchensync/features/settings/presentation/screens/settings_screen.dart';
import 'package:kitchensync/features/today/presentation/screens/today_screen.dart';

import '_gallery_harness.dart';

/// On-device visual walk of the P2 "Premium & system" screens.
///
/// Runs on the emulator harness — see [bootGallery] for why building the real
/// router without Firebase made this gallery screenshot the sign-in page for
/// every surface.
///
/// Each hop asserts the destination screen by widget type rather than by copy,
/// so a redirect (for example `/menu-sets` bouncing to `/settings/premium` for
/// a household without Premium) fails the target instead of quietly capturing
/// the wrong screen. `/menu-sets` therefore needs a Premium household, which
/// the harness grants explicitly.
///
/// Tap-level interactions (the role sheet, the apply sheet) are covered by
/// `test/app/p2_routes_test.dart`; this target covers on-device rendering.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('P2 premium and system screens render on-device', (tester) async {
    final gallery = await bootGallery(
      tester,
      binding,
      theme: AppTheme.light(),
      grantPremium: true,
    );

    await gallery.capture('01-today', expect: find.byType(TodayScreen));

    await gallery.visit(
      '/notifications',
      expect: find.byType(NotificationsScreen),
      screenshot: '02-notifications',
    );
    await gallery.visit(
      '/settings',
      expect: find.byType(SettingsScreen),
      screenshot: '03-settings',
    );
    await gallery.visit(
      '/settings/premium',
      expect: find.byType(PremiumScreen),
      screenshot: '04-premium',
    );
    await gallery.visit(
      '/household',
      expect: find.byType(HouseholdScreen),
      screenshot: '05-household',
    );
    await gallery.visit(
      '/menu-sets',
      expect: find.byType(MenuSetsScreen),
      screenshot: '06-menu-sets',
    );
    await gallery.visit(
      '/menu-sets/edit',
      expect: find.byType(MenuSetEditorScreen),
      screenshot: '07-menu-set-editor',
    );
    await gallery.visit(
      '/onboarding?switch=household',
      expect: find.byType(OnboardingEntryScreen),
      screenshot: '08-household-switch',
    );
  });
}

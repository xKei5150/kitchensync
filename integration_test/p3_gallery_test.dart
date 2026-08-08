import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kitchensync/app/theme.dart';
import 'package:kitchensync/features/dev_tools/accessibility_audit_screen.dart';
import 'package:kitchensync/features/ingredient_dictionary/presentation/screens/create_custom_ingredient_screen.dart';
import 'package:kitchensync/features/pantry/presentation/screens/add_pantry_item_screen.dart';

import '_gallery_harness.dart';

/// On-device visual walk of the P3 "Accessibility & Forms" surfaces: the two
/// graduated forms in light + dark, and the debug-only accessibility
/// verification surface.
///
/// This target previously asserted nothing at all. It ran the real router
/// without Firebase, so every route redirected to `/onboarding`, and because it
/// made no assertions it reported success while capturing five screenshots of
/// the sign-in page. A failing target is honest; a vacuous green one is not.
/// Every hop now proves it reached the screen it claims to photograph.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> verifyP3(
    WidgetTester tester, {
    required ThemeData theme,
    required String mode,
    required bool includeAudit,
  }) async {
    final light = await bootGallery(tester, binding, theme: theme);
    await light.visit(
      '/pantry/add',
      expect: find.byType(AddPantryItemScreen),
      screenshot: '01-add-pantry-$mode',
    );
    await light.visit(
      '/ingredient/create',
      expect: find.byType(CreateCustomIngredientScreen),
      screenshot: '02-create-ingredient-$mode',
    );
    if (includeAudit) {
      await light.visit(
        '/dev/a11y',
        expect: find.byType(AccessibilityAuditScreen),
        screenshot: '03-accessibility-audit',
      );
    }
  }

  // Android's IntegrationTest binding permits converting its surface to an
  // image once per process. A gallery boot owns that conversion and a live
  // Firebase ProviderContainer, so theme passes must be independent widget
  // tests rather than two boots in the same test body. This retains every
  // destination assertion while making the target portable to Android.
  testWidgets('P3 forms and accessibility surfaces render in light mode', (
    tester,
  ) {
    return verifyP3(
      tester,
      theme: AppTheme.light(),
      mode: 'light',
      includeAudit: true,
    );
  });

  testWidgets('P3 forms render in dark mode', (tester) {
    return verifyP3(
      tester,
      theme: AppTheme.dark(),
      mode: 'dark',
      includeAudit: false,
    );
  });
}

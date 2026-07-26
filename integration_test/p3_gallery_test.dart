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

  testWidgets('P3 forms and accessibility surfaces render on-device', (
    tester,
  ) async {
    final light = await bootGallery(tester, binding, theme: AppTheme.light());
    await light.visit(
      '/pantry/add',
      expect: find.byType(AddPantryItemScreen),
      screenshot: '01-add-pantry-light',
    );
    await light.visit(
      '/ingredient/create',
      expect: find.byType(CreateCustomIngredientScreen),
      screenshot: '02-create-ingredient-light',
    );
    await light.visit(
      '/dev/a11y',
      expect: find.byType(AccessibilityAuditScreen),
      screenshot: '03-accessibility-audit',
    );

    final dark = await bootGallery(tester, binding, theme: AppTheme.dark());
    await dark.visit(
      '/pantry/add',
      expect: find.byType(AddPantryItemScreen),
      screenshot: '04-add-pantry-dark',
    );
    await dark.visit(
      '/ingredient/create',
      expect: find.byType(CreateCustomIngredientScreen),
      screenshot: '05-create-ingredient-dark',
    );
  });
}

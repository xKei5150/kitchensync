import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kitchensync/app/theme.dart';
import 'package:kitchensync/core/widgets/ks_form_field.dart';
import 'package:kitchensync/features/dev_tools/accessibility_states_screen.dart';
import 'package:kitchensync/features/ingredient_dictionary/presentation/screens/create_custom_ingredient_screen.dart';
import 'package:kitchensync/features/pantry/presentation/screens/add_pantry_item_screen.dart';

import '_gallery_harness.dart';

/// On-device visual walk of the P4 "Accessibility States" surfaces: the
/// debug-only states gallery in light + dark, plus the two graduated forms with
/// their validation errors surfaced by an attempted save.
///
/// The previous revision tapped "Add to pantry" on a screen it had never
/// reached — it built the router without Firebase, so the redirect had sent it
/// to `/onboarding`. It now boots the emulator harness and proves it is on the
/// form before submitting it.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('P4 accessibility states render on-device', (tester) async {
    final light = await bootGallery(tester, binding, theme: AppTheme.light());
    await light.visit(
      '/dev/a11y-states',
      expect: find.byType(AccessibilityStatesScreen),
      screenshot: '01-a11y-states-light',
    );

    // Submitting an empty form is what surfaces the error summary, the
    // per-field danger treatment, and the inline messages this gallery exists
    // to show.
    await light.visit(
      '/pantry/add',
      expect: find.byType(AddPantryItemScreen),
      screenshot: '02-add-pantry-light',
    );
    await light.tapAndCapture(
      find.widgetWithText(FilledButton, 'Add to pantry'),
      screenshot: '03-add-pantry-errors-light',
      // Without this the shot is just the clean form again if the submit
      // button is disabled — the same vacuity this rewrite exists to remove.
      expectAfter: find.byType(KsErrorSummary),
    );

    await light.visit(
      '/ingredient/create',
      expect: find.byType(CreateCustomIngredientScreen),
      screenshot: '04-create-ingredient-light',
    );
    await light.tapAndCapture(
      find.widgetWithText(FilledButton, 'Create ingredient'),
      screenshot: '05-create-ingredient-errors-light',
      expectAfter: find.byType(KsErrorSummary),
    );

    final dark = await bootGallery(tester, binding, theme: AppTheme.dark());
    await dark.visit(
      '/dev/a11y-states',
      expect: find.byType(AccessibilityStatesScreen),
      screenshot: '06-a11y-states-dark',
    );
  });
}

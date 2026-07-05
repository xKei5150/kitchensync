import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kitchensync/app/design_tokens.dart';
import 'package:kitchensync/app/theme_mode_controller.dart';
import 'package:kitchensync/core/locale/app_currency.dart';
import 'package:kitchensync/core/locale/locale_preferences_controller.dart';
import 'package:kitchensync/core/locale/unit_system.dart';
import 'package:kitchensync/core/widgets/widgets.dart';

/// Screen 15 · Settings — the quiet, useful corners.
///
/// A calm profile header, a Premium invitation that sells capability, and the
/// grouped settings list. "Sign out" returns to the front door so the
/// onboarding flow stays reachable.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ks = context.ksColors;
    final themeMode = ref.watch(themeModeControllerProvider);
    final locale = ref.watch(localePreferencesControllerProvider);
    return Scaffold(
      backgroundColor: ks.surfaceBase,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            KsTokens.space16,
            KsTokens.space8,
            KsTokens.space16,
            KsTokens.space24,
          ),
          children: [
            Row(
              children: [
                KsHeaderAction(
                  icon: Icons.arrow_back_rounded,
                  tooltip: 'Back',
                  onTap: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/today');
                    }
                  },
                ),
                const Spacer(),
                Text(
                  'Settings'.toUpperCase(),
                  style: KsTokens.labelSmall.copyWith(
                    color: ks.brandPrimary,
                    letterSpacing: 1.4,
                  ),
                ),
              ],
            ),
            const SizedBox(height: KsTokens.space12),
            const _ProfileRow(),
            const SizedBox(height: KsTokens.space16),
            _PremiumBanner(onTap: () => context.push('/settings/premium')),
            const SizedBox(height: KsTokens.space16),
            _SettingsGroup(
              rows: [
                _SettingsRow(
                  icon: Icons.groups_outlined,
                  label: 'Household & roles',
                  onTap: () => context.push('/household'),
                ),
                _SettingsRow(
                  icon: Icons.notifications_none_rounded,
                  label: 'Notifications',
                  onTap: () => context.push('/notifications'),
                ),
                _SettingsRow(
                  icon: Icons.brightness_6_outlined,
                  label: 'Appearance',
                  trailingText: _appearanceLabel(themeMode),
                  onTap: () => _showAppearancePicker(context, ref, themeMode),
                ),
                _SettingsRow(
                  icon: Icons.public_rounded,
                  label: 'Units & locale',
                  trailingText: locale.summary,
                  onTap: () => _showUnitsLocalePicker(context),
                ),
              ],
            ),
            const SizedBox(height: KsTokens.space20),
            OutlinedButton(
              onPressed: () => context.go('/onboarding'),
              style: OutlinedButton.styleFrom(
                foregroundColor: ks.danger,
                side: BorderSide(color: ks.borderStrong),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(KsTokens.radius12),
                ),
              ),
              child: const Text('Sign out'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow();

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return Row(
      children: [
        const KsMemberAvatar(initial: 'A', seat: 0, size: 48),
        const SizedBox(width: KsTokens.space12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Ana Holloway',
              style: KsTokens.headlineLarge.copyWith(
                color: ks.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 19,
                height: 1,
              ),
            ),
            const SizedBox(height: KsTokens.space2),
            Text(
              'ana@home · Admin',
              style: KsTokens.labelSmall.copyWith(
                color: ks.textTertiary,
                fontWeight: FontWeight.w500,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// The warm "Try Premium" invitation — a wheat-and-amber gradient card that
/// sells the capability rather than gating it.
class _PremiumBanner extends StatelessWidget {
  const _PremiumBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Warm amber-and-wheat tint over the active raised surface. Dark mode
    // leans further into the accent so the card reads as an intentional gold
    // invitation rather than a muddy brown, while keeping light text legible.
    final accentBlend = isDark ? 0.34 : 0.26;
    final grainBlend = isDark ? 0.30 : 0.26;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(KsTokens.radius16),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(
                  ks.surfaceRaised,
                  KsTokens.brandAccent,
                  accentBlend,
                )!,
                Color.lerp(ks.surfaceRaised, KsTokens.catGrain, grainBlend)!,
              ],
            ),
            borderRadius: BorderRadius.circular(KsTokens.radius16),
            border: Border.all(
              color: KsTokens.brandAccent.withValues(
                alpha: isDark ? 0.55 : 0.4,
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                size: 26,
                color: ks.brandPrimary,
              ),
              const SizedBox(width: KsTokens.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Try Premium',
                      style: KsTokens.headlineMedium.copyWith(
                        color: ks.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      'Menu Sets, insights & joint households',
                      style: KsTokens.bodySmall.copyWith(
                        color: ks.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: ks.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.rows});

  final List<_SettingsRow> rows;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: ks.surfaceRaised,
        borderRadius: BorderRadius.circular(KsTokens.radius12),
        border: Border.all(color: ks.border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) Divider(height: 1, thickness: 1, color: ks.hairline),
            rows[i],
          ],
        ],
      ),
    );
  }
}

/// Human label for the trailing value of the Appearance row.
String _appearanceLabel(ThemeMode mode) => switch (mode) {
  ThemeMode.system => 'Auto',
  ThemeMode.light => 'Light',
  ThemeMode.dark => 'Dark',
};

/// Opens the appearance picker and persists the choice via the controller.
Future<void> _showAppearancePicker(
  BuildContext context,
  WidgetRef ref,
  ThemeMode current,
) async {
  final selected = await showModalBottomSheet<ThemeMode>(
    context: context,
    builder: (_) => _AppearanceSheet(current: current),
  );
  if (selected != null) {
    await ref.read(themeModeControllerProvider.notifier).set(selected);
  }
}

/// Bottom-sheet selector for System / Light / Dark appearance.
class _AppearanceSheet extends StatelessWidget {
  const _AppearanceSheet({required this.current});

  final ThemeMode current;

  static const _options = [
    (
      mode: ThemeMode.system,
      icon: Icons.brightness_auto_rounded,
      label: 'Auto',
    ),
    (mode: ThemeMode.light, icon: Icons.light_mode_outlined, label: 'Light'),
    (mode: ThemeMode.dark, icon: Icons.dark_mode_outlined, label: 'Dark'),
  ];

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          KsTokens.space16,
          KsTokens.space12,
          KsTokens.space16,
          KsTokens.space16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: ks.hairline,
                  borderRadius: BorderRadius.circular(KsTokens.radius8),
                ),
              ),
            ),
            const SizedBox(height: KsTokens.space16),
            Text(
              'Appearance',
              style: KsTokens.headlineMedium.copyWith(
                color: ks.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: KsTokens.space4),
            Text(
              'Auto follows your device setting.',
              style: KsTokens.bodySmall.copyWith(color: ks.textTertiary),
            ),
            const SizedBox(height: KsTokens.space12),
            for (final option in _options)
              _AppearanceOption(
                icon: option.icon,
                label: option.label,
                selected: option.mode == current,
                onTap: () => Navigator.of(context).pop(option.mode),
              ),
          ],
        ),
      ),
    );
  }
}

class _AppearanceOption extends StatelessWidget {
  const _AppearanceOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(KsTokens.radius12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: selected ? ks.brandPrimary : ks.textSecondary,
              ),
              const SizedBox(width: KsTokens.space12),
              Expanded(
                child: Text(
                  label,
                  style: KsTokens.bodyMedium.copyWith(
                    color: selected ? ks.brandPrimary : ks.textPrimary,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
              if (selected)
                Icon(Icons.check_rounded, size: 20, color: ks.brandPrimary),
            ],
          ),
        ),
      ),
    );
  }
}

/// Opens the units-and-locale picker. Selections persist immediately via the
/// controller, so the sheet stays open while both choices are set.
Future<void> _showUnitsLocalePicker(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (_) => const _UnitsLocaleSheet(),
  );
}

/// Bottom-sheet selector for measurement system and currency.
class _UnitsLocaleSheet extends ConsumerWidget {
  const _UnitsLocaleSheet();

  static const _unitOptions = [
    (system: UnitSystem.metric, icon: Icons.straighten_rounded),
    (system: UnitSystem.imperial, icon: Icons.square_foot_rounded),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ks = context.ksColors;
    final locale = ref.watch(localePreferencesControllerProvider);
    final controller = ref.read(localePreferencesControllerProvider.notifier);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          KsTokens.space16,
          KsTokens.space12,
          KsTokens.space16,
          KsTokens.space16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: ks.hairline,
                  borderRadius: BorderRadius.circular(KsTokens.radius8),
                ),
              ),
            ),
            const SizedBox(height: KsTokens.space16),
            Text(
              'Units & locale',
              style: KsTokens.headlineMedium.copyWith(
                color: ks.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: KsTokens.space4),
            Text(
              'Recipes and pantry amounts convert to match.',
              style: KsTokens.bodySmall.copyWith(color: ks.textTertiary),
            ),
            const SizedBox(height: KsTokens.space16),
            const _SheetSectionLabel('Measurement'),
            const SizedBox(height: KsTokens.space4),
            for (final option in _unitOptions)
              _AppearanceOption(
                icon: option.icon,
                label: option.system.label,
                selected: option.system == locale.unitSystem,
                onTap: () => controller.setUnitSystem(option.system),
              ),
            const SizedBox(height: KsTokens.space12),
            const _SheetSectionLabel('Currency'),
            const SizedBox(height: KsTokens.space4),
            for (final currency in AppCurrency.values)
              _CurrencyOption(
                currency: currency,
                selected: currency == locale.currency,
                onTap: () => controller.setCurrency(currency),
              ),
          ],
        ),
      ),
    );
  }
}

/// Small uppercase section header inside the picker sheet.
class _SheetSectionLabel extends StatelessWidget {
  const _SheetSectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return Text(
      text.toUpperCase(),
      style: KsTokens.labelSmall.copyWith(
        color: ks.textTertiary,
        letterSpacing: 1.2,
      ),
    );
  }
}

/// One currency row — symbol glyph, name, and ISO code, with a check when
/// active. Mirrors [_AppearanceOption] but leads with the currency symbol.
class _CurrencyOption extends StatelessWidget {
  const _CurrencyOption({
    required this.currency,
    required this.selected,
    required this.onTap,
  });

  final AppCurrency currency;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    final accent = selected ? ks.brandPrimary : ks.textPrimary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(KsTokens.radius12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
          child: Row(
            children: [
              SizedBox(
                width: 20,
                child: Text(
                  currency.symbol,
                  textAlign: TextAlign.center,
                  style: KsTokens.bodyMedium.copyWith(
                    color: selected ? ks.brandPrimary : ks.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: KsTokens.space12),
              Expanded(
                child: Text(
                  currency.label,
                  style: KsTokens.bodyMedium.copyWith(
                    color: accent,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
              Text(
                currency.code,
                style: KsTokens.labelSmall.copyWith(color: ks.textTertiary),
              ),
              if (selected) ...[
                const SizedBox(width: KsTokens.space8),
                Icon(Icons.check_rounded, size: 20, color: ks.brandPrimary),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.label,
    this.onTap,
    this.trailingText,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final String? trailingText;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Icon(icon, size: 18, color: ks.textSecondary),
              const SizedBox(width: KsTokens.space12),
              Expanded(
                child: Text(
                  label,
                  style: KsTokens.bodyMedium.copyWith(
                    color: ks.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (trailingText != null) ...[
                Text(
                  trailingText!,
                  style: KsTokens.bodySmall.copyWith(color: ks.textTertiary),
                ),
                if (onTap != null) ...[
                  const SizedBox(width: KsTokens.space4),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: ks.textTertiary,
                  ),
                ],
              ] else
                Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: ks.textTertiary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

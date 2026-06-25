import 'package:flutter/material.dart';
import 'package:kitchensync/app/design_tokens.dart';
import 'package:kitchensync/core/utils/motion.dart';
import 'package:kitchensync/core/widgets/widgets.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';

/// Screens 22–25 · The accessibility *states* gallery, ported to a live runtime
/// surface ("KitchenSync — P4 Accessibility States").
///
/// Where the P3 audit screen proved the palette *looks* right, this proves the
/// *behaviour* holds: a single focus ring on every primitive, hit targets that
/// clear 44px around smaller glyphs, the same row surviving 200% type, and a
/// motion map that yields when the system asks. The reduced-motion demo reads
/// the live [MediaQueryData.disableAnimations], so it freezes if your setting
/// is on.
///
/// Debug-only: reached from the DevTools screen, never shipped to users.
class AccessibilityStatesScreen extends StatelessWidget {
  const AccessibilityStatesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return Scaffold(
      backgroundColor: ks.surfaceBase,
      appBar: AppBar(title: const Text('Accessibility states')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          KsTokens.space20,
          KsTokens.space8,
          KsTokens.space20,
          KsTokens.space40,
        ),
        children: [
          Text(
            'Built to bend, not break',
            style: KsTokens.displaySmall.copyWith(color: ks.textPrimary),
          ),
          const SizedBox(height: KsTokens.space8),
          Text(
            'Visible focus for keyboards, generous touch targets, layout that '
            'survives 200% type, and motion that yields when asked.',
            style: KsTokens.bodyMedium.copyWith(color: ks.textSecondary),
          ),
          const SizedBox(height: KsTokens.space24),

          const _SectionHeading(
            eyebrow: 'Screen 22 · Focus & keyboard',
            title: 'Always know where you are',
          ),
          const _FocusPanel(),
          const SizedBox(height: KsTokens.space12),
          const _HitTargetPanel(),
          const SizedBox(height: KsTokens.space12),
          const _TabOrderPanel(),
          const SizedBox(height: KsTokens.space32),

          const _SectionHeading(
            eyebrow: 'Screen 23 · Dynamic type & reflow',
            title: 'Bigger text, never broken layout',
          ),
          const _DynamicTypePanel(),
          const SizedBox(height: KsTokens.space32),

          const _SectionHeading(
            eyebrow: 'Screen 24 · Reduced motion',
            title: 'Movement that yields on request',
          ),
          const _ReducedMotionPanel(),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Shared chrome
// ─────────────────────────────────────────────────────────────────────────

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.eyebrow, required this.title});

  final String eyebrow;
  final String title;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: KsTokens.space12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eyebrow.toUpperCase(),
            style: KsTokens.labelSmall.copyWith(
              color: ks.brandPrimary,
              letterSpacing: 1.4,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: KsTokens.space4),
          Text(
            title,
            style: KsTokens.headlineMedium.copyWith(color: ks.textPrimary),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.eyebrow, required this.child});

  final String eyebrow;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(KsTokens.space16),
      decoration: BoxDecoration(
        color: ks.surfaceRaised,
        borderRadius: BorderRadius.circular(KsTokens.radius16),
        border: Border.all(color: ks.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eyebrow.toUpperCase(),
            style: KsTokens.labelSmall.copyWith(
              color: ks.textTertiary,
              fontSize: 10,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: KsTokens.space12),
          child,
        ],
      ),
    );
  }
}

/// Always paints the canonical focus treatment (2px ring + 2px surface offset),
/// regardless of real focus — for demonstrating the ring statically.
class _StaticFocusRing extends StatelessWidget {
  const _StaticFocusRing({
    required this.child,
    this.radius = KsTokens.radius10,
  });

  final Widget child;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(color: ks.focusRing, spreadRadius: 4),
          BoxShadow(color: ks.surfaceRaised, spreadRadius: 2),
        ],
      ),
      child: child,
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.caption, required this.child});

  final String caption;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        child,
        const SizedBox(height: KsTokens.space8),
        Text(
          caption.toUpperCase(),
          style: KsTokens.labelSmall.copyWith(
            color: ks.textTertiary,
            fontSize: 9,
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Screen 22 · Focus & keyboard
// ─────────────────────────────────────────────────────────────────────────

class _FocusPanel extends StatelessWidget {
  const _FocusPanel();

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return _Panel(
      eyebrow: 'Focus-visible ring · one treatment, every component',
      child: Wrap(
        spacing: KsTokens.space24,
        runSpacing: KsTokens.space20,
        children: [
          _Swatch(
            caption: 'Button',
            child: _StaticFocusRing(
              child: FilledButton(
                onPressed: () {},
                child: const Text('Add to pantry'),
              ),
            ),
          ),
          _Swatch(
            caption: 'Text field',
            child: _StaticFocusRing(
              child: Container(
                width: 150,
                padding: const EdgeInsets.symmetric(
                  horizontal: KsTokens.space12,
                  vertical: KsTokens.space12,
                ),
                decoration: BoxDecoration(
                  color: ks.surfaceRaised,
                  borderRadius: BorderRadius.circular(KsTokens.radius10),
                  border: Border.all(color: ks.brandPrimary, width: 2),
                ),
                child: Text(
                  'Spinach',
                  style: KsTokens.bodyMedium.copyWith(color: ks.textPrimary),
                ),
              ),
            ),
          ),
          _Swatch(
            caption: 'Chip',
            child: _StaticFocusRing(
              radius: KsTokens.radius8,
              child: KsSelectChip(
                label: 'Produce',
                selected: true,
                onTap: () {},
              ),
            ),
          ),
          _Swatch(
            caption: 'List row',
            child: _StaticFocusRing(
              radius: KsTokens.radius12,
              child: Container(
                width: 190,
                padding: const EdgeInsets.all(KsTokens.space12),
                decoration: BoxDecoration(
                  color: ks.surfaceRaised,
                  borderRadius: BorderRadius.circular(KsTokens.radius12),
                  border: Border.all(color: ks.border),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 3,
                      height: 18,
                      decoration: BoxDecoration(
                        color: ks.calPlanned,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: KsTokens.space10),
                    Expanded(
                      child: Text(
                        'Pad thai',
                        style: KsTokens.labelMedium.copyWith(
                          color: ks.textPrimary,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                    Icon(Icons.check_rounded, size: 14, color: ks.calPlanned),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HitTargetPanel extends StatelessWidget {
  const _HitTargetPanel();

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return _Panel(
      eyebrow: 'Hit targets clear 44px — even when the glyph is smaller',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Wrap(
            spacing: KsTokens.space24,
            runSpacing: KsTokens.space16,
            children: [
              _HitTargetSpec(
                caption: 'Back · 34/48',
                glyphSize: 34,
                icon: Icons.chevron_left_rounded,
              ),
              _HitTargetSpec(
                caption: 'Add · 30/48',
                glyphSize: 30,
                icon: Icons.add_rounded,
                filled: true,
              ),
              _HitTargetSpec(
                caption: 'Close · 24/48',
                glyphSize: 24,
                icon: Icons.close_rounded,
              ),
            ],
          ),
          const SizedBox(height: KsTokens.space12),
          Text(
            'The dashed box is the pressable area (KsHitTarget); the icon is '
            'the visual. Adjacent targets are spaced so they never overlap.',
            style: KsTokens.bodySmall.copyWith(
              color: ks.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _HitTargetSpec extends StatelessWidget {
  const _HitTargetSpec({
    required this.caption,
    required this.glyphSize,
    required this.icon,
    this.filled = false,
  });

  final String caption;
  final double glyphSize;
  final IconData icon;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    final glyph = Container(
      width: glyphSize,
      height: glyphSize,
      decoration: BoxDecoration(
        color: filled ? ks.brandPrimary : ks.neutralSubtle,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Icon(
        icon,
        size: glyphSize * 0.5,
        color: filled ? KsTokens.textOnBrand : ks.textSecondary,
      ),
    );
    return _Swatch(
      caption: caption,
      child: KsDashedBorder(
        color: ks.brandPrimary,
        radius: KsTokens.radius10,
        child: KsHitTarget(
          shape: BoxShape.rectangle,
          label: caption,
          onTap: () {},
          child: glyph,
        ),
      ),
    );
  }
}

class _TabOrderPanel extends StatelessWidget {
  const _TabOrderPanel();

  @override
  Widget build(BuildContext context) {
    const steps = ['Item name', 'Category', 'Quantity & unit', 'Add to pantry'];
    return _Panel(
      eyebrow: 'Tab order follows reading order',
      child: Column(
        children: [
          for (var i = 0; i < steps.length; i++) ...[
            if (i > 0) const SizedBox(height: KsTokens.space8),
            _TabStep(
              index: i + 1,
              label: steps[i],
              isAction: i == steps.length - 1,
            ),
          ],
        ],
      ),
    );
  }
}

class _TabStep extends StatelessWidget {
  const _TabStep({
    required this.index,
    required this.label,
    required this.isAction,
  });

  final int index;
  final String label;
  final bool isAction;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: ks.brandPrimary,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            '$index',
            style: KsTokens.labelSmall.copyWith(
              color: KsTokens.textOnBrand,
              fontWeight: FontWeight.w700,
              fontSize: 11,
              letterSpacing: 0,
            ),
          ),
        ),
        const SizedBox(width: KsTokens.space12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: KsTokens.space12,
              vertical: KsTokens.space12,
            ),
            decoration: BoxDecoration(
              color: isAction ? ks.brandPrimary : ks.surfaceBase,
              borderRadius: BorderRadius.circular(KsTokens.radius10),
              border: isAction ? null : Border.all(color: ks.borderStrong),
            ),
            alignment: isAction ? Alignment.center : Alignment.centerLeft,
            child: Text(
              label,
              style: KsTokens.bodyMedium.copyWith(
                color: isAction ? KsTokens.textOnBrand : ks.textSecondary,
                fontWeight: isAction ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Screen 23 · Dynamic type & reflow
// ─────────────────────────────────────────────────────────────────────────

class _DynamicTypePanel extends StatelessWidget {
  const _DynamicTypePanel();

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return _Panel(
      eyebrow: 'Same row · 100% / 130% / 200% system text',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final scale in const [1.0, 1.3, 2.0]) ...[
            if (scale != 1.0) const SizedBox(height: KsTokens.space16),
            Text(
              '${(scale * 100).round()}%',
              style: KsTokens.labelSmall.copyWith(
                color: ks.brandPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: KsTokens.space6),
            MediaQuery.withClampedTextScaling(
              minScaleFactor: scale,
              maxScaleFactor: scale,
              child: const _PantrySampleRow(),
            ),
          ],
          const SizedBox(height: KsTokens.space12),
          Text(
            'Text sizes with the system; lines wrap instead of truncating, '
            'and the action drops below the meta at the largest setting '
            'rather than clipping.',
            style: KsTokens.bodySmall.copyWith(
              color: ks.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// A pantry row + action that reflows under large text: the button wraps below
/// the badge (via [Wrap]) rather than overflowing, and nothing sets a fixed
/// height.
class _PantrySampleRow extends StatelessWidget {
  const _PantrySampleRow();

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    final brightness = Theme.of(context).brightness;
    final produce = IngredientCategory.produce.colorFor(brightness);
    return Container(
      padding: const EdgeInsets.all(KsTokens.space12),
      decoration: BoxDecoration(
        color: ks.surfaceBase,
        borderRadius: BorderRadius.circular(KsTokens.radius12),
        border: Border.all(color: ks.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 6,
                height: 34,
                margin: const EdgeInsets.only(top: 2, right: KsTokens.space10),
                decoration: BoxDecoration(
                  color: produce,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Baby spinach',
                      style: KsTokens.titleMedium.copyWith(
                        color: ks.textPrimary,
                      ),
                    ),
                    Text(
                      '2 bags · best by Sun 29 Jun',
                      style: KsTokens.bodySmall.copyWith(
                        color: ks.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: KsTokens.space10),
          Wrap(
            spacing: KsTokens.space8,
            runSpacing: KsTokens.space8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const KsExpiryBadge(
                freshness: Freshness.fresh,
                label: 'Fresh · 4d',
              ),
              FilledButton(onPressed: () {}, child: const Text('Use tonight')),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Screen 24 · Reduced motion
// ─────────────────────────────────────────────────────────────────────────

class _ReducedMotionPanel extends StatelessWidget {
  const _ReducedMotionPanel();

  static const _rows = [
    ('Sheet & dialog', 'Slide-up 300ms', 'Fade 150ms'),
    ('Day-cell tap', 'Scale 0.92 · 150ms', 'None · colour only'),
    ('Toast / nudge', 'Rise + fade 300ms', 'Fade 150ms'),
    ('Page transition', 'Shared-axis 300ms', 'Fade 150ms'),
  ];

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    final reduced = context.reduceMotion;
    return _Panel(
      eyebrow: 'What maps to what',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: KsTokens.space12,
              vertical: KsTokens.space10,
            ),
            decoration: BoxDecoration(
              color: ks.surfaceBase,
              borderRadius: BorderRadius.circular(KsTokens.radius10),
              border: Border.all(color: ks.border),
            ),
            child: Row(
              children: [
                Icon(
                  reduced ? Icons.motion_photos_off_outlined : Icons.animation,
                  size: 18,
                  color: reduced ? ks.warning : ks.brandPrimary,
                ),
                const SizedBox(width: KsTokens.space8),
                Expanded(
                  child: Text(
                    reduced
                        ? 'Reduce motion is ON — transitions are cross-fading.'
                        : 'Reduce motion is OFF — transitions travel.',
                    style: KsTokens.bodySmall.copyWith(color: ks.textSecondary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: KsTokens.space16),
          const _MapHeaderRow(),
          for (final row in _rows) _MapRow(row: row),
        ],
      ),
    );
  }
}

class _MapHeaderRow extends StatelessWidget {
  const _MapHeaderRow();

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    TextStyle style() => KsTokens.labelSmall.copyWith(
      color: ks.textTertiary,
      fontSize: 9,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.6,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: KsTokens.space8),
      child: Row(
        children: [
          Expanded(flex: 14, child: Text('INTERACTION', style: style())),
          Expanded(flex: 10, child: Text('DEFAULT', style: style())),
          Expanded(flex: 10, child: Text('REDUCED', style: style())),
        ],
      ),
    );
  }
}

class _MapRow extends StatelessWidget {
  const _MapRow({required this.row});

  final (String, String, String) row;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: KsTokens.space8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: ks.hairline)),
        ),
        child: Padding(
          padding: const EdgeInsets.only(top: KsTokens.space8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 14,
                child: Text(
                  row.$1,
                  style: KsTokens.bodySmall.copyWith(
                    color: ks.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                flex: 10,
                child: Text(
                  row.$2,
                  style: KsTokens.bodySmall.copyWith(color: ks.textSecondary),
                ),
              ),
              Expanded(
                flex: 10,
                child: Text(
                  row.$3,
                  style: KsTokens.bodySmall.copyWith(color: ks.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

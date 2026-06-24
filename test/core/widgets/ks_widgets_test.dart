import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/app/design_tokens.dart';
import 'package:kitchensync/core/widgets/widgets.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';

Future<void> _pump(WidgetTester tester, Widget child) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: Center(child: child)),
    ),
  );
}

BoxDecoration _decorationOf(WidgetTester tester, Finder finder) {
  final container = tester.widget<Container>(finder);
  return container.decoration! as BoxDecoration;
}

BoxDecoration _animatedDecorationOf(WidgetTester tester, Finder finder) {
  final container = tester.widget<AnimatedContainer>(finder);
  return container.decoration! as BoxDecoration;
}

void main() {
  group('KsTag', () {
    testWidgets('renders its label', (tester) async {
      await _pump(tester, const KsTag(label: 'produce'));
      expect(find.text('produce'), findsOneWidget);
    });

    testWidgets('default tone is tonal at md radius', (tester) async {
      await _pump(tester, const KsTag(label: 'x'));
      final deco = _decorationOf(tester, find.byType(Container));
      expect(deco.color, KsTokens.brandPrimary.withValues(alpha: 0.12));
      expect(deco.borderRadius, BorderRadius.circular(KsTokens.radius6));
      expect(deco.border, isNull);
    });

    testWidgets('category factory colours by category and uses its name', (
      tester,
    ) async {
      await _pump(tester, KsTag.category(IngredientCategory.meat));
      expect(find.text('meat'), findsOneWidget);
      final deco = _decorationOf(tester, find.byType(Container));
      expect(deco.color, IngredientCategory.meat.color.withValues(alpha: 0.12));
    });

    testWidgets('lowStock factory is a small "Low" pill at radius4', (
      tester,
    ) async {
      await _pump(tester, KsTag.lowStock());
      expect(find.text('Low'), findsOneWidget);
      final deco = _decorationOf(tester, find.byType(Container));
      expect(deco.borderRadius, BorderRadius.circular(KsTokens.radius4));
    });

    testWidgets('alias factory uses the neutral tone with a border', (
      tester,
    ) async {
      await _pump(tester, KsTag.alias('also: scallion'));
      expect(find.text('also: scallion'), findsOneWidget);
      final deco = _decorationOf(tester, find.byType(Container));
      expect(deco.color, KsTokens.neutralSubtle);
      expect(deco.border, isNotNull);
    });
  });

  group('KsErrorAlert', () {
    testWidgets('renders message and an error glyph', (tester) async {
      await _pump(tester, const KsErrorAlert(message: 'Something failed'));
      expect(find.text('Something failed'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      final deco = _decorationOf(tester, find.byType(Container));
      expect(deco.color, KsTokens.expired.withValues(alpha: 0.08));
    });
  });

  group('KsEmptyState', () {
    testWidgets('renders title, subtitle, and an optional action', (
      tester,
    ) async {
      await _pump(
        tester,
        KsEmptyState(
          icon: Icons.search_off,
          title: 'No matches',
          subtitle: 'Try another search',
          action: FilledButton(onPressed: () {}, child: const Text('Add')),
        ),
      );
      expect(find.text('No matches'), findsOneWidget);
      expect(find.text('Try another search'), findsOneWidget);
      expect(find.text('Add'), findsOneWidget);
    });

    testWidgets('marks the title as a semantic header', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        const KsEmptyState(
          icon: Icons.inbox,
          title: 'Empty',
          subtitle: 'Nothing here yet',
        ),
      );
      expect(
        tester.getSemantics(find.text('Empty')),
        matchesSemantics(label: 'Empty', isHeader: true),
      );
      handle.dispose();
    });
  });

  group('KsSectionTab', () {
    Widget tab({required bool selected, VoidCallback? onTap}) => KsSectionTab(
      label: 'Food',
      icon: Icons.restaurant,
      color: KsTokens.sectionFood,
      isSelected: selected,
      onTap: onTap ?? () {},
    );

    testWidgets('selected fills with the section colour', (tester) async {
      await _pump(tester, tab(selected: true));
      final deco = _animatedDecorationOf(
        tester,
        find.byType(AnimatedContainer),
      );
      expect(deco.color, KsTokens.sectionFood);
    });

    testWidgets('unselected fills with the raised surface', (tester) async {
      await _pump(tester, tab(selected: false));
      final deco = _animatedDecorationOf(
        tester,
        find.byType(AnimatedContainer),
      );
      expect(deco.color, KsTokens.surfaceRaised);
    });

    testWidgets('invokes onTap when pressed', (tester) async {
      var taps = 0;
      await _pump(tester, tab(selected: false, onTap: () => taps++));
      await tester.tap(find.byType(KsSectionTab));
      expect(taps, 1);
    });
  });

  group('KsFreshnessBar', () {
    testWidgets('unknown freshness uses a neutral border colour', (
      tester,
    ) async {
      await _pump(tester, const KsFreshnessBar(freshness: Freshness.unknown));
      final deco = _decorationOf(tester, find.byType(Container));
      expect(deco.color, KsTokens.border);
    });

    testWidgets('fresh freshness uses the fresh colour', (tester) async {
      await _pump(tester, const KsFreshnessBar(freshness: Freshness.fresh));
      final deco = _decorationOf(tester, find.byType(Container));
      expect(deco.color, KsTokens.fresh);
    });
  });

  group('KsExpiryBadge', () {
    testWidgets('renders the relative label', (tester) async {
      await _pump(
        tester,
        const KsExpiryBadge(freshness: Freshness.fresh, label: '3 days left'),
      );
      expect(find.text('3 days left'), findsOneWidget);
    });
  });

  group('KsThumbnail', () {
    testWidgets('falls back to a tinted placeholder glyph without a url', (
      tester,
    ) async {
      await _pump(
        tester,
        const KsThumbnail(categoryColor: KsTokens.catProduce),
      );
      expect(find.byIcon(Icons.local_dining), findsOneWidget);
    });
  });

  group('KsQuantityStepper', () {
    testWidgets('renders quantity and unit', (tester) async {
      await _pump(tester, const KsQuantityStepper(qty: '2', unit: 'pieces'));
      expect(find.text('2'), findsOneWidget);
      expect(find.text('pieces'), findsOneWidget);
    });

    testWidgets('increment and decrement fire their callbacks', (tester) async {
      var up = 0;
      var down = 0;
      await _pump(
        tester,
        KsQuantityStepper(
          qty: '2',
          unit: 'pieces',
          onIncrease: () => up++,
          onDecrease: () => down++,
        ),
      );
      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.tap(find.byIcon(Icons.remove_rounded));
      expect(up, 1);
      expect(down, 1);
    });
  });

  group('KsMetadataRow', () {
    testWidgets('renders label and value', (tester) async {
      await _pump(tester, const KsMetadataRow(label: 'Section', value: 'Food'));
      expect(find.text('Section'), findsOneWidget);
      expect(find.text('Food'), findsOneWidget);
    });

    testWidgets('shows a status dot when a colour is given', (tester) async {
      await _pump(
        tester,
        const KsMetadataRow(
          label: 'Freshness',
          value: '3 days left',
          color: KsTokens.fresh,
          showDot: true,
        ),
      );
      expect(find.byType(KsStatusDot), findsOneWidget);
    });
  });
}

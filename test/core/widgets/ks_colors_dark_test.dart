import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/app/design_tokens.dart';
import 'package:kitchensync/app/theme.dart';
import 'package:kitchensync/core/widgets/widgets.dart';

Future<void> _pumpThemed(WidgetTester tester, ThemeData theme, Widget child) {
  return tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Scaffold(body: Center(child: child)),
    ),
  );
}

BoxDecoration _decoIn(WidgetTester tester, Type host, Type box) {
  final finder = find.descendant(
    of: find.byType(host),
    matching: find.byType(box),
  );
  final widget = tester.widget(finder.first);
  final decoration = (widget as dynamic).decoration as Decoration;
  return decoration as BoxDecoration;
}

KsSectionTab _unselectedTab() => KsSectionTab(
  label: 'Food',
  icon: Icons.restaurant,
  color: KsTokens.sectionFood,
  isSelected: false,
  onTap: () {},
);

void main() {
  testWidgets('context.ksColors resolves the dark set under the dark theme', (
    tester,
  ) async {
    late KsColors resolved;
    await _pumpThemed(
      tester,
      AppTheme.dark(),
      Builder(
        builder: (context) {
          resolved = context.ksColors;
          return const SizedBox();
        },
      ),
    );
    expect(resolved.surfaceRaised, KsColors.dark.surfaceRaised);
    expect(resolved.textPrimary, KsColors.dark.textPrimary);
    expect(resolved.brandPrimary, KsTokens.brandPrimaryLight);
  });

  testWidgets('context.ksColors resolves the light set under the light theme', (
    tester,
  ) async {
    late KsColors resolved;
    await _pumpThemed(
      tester,
      AppTheme.light(),
      Builder(
        builder: (context) {
          resolved = context.ksColors;
          return const SizedBox();
        },
      ),
    );
    expect(resolved.surfaceRaised, KsTokens.surfaceRaised);
    expect(resolved.textPrimary, KsTokens.textPrimary);
  });

  testWidgets('KsCard fills with the dark surface under the dark theme', (
    tester,
  ) async {
    await _pumpThemed(tester, AppTheme.dark(), const KsCard(child: Text('x')));
    expect(
      _decoIn(tester, KsCard, Container).color,
      KsColors.dark.surfaceRaised,
    );
  });

  testWidgets('KsCard fills with the light surface under the light theme', (
    tester,
  ) async {
    await _pumpThemed(tester, AppTheme.light(), const KsCard(child: Text('x')));
    expect(_decoIn(tester, KsCard, Container).color, KsTokens.surfaceRaised);
  });

  testWidgets('KsSectionTab unselected uses the dark surface in dark mode', (
    tester,
  ) async {
    await _pumpThemed(tester, AppTheme.dark(), _unselectedTab());
    expect(
      _decoIn(tester, KsSectionTab, AnimatedContainer).color,
      KsColors.dark.surfaceRaised,
    );
  });

  testWidgets('KsSectionTab unselected uses the light surface in light mode', (
    tester,
  ) async {
    await _pumpThemed(tester, AppTheme.light(), _unselectedTab());
    expect(
      _decoIn(tester, KsSectionTab, AnimatedContainer).color,
      KsTokens.surfaceRaised,
    );
  });

  testWidgets('KsErrorAlert tints with the dark danger accent', (tester) async {
    await _pumpThemed(
      tester,
      AppTheme.dark(),
      const KsErrorAlert(message: 'boom'),
    );
    expect(
      _decoIn(tester, KsErrorAlert, Container).color,
      KsColors.dark.danger.withValues(alpha: 0.08),
    );
  });
}

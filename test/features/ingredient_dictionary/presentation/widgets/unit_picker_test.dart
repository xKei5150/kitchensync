import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/app/theme.dart';
import 'package:kitchensync/core/widgets/widgets.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/unit_registry.dart';
import 'package:kitchensync/features/ingredient_dictionary/presentation/widgets/unit_picker.dart';

UnitDefinition _localUnit(String id, String label) => UnitDefinition(
  id: UnitId(id),
  label: label,
  pluralLabel: '${label}s',
  dimension: UnitDimension.informal,
  family: UnitSystemFamily.local,
);

Future<void> _pumpPicker(
  WidgetTester tester, {
  required bool allowCreate,
  UnitId selectedUnit = UnitId.piece,
  List<UnitDefinition> localUnits = const <UnitDefinition>[],
  ValueChanged<UnitId>? onSelected,
  ValueChanged<UnitDefinition>? onLocalUnitAdded,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: UnitPicker(
              selectedUnit: selectedUnit,
              localUnitDefinitions: localUnits,
              allowCreate: allowCreate,
              onSelected: onSelected ?? (_) {},
              onLocalUnitAdded: onLocalUnitAdded,
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> _tapVisible(WidgetTester tester, String text) async {
  final finder = find.text(text);
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
}

void main() {
  testWidgets('renders grouped built-in and local units in select-only mode', (
    tester,
  ) async {
    await _pumpPicker(
      tester,
      allowCreate: false,
      localUnits: <UnitDefinition>[
        _localUnit('sachet', 'sachet'),
        _localUnit('sachet', 'sachet'),
      ],
    );

    expect(find.text('FORMAL METRIC'), findsOneWidget);
    expect(find.text('FORMAL IMPERIAL'), findsOneWidget);
    expect(find.text('COOKING'), findsOneWidget);
    expect(find.text('INFORMAL'), findsOneWidget);
    expect(find.text('LOCAL'), findsOneWidget);
    expect(find.text('kg'), findsOneWidget);
    expect(find.text('lb'), findsOneWidget);
    expect(find.text('cup'), findsOneWidget);
    expect(find.text('bunch'), findsOneWidget);
    expect(find.text('sachet'), findsOneWidget);
    expect(find.text('Add unit'), findsNothing);
  });

  testWidgets('keeps same-label local units distinct by UnitId', (
    tester,
  ) async {
    UnitId? selected;

    await _pumpPicker(
      tester,
      allowCreate: false,
      selectedUnit: UnitId('small-scoop'),
      localUnits: <UnitDefinition>[
        _localUnit('small-scoop', 'scoop'),
        _localUnit('large-scoop', 'scoop'),
      ],
      onSelected: (unit) => selected = unit,
    );

    expect(find.text('scoop'), findsNWidgets(2));
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is KsSelectChip &&
            widget.label == 'scoop' &&
            widget.selected,
      ),
      findsOneWidget,
    );

    await tester.tap(
      find
          .byWidgetPredicate(
            (widget) => widget is KsSelectChip && widget.label == 'scoop',
          )
          .last,
    );
    await tester.pump();

    expect(selected, UnitId('large-scoop'));
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is KsSelectChip &&
            widget.label == 'scoop' &&
            widget.selected,
      ),
      findsOneWidget,
    );
  });

  testWidgets('shows validation for duplicate local unit', (tester) async {
    UnitDefinition? added;

    await _pumpPicker(
      tester,
      allowCreate: true,
      localUnits: <UnitDefinition>[_localUnit('sachet', 'sachet')],
      onLocalUnitAdded: (unit) => added = unit,
    );

    await _tapVisible(tester, 'Add unit');
    await tester.enterText(find.byType(TextField), 'sachet');
    await tester.pump();
    await _tapVisible(tester, 'Add local unit');

    expect(added, isNull);
    expect(find.text('A unit with this ID already exists.'), findsOneWidget);
  });

  testWidgets('shows validation for duplicate built-in unit slug', (
    tester,
  ) async {
    UnitDefinition? added;

    await _pumpPicker(
      tester,
      allowCreate: true,
      onLocalUnitAdded: (unit) => added = unit,
    );

    await _tapVisible(tester, 'Add unit');
    await tester.enterText(find.byType(TextField), 'kg');
    await tester.pump();
    await _tapVisible(tester, 'Add local unit');

    expect(added, isNull);
    expect(find.text('A unit with this ID already exists.'), findsOneWidget);
  });
}

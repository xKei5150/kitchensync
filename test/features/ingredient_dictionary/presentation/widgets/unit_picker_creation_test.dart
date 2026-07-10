import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/app/theme.dart';
import 'package:kitchensync/core/widgets/widgets.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/unit_registry.dart';
import 'package:kitchensync/features/ingredient_dictionary/presentation/widgets/unit_picker.dart';

Future<void> _tapVisible(WidgetTester tester, String text) async {
  final finder = find.text(text);
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
}

Future<void> _pumpCreatePicker(
  WidgetTester tester, {
  required List<UnitDefinition> localUnits,
  required UnitId Function() selectedUnit,
  required ValueChanged<UnitId> onSelected,
  required ValueChanged<UnitDefinition> onLocalUnitAdded,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) => SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: UnitPicker(
                selectedUnit: selectedUnit(),
                localUnitDefinitions: List<UnitDefinition>.unmodifiable(
                  localUnits,
                ),
                allowCreate: true,
                onSelected: (unit) => setState(() => onSelected(unit)),
                onLocalUnitAdded: (unit) =>
                    setState(() => onLocalUnitAdded(unit)),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('adds a local informal unit and selects it', (tester) async {
    final localUnits = <UnitDefinition>[];
    UnitId selected = UnitId.piece;
    UnitDefinition? added;

    await _pumpCreatePicker(
      tester,
      localUnits: localUnits,
      selectedUnit: () => selected,
      onSelected: (unit) => selected = unit,
      onLocalUnitAdded: (unit) {
        added = unit;
        localUnits.add(unit);
      },
    );

    await _tapVisible(tester, 'Add unit');
    await tester.enterText(find.byType(TextField), 'tray');
    await tester.pump();

    expect(find.text('ID: tray'), findsOneWidget);

    await _tapVisible(tester, 'Add local unit');

    expect(selected, UnitId('tray'));
    expect(localUnits, hasLength(1));
    expect(added?.id, UnitId('tray'));
    expect(added?.label, 'tray');
    expect(added?.pluralLabel, 'trays');
    expect(added?.dimension, UnitDimension.informal);
    expect(added?.family, UnitSystemFamily.local);
    expect(find.text('tray'), findsOneWidget);
  });

  testWidgets('adds digit-leading local unit and keeps duplicate validation', (
    tester,
  ) async {
    final localUnits = <UnitDefinition>[];
    UnitId selected = UnitId.piece;
    UnitDefinition? added;

    await _pumpCreatePicker(
      tester,
      localUnits: localUnits,
      selectedUnit: () => selected,
      onSelected: (unit) => selected = unit,
      onLocalUnitAdded: (unit) {
        added = unit;
        localUnits.add(unit);
      },
    );

    await _tapVisible(tester, 'Add unit');
    await tester.enterText(find.byType(TextField), '2 pack');
    await tester.pump();

    expect(find.text('ID: 2-pack'), findsOneWidget);

    await _tapVisible(tester, 'Add local unit');

    expect(selected, UnitId('2-pack'));
    expect(added?.id, UnitId('2-pack'));
    expect(added?.label, '2 pack');
    expect(find.text('2 pack'), findsOneWidget);

    added = null;
    await _tapVisible(tester, 'Add unit');
    await tester.enterText(find.byType(TextField), '2 pack');
    await tester.pump();
    await _tapVisible(tester, 'Add local unit');

    expect(added, isNull);
    expect(find.text('A unit with this ID already exists.'), findsOneWidget);
  });

  testWidgets(
    'controlled parent local unit rebuild shows the added unit once',
    (tester) async {
      final localUnits = <UnitDefinition>[];
      UnitId selected = UnitId.piece;

      await _pumpCreatePicker(
        tester,
        localUnits: localUnits,
        selectedUnit: () => selected,
        onSelected: (unit) => selected = unit,
        onLocalUnitAdded: localUnits.add,
      );

      await _tapVisible(tester, 'Add unit');
      await tester.enterText(find.byType(TextField), 'tray');
      await tester.pump();
      await _tapVisible(tester, 'Add local unit');
      await tester.pump();

      expect(selected, UnitId('tray'));
      expect(find.text('tray'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is KsSelectChip &&
              widget.label == 'tray' &&
              widget.selected,
        ),
        findsOneWidget,
      );
    },
  );
}

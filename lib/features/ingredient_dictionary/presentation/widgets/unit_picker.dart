import 'package:flutter/material.dart';
import 'package:kitchensync/app/design_tokens.dart';
import 'package:kitchensync/core/widgets/widgets.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/unit_registry.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/usecases/custom_ingredient_local_units.dart';

part 'unit_picker_sections.dart';

class UnitPicker extends StatefulWidget {
  const UnitPicker({
    required this.selectedUnit,
    required this.localUnitDefinitions,
    required this.allowCreate,
    required this.onSelected,
    this.onLocalUnitAdded,
    this.selectedUnits,
    this.availableUnits,
    super.key,
  });

  final UnitId selectedUnit;
  final List<UnitDefinition> localUnitDefinitions;
  final bool allowCreate;
  final ValueChanged<UnitId> onSelected;
  final ValueChanged<UnitDefinition>? onLocalUnitAdded;
  final Set<UnitId>? selectedUnits;
  final Set<UnitId>? availableUnits;

  @override
  State<UnitPicker> createState() => _UnitPickerState();
}

class _UnitPickerState extends State<UnitPicker> {
  final TextEditingController _label = TextEditingController();
  bool _editorOpen = false;
  late UnitId _selectedUnit = widget.selectedUnit;
  String? _error;

  List<UnitDefinition> get _localUnits {
    final unitsById = <UnitId, UnitDefinition>{};
    for (final unit in widget.localUnitDefinitions) {
      unitsById[unit.id] = unit;
    }
    return List<UnitDefinition>.unmodifiable(unitsById.values);
  }

  String get _slug => normalizeLocalUnitLabel(_label.text);

  @override
  void didUpdateWidget(UnitPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedUnit != widget.selectedUnit) {
      _selectedUnit = widget.selectedUnit;
    }
  }

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  void _showEditor() {
    setState(() {
      _editorOpen = true;
      _error = null;
    });
  }

  void _addLocalUnit() {
    final label = _label.text.trim();
    final slug = _slug;
    final message = _validationMessage(label: label, slug: slug);
    if (message != null) {
      setState(() => _error = message);
      return;
    }

    final unitId = UnitId(slug);
    final unit = UnitDefinition(
      id: unitId,
      label: label,
      pluralLabel: '${label}s',
      dimension: UnitDimension.informal,
      family: UnitSystemFamily.local,
    );
    setState(() {
      _label.clear();
      _editorOpen = false;
      _error = null;
      _selectedUnit = unit.id;
    });
    widget.onLocalUnitAdded?.call(unit);
    widget.onSelected(unit.id);
  }

  String? _validationMessage({required String label, required String slug}) {
    if (label.isEmpty) return 'Enter a local unit label.';
    if (slug.isEmpty) return 'Label must include letters or numbers.';
    if (label.length > 40) {
      return 'Local unit labels must be 40 characters or fewer.';
    }
    if (slug.length > 32) {
      return 'Local unit IDs must be 32 characters or fewer.';
    }
    late final UnitId unitId;
    try {
      unitId = UnitId(slug);
    } on FormatException {
      return 'Label must produce a valid unit ID.';
    }
    if (UnitRegistry.find(unitId) != null ||
        _localUnits.any(
          (unit) =>
              unit.id == unitId ||
              unit.label.trim().toLowerCase() == label.toLowerCase(),
        )) {
      return 'A unit with this ID already exists.';
    }
    return null;
  }

  void _select(UnitId unit) {
    setState(() => _selectedUnit = unit);
    widget.onSelected(unit);
  }

  @override
  Widget build(BuildContext context) {
    final groups = _groups();
    final selectedUnits = widget.selectedUnits ?? {_selectedUnit};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final group in groups) ...[
          _UnitGroup(
            title: group.title,
            units: group.units,
            selectedUnits: selectedUnits,
            onSelected: _select,
          ),
          if (group != groups.last) const SizedBox(height: KsTokens.space16),
        ],
        if (widget.allowCreate) ...[
          const SizedBox(height: KsTokens.space16),
          if (_editorOpen)
            _AddLocalUnitEditor(
              controller: _label,
              slug: _slug,
              error: _error,
              onChanged: () => setState(() => _error = null),
              onAdd: _addLocalUnit,
            )
          else
            OutlinedButton.icon(
              onPressed: _showEditor,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add unit'),
            ),
        ],
      ],
    );
  }

  List<_UnitGroupData> _groups() {
    const builtIns = UnitRegistry.builtIns;
    final availableUnits = widget.availableUnits;
    List<UnitDefinition> onlyAvailable(Iterable<UnitDefinition> units) {
      if (availableUnits == null) return units.toList(growable: false);
      return units
          .where((unit) => availableUnits.contains(unit.id))
          .toList(growable: false);
    }

    return <_UnitGroupData>[
      _UnitGroupData(
        'Formal metric',
        onlyAvailable(
          builtIns.where((unit) => unit.family == UnitSystemFamily.metric),
        ),
      ),
      _UnitGroupData(
        'Formal imperial',
        onlyAvailable(
          builtIns.where((unit) => unit.family == UnitSystemFamily.imperial),
        ),
      ),
      _UnitGroupData(
        'Cooking',
        onlyAvailable(
          builtIns.where((unit) => unit.dimension == UnitDimension.cooking),
        ),
      ),
      _UnitGroupData(
        'Informal',
        onlyAvailable(
          builtIns.where(
            (unit) =>
                unit.dimension == UnitDimension.informal ||
                unit.dimension == UnitDimension.count,
          ),
        ),
      ),
      _UnitGroupData('Local', onlyAvailable(_localUnits)),
    ];
  }
}

import 'package:kitchensync/core/errors/failure.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/unit_registry.dart';

const int _maxLocalUnitIdLength = 32;
const int _maxLocalUnitLabelLength = 40;

List<UnitDefinition> normalizeLocalUnitDefinitions(
  List<UnitDefinition> definitions,
) => definitions
    .map(
      (definition) => UnitDefinition(
        id: definition.id,
        label: definition.label.trim(),
        pluralLabel: definition.pluralLabel.trim(),
        dimension: definition.dimension,
        family: definition.family,
        gramsPerUnit: definition.gramsPerUnit,
        millilitersPerUnit: definition.millilitersPerUnit,
      ),
    )
    .toList(growable: false);

String normalizeLocalUnitLabel(String label) {
  final lowercase = label.trim().toLowerCase();
  final hyphenated = lowercase.replaceAll(RegExp(r'[\s_]+'), '-');
  final asciiOnly = hyphenated.replaceAll(RegExp('[^a-z0-9-]'), '');
  return asciiOnly
      .replaceAll(RegExp('-+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
}

Failure? validateLocalUnitDefinitions({
  required List<UnitId> allowedUnits,
  required List<UnitDefinition> localUnitDefinitions,
}) {
  final allowedUnitSet = allowedUnits.toSet();
  final localUnitIds = <UnitId>{};

  for (final definition in localUnitDefinitions) {
    final failure = _validateLocalUnitDefinition(
      definition: definition,
      allowedUnitSet: allowedUnitSet,
      localUnitIds: localUnitIds,
    );
    if (failure != null) {
      return failure;
    }
  }

  for (final unit in allowedUnits) {
    if (UnitRegistry.find(unit) == null && !localUnitIds.contains(unit)) {
      return Failure.validation(
        field: 'allowedUnits',
        message: 'Custom unit "${unit.value}" needs a local definition.',
      );
    }
  }

  return null;
}

Failure? _validateLocalUnitDefinition({
  required UnitDefinition definition,
  required Set<UnitId> allowedUnitSet,
  required Set<UnitId> localUnitIds,
}) {
  if (!localUnitIds.add(definition.id)) {
    return const Failure.validation(
      field: 'localUnitDefinitions',
      message: 'Local unit definitions must not contain duplicate IDs.',
    );
  }
  if (!allowedUnitSet.contains(definition.id)) {
    return Failure.validation(
      field: 'localUnitDefinitions',
      message:
          'Local unit "${definition.id.value}" must appear in allowedUnits.',
    );
  }

  final label = definition.label.trim();
  final pluralLabel = definition.pluralLabel.trim();
  if (label.isEmpty || pluralLabel.isEmpty) {
    return const Failure.validation(
      field: 'localUnitDefinitions',
      message: 'Local unit labels are required.',
    );
  }
  if (label.length > _maxLocalUnitLabelLength ||
      pluralLabel.length > _maxLocalUnitLabelLength) {
    return const Failure.validation(
      field: 'localUnitDefinitions',
      message: 'Local unit labels must be 40 characters or fewer.',
    );
  }

  final builtIn = UnitRegistry.find(definition.id);
  if (builtIn != null) {
    if (label != builtIn.label) {
      return Failure.validation(
        field: 'localUnitDefinitions',
        message:
            'Local unit "${definition.id.value}" conflicts with a built-in '
            'unit.',
      );
    }
    return null;
  }

  if (definition.id.value.length > _maxLocalUnitIdLength) {
    return const Failure.validation(
      field: 'localUnitDefinitions',
      message: 'Local unit IDs must be 32 characters or fewer.',
    );
  }
  if (definition.dimension != UnitDimension.informal ||
      definition.family != UnitSystemFamily.local) {
    return const Failure.validation(
      field: 'localUnitDefinitions',
      message: 'Local units must be informal household-local units.',
    );
  }

  final normalizedId = normalizeLocalUnitLabel(label);
  if (normalizedId.isEmpty) {
    return const Failure.validation(
      field: 'localUnitDefinitions',
      message: 'Local unit label must produce a non-empty ID.',
    );
  }
  if (normalizedId != definition.id.value) {
    return Failure.validation(
      field: 'localUnitDefinitions',
      message:
          'Local unit "${definition.id.value}" must match normalized label '
          '"$normalizedId".',
    );
  }

  return null;
}

part of 'unit_picker.dart';

final class _UnitGroupData {
  const _UnitGroupData(this.title, this.units);

  final String title;
  final List<UnitDefinition> units;
}

class _UnitGroup extends StatelessWidget {
  const _UnitGroup({
    required this.title,
    required this.units,
    required this.selectedUnits,
    required this.onSelected,
  });

  final String title;
  final List<UnitDefinition> units;
  final Set<UnitId> selectedUnits;
  final ValueChanged<UnitId> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        KsFieldLabel(title),
        if (units.isEmpty)
          Text(
            'No local units yet.',
            style: KsTokens.bodySmall.copyWith(
              color: context.ksColors.textTertiary,
            ),
          )
        else
          Wrap(
            spacing: KsTokens.space8,
            runSpacing: KsTokens.space8,
            children: [
              for (final unit in units)
                KsSelectChip(
                  label: unit.label,
                  selected: selectedUnits.contains(unit.id),
                  onTap: () => onSelected(unit.id),
                ),
            ],
          ),
      ],
    );
  }
}

class _AddLocalUnitEditor extends StatelessWidget {
  const _AddLocalUnitEditor({
    required this.controller,
    required this.slug,
    required this.onChanged,
    required this.onAdd,
    this.error,
  });

  final TextEditingController controller;
  final String slug;
  final VoidCallback onChanged;
  final VoidCallback onAdd;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(KsTokens.space16),
      decoration: BoxDecoration(
        color: ks.surfaceSunken,
        borderRadius: BorderRadius.circular(KsTokens.radius12),
        border: Border.all(color: ks.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const KsFieldLabel('Local unit label'),
          TextField(
            controller: controller,
            onChanged: (_) => onChanged(),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => onAdd(),
            decoration: InputDecoration(
              hintText: 'e.g. tray',
              errorText: error,
            ),
          ),
          const SizedBox(height: KsTokens.space8),
          Text(
            slug.isEmpty ? 'ID: -' : 'ID: $slug',
            style: KsTokens.labelMedium.copyWith(color: ks.textSecondary),
          ),
          const SizedBox(height: KsTokens.space12),
          SizedBox(
            height: 48,
            child: FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add local unit'),
            ),
          ),
        ],
      ),
    );
  }
}

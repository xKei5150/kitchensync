part of 'shopping_schedule_screen.dart';

class ShoppingScheduleBody extends StatelessWidget {
  const ShoppingScheduleBody({
    required this.schedule,
    required this.weekday,
    required this.effectiveFrom,
    required this.isActive,
    required this.canEdit,
    required this.saving,
    required this.settingsErrorMessage,
    required this.onWeekdayChanged,
    required this.onPickDate,
    required this.onActiveChanged,
    required this.onRetrySettings,
    required this.onRetryReconciliation,
    required this.onSave,
    required this.onDeactivate,
    this.error,
    this.success,
    super.key,
  });

  final ShoppingSchedule? schedule;
  final int weekday;
  final DateTime effectiveFrom;
  final bool isActive;
  final bool canEdit;
  final bool saving;
  final String? settingsErrorMessage;
  final String? error;
  final String? success;
  final ValueChanged<int> onWeekdayChanged;
  final VoidCallback onPickDate;
  final ValueChanged<bool> onActiveChanged;
  final VoidCallback onRetrySettings;
  final VoidCallback? onRetryReconciliation;
  final VoidCallback onSave;
  final VoidCallback? onDeactivate;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return ListView(
      key: const ValueKey('shopping-schedule-form'),
      padding: const EdgeInsets.all(KsTokens.space20),
      children: [
        _SummaryCard(schedule: schedule),
        if (canEdit) ...[
          const SizedBox(height: KsTokens.space20),
          const KsFieldLabel('Shopping day'),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 560 ? 7 : 4;
              final itemWidth =
                  (constraints.maxWidth - (columns - 1) * KsTokens.space8) /
                  columns;
              return Wrap(
                spacing: KsTokens.space8,
                runSpacing: KsTokens.space8,
                children: [
                  for (var day = DateTime.monday; day <= DateTime.sunday; day++)
                    SizedBox(
                      width: itemWidth,
                      child: KsSelectChip(
                        key: ValueKey('shopping-schedule-weekday-$day'),
                        label: _shortWeekdays[day - 1],
                        selected: weekday == day,
                        onTap: saving ? null : () => onWeekdayChanged(day),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: KsTokens.space16),
          const KsFieldLabel('Effective from'),
          Semantics(
            button: true,
            label: 'Choose effective date',
            child: OutlinedButton.icon(
              key: const ValueKey('shopping-schedule-effective-from'),
              onPressed: saving ? null : onPickDate,
              icon: const Icon(Icons.calendar_month_outlined),
              label: Text(_formatDate(effectiveFrom)),
            ),
          ),
          const SizedBox(height: KsTokens.space16),
          SwitchListTile.adaptive(
            key: const ValueKey('shopping-schedule-active-toggle'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Active'),
            value: isActive,
            onChanged: saving ? null : onActiveChanged,
          ),
          if (settingsErrorMessage != null) ...[
            const SizedBox(height: KsTokens.space12),
            _ProviderError(
              message: settingsErrorMessage!,
              onRetry: onRetrySettings,
            ),
          ],
          if (error != null) ...[
            const SizedBox(height: KsTokens.space12),
            if (onRetryReconciliation == null)
              KsErrorAlert(message: error!)
            else
              _ProviderError(
                message: error!,
                onRetry: onRetryReconciliation!,
                retryLabel: 'Retry list refresh',
              ),
          ],
          if (success != null) ...[
            const SizedBox(height: KsTokens.space12),
            Semantics(
              liveRegion: true,
              child: Text(
                success!,
                key: const ValueKey('shopping-schedule-success'),
                style: KsTokens.bodyMedium.copyWith(color: ks.success),
              ),
            ),
          ],
          const SizedBox(height: KsTokens.space16),
          FilledButton(
            key: const ValueKey('shopping-schedule-save'),
            onPressed: saving || (isActive && settingsErrorMessage != null)
                ? null
                : onSave,
            child: saving
                ? const SizedBox.square(
                    dimension: KsTokens.space20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save schedule'),
          ),
          if (onDeactivate != null) ...[
            const SizedBox(height: KsTokens.space12),
            OutlinedButton(
              key: const ValueKey('shopping-schedule-deactivate'),
              style: KsButtonStyles.destructiveOutline(context),
              onPressed: saving ? null : onDeactivate,
              child: const Text('Deactivate schedule'),
            ),
          ],
        ],
      ],
    );
  }
}

class DeactivateShoppingScheduleDialog extends StatelessWidget {
  const DeactivateShoppingScheduleDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Deactivate schedule?'),
      content: const Text(
        'Future scheduled shopping lists will stop updating.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: KsButtonStyles.destructive(context),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Deactivate'),
        ),
      ],
    );
  }
}

part of 'shopping_schedule_screen.dart';

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.schedule});
  final ShoppingSchedule? schedule;

  @override
  Widget build(BuildContext context) => KsCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Current schedule', style: KsTokens.titleMedium),
        const SizedBox(height: KsTokens.space12),
        if (schedule == null)
          Text('Not set', style: KsTokens.bodyMedium)
        else ...[
          KsMetadataRow(
            label: 'Shopping day',
            value: _longWeekdays[schedule!.isoWeekday - 1],
          ),
          const SizedBox(height: KsTokens.space8),
          KsMetadataRow(
            label: 'Effective from',
            value: _formatDate(schedule!.effectiveFrom),
          ),
          const SizedBox(height: KsTokens.space8),
          KsMetadataRow(
            label: 'Status',
            value: schedule!.isActive ? 'Active' : 'Inactive',
          ),
        ],
      ],
    ),
  );
}

class _ProviderError extends StatelessWidget {
  const _ProviderError({
    required this.message,
    required this.onRetry,
    this.retryLabel = 'Retry',
  });
  final String message;
  final VoidCallback onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      KsErrorAlert(message: message),
      const SizedBox(height: KsTokens.space12),
      OutlinedButton(onPressed: onRetry, child: Text(retryLabel)),
    ],
  );
}

String _formatDate(DateTime value) => DateFormat.yMMMMd().format(value);
const _shortWeekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _longWeekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

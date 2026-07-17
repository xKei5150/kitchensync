part of 'calendar_screen.dart';

/// The selected-day peek — today's plan in a tappable card that opens the
/// day's lifecycle filmstrip.
class _SelectedDayPeek extends StatelessWidget {
  const _SelectedDayPeek({
    required this.date,
    required this.meal,
    required this.recipe,
    required this.onTap,
  });

  final DateTime date;
  final MealScheduleEntry? meal;
  final PlannedRecipe? recipe;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ks = context.ksColors;
    return Material(
      color: ks.surfaceRaised,
      borderRadius: BorderRadius.circular(KsTokens.radius12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(KsTokens.radius12),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(KsTokens.radius12),
            border: Border.all(color: ks.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${_weekday(date)} ${date.day} · Planned'.toUpperCase(),
                      style: KsTokens.labelSmall.copyWith(
                        color: isDark ? KsTokens.brandAccent : ks.brandPrimary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.check_circle_outline,
                    size: 12,
                    color: KsTokens.fresh,
                  ),
                  const SizedBox(width: KsTokens.space4),
                  Text(
                    'ready',
                    style: KsTokens.labelSmall.copyWith(
                      color: KsTokens.fresh,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: KsTokens.space6),
              Text(
                recipe?.title ?? 'No meals planned',
                style: KsTokens.headlineMedium.copyWith(
                  color: ks.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              if (meal != null) ...[
                const SizedBox(height: KsTokens.space2),
                Text(
                  '${meal!.mealLabel} · serves ${meal!.servingSize}',
                  style: KsTokens.bodySmall.copyWith(
                    color: ks.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

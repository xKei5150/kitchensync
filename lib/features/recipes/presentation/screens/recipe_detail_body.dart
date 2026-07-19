part of 'recipe_detail_screen.dart';

class _RecipeDetailBody extends ConsumerWidget {
  const _RecipeDetailBody({
    required this.recipeId,
    required this.title,
    required this.author,
    required this.location,
    required this.intro,
    required this.baseServings,
    required this.ingredients,
    required this.tags,
    required this.instructions,
    required this.isPublic,
    required this.saved,
    required this.canSchedule,
    required this.onBack,
    this.priceEstimate,
    this.youtubeUrl,
    this.onEdit,
    this.onDelete,
    this.onToggleSaved,
  });

  final String recipeId;
  final String title;
  final String author;
  final String location;
  final String intro;
  final int baseServings;
  final List<KsScalableIngredient> ingredients;
  final List<String> tags;
  final List<String> instructions;
  final bool isPublic;
  final bool saved;
  final bool canSchedule;
  final double? priceEstimate;
  final Uri? youtubeUrl;
  final VoidCallback onBack;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onToggleSaved;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ks = context.ksColors;
    final unitSystem = ref
        .watch(localePreferencesControllerProvider)
        .unitSystem;
    final currency = ref.watch(localeFormattersProvider).currency;
    final scheduleFlow = _RecipeScheduleFlow(
      recipeId: recipeId,
      title: title,
      baseServings: baseServings,
      tags: tags,
    );
    return Scaffold(
      backgroundColor: ks.surfaceBase,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _Hero(
            title: title,
            tags: tags,
            saved: saved,
            onBack: onBack,
            onToggleSaved: onToggleSaved,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              KsTokens.space20,
              KsTokens.space16,
              KsTokens.space20,
              KsTokens.space24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  location.trim().isEmpty
                      ? 'by $author'
                      : 'by $author · $location',
                  style: KsTokens.labelMedium.copyWith(color: ks.textTertiary),
                ),
                const SizedBox(height: KsTokens.space10),
                _DropCapIntro(initial: _initialFor(intro), body: intro),
                if (tags.isNotEmpty || priceEstimate != null) ...[
                  const SizedBox(height: KsTokens.space12),
                  Wrap(
                    spacing: KsTokens.space8,
                    runSpacing: KsTokens.space8,
                    children: [
                      if (priceEstimate != null)
                        KsTag(
                          label: currency.format(priceEstimate!),
                          icon: Icons.payments_outlined,
                          tone: KsTagTone.outline,
                        ),
                      for (final tag in tags)
                        KsTag(label: tag, tone: KsTagTone.neutral),
                    ],
                  ),
                ],
                const SizedBox(height: KsTokens.space16),
                KsServingScaler(
                  baseServings: baseServings,
                  ingredients: ingredients,
                  unitSystem: unitSystem,
                ),
                if (instructions.isNotEmpty) ...[
                  const SizedBox(height: KsTokens.space20),
                  Text(
                    'Instructions',
                    style: KsTokens.titleMedium.copyWith(color: ks.textPrimary),
                  ),
                  const SizedBox(height: KsTokens.space10),
                  for (var i = 0; i < instructions.length; i++) ...[
                    Text(
                      '${i + 1}. ${instructions[i]}',
                      style: KsTokens.bodyMedium.copyWith(
                        color: ks.textSecondary,
                        height: 1.45,
                      ),
                    ),
                    if (i != instructions.length - 1)
                      const SizedBox(height: KsTokens.space8),
                  ],
                ],
                if (youtubeUrl != null) ...[
                  const SizedBox(height: KsTokens.space20),
                  Text(
                    'YouTube',
                    style: KsTokens.titleMedium.copyWith(color: ks.textPrimary),
                  ),
                  const SizedBox(height: KsTokens.space8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.play_circle_outline_rounded,
                        color: ks.brandPrimary,
                      ),
                      const SizedBox(width: KsTokens.space8),
                      Expanded(
                        child: SelectableText(
                          youtubeUrl.toString(),
                          style: KsTokens.bodyMedium.copyWith(
                            color: ks.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (onEdit != null || onDelete != null) ...[
                  const SizedBox(height: KsTokens.space20),
                  Row(
                    children: [
                      if (onEdit != null)
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: onEdit,
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('Edit'),
                          ),
                        ),
                      if (onEdit != null && onDelete != null)
                        const SizedBox(width: KsTokens.space10),
                      if (onDelete != null)
                        IconButton.outlined(
                          onPressed: onDelete,
                          tooltip: 'Delete recipe',
                          icon: const Icon(Icons.delete_outline),
                        ),
                    ],
                  ),
                ],
                if (isPublic) ...[
                  const SizedBox(height: KsTokens.space20),
                  _RecipeSocialPanel(recipeId: recipeId),
                ],
                if (canSchedule) ...[
                  const SizedBox(height: KsTokens.space20),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          onPressed: () => scheduleFlow.open(
                            context,
                            ref,
                            initialDate: scheduleFlow.today(ref),
                          ),
                          child: const Text('Start cooking'),
                        ),
                      ),
                      const SizedBox(width: KsTokens.space10),
                      OutlinedButton(
                        onPressed: () => scheduleFlow.open(
                          context,
                          ref,
                          initialDate: scheduleFlow.tomorrow(ref),
                        ),
                        child: const Text('Schedule'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _initialFor(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? 'A' : trimmed.characters.first.toUpperCase();
  }
}

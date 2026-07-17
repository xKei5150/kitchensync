part of 'recipe_detail_screen.dart';

class _RecipeDetailBody extends ConsumerWidget {
  const _RecipeDetailBody({
    required this.recipeId,
    required this.title,
    required this.intro,
    required this.baseServings,
    required this.ingredients,
    required this.tags,
    required this.instructions,
    required this.onBack,
    this.priceEstimate,
  });

  final String recipeId;
  final String title;
  final String intro;
  final int baseServings;
  final List<KsScalableIngredient> ingredients;
  final List<String> tags;
  final List<String> instructions;
  final double? priceEstimate;
  final VoidCallback onBack;

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
          _Hero(title: title, tags: tags, onBack: onBack),
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

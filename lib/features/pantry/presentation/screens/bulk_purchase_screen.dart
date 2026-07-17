import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kitchensync/app/design_tokens.dart';
import 'package:kitchensync/core/preferences/preferences_providers.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/core/utils/result.dart';
import 'package:kitchensync/core/widgets/widgets.dart';
import 'package:kitchensync/features/ingredient_dictionary/presentation/providers/ingredient_providers.dart';
import 'package:kitchensync/features/household/domain/entities/household_policy_models.dart';
import 'package:kitchensync/features/household/domain/services/household_policy.dart';
import 'package:kitchensync/features/pantry/domain/services/bulk_prediction_engine.dart';
import 'package:kitchensync/features/pantry/domain/services/bulk_suggestion_dismissal_policy.dart';
import 'package:kitchensync/features/pantry/presentation/providers/pantry_providers.dart';
import 'package:kitchensync/features/shopping/presentation/providers/shopping_repository_providers.dart';

final _dismissedBulkSuggestionsProvider =
    NotifierProvider<_DismissedBulkSuggestions, Set<String>>(
      _DismissedBulkSuggestions.new,
    );

class _DismissedBulkSuggestions extends Notifier<Set<String>> {
  late String _key;
  static const _policy = BulkSuggestionDismissalPolicy();

  @override
  Set<String> build() {
    _key = 'pantry.bulkDismissed.${ref.watch(activeHouseholdIdProvider)}';
    final preferences = ref.watch(sharedPreferencesProvider);
    final stored = preferences.getStringList(_key) ?? const [];
    final active = _policy.activeEntries(
      stored,
      now: ref.watch(clockProvider).now(),
    );
    if (active.length != stored.length) {
      preferences.setStringList(_key, _encode(active));
    }
    return active.keys.toSet();
  }

  void dismiss(String ingredientId) {
    final preferences = ref.read(sharedPreferencesProvider);
    final now = ref.read(clockProvider).now();
    final active = _policy.activeEntries(
      preferences.getStringList(_key) ?? const [],
      now: now,
    );
    active[ingredientId] = now.add(const Duration(days: 7));
    preferences.setStringList(_key, _encode(active));
    state = active.keys.toSet();
  }

  static List<String> _encode(Map<String, DateTime> entries) => [
    for (final entry in entries.entries)
      '${entry.key}\u001f${entry.value.toUtc().toIso8601String()}',
  ]..sort();
}

class BulkPurchaseScreen extends ConsumerWidget {
  const BulkPurchaseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final household = ref.watch(activeHouseholdContextProvider);
    final canReview =
        household != null &&
        household.hasPremium &&
        const HouseholdPolicy().roleCan(
          household.role,
          HouseholdCapability.reviewBulkItems,
          isSoloHousehold: household.isSolo,
        );
    if (!canReview) {
      return Scaffold(
        appBar: AppBar(title: const Text('Bulk Foods to Purchase')),
        body: Center(
          child: KsPremiumLock(
            title: 'Bulk purchase timing',
            body:
                'See which staples are likely to run out before the next shop.',
            onUnlock: () => context.pushNamed('premium'),
            child: const SizedBox(width: 280, height: 180),
          ),
        ),
      );
    }
    final dismissed = ref.watch(_dismissedBulkSuggestionsProvider);
    final statuses = ref
        .watch(bulkPantryStatusesProvider)
        .where(
          (status) =>
              status.needsPurchaseSoon &&
              !dismissed.contains(status.item.ingredientId),
        )
        .toList(growable: false);
    return Scaffold(
      appBar: AppBar(title: const Text('Bulk Foods to Purchase')),
      body: statuses.isEmpty
          ? const Center(
              child: KsEmptyState(
                icon: Icons.inventory_2_outlined,
                title: 'Nothing due right now',
                subtitle:
                    'Dismissed and well-stocked items stay out of the way.',
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(KsTokens.space16),
              itemCount: statuses.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: KsTokens.space10),
              itemBuilder: (context, index) => _BulkPurchaseCard(
                status: statuses[index],
                now: ref.watch(clockProvider).now(),
                onDismiss: () => ref
                    .read(_dismissedBulkSuggestionsProvider.notifier)
                    .dismiss(statuses[index].item.ingredientId),
              ),
            ),
    );
  }
}

class _BulkPurchaseCard extends ConsumerWidget {
  const _BulkPurchaseCard({
    required this.status,
    required this.now,
    required this.onDismiss,
  });

  final BulkPantryStatus status;
  final DateTime now;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days = status.daysLeftFrom(now);
    final ingredient = switch (ref
        .watch(pantryIngredientProvider(status.item.ingredientId))
        .valueOrNull) {
      Success(:final value) => value,
      _ => null,
    };
    final name =
        ingredient?.displayNames['en'] ??
        ingredient?.name ??
        status.item.ingredientId;
    final reason = days != null && days <= 7
        ? 'Predicted to run out soon'
        : 'Purchase interval is due';
    return KsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: KsTokens.space6),
          Text(
            [
              days == null ? 'Days left unknown' : '$days estimated days left',
              if (status.item.lastPurchaseDate != null)
                'Last purchased ${_date(status.item.lastPurchaseDate!)}',
              if (status.recommendedPurchaseIntervalDays != null)
                'Buy every ${status.recommendedPurchaseIntervalDays} days',
              reason,
            ].join(' · '),
          ),
          const SizedBox(height: KsTokens.space12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onDismiss,
                  child: const Text('Not needed this time'),
                ),
              ),
              const SizedBox(width: KsTokens.space8),
              Expanded(
                child: FilledButton(
                  onPressed: () async {
                    try {
                      await ref
                          .read(shoppingPlanningControllerProvider)
                          .createSuggestedListFromBulkStatus(status);
                      ref.invalidate(activeShoppingListsProvider);
                      if (context.mounted) context.pop();
                    } catch (error) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Could not add item: $error')),
                      );
                    }
                  },
                  child: const Text('Add to shopping'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _date(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

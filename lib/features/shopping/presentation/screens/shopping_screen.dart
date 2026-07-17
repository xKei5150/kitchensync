import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kitchensync/app/design_tokens.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/core/widgets/widgets.dart';
import 'package:kitchensync/features/household/domain/entities/household_policy_models.dart';
import 'package:kitchensync/features/household/domain/services/household_policy.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/ingredient.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/unit_registry.dart';
import 'package:kitchensync/features/ingredient_dictionary/presentation/providers/ingredient_providers.dart';
import 'package:kitchensync/features/shopping/domain/entities/shopping_command.dart';
import 'package:kitchensync/features/shopping/domain/entities/shopping_plan.dart';
import 'package:kitchensync/features/shopping/domain/entities/shopping_recovery.dart';
import 'package:kitchensync/features/shopping/presentation/providers/shopping_repository_providers.dart';

part 'shopping_home_body.dart';
part 'shopping_home_helpers.dart';
part 'shopping_home_list_tiles.dart';
part 'shopping_home_shop_now.dart';
part 'shopping_home_shop_now_feedback.dart';
part 'shopping_home_shop_now_card.dart';

final _shoppingPreviewIngredientProvider =
    FutureProvider.family<Ingredient?, String>((ref, ingredientId) {
      final householdId = ref.watch(activeHouseholdIdProvider);
      return ref
          .watch(ingredientRepositoryProvider)
          .getById(ingredientId, householdId: householdId);
    });

String _shoppingPreviewIngredientName(
  BuildContext context,
  Ingredient ingredient,
) {
  final languageCode = Localizations.localeOf(context).languageCode;
  return ingredient.displayNames[languageCode] ??
      ingredient.displayNames['en'] ??
      ingredient.name;
}

String _shoppingPreviewQuantity(
  double quantity,
  UnitId unit,
  List<UnitDefinition> localUnits,
) {
  UnitDefinition? definition;
  for (final candidate in localUnits) {
    if (candidate.id == unit) definition = candidate;
  }
  definition ??= UnitRegistry.find(unit);
  final amount = quantity == quantity.roundToDouble()
      ? quantity.toInt().toString()
      : quantity.toString();
  final label = definition == null
      ? unit.value
      : quantity == 1
      ? definition.label
      : definition.pluralLabel;
  return '$amount $label';
}

/// Screen 09 · Shopping home + Shop Now.
///
/// The Shop tab landing: scheduled shop dates, a slim history, and a prominent
/// Shop Now that opens the "how far ahead?" setup before building a generated
/// list. The in-store checklist lives at `/shop/list`.
class ShoppingScreen extends ConsumerStatefulWidget {
  const ShoppingScreen({super.key});

  @override
  ConsumerState<ShoppingScreen> createState() => _ShoppingScreenState();
}

class _ShoppingScreenState extends ConsumerState<ShoppingScreen> {
  var _wasHomeVisible = false;
  var _homeLoadGeneration = 0;
  var _requestedHomeLoadGeneration = 0;
  var _reconciliationInFlight = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isHomeVisible = TickerMode.valuesOf(context).enabled;
    if (isHomeVisible && !_wasHomeVisible) {
      _homeLoadGeneration++;
    }
    _wasHomeVisible = isHomeVisible;
  }

  void _reconcileOnHomeLoad(ActiveHouseholdContext? household) {
    if (!_wasHomeVisible ||
        !_reconcilesOnHome(household) ||
        _requestedHomeLoadGeneration >= _homeLoadGeneration) {
      return;
    }
    _requestedHomeLoadGeneration = _homeLoadGeneration;
    if (!_reconciliationInFlight) {
      unawaited(_runReconciliation());
    }
  }

  Future<void> _runReconciliation() async {
    _reconciliationInFlight = true;
    final startedGeneration = _requestedHomeLoadGeneration;
    try {
      await ref
          .read(shoppingPlanningControllerProvider)
          .reconcileShoppingHome();
    } on Object {
      // A later Shopping-home load retries without failing the visible surface.
    } finally {
      _reconciliationInFlight = false;
      if (mounted &&
          _wasHomeVisible &&
          _requestedHomeLoadGeneration > startedGeneration) {
        unawaited(_runReconciliation());
      }
    }
  }

  Future<void> _openShopNow(BuildContext context) async {
    final listId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _ShopNowSheet(),
    );
    if (listId != null && context.mounted) {
      if (context.mounted) {
        unawaited(context.push('/shop/list/$listId'));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lists = ref.watch(activeShoppingListsProvider);
    final household = ref.watch(activeHouseholdContextProvider);
    _reconcileOnHomeLoad(household);
    final canShopNow = _can(household, HouseholdCapability.initiateShopNow);
    final canManageLists = _can(
      household,
      HouseholdCapability.generateShoppingLists,
    );
    final canManageSchedule = _can(
      household,
      HouseholdCapability.manageShoppingSchedules,
    );
    return SafeArea(
      bottom: false,
      child: lists.when(
        data: (records) {
          final pending = records
              .where((list) => list.status == ShoppingListStatus.pending)
              .toList(growable: false);
          final suggestions = pending
              .where(
                (list) =>
                    list.type == ShoppingListType.suggested ||
                    list.type == ShoppingListType.emergency,
              )
              .toList(growable: false);
          final upcoming = pending
              .where(
                (list) =>
                    list.type == ShoppingListType.scheduled ||
                    list.type == ShoppingListType.shopNow,
              )
              .toList(growable: false);
          final history =
              records
                  .where((list) => list.status == ShoppingListStatus.completed)
                  .toList(growable: false)
                ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
          return _ShoppingHomeBody(
            upcoming: upcoming,
            suggestions: suggestions,
            history: history,
            canShopNow: canShopNow,
            canManageLists: canManageLists,
            canManageSchedule: canManageSchedule,
            onShopNow: () => _openShopNow(context),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Padding(
          padding: const EdgeInsets.all(KsTokens.space16),
          child: Center(
            child: KsErrorAlert(message: 'Could not load shopping: $error'),
          ),
        ),
      ),
    );
  }

  bool _can(ActiveHouseholdContext? household, HouseholdCapability capability) {
    if (household == null) return false;
    return const HouseholdPolicy().roleCan(
      household.role,
      capability,
      isSoloHousehold: household.isSolo,
    );
  }

  bool _reconcilesOnHome(ActiveHouseholdContext? household) {
    return _can(household, HouseholdCapability.generateShoppingLists);
  }
}

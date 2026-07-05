import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kitchensync/app/design_tokens.dart';
import 'package:kitchensync/core/widgets/widgets.dart';
import 'package:kitchensync/features/calendar/presentation/providers/planning_providers.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/shopping/domain/entities/shopping_plan.dart';
import 'package:kitchensync/features/shopping/presentation/providers/shopping_repository_providers.dart';

/// In-store checklist — buying ahead pays down the future.
///
/// A tactile, receipt-like list — shared, with substitutions and purchase
/// confirmation. Reached from the Shopping home's Shop Now flow or by list id.
class ShoppingListScreen extends ConsumerStatefulWidget {
  const ShoppingListScreen({this.listId, super.key});

  final String? listId;

  @override
  ConsumerState<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends ConsumerState<ShoppingListScreen> {
  // The four visible lines; the wider list is 11 items, 7 already done.
  late final List<_ShopLine> _lines = [
    const _ShopLine(
      key: 'sample-tomatoes',
      name: 'Tomatoes',
      state: ChecklistItemState.toBuy,
      quantity: '1 kg',
    ),
    const _ShopLine(
      key: 'sample-beans',
      name: 'White beans · 2 tins',
      state: ChecklistItemState.bought,
      memberInitial: 'B',
      memberSeat: 1,
    ),
    const _ShopLine(
      key: 'sample-orzo',
      name: 'Orzo',
      state: ChecklistItemState.substituted,
      note: 'risoni',
      memberInitial: 'A',
      memberSeat: 0,
    ),
    const _ShopLine(
      key: 'sample-dill',
      name: 'Fresh dill',
      state: ChecklistItemState.unavailable,
      note: 'none left',
    ),
  ];

  final Map<String, ChecklistItemState> _generatedStates = {};

  static const int _sampleTotal = 11;

  // Five of the eleven are done off-screen; the two visible done lines (a
  // bought tin, a substitution) lift the live count to the design's 7 / 11,
  // and local toggles move it from there.
  int get _sampleDone =>
      5 +
      _lines
          .where(
            (l) =>
                l.state == ChecklistItemState.bought ||
                l.state == ChecklistItemState.substituted,
          )
          .length;

  void _toggleSample(int index) {
    setState(() {
      final line = _lines[index];
      _lines[index] = line.copyWith(
        state: line.state == ChecklistItemState.bought
            ? ChecklistItemState.toBuy
            : ChecklistItemState.bought,
      );
    });
  }

  void _toggleGenerated(String key) {
    setState(() {
      final state = _generatedStates[key] ?? ChecklistItemState.toBuy;
      _generatedStates[key] = state == ChecklistItemState.bought
          ? ChecklistItemState.toBuy
          : ChecklistItemState.bought;
    });
  }

  Future<void> _togglePersisted(ShoppingListRecord list, String itemId) async {
    ShoppingListItemRecord? item;
    for (final current in list.items) {
      if (current.id == itemId) {
        item = current;
        break;
      }
    }
    if (item == null) return;
    final status = item.status == ShoppingListItemStatus.bought
        ? ShoppingListItemStatus.unchecked
        : ShoppingListItemStatus.bought;
    try {
      await ref
          .read(shoppingPlanningControllerProvider)
          .updateItemStatus(listId: list.id, itemId: item.id, status: status);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not update item: $error')));
    }
  }

  Future<void> _finishPersistedShopping(ShoppingListRecord list) async {
    try {
      await ref.read(shoppingPlanningControllerProvider).completeList(list);
      if (!mounted) return;
      context.pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not finish shop: $error')));
    }
  }

  void _finishShopping(ShoppingListPlan? activeList, List<_ShopLine> lines) {
    if (activeList != null) {
      final purchases = lines
          .where(
            (line) =>
                line.ingredientId != null &&
                line.quantityValue != null &&
                line.unit != null &&
                (line.state == ChecklistItemState.bought ||
                    line.state == ChecklistItemState.substituted),
          )
          .map(
            (line) => ShoppingPurchaseLine(
              ingredientId: line.ingredientId!,
              quantity: line.quantityValue!,
              unit: line.unit!,
            ),
          );
      ref
          .read(planningControllerProvider.notifier)
          .completeActiveShopping(lines: purchases);
    }
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final persistedList = widget.listId == null
        ? null
        : ref.watch(activeShoppingListRecordProvider(widget.listId!));
    if (persistedList != null) {
      return persistedList.when(
        data: (list) {
          if (list == null) {
            return const Scaffold(
              body: Center(
                child: KsEmptyState(
                  icon: Icons.shopping_bag_outlined,
                  title: 'Shopping list not found',
                  subtitle: 'It may have been completed or deleted.',
                ),
              ),
            );
          }
          return _ShoppingListBody(
            lines: list.items.map(_ShopLine.fromRecord).toList(growable: false),
            totalFallback: list.items.length,
            onToggle: (itemId) => _togglePersisted(list, itemId),
            onDone: () => _finishPersistedShopping(list),
          );
        },
        loading: () =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (error, _) => Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(KsTokens.space16),
            child: Center(
              child: KsErrorAlert(message: 'Could not load list: $error'),
            ),
          ),
        ),
      );
    }

    final activeList = ref.watch(
      planningControllerProvider.select((state) => state.activeShoppingList),
    );
    final generatedLines = activeList?.items
        .map(
          (item) => _ShopLine.fromPlan(
            item,
            state:
                _generatedStates[_ShopLine.planKey(item)] ??
                ChecklistItemState.toBuy,
          ),
        )
        .toList(growable: false);
    final lines = generatedLines ?? _lines;
    final done = generatedLines == null
        ? _sampleDone
        : lines
              .where(
                (line) =>
                    line.state == ChecklistItemState.bought ||
                    line.state == ChecklistItemState.substituted,
              )
              .length;
    final total = generatedLines == null ? _sampleTotal : lines.length;
    return _ShoppingListBody(
      lines: lines,
      totalFallback: total,
      doneOverride: done,
      onToggle: (key) {
        if (generatedLines == null) {
          final index = lines.indexWhere((line) => line.key == key);
          _toggleSample(index);
        } else {
          _toggleGenerated(key);
        }
      },
      onDone: () => _finishShopping(activeList, lines),
    );
  }
}

class _ShoppingListBody extends StatelessWidget {
  const _ShoppingListBody({
    required this.lines,
    required this.totalFallback,
    required this.onToggle,
    required this.onDone,
    this.doneOverride,
  });

  final List<_ShopLine> lines;
  final int totalFallback;
  final ValueChanged<String> onToggle;
  final VoidCallback onDone;
  final int? doneOverride;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    final done =
        doneOverride ??
        lines
            .where(
              (line) =>
                  line.state == ChecklistItemState.bought ||
                  line.state == ChecklistItemState.substituted,
            )
            .length;
    final total = totalFallback;
    return Scaffold(
      backgroundColor: ks.surfaceBase,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            KsTokens.space16,
            KsTokens.space8,
            KsTokens.space16,
            KsTokens.space24,
          ),
          children: [
            KsFolioHeader(
              eyebrow: 'In-store · Fri 27',
              title: 'Weekly shop',
              actions: [
                KsHeaderAction(
                  icon: Icons.arrow_back_rounded,
                  tooltip: 'Back',
                  onTap: () => context.pop(),
                ),
                const KsMemberAvatar(initial: 'A', seat: 0, size: 26),
                const KsMemberAvatar(initial: 'B', seat: 1, size: 26),
              ],
            ),
            const SizedBox(height: KsTokens.space12),
            _ProgressBar(done: done, total: total),
            const SizedBox(height: KsTokens.space16),
            const _PayoffLedger(),
            const SizedBox(height: KsTokens.space16),
            Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: ks.surfaceRaised,
                borderRadius: BorderRadius.circular(KsTokens.radius16),
                border: Border.all(color: ks.border),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < lines.length; i++) ...[
                    if (i > 0)
                      Divider(height: 1, thickness: 1, color: ks.hairline),
                    KsChecklistRow(
                      name: lines[i].name,
                      state: lines[i].state,
                      quantity: lines[i].quantity,
                      note: lines[i].note,
                      memberInitial: lines[i].memberInitial,
                      memberSeat: lines[i].memberSeat,
                      onToggle: () => onToggle(lines[i].key),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: KsTokens.space16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onDone,
                child: const Text('Done shopping'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Immutable shopping-line view model for the local toggle state.
@immutable
class _ShopLine {
  const _ShopLine({
    required this.name,
    required this.state,
    this.key = '',
    this.quantity,
    this.note,
    this.memberInitial,
    this.memberSeat,
    this.ingredientId,
    this.quantityValue,
    this.unit,
  });

  factory _ShopLine.fromPlan(
    ShoppingListItemPlan item, {
    required ChecklistItemState state,
  }) {
    return _ShopLine(
      key: planKey(item),
      name: _ingredientLabel(item.ingredientId),
      state: state,
      quantity: _quantityLabel(item.quantity, item.unit),
      ingredientId: item.ingredientId,
      quantityValue: item.quantity,
      unit: item.unit,
    );
  }

  factory _ShopLine.fromRecord(
    ShoppingListItemRecord item, {
    ChecklistItemState? stateOverride,
  }) {
    final state = stateOverride ?? _stateFromRecord(item.status);
    return _ShopLine(
      key: item.id,
      name: _ingredientLabel(item.ingredientId),
      state: state,
      quantity: _quantityLabel(item.quantityNeeded, item.unit),
      ingredientId: item.substituteIngredientId ?? item.ingredientId,
      quantityValue: item.substituteQuantity ?? item.quantityNeeded,
      unit: item.substituteUnit ?? item.unit,
    );
  }

  final String key;
  final String name;
  final ChecklistItemState state;
  final String? quantity;
  final String? note;
  final String? memberInitial;
  final int? memberSeat;
  final String? ingredientId;
  final double? quantityValue;
  final Unit? unit;

  _ShopLine copyWith({ChecklistItemState? state}) => _ShopLine(
    key: key,
    name: name,
    state: state ?? this.state,
    quantity: quantity,
    note: note,
    memberInitial: memberInitial,
    memberSeat: memberSeat,
    ingredientId: ingredientId,
    quantityValue: quantityValue,
    unit: unit,
  );

  static String planKey(ShoppingListItemPlan item) {
    return '${item.ingredientId}:${item.unit.name}';
  }
}

ChecklistItemState _stateFromRecord(ShoppingListItemStatus status) {
  return switch (status) {
    ShoppingListItemStatus.bought => ChecklistItemState.bought,
    ShoppingListItemStatus.substituted => ChecklistItemState.substituted,
    ShoppingListItemStatus.unavailable => ChecklistItemState.unavailable,
    _ => ChecklistItemState.toBuy,
  };
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.done, required this.total});

  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    final fraction = total == 0 ? 0.0 : (done / total).clamp(0.0, 1.0);
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(KsTokens.radiusFull),
            child: Stack(
              children: [
                Container(height: 8, color: ks.neutralSubtle),
                FractionallySizedBox(
                  widthFactor: fraction,
                  child: Container(height: 8, color: ks.brandPrimary),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: KsTokens.space12),
        Text(
          '$done / $total',
          style: KsTokens.labelMedium.copyWith(
            color: ks.textSecondary,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

String _ingredientLabel(String ingredientId) {
  return switch (ingredientId) {
    'beans' => 'White beans',
    'chicken' => 'Roast chicken',
    'lentils' => 'Lentils',
    'potato' => 'Potatoes',
    'spinach' => 'Spinach',
    'tomato' => 'Tomatoes',
    _ =>
      ingredientId
          .split(RegExp('[-_]'))
          .map(
            (word) => word.isEmpty
                ? word
                : '${word[0].toUpperCase()}${word.substring(1)}',
          )
          .join(' '),
  };
}

String _quantityLabel(double quantity, Unit unit) {
  final amount = quantity == quantity.roundToDouble()
      ? quantity.toInt().toString()
      : quantity.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
  final unitLabel = switch (unit) {
    Unit.piece => quantity == 1 ? 'piece' : 'pieces',
    _ => unit.name,
  };
  return '$amount $unitLabel';
}

/// The "you paid down the future" ledger — ticking an item early strikes it
/// from next week's list and shrinks the count.
class _PayoffLedger extends StatelessWidget {
  const _PayoffLedger();

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return Container(
      padding: const EdgeInsets.all(KsTokens.space16),
      decoration: BoxDecoration(
        color: ks.surfaceSunken,
        borderRadius: BorderRadius.circular(KsTokens.radius16),
        border: Border.all(color: ks.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, size: 14, color: ks.calShopping),
              const SizedBox(width: KsTokens.space6),
              Text(
                'You paid down the future'.toUpperCase(),
                style: KsTokens.labelSmall.copyWith(
                  color: ks.calShopping,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
          const SizedBox(height: KsTokens.space8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                'Next week',
                style: KsTokens.bodySmall.copyWith(color: ks.textSecondary),
              ),
              const SizedBox(width: KsTokens.space10),
              Text(
                '11',
                style: KsTokens.titleMedium.copyWith(
                  color: ks.textTertiary,
                  decoration: TextDecoration.lineThrough,
                ),
              ),
              const SizedBox(width: KsTokens.space6),
              Icon(
                Icons.arrow_forward_rounded,
                size: 14,
                color: ks.textTertiary,
              ),
              const SizedBox(width: KsTokens.space6),
              Text(
                '10 items',
                style: KsTokens.titleMedium.copyWith(color: ks.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: KsTokens.space2),
          Text(
            "that's one less trip to make later",
            style: KsTokens.displaySmall.copyWith(
              color: ks.textTertiary,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w400,
              fontSize: 12,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kitchensync/app/design_tokens.dart';
import 'package:kitchensync/core/widgets/widgets.dart';

/// In-store checklist — buying ahead pays down the future.
///
/// A tactile, receipt-like list — shared, with per-member ticks and a
/// substitution. Reached from the Shopping home's Shop Now flow. Presentational
/// with representative sample data; ticking is wired to ephemeral local state
/// so the list feels alive.
class ShoppingListScreen extends StatefulWidget {
  const ShoppingListScreen({super.key});

  @override
  State<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends State<ShoppingListScreen> {
  // The four visible lines; the wider list is 11 items, 7 already done.
  late final List<_ShopLine> _lines = [
    const _ShopLine(
      name: 'Tomatoes',
      state: ChecklistItemState.toBuy,
      quantity: '1 kg',
    ),
    const _ShopLine(
      name: 'White beans · 2 tins',
      state: ChecklistItemState.bought,
      memberInitial: 'B',
      memberSeat: 1,
    ),
    const _ShopLine(
      name: 'Orzo',
      state: ChecklistItemState.substituted,
      note: 'risoni',
      memberInitial: 'A',
      memberSeat: 0,
    ),
    const _ShopLine(
      name: 'Fresh dill',
      state: ChecklistItemState.unavailable,
      note: 'none left',
    ),
  ];

  static const int _total = 11;

  // Five of the eleven are done off-screen; the two visible done lines (a
  // bought tin, a substitution) lift the live count to the design's 7 / 11,
  // and local toggles move it from there.
  int get _done =>
      5 +
      _lines
          .where(
            (l) =>
                l.state == ChecklistItemState.bought ||
                l.state == ChecklistItemState.substituted,
          )
          .length;

  void _toggle(int index) {
    setState(() {
      final line = _lines[index];
      _lines[index] = line.copyWith(
        state: line.state == ChecklistItemState.bought
            ? ChecklistItemState.toBuy
            : ChecklistItemState.bought,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
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
            _ProgressBar(done: _done, total: _total),
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
                  for (var i = 0; i < _lines.length; i++) ...[
                    if (i > 0)
                      Divider(height: 1, thickness: 1, color: ks.hairline),
                    KsChecklistRow(
                      name: _lines[i].name,
                      state: _lines[i].state,
                      quantity: _lines[i].quantity,
                      note: _lines[i].note,
                      memberInitial: _lines[i].memberInitial,
                      memberSeat: _lines[i].memberSeat,
                      onToggle: () => _toggle(i),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: KsTokens.space16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => context.pop(),
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
    this.quantity,
    this.note,
    this.memberInitial,
    this.memberSeat,
  });

  final String name;
  final ChecklistItemState state;
  final String? quantity;
  final String? note;
  final String? memberInitial;
  final int? memberSeat;

  _ShopLine copyWith({ChecklistItemState? state}) => _ShopLine(
    name: name,
    state: state ?? this.state,
    quantity: quantity,
    note: note,
    memberInitial: memberInitial,
    memberSeat: memberSeat,
  );
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.done, required this.total});

  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    final fraction = (done / total).clamp(0.0, 1.0);
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kitchensync/app/design_tokens.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/core/utils/result.dart';
import 'package:kitchensync/core/widgets/widgets.dart';
import 'package:kitchensync/features/pantry/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/entities/pantry_item.dart';
import 'package:kitchensync/features/pantry/domain/usecases/mark_as_waste.dart';
import 'package:kitchensync/features/pantry/presentation/providers/pantry_providers.dart';

class MarkAsWasteSheet extends ConsumerStatefulWidget {
  const MarkAsWasteSheet({required this.item, super.key});

  final PantryItem item;

  @override
  ConsumerState<MarkAsWasteSheet> createState() => _MarkAsWasteSheetState();
}

class _MarkAsWasteSheetState extends ConsumerState<MarkAsWasteSheet> {
  late final TextEditingController _qty;
  WasteReason _reason = WasteReason.spoiled;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _qty = TextEditingController(text: widget.item.quantity.toString());
  }

  @override
  void dispose() {
    _qty.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final qty = double.tryParse(_qty.text);
    if (qty == null || qty <= 0) {
      setState(() => _error = 'Enter a quantity greater than zero.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    final hid = ref.read(activeHouseholdIdProvider);
    final useCase = ref.read(markAsWasteProvider);
    final result = await useCase(
      MarkAsWasteParams(
        householdId: hid,
        pantryItemId: widget.item.id,
        quantity: qty,
        reason: _reason,
      ),
    );

    if (!mounted) return;

    switch (result) {
      case Success():
        context.pop();
      case ResultFailure(:final failure):
        setState(() {
          _submitting = false;
          _error = failure.toString();
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        KsTokens.space20,
        KsTokens.space20,
        KsTokens.space20,
        KsTokens.space20 + bottomInset,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: KsTokens.borderStrong,
                borderRadius: BorderRadius.circular(KsTokens.radiusFull),
              ),
            ),
          ),
          const SizedBox(height: KsTokens.space20),
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: KsTokens.expired.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(KsTokens.radius10),
                ),
                child: Icon(
                  Icons.delete_outline,
                  color: KsTokens.expired,
                  size: 22,
                ),
              ),
              const SizedBox(width: KsTokens.space12),
              Text(
                'Mark as waste',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
          const SizedBox(height: KsTokens.space20),
          TextField(
            controller: _qty,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Quantity'),
          ),
          const SizedBox(height: KsTokens.space12),
          DropdownButtonFormField<WasteReason>(
            value: _reason,
            decoration: const InputDecoration(labelText: 'Reason'),
            items: WasteReason.values
                .map((r) => DropdownMenuItem(value: r, child: Text(r.name)))
                .toList(),
            onChanged: _submitting
                ? null
                : (r) {
                    if (r != null) setState(() => _reason = r);
                  },
          ),
          if (_error != null) ...[
            const SizedBox(height: KsTokens.space12),
            KsErrorAlert(message: _error!),
          ],
          const SizedBox(height: KsTokens.space24),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            style: FilledButton.styleFrom(backgroundColor: KsTokens.expired),
            child: _submitting
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: KsTokens.textOnBrand,
                    ),
                  )
                : const Text('Confirm waste'),
          ),
        ],
      ),
    );
  }
}

part of 'shopping_list_screen.dart';

extension _ShoppingListMutationActions on _ShoppingListScreenState {
  Future<void> _togglePersisted(ShoppingListRecord list, String itemId) async {
    ShoppingListItemRecord? item;
    for (final current in list.items) {
      if (current.id == itemId) {
        item = current;
        break;
      }
    }
    if (item == null) return;
    final currentItem = item;
    final status = currentItem.status == ShoppingListItemStatus.bought
        ? ShoppingListItemStatus.unchecked
        : ShoppingListItemStatus.bought;
    await _runItemMutation(
      list,
      currentItem.id,
      (revision) => ref
          .read(shoppingPlanningControllerProvider)
          .updateItemStatus(
            listId: list.id,
            itemId: currentItem.id,
            expectedRevision: revision,
            status: status,
            purchasedQuantity: status == ShoppingListItemStatus.bought
                ? currentItem.purchasedQuantity ?? currentItem.quantityNeeded
                : null,
          ),
    );
  }

  Future<void> _setPersistedStatus(
    ShoppingListRecord list,
    String itemId,
    ShoppingListItemStatus status, {
    double? purchasedQuantity,
  }) => _runItemMutation(
    list,
    itemId,
    (revision) => ref
        .read(shoppingPlanningControllerProvider)
        .updateItemStatus(
          listId: list.id,
          itemId: itemId,
          expectedRevision: revision,
          status: status,
          purchasedQuantity: purchasedQuantity,
        ),
  );

  Future<void> _addPersisted(ShoppingListRecord list) async {
    final ingredient = await _showIngredientPicker(context);
    if (ingredient == null || !mounted) return;
    final draft = await _quantityDraft(
      title: 'Add ${_ingredientName(context, ingredient)}',
      actionLabel: 'Add to list',
      initialQuantity: 1,
      initialUnit: ingredient.defaultUnit,
      ingredient: ingredient,
    );
    if (draft == null) return;
    await _runItemMutation(
      list,
      null,
      (revision) => ref
          .read(shoppingPlanningControllerProvider)
          .addItem(
            listId: list.id,
            expectedRevision: revision,
            ingredientId: ingredient.id,
            quantityNeeded: draft.quantity,
            unit: draft.unit,
          ),
    );
  }

  Future<void> _editNeededPersisted(
    ShoppingListRecord list,
    ShoppingListItemRecord item,
  ) async {
    final ingredient = await ref.read(
      shoppingIngredientProvider(item.ingredientId).future,
    );
    if (!mounted) return;
    final draft = await _quantityDraft(
      title: 'Edit needed quantity',
      actionLabel: 'Save needed quantity',
      initialQuantity: item.quantityNeeded,
      initialUnit: item.unit,
      ingredient: ingredient,
      lockUnit: true,
    );
    if (draft == null) return;
    await _runItemMutation(
      list,
      item.id,
      (revision) => ref
          .read(shoppingPlanningControllerProvider)
          .setItemNeededQuantity(
            listId: list.id,
            itemId: item.id,
            expectedRevision: revision,
            quantityNeeded: draft.quantity,
          ),
    );
  }

  Future<void> _editPurchasedPersisted(
    ShoppingListRecord list,
    ShoppingListItemRecord item,
  ) async {
    final ingredient = await ref.read(
      shoppingIngredientProvider(item.ingredientId).future,
    );
    if (!mounted) return;
    final draft = await _quantityDraft(
      title: 'Edit purchased quantity',
      actionLabel: 'Save purchased quantity',
      initialQuantity: item.purchasedQuantity ?? item.quantityNeeded,
      initialUnit: item.unit,
      ingredient: ingredient,
      lockUnit: true,
    );
    if (draft == null) return;
    await _runItemMutation(
      list,
      item.id,
      (revision) => ref
          .read(shoppingPlanningControllerProvider)
          .setItemPurchasedQuantity(
            listId: list.id,
            itemId: item.id,
            expectedRevision: revision,
            purchasedQuantity: draft.quantity,
          ),
    );
  }

  Future<void> _removePersisted(
    ShoppingListRecord list,
    ShoppingListItemRecord item,
  ) => _runItemMutation(
    list,
    item.id,
    (revision) => ref
        .read(shoppingPlanningControllerProvider)
        .removeItem(
          listId: list.id,
          itemId: item.id,
          expectedRevision: revision,
        ),
  );

  Future<void> _substitutePersisted(
    ShoppingListRecord list,
    ShoppingListItemRecord item,
  ) async {
    final ingredient = await _showIngredientPicker(context);
    if (ingredient == null || !mounted) return;
    final draft = await showModalBottomSheet<_SubstitutionDraft>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _SubstitutionSheet(item: item, ingredient: ingredient),
    );
    if (draft == null) return;
    await _runItemMutation(
      list,
      item.id,
      (revision) => ref
          .read(shoppingPlanningControllerProvider)
          .updateItemStatus(
            listId: list.id,
            itemId: item.id,
            expectedRevision: revision,
            status: ShoppingListItemStatus.substituted,
            substituteIngredientId: draft.ingredientId,
            substituteQuantity: draft.quantity,
            substituteUnit: draft.unit,
          ),
    );
  }

  Future<_QuantityDraft?> _quantityDraft({
    required String title,
    required String actionLabel,
    required double initialQuantity,
    required UnitId initialUnit,
    required Ingredient? ingredient,
    bool lockUnit = false,
  }) => showModalBottomSheet<_QuantityDraft>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _QuantitySheet(
      title: title,
      actionLabel: actionLabel,
      initialQuantity: initialQuantity,
      initialUnit: initialUnit,
      ingredient: ingredient,
      lockUnit: lockUnit,
    ),
  );

  Future<void> _runItemMutation(
    ShoppingListRecord list,
    String? itemId,
    Future<ShoppingCommandResult?> Function(int revision) mutation,
  ) async {
    if (_isMutating) return;
    // This extension is part of the owning State implementation.
    // ignore: invalid_use_of_protected_member
    setState(() {
      _isMutating = true;
      _busyItemId = itemId;
      _completionError = null;
    });
    try {
      ShoppingCommandResult? result;
      try {
        result = await mutation(list.revision);
      } on ShoppingCommandFailure catch (error) {
        if (error.kind != ShoppingCommandFailureKind.conflict) rethrow;
        ref.invalidate(activeShoppingListRecordProvider(list.id));
        final authoritative = await ref.read(
          activeShoppingListRecordProvider(list.id).future,
        );
        if (authoritative == null ||
            authoritative.status != ShoppingListStatus.pending) {
          rethrow;
        }
        result = await mutation(authoritative.revision);
      }
      final revision = result?.revision;
      if (revision != null) {
        await ref
            .read(shoppingRepositoryProvider)
            .watchList(householdId: list.householdId, listId: list.id)
            .firstWhere(
              (current) => current == null || current.revision >= revision,
            );
      }
    } on ShoppingCommandFailure catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.userMessage)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            const ShoppingCommandFailure(
              ShoppingCommandFailureKind.unknown,
            ).userMessage,
          ),
        ),
      );
    } finally {
      if (mounted) {
        // This extension is part of the owning State implementation.
        // ignore: invalid_use_of_protected_member
        setState(() {
          _isMutating = false;
          _busyItemId = null;
        });
      }
    }
  }
}

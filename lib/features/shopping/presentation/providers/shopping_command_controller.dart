part of 'shopping_repository_providers.dart';

class ShoppingCommandController {
  ShoppingCommandController({
    required this.repository,
    required this.householdId,
    required this.household,
    required this.idGenerator,
    this.onShoppingCompleted,
  });

  final ShoppingCommandRepository repository;
  final String householdId;
  final ActiveHouseholdContext? household;
  final IdGenerator idGenerator;
  final Future<void> Function()? onShoppingCompleted;
  final Map<(ShoppingCommandStatus, String), String> _commandIds = {};
  final Set<(ShoppingCommandStatus, String)> _inFlight = {};
  static const _policy = HouseholdPolicy();

  bool isCompletionInFlight(String listId) =>
      _inFlight.contains((ShoppingCommandStatus.completed, listId));

  String? completionCommandIdFor(String listId) =>
      _commandIds[(ShoppingCommandStatus.completed, listId)];

  Future<ShoppingCommandResult?> completeList(String listId) => _run(
    status: ShoppingCommandStatus.completed,
    listId: listId,
    capability: HouseholdCapability.completeShopping,
    invoke: repository.completeList,
  );

  Future<ShoppingCommandResult?> cancelList(String listId) {
    final repository = this.repository;
    final Future<ShoppingCommandResult> Function(ShoppingCommandRequest) invoke;
    if (repository is ShoppingCancellationCommandRepository) {
      final cancellation = repository as ShoppingCancellationCommandRepository;
      invoke = cancellation.cancelList;
    } else {
      invoke = repository.deleteList;
    }
    return _run(
      status: ShoppingCommandStatus.cancelled,
      listId: listId,
      capability: HouseholdCapability.deleteShoppingLists,
      invoke: invoke,
    );
  }

  Future<ShoppingCommandResult?> deleteList(String listId) => _run(
    status: ShoppingCommandStatus.deleted,
    listId: listId,
    capability: HouseholdCapability.deleteShoppingLists,
    invoke: repository.deleteList,
  );

  Future<ShoppingCommandResult?> _run({
    required ShoppingCommandStatus status,
    required String listId,
    required HouseholdCapability capability,
    required Future<ShoppingCommandResult> Function(ShoppingCommandRequest)
    invoke,
  }) async {
    _require(capability);
    final key = (status, listId);
    if (!_inFlight.add(key)) return null;
    final commandId = _commandIds[key] ??= idGenerator.newId();
    try {
      final result = await invoke(
        ShoppingCommandRequest(
          householdId: householdId,
          listId: listId,
          commandId: commandId,
        ),
      );
      if (status == ShoppingCommandStatus.completed) {
        try {
          await onShoppingCompleted?.call();
        } on Object {
          // A completed checkout stays successful if recovery sync fails.
        }
      }
      return result;
    } finally {
      _inFlight.remove(key);
    }
  }

  void _require(HouseholdCapability capability) {
    final household = this.household;
    if (household == null) return;
    if (!_policy.roleCan(
      household.role,
      capability,
      isSoloHousehold: household.isSolo,
    )) {
      throw StateError('${household.role.label} cannot ${capability.name}.');
    }
  }
}

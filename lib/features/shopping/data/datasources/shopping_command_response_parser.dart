import 'package:kitchensync/features/shopping/domain/entities/shopping_command.dart';

ShoppingCommandResult parseShoppingWriteResponse(
  Object? data, {
  String? expectedListId,
}) {
  final map = _responseMap(data);
  if (!_hasExactKeys(map, const {
    'listId',
    'status',
    'revision',
    'alreadyApplied',
  })) {
    throw const FormatException('Unexpected shopping write response fields.');
  }
  final listId = map['listId'];
  final revision = map['revision'];
  final alreadyApplied = map['alreadyApplied'];
  final status = switch (map['status']) {
    'pending' => ShoppingCommandStatus.pending,
    'cancelled' => ShoppingCommandStatus.cancelled,
    final value => throw FormatException(
      'Unknown shopping write response status: $value',
    ),
  };
  if (listId is! String ||
      listId.isEmpty ||
      expectedListId != null && listId != expectedListId ||
      revision is! int ||
      revision < 0 ||
      alreadyApplied is! bool) {
    throw const FormatException('Invalid shopping write response fields.');
  }
  return ShoppingCommandResult(
    listId: listId,
    status: status,
    revision: revision,
    alreadyApplied: alreadyApplied,
  );
}

ShoppingCommandResult parseLegacyShoppingCommandResponse(
  Object? data, {
  required String expectedListId,
  required ShoppingCommandStatus expectedStatus,
}) {
  final map = _responseMap(data);
  final expectedKeys = expectedStatus == ShoppingCommandStatus.completed
      ? const {'listId', 'status', 'alreadyApplied', 'completionId'}
      : const {'listId', 'status', 'alreadyApplied'};
  if (!_hasExactKeys(map, expectedKeys) &&
      !(expectedStatus == ShoppingCommandStatus.completed &&
          _hasExactKeys(map, const {'listId', 'status', 'alreadyApplied'}))) {
    throw const FormatException('Unexpected shopping command response fields.');
  }
  final listId = map['listId'];
  final alreadyApplied = map['alreadyApplied'];
  final hasCompletionId = map.containsKey('completionId');
  final completionId = map['completionId'];
  final status = switch (map['status']) {
    'completed' => ShoppingCommandStatus.completed,
    'cancelled' => ShoppingCommandStatus.cancelled,
    'deleted' => ShoppingCommandStatus.deleted,
    final value => throw FormatException(
      'Unknown shopping command status: $value',
    ),
  };
  if (listId is! String ||
      listId != expectedListId ||
      status != expectedStatus ||
      alreadyApplied is! bool ||
      hasCompletionId && completionId is! String) {
    throw const FormatException('Invalid shopping command response fields.');
  }
  return ShoppingCommandResult(
    listId: listId,
    status: status,
    alreadyApplied: alreadyApplied,
    completionId: completionId as String?,
  );
}

Map<Object?, Object?> _responseMap(Object? data) {
  if (data is! Map<Object?, Object?>) {
    throw const FormatException('Shopping command response must be a map.');
  }
  return data;
}

bool _hasExactKeys(Map<Object?, Object?> map, Set<String> expected) =>
    map.length == expected.length && map.keys.toSet().containsAll(expected);

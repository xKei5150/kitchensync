part of 'shopping_command.dart';

enum ShoppingCommandFailureKind {
  unauthenticated,
  permissionDenied,
  notFound,
  conflict,
  resourceExhausted,
  unavailable,
  invalidRequest,
  invalidResponse,
  unknown,
}

class ShoppingCommandFailure implements Exception {
  const ShoppingCommandFailure(this.kind, {this.code});
  final ShoppingCommandFailureKind kind;
  final String? code;

  String get userMessage => switch (kind) {
    ShoppingCommandFailureKind.unauthenticated =>
      'Sign in again before updating this shopping list.',
    ShoppingCommandFailureKind.permissionDenied =>
      'You do not have permission to update this shopping list.',
    ShoppingCommandFailureKind.notFound =>
      'This shopping list no longer exists.',
    ShoppingCommandFailureKind.conflict =>
      'This shopping list changed. Refresh it and try again.',
    ShoppingCommandFailureKind.resourceExhausted =>
      'This shopping list is too large to finish at once.',
    ShoppingCommandFailureKind.unavailable =>
      'The shopping service is temporarily unavailable. Try again.',
    ShoppingCommandFailureKind.invalidRequest =>
      'The shopping request was invalid. Refresh the list and try again.',
    ShoppingCommandFailureKind.invalidResponse =>
      'The shopping service returned an unexpected response. Try again.',
    ShoppingCommandFailureKind.unknown =>
      'Could not update the shopping list. Try again.',
  };

  @override
  String toString() => userMessage;
}

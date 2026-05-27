import 'package:freezed_annotation/freezed_annotation.dart';

part 'failure.freezed.dart';

@freezed
sealed class Failure with _$Failure {
  const factory Failure.validation({
    required String field,
    required String message,
  }) = ValidationFailure;

  const factory Failure.notFound({required String entity, required String id}) =
      NotFoundFailure;

  const factory Failure.conflict({required String reason}) = ConflictFailure;

  const factory Failure.network() = NetworkFailure;

  const factory Failure.permission() = PermissionFailure;

  const factory Failure.unknown({required String cause}) = UnknownFailure;
}

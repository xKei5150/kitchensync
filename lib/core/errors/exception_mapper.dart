import 'package:firebase_core/firebase_core.dart';
import 'package:kitchensync/core/errors/failure.dart';

class ExceptionMapper {
  const ExceptionMapper._();

  static Failure toFailure(Object error) {
    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return const Failure.permission();
        case 'unavailable':
        case 'deadline-exceeded':
          return const Failure.network();
        case 'not-found':
          return const Failure.notFound(entity: 'document', id: 'unknown');
        case 'already-exists':
          return Failure.conflict(reason: error.message ?? 'already exists');
      }
      return Failure.unknown(cause: '${error.code}: ${error.message ?? ''}');
    }
    return Failure.unknown(cause: error.toString());
  }
}

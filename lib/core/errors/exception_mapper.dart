import 'package:firebase_core/firebase_core.dart';
import 'package:kitchensync/core/errors/failure.dart';
import 'package:kitchensync/core/errors/firebase_reachability.dart';

class ExceptionMapper {
  const ExceptionMapper._();

  static Failure toFailure(Object error) {
    if (error is FirebaseException) {
      // Checked before the switch because iOS reports an unreachable backend
      // as `unknown`, which would otherwise fall through to Failure.unknown.
      if (isFirebaseBackendUnreachable(
        code: error.code,
        message: error.message,
      )) {
        return const Failure.network();
      }
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

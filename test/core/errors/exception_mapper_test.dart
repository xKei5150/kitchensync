import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/core/errors/exception_mapper.dart';
import 'package:kitchensync/core/errors/failure.dart';

void main() {
  group('ExceptionMapper.toFailure', () {
    test('permission-denied → PermissionFailure', () {
      final ex = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
        message: 'nope',
      );
      expect(ExceptionMapper.toFailure(ex), isA<PermissionFailure>());
    });

    test('unavailable → NetworkFailure', () {
      final ex = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
        message: 'offline',
      );
      expect(ExceptionMapper.toFailure(ex), isA<NetworkFailure>());
    });

    test('not-found → NotFoundFailure with entity=document', () {
      final ex = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'not-found',
        message: 'missing',
      );
      final f = ExceptionMapper.toFailure(ex);
      expect(f, isA<NotFoundFailure>());
      expect((f as NotFoundFailure).entity, 'document');
    });

    test('unknown code → UnknownFailure carrying cause', () {
      final ex = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'something-else',
        message: 'huh',
      );
      final f = ExceptionMapper.toFailure(ex);
      expect(f, isA<UnknownFailure>());
      expect((f as UnknownFailure).cause, contains('something-else'));
    });

    test('non-Firebase exception → UnknownFailure', () {
      final f = ExceptionMapper.toFailure(StateError('boom'));
      expect(f, isA<UnknownFailure>());
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/core/errors/failure.dart';
import 'package:kitchensync/core/utils/result.dart';

void main() {
  group('Result', () {
    test('Success exposes value via pattern matching', () {
      const Result<int> r = Result.success(42);
      final mapped = switch (r) {
        Success(:final value) => value,
        ResultFailure() => -1,
      };
      expect(mapped, 42);
    });

    test('Failure exposes failure via pattern matching', () {
      const failure = Failure.unknown(cause: 'boom');
      const Result<int> r = Result.failure(failure);
      final mapped = switch (r) {
        Success() => null,
        ResultFailure(:final failure) => failure,
      };
      expect(mapped, failure);
    });
  });
}

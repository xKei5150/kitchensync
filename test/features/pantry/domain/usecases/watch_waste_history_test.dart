import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/features/pantry/domain/entities/waste_event.dart';
import 'package:kitchensync/features/pantry/domain/repositories/waste_repository.dart';
import 'package:kitchensync/features/pantry/domain/usecases/watch_waste_history.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements WasteRepository {}

void main() {
  test('delegates to repo.watchByHousehold', () {
    final repo = _MockRepo();
    final stub = Stream.value(<WasteEvent>[]);
    when(() => repo.watchByHousehold('h1')).thenAnswer((_) => stub);

    final stream = WatchWasteHistory(repo).watch('h1');
    expect(stream, isA<Stream<List<WasteEvent>>>());
    verify(() => repo.watchByHousehold('h1')).called(1);
  });
}

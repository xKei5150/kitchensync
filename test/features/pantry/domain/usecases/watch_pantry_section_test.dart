import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/features/pantry/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/entities/pantry_item.dart';
import 'package:kitchensync/features/pantry/domain/repositories/pantry_repository.dart';
import 'package:kitchensync/features/pantry/domain/usecases/watch_pantry_section.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements PantryRepository {}

void main() {
  test('delegates to repo.watchBySection', () {
    final repo = _MockRepo();
    final stub = Stream.value(<PantryItem>[]);
    when(
      () => repo.watchBySection('h1', PantrySection.food),
    ).thenAnswer((_) => stub);
    final stream = WatchPantrySection(repo).watch('h1', PantrySection.food);
    expect(stream, isA<Stream<List<PantryItem>>>());
    verify(() => repo.watchBySection('h1', PantrySection.food)).called(1);
  });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/core/errors/failure.dart';
import 'package:kitchensync/core/utils/result.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/entities/enums.dart';
import 'package:kitchensync/features/pantry/domain/entities/pantry_item.dart';
import 'package:kitchensync/features/pantry/domain/repositories/pantry_repository.dart';
import 'package:kitchensync/features/pantry/domain/usecases/add_pantry_item_photo.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements PantryRepository {}

class _FakePantryItem extends Fake implements PantryItem {}

class _FakeFile extends Fake implements File {}

PantryItem _item() => PantryItem(
  id: 'p1',
  householdId: 'h1',
  ingredientId: 'onion',
  quantity: 2,
  unit: UnitId.piece,
  section: PantrySection.food,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

void main() {
  setUpAll(() {
    registerFallbackValue(_FakePantryItem());
    registerFallbackValue(_FakeFile());
  });

  late _MockRepo repo;
  late Directory tempDir;

  setUp(() async {
    repo = _MockRepo();
    tempDir = await Directory.systemTemp.createTemp('pantry_photo_test_');
    when(() => repo.update(any())).thenAnswer((_) async {});
    when(
      () => repo.uploadPhoto(any(), any(), any()),
    ).thenAnswer((_) async => 'https://example.com/photo.jpg');
    when(
      () => repo.watchById('h1', 'p1'),
    ).thenAnswer((_) => Stream.value(_item()));
  });

  tearDown(() => tempDir.deleteSync(recursive: true));

  AddPantryItemPhoto makeUc() => AddPantryItemPhoto(repo);

  test('missing file returns ValidationFailure', () async {
    final missingFile = File('${tempDir.path}/does_not_exist.jpg');
    final result = await makeUc().call(
      AddPantryItemPhotoParams(
        householdId: 'h1',
        itemId: 'p1',
        file: missingFile,
      ),
    );
    expect(result, isA<ResultFailure<PantryItem>>());
    final f = (result as ResultFailure<PantryItem>).failure;
    expect(f, isA<ValidationFailure>());
    expect((f as ValidationFailure).field, 'file');
  });

  test('oversized file (> 5 MB) returns ValidationFailure', () async {
    final bigFile = File('${tempDir.path}/big.jpg');
    // Write 6 MB
    final bytes = List<int>.filled(6 * 1024 * 1024, 0);
    await bigFile.writeAsBytes(bytes);

    final result = await makeUc().call(
      AddPantryItemPhotoParams(householdId: 'h1', itemId: 'p1', file: bigFile),
    );
    expect(result, isA<ResultFailure<PantryItem>>());
    final f = (result as ResultFailure<PantryItem>).failure;
    expect(f, isA<ValidationFailure>());
    expect((f as ValidationFailure).field, 'file');
  });

  test('valid file calls repo.update and returns updated item', () async {
    final validFile = File('${tempDir.path}/photo.jpg');
    await validFile.writeAsBytes([1, 2, 3]);

    final result = await makeUc().call(
      AddPantryItemPhotoParams(
        householdId: 'h1',
        itemId: 'p1',
        file: validFile,
      ),
    );
    expect(result, isA<Success<PantryItem>>());
    final item = (result as Success<PantryItem>).value;
    expect(item.imageUrl, 'https://example.com/photo.jpg');
    verify(() => repo.update(any())).called(1);
  });
}

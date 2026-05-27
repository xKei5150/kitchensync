import 'dart:io';

import 'package:kitchensync/core/errors/exception_mapper.dart';
import 'package:kitchensync/core/errors/failure.dart';
import 'package:kitchensync/core/usecases/usecase.dart';
import 'package:kitchensync/core/utils/result.dart';
import 'package:kitchensync/features/pantry/domain/entities/pantry_item.dart';
import 'package:kitchensync/features/pantry/domain/repositories/pantry_repository.dart';

const int _maxFileSizeBytes = 5 * 1024 * 1024;

class AddPantryItemPhotoParams {
  const AddPantryItemPhotoParams({
    required this.householdId,
    required this.itemId,
    required this.file,
  });

  final String householdId;
  final String itemId;
  final File file;
}

class AddPantryItemPhoto extends UseCase<PantryItem, AddPantryItemPhotoParams> {
  AddPantryItemPhoto(this._repo);

  final PantryRepository _repo;

  @override
  Future<Result<PantryItem>> call(AddPantryItemPhotoParams params) async {
    if (!params.file.existsSync()) {
      return const Result.failure(
        Failure.validation(field: 'file', message: 'File does not exist.'),
      );
    }

    final size = params.file.lengthSync();
    if (size > _maxFileSizeBytes) {
      return const Result.failure(
        Failure.validation(field: 'file', message: 'File exceeds 5 MB.'),
      );
    }

    try {
      final url = await _repo.uploadPhoto(
        params.householdId,
        params.itemId,
        params.file,
      );
      final current = await _repo
          .watchById(params.householdId, params.itemId)
          .first;
      if (current == null) {
        return Result.failure(
          Failure.notFound(entity: 'pantryItem', id: params.itemId),
        );
      }
      final updated = current.copyWith(
        imageUrl: url,
        updatedAt: DateTime.now(),
      );
      await _repo.update(updated);
      return Result.success(updated);
    } catch (e) {
      return Result.failure(ExceptionMapper.toFailure(e));
    }
  }
}

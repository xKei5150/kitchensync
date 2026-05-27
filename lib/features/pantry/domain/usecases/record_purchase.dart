import 'package:kitchensync/core/errors/exception_mapper.dart';
import 'package:kitchensync/core/usecases/usecase.dart';
import 'package:kitchensync/core/utils/result.dart';
import 'package:kitchensync/features/pantry/domain/entities/purchase_record.dart';
import 'package:kitchensync/features/pantry/domain/repositories/purchase_history_repository.dart';

class RecordPurchase extends UseCase<void, PurchaseRecord> {
  RecordPurchase(this._repo);

  final PurchaseHistoryRepository _repo;

  @override
  Future<Result<void>> call(PurchaseRecord record) async {
    try {
      await _repo.record(record);
      return const Result.success(null);
    } catch (e) {
      return Result.failure(ExceptionMapper.toFailure(e));
    }
  }
}

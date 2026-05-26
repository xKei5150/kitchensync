import 'package:kitchensync/core/utils/result.dart';

abstract class UseCase<R, P> {
  const UseCase();
  Future<Result<R>> call(P params);
}

class NoParams {
  const NoParams();
}

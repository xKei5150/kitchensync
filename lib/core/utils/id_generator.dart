import 'package:uuid/uuid.dart';

abstract class IdGenerator {
  String newId();
}

class UuidV4IdGenerator implements IdGenerator {
  const UuidV4IdGenerator();
  static const _uuid = Uuid();

  @override
  String newId() => _uuid.v4();
}

class FakeIdGenerator implements IdGenerator {
  FakeIdGenerator(List<String> ids) : _ids = List.of(ids);
  final List<String> _ids;
  int _i = 0;

  @override
  String newId() {
    if (_i >= _ids.length) {
      throw StateError('FakeIdGenerator exhausted after $_i calls');
    }
    return _ids[_i++];
  }
}

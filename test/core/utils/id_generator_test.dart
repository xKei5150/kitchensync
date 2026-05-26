import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/core/utils/id_generator.dart';

void main() {
  test('UuidV4IdGenerator returns 36-char UUID v4 string', () {
    const gen = UuidV4IdGenerator();
    final id = gen.newId();
    expect(id.length, 36);
    // UUID v4 has '4' at index 14 (after 8-4- prefix).
    expect(id[14], '4');
  });

  test('Two calls return distinct ids', () {
    const gen = UuidV4IdGenerator();
    expect(gen.newId(), isNot(gen.newId()));
  });

  test('FakeIdGenerator returns sequenced ids', () {
    final gen = FakeIdGenerator(['a', 'b', 'c']);
    expect(gen.newId(), 'a');
    expect(gen.newId(), 'b');
    expect(gen.newId(), 'c');
    expect(gen.newId, throwsStateError);
  });
}

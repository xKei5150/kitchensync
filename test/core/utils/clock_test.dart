import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/core/utils/clock.dart';

void main() {
  test('SystemClock.now is within one second of DateTime.now', () {
    const clock = SystemClock();
    final before = DateTime.now();
    final clocked = clock.now();
    final after = DateTime.now();
    expect(
      clocked.isAfter(before.subtract(const Duration(seconds: 1))),
      isTrue,
    );
    expect(clocked.isBefore(after.add(const Duration(seconds: 1))), isTrue);
  });

  test('FakeClock returns the value set at construction', () {
    final fixed = DateTime.utc(2026);
    final clock = FakeClock(fixed);
    expect(clock.now(), fixed);
  });
}

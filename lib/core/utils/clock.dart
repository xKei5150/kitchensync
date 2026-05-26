abstract class Clock {
  DateTime now();
}

class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now();
}

class FakeClock implements Clock {
  FakeClock(this._fixed);
  final DateTime _fixed;

  @override
  DateTime now() => _fixed;
}

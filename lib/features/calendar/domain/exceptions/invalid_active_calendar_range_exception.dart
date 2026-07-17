class InvalidActiveCalendarRangeException extends FormatException {
  const InvalidActiveCalendarRangeException({
    required this.start,
    required this.end,
  }) : super('Active calendar range end must be on or after start.');

  final DateTime start;
  final DateTime end;
}

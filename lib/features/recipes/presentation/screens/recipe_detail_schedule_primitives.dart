part of 'recipe_detail_screen.dart';

class _ScheduleDateOption {
  const _ScheduleDateOption(this.label, this.date);

  final String label;
  final DateTime date;
}

bool _sameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

String _datePath(DateTime date) {
  return '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

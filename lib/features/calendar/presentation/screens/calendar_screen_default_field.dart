part of 'calendar_screen.dart';

class _CalendarDefaultsTextField extends StatelessWidget {
  const _CalendarDefaultsTextField({
    required this.controller,
    required this.label,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: ks.surfaceBase,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(KsTokens.radius12),
        ),
      ),
    );
  }
}

DateTime _dateKey(DateTime date) {
  return DateTime(date.year, date.month, date.day);
}

DateTime _clampToMonth(DateTime date, DateTime month) {
  final lastDay = DateTime(month.year, month.month + 1, 0).day;
  return DateTime(month.year, month.month, date.day.clamp(1, lastDay));
}

String _monthTitle(DateTime month) {
  return '${_months[month.month - 1]} ${month.year}';
}

String _weekday(DateTime date) {
  return _weekdays[date.weekday - 1];
}

String _datePath(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

const _months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

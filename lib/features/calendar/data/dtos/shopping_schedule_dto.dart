import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kitchensync/features/calendar/domain/entities/shopping_schedule.dart';

class ShoppingScheduleMapper {
  const ShoppingScheduleMapper._();

  static Map<String, dynamic> toMap(ShoppingSchedule schedule) => {
    'householdId': schedule.householdId,
    'cadence': schedule.cadence.name,
    'isoWeekday': schedule.isoWeekday,
    'effectiveFrom': _dateKey(schedule.effectiveFrom),
    'isActive': schedule.isActive,
    'createdAt': Timestamp.fromDate(schedule.createdAt),
    'updatedAt': Timestamp.fromDate(schedule.updatedAt),
    'updatedByUserId': schedule.updatedByUserId,
  };

  static ShoppingSchedule fromMap(
    Map<String, dynamic> map, {
    required String expectedHouseholdId,
  }) {
    final cadence = map['cadence'];
    if (cadence != ShoppingScheduleCadence.weekly.name) {
      throw const FormatException('Shopping schedule cadence must be weekly.');
    }
    final householdId = _string(map, 'householdId');
    if (householdId != expectedHouseholdId) {
      throw const FormatException(
        'Shopping schedule householdId does not match its document scope.',
      );
    }
    return ShoppingSchedule(
      householdId: householdId,
      cadence: ShoppingScheduleCadence.weekly,
      isoWeekday: _int(map, 'isoWeekday'),
      effectiveFrom: _dateFromKey(_string(map, 'effectiveFrom')),
      isActive: _bool(map, 'isActive'),
      createdAt: _timestamp(map, 'createdAt'),
      updatedAt: _timestamp(map, 'updatedAt'),
      updatedByUserId: _string(map, 'updatedByUserId'),
    );
  }
}

String _string(Map<String, dynamic> map, String field) {
  final value = map[field];
  if (value is String && value.isNotEmpty) return value;
  throw FormatException('Shopping schedule $field must be a non-empty string.');
}

int _int(Map<String, dynamic> map, String field) {
  final value = map[field];
  if (value is int) return value;
  throw FormatException('Shopping schedule $field must be an integer.');
}

bool _bool(Map<String, dynamic> map, String field) {
  final value = map[field];
  if (value is bool) return value;
  throw FormatException('Shopping schedule $field must be a boolean.');
}

DateTime _timestamp(Map<String, dynamic> map, String field) {
  final value = map[field];
  if (value is Timestamp) return value.toDate();
  throw FormatException('Shopping schedule $field must be a timestamp.');
}

String _dateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

DateTime _dateFromKey(String key) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(key);
  if (match == null) {
    throw const FormatException(
      'Shopping schedule effectiveFrom must be YYYY-MM-DD.',
    );
  }
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final date = DateTime(year, month, day);
  if (date.year != year || date.month != month || date.day != day) {
    throw const FormatException(
      'Shopping schedule effectiveFrom is not a valid date.',
    );
  }
  return date;
}

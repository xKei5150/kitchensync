enum ShoppingScheduleCadence { weekly }

class ShoppingSchedule {
  ShoppingSchedule({
    required this.householdId,
    required this.cadence,
    required this.isoWeekday,
    required DateTime effectiveFrom,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    required this.updatedByUserId,
  }) : effectiveFrom = _dateOnly(effectiveFrom) {
    if (householdId.isEmpty) {
      throw ArgumentError.value(
        householdId,
        'householdId',
        'Household id is required.',
      );
    }
    if (isoWeekday < DateTime.monday || isoWeekday > DateTime.sunday) {
      throw ArgumentError.value(
        isoWeekday,
        'isoWeekday',
        'ISO weekday must be between 1 and 7.',
      );
    }
    if (updatedByUserId.isEmpty) {
      throw ArgumentError.value(
        updatedByUserId,
        'updatedByUserId',
        'Updated-by user id is required.',
      );
    }
  }

  final String householdId;
  final ShoppingScheduleCadence cadence;
  final int isoWeekday;
  final DateTime effectiveFrom;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String updatedByUserId;
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

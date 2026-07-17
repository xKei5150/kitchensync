part of 'shopping_schedule_screen.dart';

extension _ShoppingSchedulePersistence on _ShoppingScheduleScreenState {
  Future<void> _save(
    ShoppingSchedule? existing,
    AsyncValue<List<CalendarDaySettings>> settingsValue,
  ) => _persist(
    existing: existing,
    settingsValue: settingsValue,
    reconcile: true,
  );

  Future<bool> _persist({
    required ShoppingSchedule? existing,
    required AsyncValue<List<CalendarDaySettings>> settingsValue,
    required bool reconcile,
  }) async {
    if (_saving) return false;
    final effectiveFrom = _effectiveFrom;
    if (effectiveFrom == null || !_isValidCalendarDate(effectiveFrom)) {
      _updateState(() => _error = 'Choose a valid effective date.');
      return false;
    }
    var ranges = const <ScheduledShoppingRange>[];
    if (_isActive && reconcile) {
      final settings = settingsValue.valueOrNull;
      if (settings == null) {
        _updateState(() => _error = 'Could not load planned meal ranges.');
        return false;
      }
      try {
        ranges = mergeActiveCalendarRanges(settings);
      } on InvalidActiveCalendarRangeException {
        _updateState(() {
          _reconciliationRetryRanges = null;
          _error =
              'Fix planned meal ranges before saving. '
              'Make sure each end date is on or after its start date.';
          _success = null;
        });
        return false;
      }
    }
    _updateState(() {
      _saving = true;
      _reconciliationRetryRanges = null;
      _error = null;
      _success = null;
    });
    try {
      final ShoppingSchedule savedSchedule;
      try {
        savedSchedule = await ref
            .read(shoppingScheduleControllerProvider)
            .save(
              existing: existing,
              isoWeekday: _weekday,
              effectiveFrom: _dateOnly(effectiveFrom),
              isActive: _isActive,
            );
      } on Object {
        if (mounted) {
          _updateState(() => _error = 'Could not save shopping schedule.');
        }
        return false;
      }
      if (!mounted) return true;

      _updateState(() {
        _optimisticSchedule = savedSchedule;
        _dirty = false;
      });
      ref.invalidate(activeShoppingScheduleProvider);

      if (!reconcile || !savedSchedule.isActive || ranges.isEmpty) {
        _updateState(() {
          _success = !savedSchedule.isActive
              ? existing?.isActive ?? false
                    ? 'Shopping schedule deactivated'
                    : 'Shopping schedule saved'
              : ranges.isEmpty
              ? 'Lists will appear as meals are planned'
              : 'Shopping schedule saved';
        });
        return true;
      }

      try {
        await _reconcileRanges(ranges);
        if (mounted) {
          _updateState(() => _success = 'Shopping schedule saved');
        }
      } on Object {
        if (mounted) {
          _updateState(() {
            _reconciliationRetryRanges = ranges;
            _error = 'Schedule saved, but shopping lists could not refresh.';
          });
        }
      }
      return true;
    } finally {
      if (mounted) _updateState(() => _saving = false);
    }
  }

  Future<void> _retryReconciliation() async {
    final ranges = _reconciliationRetryRanges;
    if (_saving || ranges == null) return;
    _updateState(() {
      _saving = true;
      _error = null;
      _success = null;
    });
    try {
      await _reconcileRanges(ranges);
      if (!mounted) return;
      _updateState(() {
        _reconciliationRetryRanges = null;
        _success = 'Shopping lists refreshed';
      });
    } on Object {
      if (mounted) {
        _updateState(() {
          _error = 'Schedule saved, but shopping lists could not refresh.';
        });
      }
    } finally {
      if (mounted) _updateState(() => _saving = false);
    }
  }

  Future<void> _reconcileRanges(List<ScheduledShoppingRange> ranges) async {
    final planning = ref.read(shoppingPlanningControllerProvider);
    for (final range in ranges) {
      await planning.reconcileScheduledLists([range]);
    }
  }
}

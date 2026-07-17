import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:kitchensync/app/design_tokens.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/core/widgets/widgets.dart';
import 'package:kitchensync/features/calendar/domain/entities/meal_schedule.dart';
import 'package:kitchensync/features/calendar/domain/entities/shopping_schedule.dart';
import 'package:kitchensync/features/calendar/domain/exceptions/invalid_active_calendar_range_exception.dart';
import 'package:kitchensync/features/calendar/presentation/helpers/active_scheduled_shopping_ranges.dart';
import 'package:kitchensync/features/calendar/presentation/providers/calendar_repository_providers.dart';
import 'package:kitchensync/features/calendar/presentation/providers/shopping_schedule_providers.dart';
import 'package:kitchensync/features/household/domain/entities/household_policy_models.dart';
import 'package:kitchensync/features/household/domain/services/household_policy.dart';
import 'package:kitchensync/features/ingredient_dictionary/presentation/providers/ingredient_providers.dart';
import 'package:kitchensync/features/shopping/domain/services/scheduled_shopping_list_planner.dart';
import 'package:kitchensync/features/shopping/presentation/providers/shopping_repository_providers.dart';

part 'shopping_schedule_screen_sections.dart';
part 'shopping_schedule_screen_summary.dart';
part 'shopping_schedule_screen_persistence.dart';

class ShoppingScheduleScreen extends ConsumerStatefulWidget {
  const ShoppingScheduleScreen({this.initialEffectiveFrom, super.key});

  @visibleForTesting
  final DateTime? initialEffectiveFrom;

  @override
  ConsumerState<ShoppingScheduleScreen> createState() =>
      _ShoppingScheduleScreenState();
}

class _ShoppingScheduleScreenState
    extends ConsumerState<ShoppingScheduleScreen> {
  static const _policy = HouseholdPolicy();
  int _weekday = DateTime.saturday;
  DateTime? _effectiveFrom;
  bool _isActive = true;
  bool _hasForm = false;
  bool _dirty = false;
  bool _saving = false;
  bool _confirmingDeactivate = false;
  ShoppingSchedule? _optimisticSchedule;
  List<ScheduledShoppingRange>? _reconciliationRetryRanges;
  String? _error;
  String? _success;

  @override
  void initState() {
    super.initState();
    ref.listenManual<AsyncValue<ShoppingSchedule?>>(
      activeShoppingScheduleProvider,
      (previous, next) {
        final schedule = next.valueOrNull;
        if (!mounted || _dirty || next.isLoading) return;
        if (schedule == null && _optimisticSchedule != null) return;
        setState(() {
          _optimisticSchedule = null;
          _applySchedule(schedule);
        });
      },
      fireImmediately: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final household = ref.watch(activeHouseholdContextProvider);
    final scheduleValue = ref.watch(activeShoppingScheduleProvider);
    final settingsValue = ref.watch(activeCalendarDaySettingsProvider);
    final settingsErrorMessage = switch (settingsValue.error) {
      InvalidActiveCalendarRangeException() =>
        'Fix planned meal ranges before saving. '
            'Make sure each end date is on or after its start date.',
      null => null,
      _ => 'Could not load planned meal ranges.',
    };
    final canEdit =
        household != null &&
        _policy.roleCan(
          household.role,
          HouseholdCapability.manageShoppingSchedules,
          isSoloHousehold: household.isSolo,
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Shopping schedule')),
      body: scheduleValue.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _ProviderError(
          message: 'Could not load shopping schedule.',
          onRetry: () => ref.invalidate(activeShoppingScheduleProvider),
        ),
        data: (schedule) {
          final currentSchedule = _optimisticSchedule ?? schedule;
          return _hasForm
              ? ShoppingScheduleBody(
                  schedule: currentSchedule,
                  weekday: _weekday,
                  effectiveFrom: _effectiveFrom!,
                  isActive: _isActive,
                  canEdit: canEdit,
                  saving: _saving,
                  error: _error,
                  success: _success,
                  settingsErrorMessage: settingsErrorMessage,
                  onWeekdayChanged: _changeWeekday,
                  onPickDate: _pickEffectiveDate,
                  onActiveChanged: (value) =>
                      unawaited(_changeActive(value, currentSchedule)),
                  onRetrySettings: () =>
                      ref.invalidate(activeCalendarDaySettingsProvider),
                  onRetryReconciliation: _reconciliationRetryRanges == null
                      ? null
                      : () => unawaited(_retryReconciliation()),
                  onSave: () => _save(currentSchedule, settingsValue),
                  onDeactivate: currentSchedule?.isActive ?? false
                      ? () => _confirmDeactivate(currentSchedule!)
                      : null,
                )
              : const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }

  void _applySchedule(ShoppingSchedule? schedule) {
    _weekday = schedule?.isoWeekday ?? DateTime.saturday;
    _effectiveFrom =
        schedule?.effectiveFrom ?? widget.initialEffectiveFrom ?? _today();
    _isActive = schedule?.isActive ?? true;
    _hasForm = true;
  }

  void _changeWeekday(int value) => setState(() {
    _weekday = value;
    _dirty = true;
  });

  Future<void> _changeActive(bool value, ShoppingSchedule? schedule) async {
    if (!value && (schedule?.isActive ?? false)) {
      await _confirmDeactivate(schedule!);
      return;
    }
    if (!mounted) return;
    setState(() {
      _isActive = value;
      _dirty = true;
    });
  }

  Future<void> _pickEffectiveDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _effectiveFrom ?? _today(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100, 12, 31),
    );
    if (selected != null && mounted) {
      setState(() {
        _effectiveFrom = _dateOnly(selected);
        _dirty = true;
      });
    }
  }

  Future<void> _confirmDeactivate(ShoppingSchedule schedule) async {
    if (_saving || _confirmingDeactivate) return;
    _confirmingDeactivate = true;
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => const DeactivateShoppingScheduleDialog(),
      );
      if (confirmed != true || !mounted) return;
      final wasActive = _isActive;
      setState(() {
        _isActive = false;
        _dirty = true;
      });
      final saved = await _persist(
        existing: schedule,
        settingsValue: ref.read(activeCalendarDaySettingsProvider),
        reconcile: false,
      );
      if (mounted && !saved) {
        setState(() => _isActive = wasActive);
      }
    } finally {
      _confirmingDeactivate = false;
    }
  }

  void _updateState(VoidCallback update) => setState(update);

  DateTime _today() => _dateOnly(ref.read(clockProvider).now());
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

bool _isValidCalendarDate(DateTime value) =>
    value.year >= 2000 && value.year <= 2100;

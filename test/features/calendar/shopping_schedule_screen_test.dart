import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/app/theme.dart';
import 'package:kitchensync/core/firebase/firestore_refs.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/core/utils/clock.dart';
import 'package:kitchensync/core/utils/id_generator.dart';
import 'package:kitchensync/core/widgets/widgets.dart';
import 'package:kitchensync/features/calendar/data/datasources/calendar_remote_data_source.dart';
import 'package:kitchensync/features/calendar/data/repositories/calendar_repository_impl.dart';
import 'package:kitchensync/features/calendar/domain/entities/meal_schedule.dart';
import 'package:kitchensync/features/calendar/domain/entities/shopping_schedule.dart';
import 'package:kitchensync/features/calendar/domain/repositories/calendar_repository.dart';
import 'package:kitchensync/features/calendar/domain/repositories/shopping_schedule_repository.dart';
import 'package:kitchensync/features/calendar/presentation/providers/calendar_repository_providers.dart';
import 'package:kitchensync/features/calendar/presentation/providers/shopping_schedule_providers.dart';
import 'package:kitchensync/features/calendar/presentation/screens/shopping_schedule_screen.dart';
import 'package:kitchensync/features/ingredient_dictionary/presentation/providers/ingredient_providers.dart';
import 'package:kitchensync/features/shopping/domain/services/scheduled_shopping_list_planner.dart';
import 'package:kitchensync/features/shopping/presentation/providers/shopping_repository_providers.dart';
import 'package:mocktail/mocktail.dart';

const _adminHousehold = ActiveHouseholdContext(
  id: 'household-1',
  name: 'Test kitchen',
  role: HouseholdRole.admin,
  isJoint: true,
  hasPremium: true,
);

ShoppingSchedule _schedule() => ShoppingSchedule(
  householdId: 'household-1',
  cadence: ShoppingScheduleCadence.weekly,
  isoWeekday: DateTime.saturday,
  effectiveFrom: DateTime(2026, 7, 4),
  isActive: true,
  createdAt: DateTime(2026, 7),
  updatedAt: DateTime(2026, 7),
  updatedByUserId: 'admin-1',
);

class _FakeShoppingScheduleRepository implements ShoppingScheduleRepository {
  _FakeShoppingScheduleRepository({
    this.schedule,
    this.failures = 0,
    this.saveGate,
    this.keepWatchStale = false,
  });

  ShoppingSchedule? schedule;
  int failures;
  final Completer<void>? saveGate;
  final bool keepWatchStale;
  final saved = <ShoppingSchedule>[];

  @override
  Stream<ShoppingSchedule?> watch(String householdId) =>
      Stream.value(keepWatchStale ? null : schedule);

  @override
  Future<void> save(ShoppingSchedule next) async {
    saved.add(next);
    if (failures > 0) {
      failures--;
      throw StateError('save failed');
    }
    await saveGate?.future;
    schedule = next;
  }
}

class _FakeCalendarRepository implements CalendarRepository {
  _FakeCalendarRepository(this.settings);

  final List<CalendarDaySettings> settings;

  @override
  Stream<List<CalendarDaySettings>> watchActiveDaySettings(
    String householdId,
  ) => Stream.value(settings);

  @override
  Stream<List<MealScheduleEntry>> watchMealsInRange({
    required String householdId,
    required DateTime startDate,
    required DateTime endDate,
  }) => Stream.value(const []);

  @override
  Future<void> upsertDaySettings(CalendarDaySettings settings) async {}

  @override
  Future<void> upsertMeal({
    required String householdId,
    required MealScheduleEntry entry,
  }) async {}

  @override
  Future<void> deleteMeal({
    required String householdId,
    required String entryId,
  }) async {}
}

class _FailingCalendarRepository extends _FakeCalendarRepository {
  _FailingCalendarRepository(this.error) : super(const []);

  final Object error;

  @override
  Stream<List<CalendarDaySettings>> watchActiveDaySettings(
    String householdId,
  ) => Stream.error(error);
}

class _MockShoppingPlanningController extends Mock
    implements ShoppingPlanningController {}

Future<void> _pumpScreen(
  WidgetTester tester, {
  ActiveHouseholdContext household = _adminHousehold,
  ShoppingSchedule? schedule,
  _FakeShoppingScheduleRepository? scheduleRepository,
  _FakeCalendarRepository? calendarRepository,
  ShoppingPlanningController? planningController,
  DateTime? initialEffectiveFrom,
}) async {
  final scheduleRepo =
      scheduleRepository ?? _FakeShoppingScheduleRepository(schedule: schedule);
  final calendarRepo = calendarRepository ?? _FakeCalendarRepository(const []);
  final planning = planningController ?? _MockShoppingPlanningController();
  when(() => planning.reconcileScheduledLists(any())).thenAnswer((_) async {});
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        activeHouseholdContextProvider.overrideWithValue(household),
        activeUserIdProvider.overrideWithValue('user-1'),
        clockProvider.overrideWithValue(FakeClock(DateTime(2026, 7, 1, 9))),
        idGeneratorProvider.overrideWithValue(FakeIdGenerator(['command-1'])),
        shoppingScheduleRepositoryProvider.overrideWithValue(scheduleRepo),
        calendarRepositoryProvider.overrideWithValue(calendarRepo),
        shoppingPlanningControllerProvider.overrideWithValue(planning),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: ShoppingScheduleScreen(
          initialEffectiveFrom: initialEffectiveFrom,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    registerFallbackValue(const <ScheduledShoppingRange>[]);
  });

  testWidgets('admin can edit a new weekly shopping schedule', (tester) async {
    await _pumpScreen(tester);

    expect(find.text('Shopping schedule'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('shopping-schedule-weekday-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('shopping-schedule-effective-from')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('shopping-schedule-active-toggle')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('shopping-schedule-save')),
      findsOneWidget,
    );
  });

  testWidgets(
    'save invokes scheduled-list reconciliation through the mock controller',
    (tester) async {
      final planning = _MockShoppingPlanningController();
      await _pumpScreen(
        tester,
        calendarRepository: _FakeCalendarRepository([
          _settings('active', DateTime(2026, 7), DateTime(2026, 7, 7)),
        ]),
        planningController: planning,
      );

      await tester.tap(find.byKey(const ValueKey('shopping-schedule-save')));
      await tester.pumpAndSettle();

      verify(() => planning.reconcileScheduledLists(any())).called(1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('joint household member sees summary without mutating controls', (
    tester,
  ) async {
    await _pumpScreen(
      tester,
      household: const ActiveHouseholdContext(
        id: 'household-1',
        name: 'Test kitchen',
        role: HouseholdRole.member,
        isJoint: true,
        hasPremium: true,
      ),
      schedule: _schedule(),
    );

    expect(find.text('Saturday'), findsOneWidget);
    expect(find.text('July 4, 2026'), findsOneWidget);
    expect(find.byKey(const ValueKey('shopping-schedule-save')), findsNothing);
    expect(
      find.byKey(const ValueKey('shopping-schedule-deactivate')),
      findsNothing,
    );
  });

  for (final role in [
    HouseholdRole.shopper,
    HouseholdRole.cook,
    HouseholdRole.member,
  ]) {
    testWidgets('joint $role remains read-only', (tester) async {
      await _pumpScreen(
        tester,
        household: ActiveHouseholdContext(
          id: 'household-1',
          name: 'Test kitchen',
          role: role,
          isJoint: true,
          hasPremium: true,
        ),
        schedule: _schedule(),
      );

      expect(find.text('Saturday'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('shopping-schedule-save')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('shopping-schedule-deactivate')),
        findsNothing,
      );
    });
  }

  testWidgets('solo member can save without active meal ranges', (
    tester,
  ) async {
    final repository = _FakeShoppingScheduleRepository();
    final planning = _MockShoppingPlanningController();
    await _pumpScreen(
      tester,
      household: const ActiveHouseholdContext(
        id: 'household-1',
        name: 'Solo kitchen',
        role: HouseholdRole.member,
        isJoint: false,
        hasPremium: false,
      ),
      scheduleRepository: repository,
      planningController: planning,
    );

    await tester.tap(find.byKey(const ValueKey('shopping-schedule-weekday-3')));
    await tester.tap(find.byKey(const ValueKey('shopping-schedule-save')));
    await tester.pumpAndSettle();

    expect(repository.saved, hasLength(1));
    expect(repository.saved.single.isoWeekday, DateTime.wednesday);
    expect(find.text('Lists will appear as meals are planned'), findsOneWidget);
    verifyNever(() => planning.reconcileScheduledLists(any()));
  });

  testWidgets('saved schedule is summarized before provider refresh', (
    tester,
  ) async {
    final repository = _FakeShoppingScheduleRepository(keepWatchStale: true);
    await _pumpScreen(tester, scheduleRepository: repository);

    await tester.tap(find.byKey(const ValueKey('shopping-schedule-weekday-3')));
    await tester.tap(find.byKey(const ValueKey('shopping-schedule-save')));
    await tester.pumpAndSettle();

    expect(repository.saved, hasLength(1));
    expect(find.text('Not set'), findsNothing);
    expect(find.text('Wednesday'), findsOneWidget);
    expect(find.text('July 1, 2026'), findsNWidgets(2));
  });

  testWidgets('existing schedule edits preserve creation audit data', (
    tester,
  ) async {
    final existing = _schedule();
    final repository = _FakeShoppingScheduleRepository(schedule: existing);
    await _pumpScreen(
      tester,
      schedule: existing,
      scheduleRepository: repository,
    );

    await tester.tap(find.byKey(const ValueKey('shopping-schedule-weekday-1')));
    await tester.tap(find.byKey(const ValueKey('shopping-schedule-save')));
    await tester.pumpAndSettle();

    expect(repository.saved, hasLength(1));
    expect(repository.saved.single.isoWeekday, DateTime.monday);
    expect(repository.saved.single.createdAt, existing.createdAt);
    expect(repository.saved.single.updatedByUserId, 'user-1');
  });

  testWidgets('save reconciles each merged active range separately', (
    tester,
  ) async {
    final repository = _FakeShoppingScheduleRepository();
    final planning = _MockShoppingPlanningController();
    final calendar = _FakeCalendarRepository([
      _settings('late', DateTime(2026, 7, 20), DateTime(2026, 7, 22)),
      _settings('early', DateTime(2026, 7), DateTime(2026, 7, 3)),
      _settings('adjacent', DateTime(2026, 7, 4), DateTime(2026, 7, 7)),
    ]);
    await _pumpScreen(
      tester,
      scheduleRepository: repository,
      calendarRepository: calendar,
      planningController: planning,
    );

    await tester.tap(find.byKey(const ValueKey('shopping-schedule-save')));
    await tester.pumpAndSettle();

    final calls = verify(
      () => planning.reconcileScheduledLists(captureAny()),
    ).captured;
    expect(calls, hasLength(2));
    expect(_bounds(calls[0] as Iterable<ScheduledShoppingRange>), [
      (DateTime(2026, 7), DateTime(2026, 7, 7)),
    ]);
    expect(_bounds(calls[1] as Iterable<ScheduledShoppingRange>), [
      (DateTime(2026, 7, 20), DateTime(2026, 7, 22)),
    ]);
  });

  testWidgets(
    'malformed active meal range blocks save and preserves form values',
    (tester) async {
      final repository = _FakeShoppingScheduleRepository();
      final planning = _MockShoppingPlanningController();
      final calendar = _FakeCalendarRepository([
        _settings('backwards', DateTime(2026, 7, 8), DateTime(2026, 7)),
      ]);
      await _pumpScreen(
        tester,
        scheduleRepository: repository,
        calendarRepository: calendar,
        planningController: planning,
      );

      await tester.tap(
        find.byKey(const ValueKey('shopping-schedule-weekday-2')),
      );
      await tester.tap(find.byKey(const ValueKey('shopping-schedule-save')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(repository.saved, isEmpty);
      expect(
        find.text(
          'Fix planned meal ranges before saving. '
          'Make sure each end date is on or after its start date.',
        ),
        findsOneWidget,
      );
      expect(find.text('Could not save shopping schedule.'), findsNothing);
      expect(
        find.text('Schedule saved, but shopping lists could not refresh.'),
        findsNothing,
      );
      final chip = tester.widget<KsSelectChip>(
        find.byKey(const ValueKey('shopping-schedule-weekday-2')),
      );
      expect(chip.selected, isTrue);
      verifyNever(() => planning.reconcileScheduledLists(any()));
    },
  );

  testWidgets(
    'persisted malformed active range shows actionable recovery without saving',
    (tester) async {
      final db = FakeFirebaseFirestore();
      await db
          .collection('households')
          .doc(_adminHousehold.id)
          .collection('daySettings')
          .doc('backwards')
          .set({
            'householdId': _adminHousehold.id,
            'dateRangeStart': '2026-07-08',
            'dateRangeEnd': '2026-07-01',
            'defaultServingSize': 4,
            'mealsPerDay': 3,
            'dishesPerMeal': 1,
            'mealModeName': 'Invalid range',
            'isActive': true,
          });
      final repository = _FakeShoppingScheduleRepository();
      final planning = _MockShoppingPlanningController();
      when(
        () => planning.reconcileScheduledLists(any()),
      ).thenAnswer((_) async {});

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeHouseholdContextProvider.overrideWithValue(_adminHousehold),
            activeUserIdProvider.overrideWithValue('user-1'),
            clockProvider.overrideWithValue(FakeClock(DateTime(2026, 7, 1, 9))),
            idGeneratorProvider.overrideWithValue(
              FakeIdGenerator(['command-1']),
            ),
            shoppingScheduleRepositoryProvider.overrideWithValue(repository),
            calendarRepositoryProvider.overrideWithValue(
              CalendarRepositoryImpl(
                CalendarRemoteDataSource(FirestoreRefs(db)),
              ),
            ),
            shoppingPlanningControllerProvider.overrideWithValue(planning),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const ShoppingScheduleScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('shopping-schedule-weekday-2')),
      );
      await tester.pumpAndSettle();

      expect(repository.saved, isEmpty);
      final chip = tester.widget<KsSelectChip>(
        find.byKey(const ValueKey('shopping-schedule-weekday-2')),
      );
      expect(chip.selected, isTrue);
      final dateButton = tester.widget<OutlinedButton>(
        find.byKey(const ValueKey('shopping-schedule-effective-from')),
      );
      expect(dateButton.onPressed, isNotNull);
      final saveButton = tester.widget<FilledButton>(
        find.byKey(const ValueKey('shopping-schedule-save')),
      );
      expect(saveButton.onPressed, isNull);
      verifyNever(() => planning.reconcileScheduledLists(any()));
      expect(
        find.text(
          'Fix planned meal ranges before saving. '
          'Make sure each end date is on or after its start date.',
        ),
        findsOneWidget,
      );
      expect(find.text('Could not load planned meal ranges.'), findsNothing);
    },
  );

  testWidgets('unrelated settings errors keep generic load guidance', (
    tester,
  ) async {
    final repository = _FakeShoppingScheduleRepository();
    final planning = _MockShoppingPlanningController();
    await _pumpScreen(
      tester,
      scheduleRepository: repository,
      calendarRepository: _FailingCalendarRepository(
        const FormatException(
          'Active calendar range end must be on or after start.',
        ),
      ),
      planningController: planning,
    );

    await tester.tap(find.byKey(const ValueKey('shopping-schedule-weekday-2')));
    await tester.pumpAndSettle();

    expect(repository.saved, isEmpty);
    expect(find.text('Could not load planned meal ranges.'), findsOneWidget);
    expect(
      find.text(
        'Fix planned meal ranges before saving. '
        'Make sure each end date is on or after its start date.',
      ),
      findsNothing,
    );
    final chip = tester.widget<KsSelectChip>(
      find.byKey(const ValueKey('shopping-schedule-weekday-2')),
    );
    expect(chip.selected, isTrue);
    final dateButton = tester.widget<OutlinedButton>(
      find.byKey(const ValueKey('shopping-schedule-effective-from')),
    );
    expect(dateButton.onPressed, isNotNull);
    final saveButton = tester.widget<FilledButton>(
      find.byKey(const ValueKey('shopping-schedule-save')),
    );
    expect(saveButton.onPressed, isNull);
    verifyNever(() => planning.reconcileScheduledLists(any()));
  });

  testWidgets('reconciliation failure retries without saving again', (
    tester,
  ) async {
    final repository = _FakeShoppingScheduleRepository(keepWatchStale: true);
    final planning = _MockShoppingPlanningController();
    final calendar = _FakeCalendarRepository([
      _settings('active', DateTime(2026, 7), DateTime(2026, 7, 7)),
    ]);
    await _pumpScreen(
      tester,
      scheduleRepository: repository,
      calendarRepository: calendar,
      planningController: planning,
    );
    when(
      () => planning.reconcileScheduledLists(any()),
    ).thenThrow(StateError('refresh failed'));

    await tester.tap(find.byKey(const ValueKey('shopping-schedule-save')));
    await tester.pumpAndSettle();

    expect(repository.saved, hasLength(1));
    expect(find.text('Saturday'), findsOneWidget);
    expect(
      find.text('Schedule saved, but shopping lists could not refresh.'),
      findsOneWidget,
    );
    expect(find.text('Could not save shopping schedule.'), findsNothing);
    expect(find.text('Retry list refresh'), findsOneWidget);

    when(
      () => planning.reconcileScheduledLists(any()),
    ).thenAnswer((_) async {});
    await tester.tap(find.text('Retry list refresh'));
    await tester.pumpAndSettle();

    expect(repository.saved, hasLength(1));
    verify(() => planning.reconcileScheduledLists(any())).called(2);
    expect(
      find.text('Schedule saved, but shopping lists could not refresh.'),
      findsNothing,
    );
    expect(find.text('Shopping lists refreshed'), findsOneWidget);
  });

  testWidgets('save failure preserves form values and retries', (tester) async {
    final repository = _FakeShoppingScheduleRepository(failures: 1);
    await _pumpScreen(tester, scheduleRepository: repository);

    await tester.tap(find.byKey(const ValueKey('shopping-schedule-weekday-2')));
    await tester.tap(find.byKey(const ValueKey('shopping-schedule-save')));
    await tester.pumpAndSettle();

    expect(find.text('Could not save shopping schedule.'), findsOneWidget);
    var chip = tester.widget<KsSelectChip>(
      find.byKey(const ValueKey('shopping-schedule-weekday-2')),
    );
    expect(chip.selected, isTrue);

    await tester.tap(find.byKey(const ValueKey('shopping-schedule-save')));
    await tester.pumpAndSettle();

    expect(repository.saved, hasLength(2));
    expect(repository.schedule?.isoWeekday, DateTime.tuesday);
    chip = tester.widget<KsSelectChip>(
      find.byKey(const ValueKey('shopping-schedule-weekday-2')),
    );
    expect(chip.selected, isTrue);
  });

  testWidgets('saving disables controls and suppresses a repeated save', (
    tester,
  ) async {
    final gate = Completer<void>();
    final repository = _FakeShoppingScheduleRepository(saveGate: gate);
    await _pumpScreen(tester, scheduleRepository: repository);

    await tester.tap(find.byKey(const ValueKey('shopping-schedule-save')));
    await tester.pump();

    expect(repository.saved, hasLength(1));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    final save = tester.widget<FilledButton>(
      find.byKey(const ValueKey('shopping-schedule-save')),
    );
    expect(save.onPressed, isNull);
    final weekday = tester.widget<KsSelectChip>(
      find.byKey(const ValueKey('shopping-schedule-weekday-2')),
    );
    expect(weekday.onTap, isNull);

    gate.complete();
    await tester.pumpAndSettle();

    expect(repository.saved, hasLength(1));
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('invalid initial effective date blocks persistence', (
    tester,
  ) async {
    final repository = _FakeShoppingScheduleRepository();
    await _pumpScreen(
      tester,
      scheduleRepository: repository,
      initialEffectiveFrom: DateTime(1900),
    );

    await tester.tap(find.byKey(const ValueKey('shopping-schedule-save')));
    await tester.pump();

    expect(find.text('Choose a valid effective date.'), findsOneWidget);
    expect(repository.saved, isEmpty);
  });

  testWidgets('deactivate requires confirmation and skips reconciliation', (
    tester,
  ) async {
    final repository = _FakeShoppingScheduleRepository(schedule: _schedule());
    final planning = _MockShoppingPlanningController();
    await _pumpScreen(
      tester,
      schedule: _schedule(),
      scheduleRepository: repository,
      planningController: planning,
    );

    await tester.tap(
      find.byKey(const ValueKey('shopping-schedule-deactivate')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Deactivate schedule?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repository.saved, isEmpty);

    await tester.tap(
      find.byKey(const ValueKey('shopping-schedule-deactivate')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Deactivate').last);
    await tester.pumpAndSettle();

    expect(repository.saved, hasLength(1));
    expect(repository.saved.single.isActive, isFalse);
    verifyNever(() => planning.reconcileScheduledLists(any()));
  });

  testWidgets('deactivation succeeds when planned range settings fail', (
    tester,
  ) async {
    final existing = _schedule();
    final repository = _FakeShoppingScheduleRepository(schedule: existing);
    final planning = _MockShoppingPlanningController();
    await _pumpScreen(
      tester,
      schedule: existing,
      scheduleRepository: repository,
      calendarRepository: _FailingCalendarRepository(
        StateError('settings unavailable'),
      ),
      planningController: planning,
    );

    expect(find.text('Could not load planned meal ranges.'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('shopping-schedule-deactivate')),
      200,
    );
    await tester.tap(
      find.byKey(const ValueKey('shopping-schedule-deactivate')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Deactivate schedule?'), findsOneWidget);
    await tester.tap(find.text('Deactivate').last);
    await tester.pumpAndSettle();

    expect(repository.saved, hasLength(1));
    final saved = repository.saved.single;
    expect(saved.isActive, isFalse);
    expect(saved.isoWeekday, existing.isoWeekday);
    expect(saved.effectiveFrom, existing.effectiveFrom);
    expect(saved.createdAt, existing.createdAt);
    expect(saved.updatedByUserId, 'user-1');
    expect(find.text('Shopping schedule deactivated'), findsOneWidget);
    expect(find.text('Lists will appear as meals are planned'), findsNothing);
    verifyNever(() => planning.reconcileScheduledLists(any()));
  });

  testWidgets(
    'deactivation succeeds through malformed persisted range provider path',
    (tester) async {
      final db = FakeFirebaseFirestore();
      await db
          .collection('households')
          .doc(_adminHousehold.id)
          .collection('daySettings')
          .doc('backwards')
          .set({
            'householdId': _adminHousehold.id,
            'dateRangeStart': '2026-07-08',
            'dateRangeEnd': '2026-07-01',
            'defaultServingSize': 4,
            'mealsPerDay': 3,
            'dishesPerMeal': 1,
            'mealModeName': 'Invalid range',
            'isActive': true,
          });
      final existing = _schedule();
      final repository = _FakeShoppingScheduleRepository(schedule: existing);
      final planning = _MockShoppingPlanningController();
      when(
        () => planning.reconcileScheduledLists(any()),
      ).thenAnswer((_) async {});

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeHouseholdContextProvider.overrideWithValue(_adminHousehold),
            activeUserIdProvider.overrideWithValue('user-1'),
            clockProvider.overrideWithValue(FakeClock(DateTime(2026, 7, 1, 9))),
            idGeneratorProvider.overrideWithValue(
              FakeIdGenerator(['command-1']),
            ),
            shoppingScheduleRepositoryProvider.overrideWithValue(repository),
            calendarRepositoryProvider.overrideWithValue(
              CalendarRepositoryImpl(
                CalendarRemoteDataSource(FirestoreRefs(db)),
              ),
            ),
            shoppingPlanningControllerProvider.overrideWithValue(planning),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const ShoppingScheduleScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Fix planned meal ranges before saving. '
          'Make sure each end date is on or after its start date.',
        ),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('shopping-schedule-deactivate')),
        200,
      );
      await tester.tap(
        find.byKey(const ValueKey('shopping-schedule-deactivate')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Deactivate schedule?'), findsOneWidget);
      await tester.tap(find.text('Deactivate').last);
      await tester.pumpAndSettle();

      expect(repository.saved, hasLength(1));
      final saved = repository.saved.single;
      expect(saved.isActive, isFalse);
      expect(saved.isoWeekday, existing.isoWeekday);
      expect(saved.effectiveFrom, existing.effectiveFrom);
      expect(saved.createdAt, existing.createdAt);
      expect(saved.updatedByUserId, 'user-1');
      expect(find.text('Shopping schedule deactivated'), findsOneWidget);
      expect(find.text('Lists will appear as meals are planned'), findsNothing);
      verifyNever(() => planning.reconcileScheduledLists(any()));
    },
  );

  testWidgets('new inactive schedule saves when planned range settings fail', (
    tester,
  ) async {
    final repository = _FakeShoppingScheduleRepository();
    final planning = _MockShoppingPlanningController();
    await _pumpScreen(
      tester,
      scheduleRepository: repository,
      calendarRepository: _FailingCalendarRepository(
        StateError('settings unavailable'),
      ),
      planningController: planning,
    );

    await tester.tap(find.byKey(const ValueKey('shopping-schedule-weekday-2')));
    await tester.tap(
      find.byKey(const ValueKey('shopping-schedule-active-toggle')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Deactivate schedule?'), findsNothing);
    final saveButton = tester.widget<FilledButton>(
      find.byKey(const ValueKey('shopping-schedule-save')),
    );
    expect(saveButton.onPressed, isNotNull);
    await tester.tap(find.byKey(const ValueKey('shopping-schedule-save')));
    await tester.pumpAndSettle();

    expect(repository.saved, hasLength(1));
    final saved = repository.saved.single;
    expect(saved.isActive, isFalse);
    expect(saved.isoWeekday, DateTime.tuesday);
    expect(saved.effectiveFrom, DateTime(2026, 7));
    expect(saved.createdAt, DateTime(2026, 7, 1, 9));
    expect(saved.updatedByUserId, 'user-1');
    expect(find.text('Shopping schedule saved'), findsOneWidget);
    expect(find.text('Lists will appear as meals are planned'), findsNothing);
    verifyNever(() => planning.reconcileScheduledLists(any()));
  });

  testWidgets('active switch uses the destructive deactivate confirmation', (
    tester,
  ) async {
    final repository = _FakeShoppingScheduleRepository(schedule: _schedule());
    await _pumpScreen(
      tester,
      schedule: _schedule(),
      scheduleRepository: repository,
    );

    await tester.tap(
      find.byKey(const ValueKey('shopping-schedule-active-toggle')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Deactivate schedule?'), findsOneWidget);
    expect(repository.saved, isEmpty);
  });
}

CalendarDaySettings _settings(String id, DateTime start, DateTime end) {
  return CalendarDaySettings(
    id: id,
    householdId: 'household-1',
    dateRangeStart: start,
    dateRangeEnd: end,
    mealsPerDay: 3,
    dishesPerMeal: 1,
    mealModeName: 'Standard',
    isActive: true,
  );
}

List<(DateTime, DateTime)> _bounds(Iterable<ScheduledShoppingRange> ranges) => [
  for (final range in ranges) (range.start, range.end),
];

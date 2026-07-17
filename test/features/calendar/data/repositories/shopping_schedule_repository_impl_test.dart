import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/core/firebase/firestore_refs.dart';
import 'package:kitchensync/features/calendar/data/datasources/shopping_schedule_remote_data_source.dart';
import 'package:kitchensync/features/calendar/data/dtos/shopping_schedule_dto.dart';
import 'package:kitchensync/features/calendar/data/repositories/shopping_schedule_repository_impl.dart';
import 'package:kitchensync/features/calendar/domain/entities/shopping_schedule.dart';

void main() {
  late FakeFirebaseFirestore db;
  late ShoppingScheduleRepositoryImpl repository;

  const householdId = 'household-1';
  ShoppingSchedule schedule({
    int isoWeekday = DateTime.saturday,
    DateTime? effectiveFrom,
    bool isActive = true,
    DateTime? updatedAt,
    String updatedByUserId = 'user-1',
  }) => ShoppingSchedule(
    householdId: householdId,
    cadence: ShoppingScheduleCadence.weekly,
    isoWeekday: isoWeekday,
    effectiveFrom: effectiveFrom ?? DateTime(2026, 7, 4),
    isActive: isActive,
    createdAt: DateTime(2026, 7, 1, 8),
    updatedAt: updatedAt ?? DateTime(2026, 7, 2, 9),
    updatedByUserId: updatedByUserId,
  );

  setUp(() {
    db = FakeFirebaseFirestore();
    repository = ShoppingScheduleRepositoryImpl(
      ShoppingScheduleRemoteDataSource(FirestoreRefs(db)),
    );
  });

  test('mapper writes the date-only weekly schedule contract', () {
    final map = ShoppingScheduleMapper.toMap(schedule());

    expect(map['householdId'], householdId);
    expect(map['cadence'], 'weekly');
    expect(map['isoWeekday'], DateTime.saturday);
    expect(map['effectiveFrom'], '2026-07-04');
    expect(map['isActive'], isTrue);
    expect(map['createdAt'], isA<Timestamp>());
    expect(map['updatedAt'], isA<Timestamp>());
    expect(map['updatedByUserId'], 'user-1');
  });

  test('mapper reads the date-only weekly schedule contract', () {
    final restored = ShoppingScheduleMapper.fromMap({
      'householdId': householdId,
      'cadence': 'weekly',
      'isoWeekday': DateTime.saturday,
      'effectiveFrom': '2026-07-04',
      'isActive': true,
      'createdAt': Timestamp.fromDate(DateTime(2026, 7, 1, 8)),
      'updatedAt': Timestamp.fromDate(DateTime(2026, 7, 2, 9)),
      'updatedByUserId': 'user-1',
    }, expectedHouseholdId: householdId);

    expect(restored.effectiveFrom, DateTime(2026, 7, 4));
    expect(restored.isoWeekday, DateTime.saturday);
  });

  test('save writes the weekly document', () async {
    await repository.save(schedule());

    final snapshot = await db
        .collection('households')
        .doc(householdId)
        .collection('shoppingSchedules')
        .get();

    expect(snapshot.docs, hasLength(1));
    expect(snapshot.docs.single.id, 'weekly');
  });

  test('save replaces the existing weekly document', () async {
    await db
        .collection('households')
        .doc(householdId)
        .collection('shoppingSchedules')
        .doc('weekly')
        .set(ShoppingScheduleMapper.toMap(schedule()));

    await repository.save(
      schedule(
        isoWeekday: DateTime.wednesday,
        isActive: false,
        updatedAt: DateTime(2026, 7, 3),
        updatedByUserId: 'user-2',
      ),
    );

    final saved = await db
        .collection('households')
        .doc(householdId)
        .collection('shoppingSchedules')
        .doc('weekly')
        .get();

    expect(saved.exists, isTrue);
    expect(saved.data()?['isoWeekday'], DateTime.wednesday);
    expect(saved.data()?['isActive'], isFalse);
    expect(saved.data()?['updatedByUserId'], 'user-2');
  });

  test('watch returns the stored weekly schedule', () async {
    await db
        .collection('households')
        .doc(householdId)
        .collection('shoppingSchedules')
        .doc('weekly')
        .set(
          ShoppingScheduleMapper.toMap(
            schedule(
              isoWeekday: DateTime.wednesday,
              isActive: false,
              updatedAt: DateTime(2026, 7, 3),
              updatedByUserId: 'user-2',
            ),
          ),
        );

    final watched = await repository.watch(householdId).first;

    expect(watched?.isoWeekday, DateTime.wednesday);
    expect(watched?.isActive, isFalse);
    expect(watched?.updatedByUserId, 'user-2');
  });

  test('watch returns null when no schedule exists', () async {
    expect(await repository.watch(householdId).first, isNull);
  });

  test('watch rejects a schedule with a non-weekly cadence', () async {
    await db
        .collection('households')
        .doc(householdId)
        .collection('shoppingSchedules')
        .doc('weekly')
        .set({
          'householdId': householdId,
          'cadence': 'monthly',
          'isoWeekday': DateTime.saturday,
          'effectiveFrom': '2026-07-04',
          'isActive': true,
          'createdAt': Timestamp.fromDate(DateTime(2026, 7)),
          'updatedAt': Timestamp.fromDate(DateTime(2026, 7)),
          'updatedByUserId': 'user-1',
        });

    await expectLater(
      repository.watch(householdId).first,
      throwsFormatException,
    );
  });

  test('watch rejects a malformed effective date', () async {
    await db
        .collection('households')
        .doc(householdId)
        .collection('shoppingSchedules')
        .doc('weekly')
        .set({
          'householdId': householdId,
          'cadence': 'weekly',
          'isoWeekday': DateTime.saturday,
          'effectiveFrom': '2026-02-30',
          'isActive': true,
          'createdAt': Timestamp.fromDate(DateTime(2026, 7)),
          'updatedAt': Timestamp.fromDate(DateTime(2026, 7)),
          'updatedByUserId': 'user-1',
        });

    await expectLater(
      repository.watch(householdId).first,
      throwsFormatException,
    );
  });

  test(
    'watch rejects a schedule whose household scope does not match',
    () async {
      await db
          .collection('households')
          .doc(householdId)
          .collection('shoppingSchedules')
          .doc('weekly')
          .set({
            ...ShoppingScheduleMapper.toMap(schedule()),
            'householdId': 'another-household',
          });

      await expectLater(
        repository.watch(householdId).first,
        throwsFormatException,
      );
    },
  );

  test('mapper rejects an invalid ISO weekday', () {
    final map = ShoppingScheduleMapper.toMap(schedule())..['isoWeekday'] = 8;

    expect(
      () =>
          ShoppingScheduleMapper.fromMap(map, expectedHouseholdId: householdId),
      throwsArgumentError,
    );
  });

  for (final field in ['createdAt', 'updatedAt']) {
    test('mapper rejects a malformed $field timestamp', () {
      final map = ShoppingScheduleMapper.toMap(schedule())
        ..[field] = 'not-a-time';

      expect(
        () => ShoppingScheduleMapper.fromMap(
          map,
          expectedHouseholdId: householdId,
        ),
        throwsFormatException,
      );
    });
  }

  test('mapper rejects a malformed active flag', () {
    final map = ShoppingScheduleMapper.toMap(schedule())..['isActive'] = 'true';

    expect(
      () =>
          ShoppingScheduleMapper.fromMap(map, expectedHouseholdId: householdId),
      throwsFormatException,
    );
  });

  test('mapper rejects a malformed updater id', () {
    final map = ShoppingScheduleMapper.toMap(schedule())
      ..['updatedByUserId'] = '';

    expect(
      () =>
          ShoppingScheduleMapper.fromMap(map, expectedHouseholdId: householdId),
      throwsFormatException,
    );
  });
}

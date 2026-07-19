import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/core/firebase/firestore_refs.dart';
import 'package:kitchensync/features/menu_sets/data/datasources/menu_set_remote_data_source.dart';
import 'package:kitchensync/features/menu_sets/data/dtos/menu_set_dto.dart';
import 'package:kitchensync/features/menu_sets/data/repositories/menu_set_repository_impl.dart';
import 'package:kitchensync/features/menu_sets/domain/entities/menu_set.dart';

void main() {
  late FakeFirebaseFirestore db;
  late MenuSetRepositoryImpl repo;

  const householdId = 'h1';
  final now = DateTime(2026, 7, 4, 12);
  late MenuSet menuSet;

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = MenuSetRepositoryImpl(MenuSetRemoteDataSource(FirestoreRefs(db)));
    menuSet = MenuSet(
      id: 'set-1',
      householdId: householdId,
      name: 'Cosy autumn week',
      description: 'Weeknight dinners',
      lengthInDays: 7,
      createdByUserId: 'user-1',
      createdAt: now,
      updatedAt: now,
      days: const [
        MenuSetDay(
          id: 'day-0',
          menuSetId: 'set-1',
          dayIndex: 0,
          label: 'Monday',
          entries: [
            MenuSetEntry(
              id: 'entry-1',
              menuSetDayId: 'day-0',
              mealSlot: 'Dinner',
              recipeId: 'dal',
              orderInSlot: 0,
            ),
          ],
        ),
        MenuSetDay(
          id: 'day-1',
          menuSetId: 'set-1',
          dayIndex: 1,
          label: 'Tuesday',
          entries: [],
        ),
      ],
    );
  });

  test('MenuSetMapper stores design-doc field names', () {
    final map = MenuSetMapper.toMap(menuSet);

    expect(map['householdId'], householdId);
    expect(map['name'], 'Cosy autumn week');
    expect(map['description'], 'Weeknight dinners');
    expect(map['lengthInDays'], 7);
    expect(map['createdByUserId'], 'user-1');
    expect(map['createdAt'], isA<Timestamp>());
    expect(map['updatedAt'], isA<Timestamp>());
    expect(map['isPublicTemplate'], isFalse);
  });

  test(
    'upsert writes nested days and entries then watch hydrates them',
    () async {
      await repo.upsert(menuSet);

      final sets = await repo.watchHouseholdMenuSets(householdId).first;

      expect(sets, hasLength(1));
      expect(sets.single.name, 'Cosy autumn week');
      expect(sets.single.days.map((day) => day.id), ['day-0', 'day-1']);
      expect(sets.single.days.first.entries.single.recipeId, 'dal');
      expect(sets.single.days.first.entries.single.mealSlot, 'Dinner');
    },
  );

  test('upsert replaces removed nested days and entries', () async {
    await repo.upsert(menuSet);
    final replacement = MenuSet(
      id: menuSet.id,
      householdId: menuSet.householdId,
      name: menuSet.name,
      description: menuSet.description,
      lengthInDays: 1,
      createdByUserId: menuSet.createdByUserId,
      createdAt: menuSet.createdAt,
      updatedAt: now.add(const Duration(minutes: 1)),
      days: const [
        MenuSetDay(
          id: 'day-0',
          menuSetId: 'set-1',
          dayIndex: 0,
          label: 'Monday',
          entries: [],
        ),
      ],
    );

    await repo.upsert(replacement);

    final stored = await repo
        .watchById(householdId: householdId, menuSetId: menuSet.id)
        .first;
    expect(stored, isNotNull);
    expect(stored!.days.map((day) => day.id), ['day-0']);
    expect(stored.days.single.entries, isEmpty);
  });

  test('watchById returns null when missing', () async {
    final missing = await repo
        .watchById(householdId: householdId, menuSetId: 'missing')
        .first;

    expect(missing, isNull);
  });

  test('delete removes the menu set, days and entries', () async {
    await repo.upsert(menuSet);

    await repo.delete(householdId: householdId, menuSetId: menuSet.id);

    final setSnap = await db
        .collection('households')
        .doc(householdId)
        .collection('menuSets')
        .doc(menuSet.id)
        .get();
    final daySnap = await db
        .collection('households')
        .doc(householdId)
        .collection('menuSets')
        .doc(menuSet.id)
        .collection('days')
        .get();
    final entrySnap = await db
        .collection('households')
        .doc(householdId)
        .collection('menuSets')
        .doc(menuSet.id)
        .collection('days')
        .doc('day-0')
        .collection('entries')
        .get();

    expect(setSnap.exists, isFalse);
    expect(daySnap.docs, isEmpty);
    expect(entrySnap.docs, isEmpty);
  });
}

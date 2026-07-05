import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/core/firebase/firestore_refs.dart';
import 'package:kitchensync/features/calendar/data/datasources/calendar_remote_data_source.dart';
import 'package:kitchensync/features/calendar/data/dtos/calendar_dto.dart';
import 'package:kitchensync/features/calendar/data/repositories/calendar_repository_impl.dart';
import 'package:kitchensync/features/calendar/domain/entities/meal_schedule.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';

void main() {
  late FakeFirebaseFirestore db;
  late CalendarRepositoryImpl repo;

  const householdId = 'h1';
  final entry = MealScheduleEntry(
    id: 'meal-1',
    recipeId: 'recipe-1',
    date: DateTime(2026, 7, 6),
    mealLabel: 'Dinner',
    servingSize: 4,
    mergedMealCount: 2,
    marking: ScheduledMealMarking.leftoverScheduled,
    ingredientOverrides: const [
      MealIngredientOverride(
        originalIngredientId: 'tomato',
        originalUnit: Unit.g,
        substituteIngredientId: 'pepper',
        substituteQuantity: 300,
        substituteUnit: Unit.g,
      ),
    ],
  );

  final settings = CalendarDaySettings(
    id: 'settings-1',
    householdId: householdId,
    dateRangeStart: DateTime(2026, 7),
    dateRangeEnd: DateTime(2026, 7, 31),
    defaultServingSize: 4,
    mealsPerDay: 3,
    dishesPerMeal: 2,
    mealModeName: 'Weekday rhythm',
    isActive: true,
  );

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = CalendarRepositoryImpl(CalendarRemoteDataSource(FirestoreRefs(db)));
  });

  test('MealScheduleEntryMapper stores design-doc field names', () {
    final map = MealScheduleEntryMapper.toMap(
      householdId: householdId,
      entry: entry,
    );

    expect(map['householdId'], householdId);
    expect(map['date'], '2026-07-06');
    expect(map['mealSlot'], 'Dinner');
    expect(map['recipeId'], 'recipe-1');
    expect(map['servingSize'], 4);
    expect(map['mergedMealCount'], 2);
    expect(map['state'], 'scheduled');
    expect(map['marking'], 'leftover_scheduled');
    expect(map['ingredientOverrides'], isA<List<Object?>>());

    final roundTrip = MealScheduleEntryMapper.fromMap('meal-1', map);
    expect(roundTrip.date, DateTime(2026, 7, 6));
    expect(roundTrip.mergedMealCount, 2);
    expect(roundTrip.marking, ScheduledMealMarking.leftoverScheduled);
    expect(roundTrip.ingredientOverrides.single.originalIngredientId, 'tomato');
    expect(
      roundTrip.ingredientOverrides.single.substituteIngredientId,
      'pepper',
    );
  });

  test('upsertMeal writes and watchMealsInRange reads ordered meals', () async {
    await repo.upsertMeal(householdId: householdId, entry: entry);
    await repo.upsertMeal(
      householdId: householdId,
      entry: MealScheduleEntry(
        id: 'meal-2',
        recipeId: 'recipe-2',
        date: DateTime(2026, 7, 8),
        mealLabel: 'Lunch',
        servingSize: 2,
      ),
    );
    await repo.upsertMeal(
      householdId: householdId,
      entry: MealScheduleEntry(
        id: 'outside-range',
        recipeId: 'recipe-3',
        date: DateTime(2026, 8),
        mealLabel: 'Dinner',
        servingSize: 2,
      ),
    );

    final meals = await repo
        .watchMealsInRange(
          householdId: householdId,
          startDate: DateTime(2026, 7),
          endDate: DateTime(2026, 7, 31),
        )
        .first;

    expect(meals.map((meal) => meal.id), ['meal-1', 'meal-2']);
    expect(meals.first.mealLabel, 'Dinner');
  });

  test('deleteMeal removes a meal document', () async {
    await repo.upsertMeal(householdId: householdId, entry: entry);

    await repo.deleteMeal(householdId: householdId, entryId: entry.id);

    final snap = await db
        .collection('households')
        .doc(householdId)
        .collection('mealScheduleEntries')
        .doc(entry.id)
        .get();
    expect(snap.exists, isFalse);
  });

  test('upsertDaySettings writes and watches active settings', () async {
    await repo.upsertDaySettings(settings);
    await repo.upsertDaySettings(
      CalendarDaySettings(
        id: 'inactive',
        householdId: householdId,
        dateRangeStart: DateTime(2026, 8),
        dateRangeEnd: DateTime(2026, 8, 31),
        mealsPerDay: 1,
        dishesPerMeal: 1,
        mealModeName: 'Away',
        isActive: false,
      ),
    );

    final active = await repo.watchActiveDaySettings(householdId).first;

    expect(active, hasLength(1));
    expect(active.single.id, 'settings-1');
    expect(active.single.defaultServingSize, 4);
    expect(active.single.mealModeName, 'Weekday rhythm');
  });
}

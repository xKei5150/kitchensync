import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/core/utils/clock.dart';
import 'package:kitchensync/core/utils/id_generator.dart';
import 'package:kitchensync/features/calendar/domain/repositories/calendar_repository.dart';
import 'package:kitchensync/features/calendar/presentation/providers/calendar_repository_providers.dart';
import 'package:kitchensync/features/ingredient_dictionary/presentation/providers/ingredient_providers.dart';
import 'package:kitchensync/features/menu_sets/data/datasources/menu_set_remote_data_source.dart';
import 'package:kitchensync/features/menu_sets/data/repositories/menu_set_repository_impl.dart';
import 'package:kitchensync/features/menu_sets/domain/entities/menu_set.dart';
import 'package:kitchensync/features/menu_sets/domain/repositories/menu_set_repository.dart';
import 'package:kitchensync/features/menu_sets/domain/services/menu_set_application_engine.dart';
import 'package:kitchensync/features/shopping/domain/entities/shopping_plan.dart';
import 'package:kitchensync/features/shopping/domain/repositories/shopping_repository.dart';
import 'package:kitchensync/features/shopping/presentation/providers/shopping_repository_providers.dart';

final menuSetRemoteDataSourceProvider = Provider<MenuSetRemoteDataSource>(
  (ref) => MenuSetRemoteDataSource(ref.watch(firestoreRefsProvider)),
);

final menuSetRepositoryProvider = Provider<MenuSetRepository>(
  (ref) => MenuSetRepositoryImpl(ref.watch(menuSetRemoteDataSourceProvider)),
);

final activeHouseholdMenuSetsProvider = StreamProvider<List<MenuSet>>((ref) {
  final householdId = ref.watch(activeHouseholdIdProvider);
  return ref
      .watch(menuSetRepositoryProvider)
      .watchHouseholdMenuSets(householdId);
});

final activeMenuSetProvider = StreamProvider.family<MenuSet?, String>((
  ref,
  menuSetId,
) {
  final householdId = ref.watch(activeHouseholdIdProvider);
  return ref
      .watch(menuSetRepositoryProvider)
      .watchById(householdId: householdId, menuSetId: menuSetId);
});

final menuSetApplyPersistenceControllerProvider =
    Provider<MenuSetApplyPersistenceController>((ref) {
      return MenuSetApplyPersistenceController(
        calendarRepository: ref.watch(calendarRepositoryProvider),
        shoppingRepository: ref.watch(shoppingRepositoryProvider),
        householdId: ref.watch(activeHouseholdIdProvider),
        idGenerator: ref.watch(idGeneratorProvider),
        clock: ref.watch(clockProvider),
      );
    });

final menuSetEditorControllerProvider = Provider<MenuSetEditorController>((
  ref,
) {
  return MenuSetEditorController(
    calendarRepository: ref.watch(calendarRepositoryProvider),
    menuSetRepository: ref.watch(menuSetRepositoryProvider),
    householdId: ref.watch(activeHouseholdIdProvider),
    userId: ref.watch(activeUserIdProvider),
    idGenerator: ref.watch(idGeneratorProvider),
    clock: ref.watch(clockProvider),
  );
});

class MenuSetEditorController {
  const MenuSetEditorController({
    required this.calendarRepository,
    required this.menuSetRepository,
    required this.householdId,
    required this.userId,
    required this.idGenerator,
    required this.clock,
  });

  final CalendarRepository calendarRepository;
  final MenuSetRepository menuSetRepository;
  final String householdId;
  final String userId;
  final IdGenerator idGenerator;
  final Clock clock;
  static const _draftFactory = MenuSetDraftFactory();

  Future<MenuSet> saveDraft({
    String name = 'Cosy autumn week',
    String? description = 'Saved from the menu set editor.',
    List<MenuSetDay>? days,
  }) async {
    final now = clock.now();
    final id = idGenerator.newId();
    final menuSet = MenuSet(
      id: id,
      householdId: householdId,
      name: name,
      description: description,
      lengthInDays: days?.length ?? 7,
      createdAt: now,
      updatedAt: now,
      days: days ?? _sampleDays(id),
    );
    await menuSetRepository.upsert(menuSet);
    return menuSet;
  }

  Future<MenuSet> createFromPastCalendar({
    required DateTime startDate,
    required DateTime endDate,
    String name = 'Saved calendar week',
  }) async {
    final meals = await calendarRepository
        .watchMealsInRange(
          householdId: householdId,
          startDate: startDate,
          endDate: endDate,
        )
        .first;
    final now = clock.now();
    final menuSetId = idGenerator.newId();
    final menuSet = _draftFactory.fromCalendarRange(
      id: menuSetId,
      householdId: householdId,
      name: name,
      description: 'Created from a past calendar range.',
      startDate: startDate,
      endDate: endDate,
      entries: meals,
      createdByUserId: userId,
      createdAt: now,
      newId: (_) => idGenerator.newId(),
    );
    await menuSetRepository.upsert(menuSet);
    return menuSet;
  }

  Future<MenuSet> addRecipeToDraft({
    required String recipeId,
    required String mealSlot,
    int dayIndex = 2,
  }) async {
    final now = clock.now();
    final id = idGenerator.newId();
    final dayId = idGenerator.newId();
    final entryId = idGenerator.newId();
    final days = _sampleDays(id)
        .map(
          (day) => day.dayIndex == dayIndex
              ? MenuSetDay(
                  id: dayId,
                  menuSetId: id,
                  dayIndex: dayIndex,
                  label: day.label,
                  entries: [
                    ...day.entries,
                    MenuSetEntry(
                      id: entryId,
                      menuSetDayId: dayId,
                      mealSlot: mealSlot,
                      recipeId: recipeId,
                      orderInSlot: day.entries.length,
                    ),
                  ],
                )
              : day,
        )
        .toList(growable: false);
    final menuSet = MenuSet(
      id: id,
      householdId: householdId,
      name: 'Cosy autumn week',
      description: 'Edited in the menu set editor.',
      lengthInDays: 7,
      createdAt: now,
      updatedAt: now,
      days: days,
    );
    await menuSetRepository.upsert(menuSet);
    return menuSet;
  }

  Future<MenuSet> removeEntryFromDraft({required String entryId}) async {
    final now = clock.now();
    final id = idGenerator.newId();
    final days = _sampleDays(id)
        .map(
          (day) => MenuSetDay(
            id: day.id,
            menuSetId: day.menuSetId,
            dayIndex: day.dayIndex,
            label: day.label,
            entries: [
              for (final entry in day.entries)
                if (entry.id != entryId) entry,
            ],
          ),
        )
        .toList(growable: false);
    final menuSet = MenuSet(
      id: id,
      householdId: householdId,
      name: 'Cosy autumn week',
      description: 'Edited in the menu set editor.',
      lengthInDays: 7,
      createdAt: now,
      updatedAt: now,
      days: days,
    );
    await menuSetRepository.upsert(menuSet);
    return menuSet;
  }

  List<MenuSetDay> _sampleDays(String menuSetId) {
    const recipes = <int, (String, String, String)>{
      0: ('Lentil dal', 'braise', 'Dinner'),
      1: ('Roast chicken', 'roast-chicken', 'Dinner'),
      3: ('Salmon traybake', 'salmon-traybake', 'Dinner'),
      4: ('Chilli pasta', 'chilli-pasta', 'Dinner'),
    };
    return [
      for (var i = 0; i < 7; i++)
        MenuSetDay(
          id: 'menu-day-$i',
          menuSetId: menuSetId,
          dayIndex: i,
          label: 'Day ${i + 1}',
          entries: [
            if (recipes[i] case final recipe?)
              MenuSetEntry(
                id: 'menu-entry-$i',
                menuSetDayId: 'menu-day-$i',
                mealSlot: recipe.$3,
                recipeId: recipe.$2,
                orderInSlot: 0,
              ),
          ],
        ),
    ];
  }
}

class MenuSetApplyPersistenceController {
  const MenuSetApplyPersistenceController({
    required this.calendarRepository,
    required this.shoppingRepository,
    required this.householdId,
    required this.idGenerator,
    required this.clock,
  });

  final CalendarRepository calendarRepository;
  final ShoppingRepository shoppingRepository;
  final String householdId;
  final IdGenerator idGenerator;
  final Clock clock;

  Future<void> persistApplication({
    required MenuSetApplicationResult result,
    required ShoppingListPlan? shoppingList,
  }) async {
    for (final entry in result.removedEntries) {
      await calendarRepository.deleteMeal(
        householdId: householdId,
        entryId: entry.id,
      );
    }
    for (final entry in result.createdEntries) {
      await calendarRepository.upsertMeal(
        householdId: householdId,
        entry: entry,
      );
    }
    if (shoppingList != null) {
      await shoppingRepository.upsertList(_toRecord(shoppingList));
    }
  }

  ShoppingListRecord _toRecord(ShoppingListPlan plan) {
    final now = clock.now();
    return ShoppingListRecord(
      id: plan.id,
      householdId: householdId,
      type: plan.type,
      shoppingDate: plan.type == ShoppingListType.scheduled
          ? plan.endDate
          : now,
      generatedForRangeStart: plan.startDate,
      generatedForRangeEnd: plan.endDate,
      status: ShoppingListStatus.pending,
      createdAt: now,
      updatedAt: now,
      items: [
        for (final item in plan.items)
          ShoppingListItemRecord(
            id: idGenerator.newId(),
            shoppingListId: plan.id,
            ingredientId: item.ingredientId,
            quantityNeeded: item.quantity,
            unit: item.unit,
            status: ShoppingListItemStatus.unchecked,
            sourceMealLinks: item.sourceMealLinks,
          ),
      ],
    );
  }
}

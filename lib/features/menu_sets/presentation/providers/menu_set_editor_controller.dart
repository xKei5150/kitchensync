import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/core/utils/clock.dart';
import 'package:kitchensync/core/utils/id_generator.dart';
import 'package:kitchensync/features/calendar/domain/repositories/calendar_repository.dart';
import 'package:kitchensync/features/household/domain/entities/household_policy_models.dart';
import 'package:kitchensync/features/household/domain/services/household_policy.dart';
import 'package:kitchensync/features/menu_sets/domain/entities/menu_set.dart';
import 'package:kitchensync/features/menu_sets/domain/repositories/menu_set_repository.dart';

class MenuSetEditorController {
  const MenuSetEditorController({
    required this.calendarRepository,
    required this.menuSetRepository,
    required this.householdId,
    this.household,
    required this.userId,
    required this.idGenerator,
    required this.clock,
  });

  final CalendarRepository calendarRepository;
  final MenuSetRepository menuSetRepository;
  final String householdId;
  final ActiveHouseholdContext? household;
  final String userId;
  final IdGenerator idGenerator;
  final Clock clock;
  static const _draftFactory = MenuSetDraftFactory();
  static const _policy = HouseholdPolicy();

  Future<MenuSet> saveDraft({
    String name = 'New menu set',
    String? description = 'Saved from the menu set editor.',
    List<MenuSetDay>? days,
  }) async {
    _require(HouseholdCapability.createMenuSets);
    _requirePremium(HouseholdCapability.createMenuSets);
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
      days: days ?? _emptyDays(id),
    );
    await menuSetRepository.upsert(menuSet);
    return menuSet;
  }

  Future<MenuSet> createFromPastCalendar({
    required DateTime startDate,
    required DateTime endDate,
    String name = 'Saved calendar week',
  }) async {
    _require(HouseholdCapability.createMenuSetsFromPastCalendar);
    _requirePremium(HouseholdCapability.createMenuSetsFromPastCalendar);
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
    required MenuSet draft,
    required String recipeId,
    required String mealSlot,
    int dayIndex = 2,
  }) async {
    _require(HouseholdCapability.editMenuSets);
    _requirePremium(HouseholdCapability.editMenuSets);
    final now = clock.now();
    final entryId = idGenerator.newId();
    final days = draft.days.isEmpty ? _emptyDays(draft.id) : draft.days;
    final updatedDays = [
      for (final day in days)
        if (day.dayIndex == dayIndex)
          MenuSetDay(
            id: day.id,
            menuSetId: draft.id,
            dayIndex: day.dayIndex,
            label: day.label,
            entries: [
              ...day.entries,
              MenuSetEntry(
                id: entryId,
                menuSetDayId: day.id,
                mealSlot: mealSlot,
                recipeId: recipeId,
                orderInSlot: day.entries.length,
              ),
            ],
          )
        else
          day,
    ];
    final menuSet = _copyMenuSet(draft, updatedAt: now, days: updatedDays);
    await menuSetRepository.upsert(menuSet);
    return menuSet;
  }

  Future<MenuSet> removeEntryFromDraft({
    required MenuSet draft,
    required String entryId,
  }) async {
    _require(HouseholdCapability.editMenuSets);
    _requirePremium(HouseholdCapability.editMenuSets);
    final now = clock.now();
    final days = draft.days
        .map(
          (day) => MenuSetDay(
            id: day.id,
            menuSetId: draft.id,
            dayIndex: day.dayIndex,
            label: day.label,
            entries: [
              for (final entry in day.entries)
                if (entry.id != entryId) entry,
            ],
          ),
        )
        .toList(growable: false);
    final menuSet = _copyMenuSet(draft, updatedAt: now, days: days);
    await menuSetRepository.upsert(menuSet);
    return menuSet;
  }

  List<MenuSetDay> _emptyDays(String menuSetId) {
    return [
      for (var i = 0; i < 7; i++)
        MenuSetDay(
          id: idGenerator.newId(),
          menuSetId: menuSetId,
          dayIndex: i,
          label: 'Day ${i + 1}',
          entries: const [],
        ),
    ];
  }

  MenuSet _copyMenuSet(
    MenuSet menuSet, {
    required DateTime updatedAt,
    required List<MenuSetDay> days,
  }) {
    return MenuSet(
      id: menuSet.id,
      householdId: menuSet.householdId,
      name: menuSet.name,
      description: menuSet.description,
      lengthInDays: menuSet.lengthInDays,
      createdByUserId: menuSet.createdByUserId,
      createdAt: menuSet.createdAt,
      updatedAt: updatedAt,
      days: List.unmodifiable(days),
    );
  }

  void _require(HouseholdCapability capability) {
    final household = this.household;
    if (household == null) return;
    if (!_policy.roleCan(
      household.role,
      capability,
      isSoloHousehold: household.isSolo,
    )) {
      throw StateError('${household.role.label} cannot ${capability.name}.');
    }
  }

  void _requirePremium(HouseholdCapability capability) {
    final household = this.household;
    if (household == null) return;
    if (!_policy.canUsePremiumCapability(
      householdHasPremium: household.hasPremium,
      capability: capability,
    )) {
      throw StateError('Premium is required for ${capability.name}.');
    }
  }
}

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
    int lengthInDays = 7,
    List<MenuSetDay>? days,
  }) async {
    _require(HouseholdCapability.createMenuSets);
    _requirePremium(HouseholdCapability.createMenuSets);
    final normalizedName = name.trim();
    final requestedLength = days?.length ?? lengthInDays;
    if (normalizedName.isEmpty || normalizedName.length > 120) {
      throw ArgumentError.value(
        name,
        'name',
        'Menu set name must contain 1 to 120 characters.',
      );
    }
    if (requestedLength < 1 || requestedLength > 365) {
      throw ArgumentError.value(
        requestedLength,
        'lengthInDays',
        'Menu set length must be between 1 and 365 days.',
      );
    }
    if (description != null && description.length > 1000) {
      throw ArgumentError.value(
        description,
        'description',
        'Menu set description cannot exceed 1000 characters.',
      );
    }
    final now = clock.now();
    final id = idGenerator.newId();
    final menuSet = MenuSet(
      id: id,
      householdId: householdId,
      name: normalizedName,
      description: description,
      lengthInDays: requestedLength,
      createdByUserId: userId,
      createdAt: now,
      updatedAt: now,
      days: _freezeDays(days ?? _emptyDays(id, requestedLength)),
    );
    await menuSetRepository.upsert(menuSet);
    return menuSet;
  }

  /// Defensively copies caller-supplied day/entry structure so that later
  /// mutation of the original growable lists cannot alter the persisted set.
  List<MenuSetDay> _freezeDays(List<MenuSetDay> days) {
    return List.unmodifiable([
      for (final day in days) _copyDay(day, entries: List.of(day.entries)),
    ]);
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
    final days = draft.days.isEmpty
        ? _emptyDays(draft.id, draft.lengthInDays)
        : draft.days;
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

  Future<MenuSet> renameDay({
    required MenuSet draft,
    required int dayIndex,
    required String label,
  }) async {
    _requireMenuSetEdit();
    _requireDay(draft, dayIndex);
    final normalized = label.trim();
    if (normalized.isEmpty || normalized.length > 80) {
      throw ArgumentError.value(
        label,
        'label',
        'Day label must contain 1 to 80 characters.',
      );
    }
    return _persistDays(draft, [
      for (final day in draft.days)
        if (day.dayIndex == dayIndex) _copyDay(day, label: normalized) else day,
    ]);
  }

  Future<MenuSet> clearDay({
    required MenuSet draft,
    required int dayIndex,
  }) async {
    _requireMenuSetEdit();
    _requireDay(draft, dayIndex);
    return _persistDays(draft, [
      for (final day in draft.days)
        if (day.dayIndex == dayIndex) _copyDay(day, entries: const []) else day,
    ]);
  }

  Future<MenuSet> moveEntry({
    required MenuSet draft,
    required String sourceDayId,
    required String entryId,
    required int targetDayIndex,
    required String targetMealSlot,
    required int targetOrder,
  }) async {
    _requireMenuSetEdit();
    _requireDay(draft, targetDayIndex);
    if (targetOrder < 0) {
      throw ArgumentError.value(
        targetOrder,
        'targetOrder',
        'Target order cannot be negative.',
      );
    }
    final slot = targetMealSlot.trim();
    if (slot.isEmpty || slot.length > 80) {
      throw ArgumentError.value(
        targetMealSlot,
        'targetMealSlot',
        'Meal slot must contain 1 to 80 characters.',
      );
    }
    // Menu set entry IDs are only unique within a single day, so the entry
    // being moved must be located by its owning day rather than by scanning
    // every day for a matching ID.
    MenuSetEntry? moving;
    for (final day in draft.days) {
      if (day.id != sourceDayId) continue;
      for (final entry in day.entries) {
        if (entry.id == entryId) moving = entry;
      }
    }
    if (moving == null) {
      throw StateError(
        'Menu set entry $entryId was not found in day $sourceDayId.',
      );
    }
    final daysWithoutEntry = [
      for (final day in draft.days)
        if (day.id == sourceDayId)
          _copyDay(
            day,
            entries: [
              for (final entry in day.entries)
                if (entry.id != entryId) entry,
            ],
          )
        else
          day,
    ];
    final updatedDays = [
      for (final day in daysWithoutEntry)
        if (day.dayIndex == targetDayIndex)
          _insertEntry(day, moving, slot, targetOrder)
        else
          _normalizeOrders(day),
    ];
    return _persistDays(draft, updatedDays);
  }

  Future<MenuSet> duplicateDay({
    required MenuSet draft,
    required int dayIndex,
  }) async {
    _requireMenuSetEdit();
    final source = _requireDay(draft, dayIndex);
    if (draft.lengthInDays >= 365) {
      throw StateError('Menu sets cannot contain more than 365 days.');
    }
    final dayId = idGenerator.newId();
    final duplicate = MenuSetDay(
      id: dayId,
      menuSetId: draft.id,
      dayIndex: dayIndex + 1,
      label: source.label,
      entries: [
        for (final entry in source.entries)
          MenuSetEntry(
            id: idGenerator.newId(),
            menuSetDayId: dayId,
            mealSlot: entry.mealSlot,
            recipeId: entry.recipeId,
            orderInSlot: entry.orderInSlot,
          ),
      ],
    );
    // Insert the copy immediately after the source day and shift only the
    // later days forward by one, preserving any sparse cycle gaps rather than
    // compacting indices.
    final days = <MenuSetDay>[];
    for (final day in draft.days) {
      if (day.dayIndex > dayIndex) {
        days.add(_copyDay(day, dayIndex: day.dayIndex + 1));
      } else {
        days.add(day);
      }
    }
    days
      ..add(duplicate)
      ..sort((a, b) => a.dayIndex.compareTo(b.dayIndex));
    return _persistDays(
      draft,
      days,
      lengthInDays: draft.lengthInDays + 1,
    );
  }

  Future<MenuSet> _persistDays(
    MenuSet draft,
    List<MenuSetDay> days, {
    int? lengthInDays,
  }) async {
    _requireMenuSetEdit();
    final menuSet = _copyMenuSet(
      draft,
      updatedAt: clock.now(),
      days: days,
      lengthInDays: lengthInDays,
    );
    await menuSetRepository.upsert(menuSet);
    return menuSet;
  }

  MenuSetDay _insertEntry(
    MenuSetDay day,
    MenuSetEntry entry,
    String mealSlot,
    int targetOrder,
  ) {
    final inSlot = day.entries
        .where((value) => value.mealSlot == mealSlot)
        .toList();
    final index = targetOrder.clamp(0, inSlot.length);
    inSlot.insert(
      index,
      MenuSetEntry(
        id: entry.id,
        menuSetDayId: day.id,
        mealSlot: mealSlot,
        recipeId: entry.recipeId,
        orderInSlot: index,
      ),
    );
    final other = day.entries.where((value) => value.mealSlot != mealSlot);
    return _normalizeOrders(_copyDay(day, entries: [...other, ...inSlot]));
  }

  MenuSetDay _normalizeOrders(MenuSetDay day) {
    final counts = <String, int>{};
    return _copyDay(
      day,
      entries: [
        for (final entry in day.entries)
          MenuSetEntry(
            id: entry.id,
            menuSetDayId: day.id,
            mealSlot: entry.mealSlot,
            recipeId: entry.recipeId,
            orderInSlot: counts.update(
              entry.mealSlot,
              (value) => value + 1,
              ifAbsent: () => 0,
            ),
          ),
      ],
    );
  }

  MenuSetDay _copyDay(
    MenuSetDay day, {
    int? dayIndex,
    String? label,
    List<MenuSetEntry>? entries,
  }) => MenuSetDay(
    id: day.id,
    menuSetId: day.menuSetId,
    dayIndex: dayIndex ?? day.dayIndex,
    label: label ?? day.label,
    entries: List.unmodifiable(entries ?? day.entries),
  );

  List<MenuSetDay> _emptyDays(String menuSetId, int lengthInDays) {
    return [
      for (var i = 0; i < lengthInDays; i++)
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
    int? lengthInDays,
  }) {
    return MenuSet(
      id: menuSet.id,
      householdId: menuSet.householdId,
      name: menuSet.name,
      description: menuSet.description,
      lengthInDays: lengthInDays ?? menuSet.lengthInDays,
      createdByUserId: menuSet.createdByUserId,
      createdAt: menuSet.createdAt,
      updatedAt: updatedAt,
      isPublicTemplate: menuSet.isPublicTemplate,
      days: List.unmodifiable(days),
    );
  }

  void _requireMenuSetEdit() {
    _require(HouseholdCapability.editMenuSets);
    _requirePremium(HouseholdCapability.editMenuSets);
  }

  MenuSetDay _requireDay(MenuSet draft, int dayIndex) {
    final day = draft.dayAt(dayIndex);
    if (day == null) {
      throw StateError('Menu set day $dayIndex was not found.');
    }
    return day;
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

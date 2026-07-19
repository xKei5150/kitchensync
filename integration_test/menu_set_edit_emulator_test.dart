import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/core/session/debug_household_session.dart';
import 'package:kitchensync/core/utils/clock.dart';
import 'package:kitchensync/core/utils/id_generator.dart';
import 'package:kitchensync/features/calendar/domain/entities/meal_schedule.dart';
import 'package:kitchensync/features/calendar/presentation/providers/calendar_repository_providers.dart';
import 'package:kitchensync/features/household/domain/entities/household_policy_models.dart';
import 'package:kitchensync/features/menu_sets/domain/entities/menu_set.dart';
import 'package:kitchensync/features/menu_sets/presentation/providers/menu_set_repository_providers.dart';

import '_helpers.dart';

MenuSetEditorController _editor(
  ProviderContainer container, {
  required String householdId,
  required String userId,
  required List<String> ids,
  required DateTime clockNow,
}) {
  return MenuSetEditorController(
    calendarRepository: container.read(calendarRepositoryProvider),
    menuSetRepository: container.read(menuSetRepositoryProvider),
    householdId: householdId,
    household: ActiveHouseholdContext(
      id: householdId,
      name: 'Menu QA kitchen',
      role: HouseholdRole.admin,
      isJoint: true,
      hasPremium: true,
    ),
    userId: userId,
    idGenerator: FakeIdGenerator(ids),
    clock: FakeClock(clockNow),
  );
}

/// Menu Sets are a Premium feature: `canManageMenuSets` in the rules requires
/// the household document's `hasPremium == true`. The debug bootstrap creates a
/// free household, so the test upgrades it to Premium through the emulator
/// admin surface before exercising the controller (the client-side context
/// alone does not satisfy the rules boundary).
Future<void> _upgradeHouseholdToPremium({
  required String uid,
  required String householdId,
  required DateTime now,
}) async {
  await seedFirestoreDocumentsThroughEmulatorAdmin({
    'households/$householdId': {
      'name': 'Debug kitchen',
      'creatorUserId': uid,
      'isJoint': false,
      'hasPremium': true,
      'maxMembers': 1,
      'memberCount': 1,
      'updatedAt': now,
    },
  });
}

MealScheduleEntry _meal({
  required String id,
  required String recipeId,
  required DateTime date,
  required String mealLabel,
  ScheduledMealState state = ScheduledMealState.scheduled,
}) {
  return MealScheduleEntry(
    id: id,
    recipeId: recipeId,
    date: date,
    mealLabel: mealLabel,
    servingSize: 2,
    state: state,
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'menu set from past calendar normalizes days and drops cancelled',
    (tester) async {
    await bootEmulatedApp();
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final householdId = debugHouseholdIdForUser(uid);
    await withTimeout(
      'upgrade household to premium',
      () => _upgradeHouseholdToPremium(
        uid: uid,
        householdId: householdId,
        now: DateTime(2026, 7, 5),
      ),
    );
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final calendar = container.read(calendarRepositoryProvider);
    final day1 = DateTime(2026, 7, 6);
    final day2 = DateTime(2026, 7, 7);

    await withTimeout('seed day1 dinner', () => calendar.upsertMeal(
      householdId: householdId,
      entry: _meal(id: 'm1', recipeId: 'r1', date: day1, mealLabel: 'Dinner'),
    ));
    await withTimeout('seed day1 lunch', () => calendar.upsertMeal(
      householdId: householdId,
      entry: _meal(id: 'm2', recipeId: 'r2', date: day1, mealLabel: 'Lunch'),
    ));
    await withTimeout('seed day1 cancelled', () => calendar.upsertMeal(
      householdId: householdId,
      entry: _meal(
        id: 'm3',
        recipeId: 'r3',
        date: day1,
        mealLabel: 'Breakfast',
        state: ScheduledMealState.cancelled,
      ),
    ));
    await withTimeout('seed day2 dinner', () => calendar.upsertMeal(
      householdId: householdId,
      entry: _meal(id: 'm4', recipeId: 'r4', date: day2, mealLabel: 'Dinner'),
    ));

    final editor = _editor(
      container,
      householdId: householdId,
      userId: uid,
      ids: List.generate(20, (i) => 'past-$i'),
      clockNow: DateTime(2026, 7, 10, 9),
    );
    final created = await withTimeout(
      'create menu set from past calendar',
      () => editor.createFromPastCalendar(startDate: day1, endDate: day2),
    );

    final repo = container.read(menuSetRepositoryProvider);
    final loaded = await withTimeout(
      'reload created menu set',
      () => repo
          .watchById(householdId: householdId, menuSetId: created.id)
          .firstWhere((m) => m != null),
    );
    expect(loaded!.lengthInDays, 2);
    final d0 = loaded.dayAt(0)!;
    final d1 = loaded.dayAt(1)!;
    // Day 1 kept its two active meals; the cancelled breakfast was dropped.
    expect(d0.entries, hasLength(2));
    expect(d0.entries.map((e) => e.recipeId).toSet(), {'r1', 'r2'});
    expect(d0.entries.map((e) => e.recipeId), isNot(contains('r3')));
    expect(d1.entries, hasLength(1));
    expect(d1.entries.single.recipeId, 'r4');
  });

  testWidgets('day-structure edits persist through the repository', (
    tester,
  ) async {
    await bootEmulatedApp();
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final householdId = debugHouseholdIdForUser(uid);
    await withTimeout(
      'upgrade household to premium',
      () => _upgradeHouseholdToPremium(
        uid: uid,
        householdId: householdId,
        now: DateTime(2026, 7, 5),
      ),
    );
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final repo = container.read(menuSetRepositoryProvider);

    final editor = _editor(
      container,
      householdId: householdId,
      userId: uid,
      ids: ['edit-set', ...List.generate(20, (i) => 'edit-$i')],
      clockNow: DateTime(2026, 7, 10, 9),
    );

    var draft = await withTimeout(
      'save 3-day draft',
      () => editor.saveDraft(name: 'Editable rotation', lengthInDays: 3),
    );

    draft = await withTimeout(
      'rename day 0',
      () => editor.renameDay(draft: draft, dayIndex: 0, label: 'Feast day'),
    );
    draft = await withTimeout(
      'duplicate day 0',
      () => editor.duplicateDay(draft: draft, dayIndex: 0),
    );

    final loaded = await withTimeout(
      'reload edited menu set',
      () => repo
          .watchById(householdId: householdId, menuSetId: draft.id)
          .firstWhere((m) => m != null && m.lengthInDays == 4),
    );
    expect(loaded!.lengthInDays, 4);
    expect(loaded.dayAt(0)!.label, 'Feast day');
    // The duplicate lands at index 1 carrying the source label.
    expect(loaded.dayAt(1)!.label, 'Feast day');
  });

  testWidgets(
    'duplicating persists an independent copy authored by the actor',
    (tester) async {
    await bootEmulatedApp();
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final householdId = debugHouseholdIdForUser(uid);
    await withTimeout(
      'upgrade household to premium',
      () => _upgradeHouseholdToPremium(
        uid: uid,
        householdId: householdId,
        now: DateTime(2026, 7, 5),
      ),
    );
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final repo = container.read(menuSetRepositoryProvider);
    final editor = _editor(
      container,
      householdId: householdId,
      userId: uid,
      ids: ['dup-source', ...List.generate(20, (i) => 'dup-$i')],
      clockNow: DateTime(2026, 7, 10, 9),
    );

    // Persist a source set, then add a recipe so it has nested content.
    var source = await withTimeout(
      'save source set',
      () => editor.saveDraft(name: 'Rotation', lengthInDays: 2),
    );
    source = await withTimeout(
      'add recipe to source day 0',
      () => editor.addRecipeToDraft(
        draft: source,
        recipeId: 'braise',
        mealSlot: 'Dinner',
        dayIndex: 0,
      ),
    );

    // Duplicate through the real production path (screen delegates to this).
    final copy = const MenuSetDraftFactory().duplicate(
      source: source,
      suffix: 99,
      createdByUserId: uid,
      now: DateTime(2026, 7, 10, 10),
    );
    await withTimeout('persist duplicate', () => repo.upsert(copy));

    final loadedCopy = await withTimeout(
      'reload duplicate',
      () => repo
          .watchById(householdId: householdId, menuSetId: copy.id)
          .firstWhere((m) => m != null),
    );
    expect(loadedCopy!.name, 'Rotation copy');
    expect(loadedCopy.createdByUserId, uid);
    expect(loadedCopy.dayAt(0)!.entries.single.recipeId, 'braise');

    // Independence: rename the COPY's day; the SOURCE must be unaffected.
    await withTimeout(
      'rename copy day 0',
      () => editor.renameDay(draft: loadedCopy, dayIndex: 0, label: 'Copy day'),
    );
    final sourceAfter = await withTimeout(
      'reload source after copy edit',
      () => repo
          .watchById(householdId: householdId, menuSetId: source.id)
          .firstWhere((m) => m != null),
    );
    expect(sourceAfter!.dayAt(0)!.label, isNot('Copy day'));
    expect(sourceAfter.dayAt(0)!.entries.single.recipeId, 'braise');
  });

  testWidgets('move and clear day operations persist through the repository', (
    tester,
  ) async {
    await bootEmulatedApp();
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final householdId = debugHouseholdIdForUser(uid);
    await withTimeout(
      'upgrade household to premium',
      () => _upgradeHouseholdToPremium(
        uid: uid,
        householdId: householdId,
        now: DateTime(2026, 7, 5),
      ),
    );
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final repo = container.read(menuSetRepositoryProvider);
    final editor = _editor(
      container,
      householdId: householdId,
      userId: uid,
      ids: ['move-set', ...List.generate(20, (i) => 'move-$i')],
      clockNow: DateTime(2026, 7, 10, 9),
    );

    var draft = await withTimeout(
      'save 2-day draft',
      () => editor.saveDraft(name: 'Movable rotation', lengthInDays: 2),
    );
    draft = await withTimeout(
      'add soup to day 0 dinner',
      () => editor.addRecipeToDraft(
        draft: draft,
        recipeId: 'soup',
        mealSlot: 'Dinner',
        dayIndex: 0,
      ),
    );
    draft = await withTimeout(
      'add salad to day 1 lunch',
      () => editor.addRecipeToDraft(
        draft: draft,
        recipeId: 'salad',
        mealSlot: 'Lunch',
        dayIndex: 1,
      ),
    );

    // Move the day-0 soup entry to day 1. Locate ids from the live draft so the
    // test does not depend on the FakeIdGenerator emission order.
    final sourceDay = draft.dayAt(0)!;
    final movingEntryId = sourceDay.entries.single.id;
    draft = await withTimeout(
      'move soup from day 0 to day 1',
      () => editor.moveEntry(
        draft: draft,
        sourceDayId: sourceDay.id,
        entryId: movingEntryId,
        targetDayIndex: 1,
        targetMealSlot: 'Dinner',
        targetOrder: 1,
      ),
    );

    final afterMove = await withTimeout(
      'reload after move',
      () => repo
          .watchById(householdId: householdId, menuSetId: draft.id)
          .firstWhere((m) => m != null && m.dayAt(0)!.entries.isEmpty),
    );
    // Day 0 is now empty; day 1 holds both salad and the moved soup.
    expect(afterMove!.dayAt(0)!.entries, isEmpty);
    expect(afterMove.dayAt(1)!.entries.map((e) => e.recipeId).toSet(), {
      'salad',
      'soup',
    });

    // Clear day 1 and confirm the emptied day persists on reload.
    draft = await withTimeout(
      'clear day 1',
      () => editor.clearDay(draft: afterMove, dayIndex: 1),
    );
    final afterClear = await withTimeout(
      'reload after clear',
      () => repo
          .watchById(householdId: householdId, menuSetId: draft.id)
          .firstWhere((m) => m != null && m.dayAt(1)!.entries.isEmpty),
    );
    expect(afterClear!.dayAt(1)!.entries, isEmpty);
    expect(afterClear.lengthInDays, 2);
  });
}

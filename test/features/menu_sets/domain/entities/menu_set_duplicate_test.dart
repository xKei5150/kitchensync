import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/features/menu_sets/domain/entities/menu_set.dart';

MenuSet _source() => const MenuSet(
  id: 'set-1',
  householdId: 'solo-household',
  name: 'Persisted week',
  description: 'Original description',
  lengthInDays: 2,
  createdByUserId: 'author-original',
  isPublicTemplate: true,
  days: [
    MenuSetDay(
      id: 'day-1',
      menuSetId: 'set-1',
      dayIndex: 0,
      label: 'Day 1',
      entries: [
        MenuSetEntry(
          id: 'entry-1',
          menuSetDayId: 'day-1',
          mealSlot: 'Dinner',
          recipeId: 'braise',
          orderInSlot: 0,
        ),
      ],
    ),
    MenuSetDay(
      id: 'day-2',
      menuSetId: 'set-1',
      dayIndex: 1,
      label: 'Day 2',
      entries: [],
    ),
  ],
);

void main() {
  const factory = MenuSetDraftFactory();
  final now = DateTime(2026, 7, 18, 9);

  test('duplicate copies structure under a new id authored by the actor', () {
    final copy = factory.duplicate(
      source: _source(),
      suffix: 42,
      createdByUserId: 'acting-user',
      now: now,
    );

    expect(copy.id, 'set-1-copy-42');
    expect(copy.name, 'Persisted week copy');
    expect(copy.description, 'Original description');
    expect(copy.lengthInDays, 2);
    expect(copy.isPublicTemplate, isTrue);
    expect(copy.createdByUserId, 'acting-user');
    expect(copy.createdAt, now);
    expect(copy.updatedAt, now);
    expect(copy.days, hasLength(2));

    final day0 = copy.dayAt(0)!;
    expect(day0.id, 'day-1-copy-42');
    expect(day0.menuSetId, 'set-1-copy-42');
    expect(day0.label, 'Day 1');
    expect(day0.entries, hasLength(1));
    final entry = day0.entries.single;
    expect(entry.id, 'entry-1-copy-42');
    expect(entry.menuSetDayId, 'day-1-copy-42');
    expect(entry.recipeId, 'braise');
    expect(entry.mealSlot, 'Dinner');
    expect(entry.orderInSlot, 0);
  });

  test('duplicate does not reuse any source nested ids', () {
    final source = _source();
    final copy = factory.duplicate(source: source, suffix: 7, now: now);

    final sourceIds = <String>{
      source.id,
      for (final d in source.days) ...[d.id, for (final e in d.entries) e.id],
    };
    final copyIds = <String>{
      copy.id,
      for (final d in copy.days) ...[d.id, for (final e in d.entries) e.id],
    };
    expect(sourceIds.intersection(copyIds), isEmpty);
  });
}

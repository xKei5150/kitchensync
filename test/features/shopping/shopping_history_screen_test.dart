import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kitchensync/app/theme.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/features/household/domain/entities/household_policy_models.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/shopping/domain/entities/shopping_plan.dart';
import 'package:kitchensync/features/shopping/domain/repositories/shopping_repository.dart';
import 'package:kitchensync/features/shopping/presentation/providers/shopping_repository_providers.dart';
import 'package:kitchensync/features/shopping/presentation/screens/shopping_history_screen.dart';

const _household = ActiveHouseholdContext(
  id: 'history-household',
  name: 'History kitchen',
  role: HouseholdRole.shopper,
  isJoint: true,
  hasPremium: false,
);

void main() {
  testWidgets('loads 21 completed shops across two pages without duplicates', (
    tester,
  ) async {
    final records = [for (var index = 0; index < 21; index++) _record(index)];
    final repository = _HistoryRepository([
      ShoppingHistoryPage(
        records: records.take(20).toList(),
        nextCursorId: 'p2',
      ),
      ShoppingHistoryPage(records: [records.last], nextCursorId: null),
    ]);
    await tester.pumpWidget(_app(repository));
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(
      find.byKey(const Key('completed-history-completed-00')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('completed-history-completed-20')),
      findsNothing,
    );
    expect(repository.cursors, [null]);
    await tester.scrollUntilVisible(find.text('Load more'), 300);
    expect(find.text('Load more'), findsOneWidget);

    await tester.tap(find.text('Load more'));
    await tester.pump();
    await tester.pump();
    await tester.pump();

    await tester.scrollUntilVisible(find.text('Completed shops'), -300);
    expect(find.text('Completed shops'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('completed-history-completed-20')),
      300,
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('completed-history-completed-20')),
      300,
    );
    expect(
      find.byKey(const Key('completed-history-completed-20')),
      findsOneWidget,
    );
    expect(repository.cursors, [null, 'p2']);
  });

  testWidgets('shows empty state and retries an initial error', (tester) async {
    final repository = _HistoryRepository([
      const ShoppingHistoryPage(records: [], nextCursorId: null),
    ], failFirst: true);
    await tester.pumpWidget(_app(repository));
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(
      find.textContaining('Could not load completed shops'),
      findsOneWidget,
    );
    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.text('No completed shops yet'), findsOneWidget);
  });

  testWidgets('tapping a completed row opens its immutable list route', (
    tester,
  ) async {
    final repository = _HistoryRepository([
      ShoppingHistoryPage(records: [_record(0)], nextCursorId: null),
    ]);
    final router = GoRouter(
      initialLocation: '/shop/history',
      routes: [
        GoRoute(
          path: '/shop/history',
          builder: (_, _) => const ShoppingHistoryScreen(),
        ),
        GoRoute(
          path: '/shop/list/:listId',
          builder: (_, state) =>
              Text('detail ${state.pathParameters['listId']}'),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides(repository),
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byKey(const Key('completed-history-completed-00')));
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.text('detail completed-00'), findsOneWidget);
  });
}

Widget _app(ShoppingRepository repository) => ProviderScope(
  overrides: _overrides(repository),
  child: MaterialApp(
    theme: AppTheme.light(),
    home: const ShoppingHistoryScreen(),
  ),
);

List<Override> _overrides(ShoppingRepository repository) => [
  activeHouseholdContextProvider.overrideWithValue(_household),
  activeHouseholdIdProvider.overrideWithValue(_household.id),
  shoppingRepositoryProvider.overrideWithValue(repository),
];

ShoppingListRecord _record(int index) {
  final date = DateTime(2026, 7, 10, 9).subtract(Duration(minutes: index));
  return ShoppingListRecord(
    id: 'completed-${index.toString().padLeft(2, '0')}',
    householdId: _household.id,
    type: ShoppingListType.shopNow,
    shoppingDate: date,
    generatedForRangeStart: date,
    generatedForRangeEnd: date,
    status: ShoppingListStatus.completed,
    completedAt: date,
    completedByUserId: 'member-1',
    createdAt: date,
    updatedAt: date,
    items: [
      ShoppingListItemRecord(
        id: 'item-$index',
        shoppingListId: 'completed-$index',
        ingredientId: 'tomato',
        quantityNeeded: 1,
        unit: UnitId.g,
        status: ShoppingListItemStatus.bought,
        purchasedQuantity: 1,
        sourceMealLinks: const [],
      ),
    ],
  );
}

class _HistoryRepository extends ShoppingRepository {
  _HistoryRepository(this.pages, {this.failFirst = false});

  final List<ShoppingHistoryPage> pages;
  final bool failFirst;
  final cursors = <String?>[];
  var _attempts = 0;
  var _pageIndex = 0;

  @override
  Future<ShoppingHistoryPage> loadCompletedHistory(
    String householdId, {
    String? afterListId,
  }) async {
    cursors.add(afterListId);
    if (failFirst && _attempts++ == 0) throw StateError('network unavailable');
    return pages[_pageIndex++];
  }

  @override
  Stream<ShoppingListRecord?> watchList({
    required String householdId,
    required String listId,
  }) => Stream.value(null);

  @override
  Stream<List<ShoppingListRecord>> watchLists(String householdId) =>
      Stream.value(const []);
}

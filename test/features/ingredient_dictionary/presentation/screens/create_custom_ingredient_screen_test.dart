import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kitchensync/app/theme.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/ingredient.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/repositories/ingredient_repository.dart';
import 'package:kitchensync/features/ingredient_dictionary/presentation/providers/ingredient_providers.dart';
import 'package:kitchensync/features/ingredient_dictionary/presentation/screens/create_custom_ingredient_screen.dart';

class _CapturingIngredientRepository implements IngredientRepository {
  final List<Ingredient> created = [];

  @override
  Future<void> createCustom(Ingredient ingredient) async {
    created.add(ingredient);
  }

  @override
  Future<Ingredient?> getById(String id, {String? householdId}) async => null;

  @override
  Future<List<Ingredient>> listVariantsOf(String parentId) async =>
      const <Ingredient>[];

  @override
  Future<List<Ingredient>> search({
    required String query,
    String? householdId,
    int limit = 30,
    String? startAfterId,
  }) async => const <Ingredient>[];

  @override
  Future<void> updateCustom(Ingredient ingredient) async {}

  @override
  Future<int> upsertSeed(List<Ingredient> seed) async => seed.length;

  @override
  Stream<List<Ingredient>> watchByBarcode(String barcode) =>
      const Stream<List<Ingredient>>.empty();

  @override
  Stream<List<Ingredient>> watchByIds(List<String> ids) =>
      const Stream<List<Ingredient>>.empty();
}

void main() {
  Future<void> pump(
    WidgetTester tester,
    ThemeData theme, {
    String? initialName,
    _CapturingIngredientRepository? repository,
  }) async {
    tester.view.physicalSize = const Size(400, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = GoRouter(
      initialLocation: '/create',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(body: Text('Done')),
          routes: [
            GoRoute(
              path: 'create',
              builder: (context, state) =>
                  CreateCustomIngredientScreen(initialName: initialName),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          if (repository != null) ...[
            activeHouseholdIdProvider.overrideWithValue('household-1'),
            ingredientRepositoryProvider.overrideWithValue(repository),
          ],
        ],
        child: MaterialApp.router(theme: theme, routerConfig: router),
      ),
    );
    await tester.pump();
  }

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pump();
    await tester.tap(finder);
    await tester.pump();
  }

  Finder localUnitField() => find.byWidgetPredicate(
    (widget) =>
        widget is TextField && widget.decoration?.hintText == 'e.g. tray',
  );

  testWidgets('renders the identity preview and core fields', (tester) async {
    await pump(tester, AppTheme.light());

    expect(find.text('Add to catalog'), findsOneWidget);
    expect(find.text('NAME'), findsOneWidget);
    expect(find.text('CATEGORY — SETS THE COLOUR EVERYWHERE'), findsOneWidget);
    // Default identity card: empty name + 7-day default shelf life.
    expect(find.text('New ingredient'), findsOneWidget);
    expect(find.textContaining('keeps ~7 days'), findsOneWidget);
    expect(find.byType(Slider), findsOneWidget);
  });

  testWidgets('identity card reflects the typed name', (tester) async {
    await pump(tester, AppTheme.light(), initialName: 'Sweet potato');
    expect(find.text('Sweet potato'), findsWidgets);
  });

  testWidgets('surfaces a summary and field error when the name is empty', (
    tester,
  ) async {
    await pump(tester, AppTheme.light());

    await tester.tap(find.widgetWithText(FilledButton, 'Create ingredient'));
    await tester.pump();

    expect(find.text('One thing needs a look'), findsOneWidget);
    expect(
      find.text('Give it a name so you can find it later.'),
      findsOneWidget,
    );
  });

  testWidgets('clears the name error live once a name is typed', (
    tester,
  ) async {
    await pump(tester, AppTheme.light());

    await tester.tap(find.widgetWithText(FilledButton, 'Create ingredient'));
    await tester.pump();
    expect(
      find.text('Give it a name so you can find it later.'),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextField).first, 'Sweet potato');
    await tester.pump();

    expect(find.text('Give it a name so you can find it later.'), findsNothing);
  });

  testWidgets('renders in dark theme without error', (tester) async {
    await pump(tester, AppTheme.dark());
    expect(tester.takeException(), isNull);
  });

  testWidgets('creates ingredient with local informal default unit', (
    tester,
  ) async {
    final repository = _CapturingIngredientRepository();
    await pump(
      tester,
      AppTheme.light(),
      initialName: 'Party platter',
      repository: repository,
    );

    await tapVisible(tester, find.widgetWithText(OutlinedButton, 'Add unit'));
    await tester.enterText(localUnitField(), 'tray');
    await tapVisible(
      tester,
      find.widgetWithText(FilledButton, 'Add local unit'),
    );
    await tapVisible(
      tester,
      find.widgetWithText(FilledButton, 'Create ingredient'),
    );
    await tester.pumpAndSettle();

    expect(repository.created, hasLength(1));
    final ingredient = repository.created.single;
    expect(ingredient.defaultUnit, UnitId('tray'));
    expect(ingredient.allowedUnits, contains(UnitId('tray')));
    expect(
      ingredient.localUnitDefinitions.map((unit) => unit.id),
      contains(UnitId('tray')),
    );
  });

  testWidgets('prevents duplicate local unit labels', (tester) async {
    final repository = _CapturingIngredientRepository();
    await pump(
      tester,
      AppTheme.light(),
      initialName: 'Soup pouch',
      repository: repository,
    );

    await tapVisible(tester, find.widgetWithText(OutlinedButton, 'Add unit'));
    await tester.enterText(localUnitField(), 'sachet');
    await tapVisible(
      tester,
      find.widgetWithText(FilledButton, 'Add local unit'),
    );
    await tapVisible(tester, find.widgetWithText(OutlinedButton, 'Add unit'));
    await tester.enterText(localUnitField(), 'sachet');
    await tapVisible(
      tester,
      find.widgetWithText(FilledButton, 'Add local unit'),
    );
    expect(find.text('A unit with this ID already exists.'), findsOneWidget);
    await tapVisible(
      tester,
      find.widgetWithText(FilledButton, 'Create ingredient'),
    );
    await tester.pumpAndSettle();

    expect(repository.created, hasLength(1));
    expect(
      repository.created.single.localUnitDefinitions.where(
        (unit) => unit.id == UnitId('sachet'),
      ),
      hasLength(1),
    );
  });
}

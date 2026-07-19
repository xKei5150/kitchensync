import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kitchensync/app/theme.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/core/utils/clock.dart';
import 'package:kitchensync/core/widgets/widgets.dart';
import 'package:kitchensync/features/calendar/domain/entities/meal_schedule.dart';
import 'package:kitchensync/features/calendar/domain/entities/shopping_schedule.dart';
import 'package:kitchensync/features/calendar/domain/repositories/calendar_repository.dart';
import 'package:kitchensync/features/calendar/domain/repositories/shopping_schedule_repository.dart';
import 'package:kitchensync/features/calendar/presentation/providers/calendar_repository_providers.dart';
import 'package:kitchensync/features/calendar/presentation/providers/shopping_schedule_providers.dart';
import 'package:kitchensync/features/calendar/presentation/screens/shopping_schedule_screen.dart';
import 'package:kitchensync/features/ingredient_dictionary/data/datasources/ingredient_seed_data_source.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/ingredient.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/repositories/ingredient_repository.dart';
import 'package:kitchensync/features/ingredient_dictionary/presentation/providers/ingredient_providers.dart';
import 'package:kitchensync/features/shopping/domain/entities/shopping_plan.dart';
import 'package:kitchensync/features/shopping/domain/repositories/shopping_repository.dart';
import 'package:kitchensync/features/shopping/presentation/providers/shopping_repository_providers.dart';
import 'package:kitchensync/features/shopping/presentation/screens/shopping_list_screen.dart';
import 'package:kitchensync/features/shopping/presentation/screens/shopping_screen.dart';
import 'package:mocktail/mocktail.dart';

class _VisualPlanningController extends Mock
    implements ShoppingPlanningController {}

class _VisualShoppingRepository extends ShoppingRepository {
  _VisualShoppingRepository({this.list});

  final ShoppingListRecord? list;

  @override
  Stream<List<ShoppingListRecord>> watchLists(String householdId) =>
      Stream.value(list == null ? const [] : [list!]);

  @override
  Stream<ShoppingListRecord?> watchList({
    required String householdId,
    required String listId,
  }) => Stream.value(list?.id == listId ? list : null);
}

class _VisualIngredientRepository implements IngredientRepository {
  const _VisualIngredientRepository(this.ingredient);

  final Ingredient ingredient;

  @override
  Future<void> createCustom(Ingredient ingredient) async {}

  @override
  Future<Ingredient?> getById(String id, {String? householdId}) async =>
      id == ingredient.id ? ingredient : null;

  @override
  Future<List<Ingredient>> listVariantsOf(String parentId) async => const [];

  @override
  Future<List<Ingredient>> search({
    required String query,
    String? householdId,
    int limit = 30,
  }) async =>
      query.isEmpty ||
          ingredient.displayNames.values.any(
            (name) => name.toLowerCase().contains(query.toLowerCase()),
          )
      ? [ingredient]
      : const [];

  @override
  Future<void> updateCustom(Ingredient ingredient) async {}

  @override
  Future<int> upsertSeed(List<Ingredient> seed) async => seed.length;

  @override
  Stream<List<Ingredient>> watchByBarcode(String barcode) =>
      Stream.value(ingredient.barcode == barcode ? [ingredient] : const []);

}

class _VisualScheduleRepository implements ShoppingScheduleRepository {
  _VisualScheduleRepository({this.saveGate, this.failSave = false});

  final Completer<void>? saveGate;
  final bool failSave;

  @override
  Future<void> save(ShoppingSchedule schedule) async {
    if (failSave) throw StateError('fixture save failure');
    await saveGate?.future;
  }

  @override
  Stream<ShoppingSchedule?> watch(String householdId) => Stream.value(null);
}

class _EmptyCalendarRepository implements CalendarRepository {
  @override
  Future<void> deleteMeal({
    required String householdId,
    required String entryId,
  }) async {}

  @override
  Future<void> upsertDaySettings(CalendarDaySettings settings) async {}

  @override
  Future<void> upsertMeal({
    required String householdId,
    required MealScheduleEntry entry,
  }) async {}

  @override
  Stream<List<CalendarDaySettings>> watchActiveDaySettings(
    String householdId,
  ) => Stream.value(const []);

  @override
  Stream<List<MealScheduleEntry>> watchMealsInRange({
    required String householdId,
    required DateTime startDate,
    required DateTime endDate,
  }) => Stream.value(const []);
}

const _household = ActiveHouseholdContext(
  id: 'visual-shopping-household',
  name: 'Visual shopping kitchen',
  role: HouseholdRole.admin,
  isJoint: true,
  hasPremium: true,
);

const _shopperHousehold = ActiveHouseholdContext(
  id: 'visual-shopping-household',
  name: 'Visual shopping kitchen',
  role: HouseholdRole.shopper,
  isJoint: true,
  hasPremium: true,
);

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const useNativeTabletSurface = bool.fromEnvironment(
    'VISUAL_NATIVE_TABLET_CAPTURE',
  );

  testWidgets('captures Shopping mobile recoverable and schedule states', (
    tester,
  ) async {
    debugPaintBaselinesEnabled = false;
    debugPaintPointersEnabled = false;
    await binding.convertFlutterSurfaceToImage();
    final preview = _preview();
    final cjkDictionaryIngredient = await _seedDictionaryCjkIngredient();
    final chineseDictionaryIngredientLabel =
        cjkDictionaryIngredient.displayNames['zh']!;
    final hangulDictionaryIngredientLabel =
        cjkDictionaryIngredient.displayNames['ko']!;

    final previewFailure = _VisualPlanningController();
    when(
      () => previewFailure.previewShopNowList(
        startDate: any(named: 'startDate'),
        endDate: any(named: 'endDate'),
      ),
    ).thenThrow(StateError('fixture preview failure'));
    await _captureShopNow(
      tester,
      binding,
      controller: previewFailure,
      surface: 'shop-now-preview-failure',
      expected: find.textContaining('Could not preview this range'),
    );
    expect(find.text('Retry'), findsOneWidget);

    final previewGate = Completer<ShoppingListPlan>();
    final previewLoading = _VisualPlanningController();
    when(
      () => previewLoading.previewShopNowList(
        startDate: any(named: 'startDate'),
        endDate: any(named: 'endDate'),
      ),
    ).thenAnswer((_) => previewGate.future);
    await _captureShopNow(
      tester,
      binding,
      controller: previewLoading,
      surface: 'shop-now-loading',
      expected: find.byType(CircularProgressIndicator),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Generate list'), findsOneWidget);
    expect(
      tester.getBottomLeft(find.byType(CircularProgressIndicator)).dy,
      lessThan(tester.view.physicalSize.height / tester.view.devicePixelRatio),
    );
    expect(
      tester.getBottomLeft(find.text('Generate list')).dy,
      lessThan(tester.view.physicalSize.height / tester.view.devicePixelRatio),
    );
    previewGate.complete(preview);

    final generationGate = Completer<ShoppingListRecord>();
    final generationLoading = _VisualPlanningController();
    _stubPreview(generationLoading, preview);
    when(
      () => generationLoading.persistShopNowPreview(preview),
    ).thenAnswer((_) => generationGate.future);
    await _captureShopNow(
      tester,
      binding,
      controller: generationLoading,
      surface: 'shop-now-generating',
      expected: find.text('Generating...'),
      tapGenerate: true,
    );
    expect(find.text('Generating...'), findsOneWidget);
    generationGate.completeError(StateError('fixture teardown'));

    final generationFailure = _VisualPlanningController();
    _stubPreview(generationFailure, preview);
    when(
      () => generationFailure.persistShopNowPreview(preview),
    ).thenThrow(StateError('fixture generation failure'));
    await _captureShopNow(
      tester,
      binding,
      controller: generationFailure,
      surface: 'shop-now-generation-failure-retry',
      expected: find.textContaining('Could not generate this list'),
      tapGenerate: true,
    );
    expect(find.textContaining('Could not generate this list'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    verify(() => generationFailure.persistShopNowPreview(preview)).called(2);

    final saveGate = Completer<void>();
    await _captureSchedule(
      tester,
      binding,
      surface: 'schedule-saving',
      repository: _VisualScheduleRepository(saveGate: saveGate),
      expected: find.byKey(const ValueKey('shopping-schedule-save')),
      tapSave: true,
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    saveGate.complete();

    await _captureSchedule(
      tester,
      binding,
      surface: 'schedule-save-error',
      repository: _VisualScheduleRepository(failSave: true),
      expected: find.byKey(const ValueKey('shopping-schedule-save')),
      tapSave: true,
    );
    expect(find.text('Could not save shopping schedule.'), findsOneWidget);

    await _captureScheduleTablet(
      tester,
      binding,
      surface: 'schedule-tablet-weekday-layout',
      repository: _VisualScheduleRepository(),
      useNativeTabletSurface: useNativeTabletSurface,
    );

    if (useNativeTabletSurface) {
      await _settleNativeDeviceFrame(tester);
      await _signalInAppCapture(signal: 1);
    }

    await _captureCjkDictionaryShoppingList(
      tester,
      binding,
      surface: 'cjk-chinese-long-labels-text-scale',
      ingredient: cjkDictionaryIngredient,
      textScaler: const TextScaler.linear(1.5),
      locale: const Locale('zh'),
      label: chineseDictionaryIngredientLabel,
    );
    expect(find.text(chineseDictionaryIngredientLabel), findsOneWidget);
    expect(find.byType(KsChecklistRow), findsOneWidget);
    expect(tester.takeException(), isNull);
    if (useNativeTabletSurface) {
      await _settleNativeDeviceFrame(tester);
      await _signalInAppCapture(signal: 2);
    }

    await _captureCjkDictionaryShoppingList(
      tester,
      binding,
      surface: 'cjk-hangul-long-labels-text-scale',
      ingredient: cjkDictionaryIngredient,
      textScaler: const TextScaler.linear(1.5),
      locale: const Locale('ko'),
      label: hangulDictionaryIngredientLabel,
    );
    expect(find.text(hangulDictionaryIngredientLabel), findsOneWidget);
    expect(find.byType(KsChecklistRow), findsOneWidget);
    expect(tester.takeException(), isNull);
    if (useNativeTabletSurface) {
      await _settleNativeDeviceFrame(tester);
    }
    await _signalInAppCapture(signal: useNativeTabletSurface ? 3 : 1);
  });
}

Future<Ingredient> _seedDictionaryCjkIngredient() async =>
    (await IngredientSeedDataSource(
      clock: FakeClock(DateTime(2026, 7, 13, 9)),
    ).load()).firstWhere((ingredient) => ingredient.id == 'onion-shallot');

void _stubPreview(
  _VisualPlanningController controller,
  ShoppingListPlan preview,
) {
  when(
    () => controller.previewShopNowList(
      startDate: any(named: 'startDate'),
      endDate: any(named: 'endDate'),
    ),
  ).thenAnswer((_) async => preview);
}

Future<void> _captureShopNow(
  WidgetTester tester,
  IntegrationTestWidgetsFlutterBinding binding, {
  required _VisualPlanningController controller,
  required String surface,
  required Finder expected,
  bool tapGenerate = false,
  TextScaler textScaler = TextScaler.noScaling,
  Locale? locale,
}) async {
  await tester.pumpWidget(
    _app(
      controller: controller,
      household: _shopperHousehold,
      appKey: ValueKey(surface),
      child: _withTextScale(const ShoppingScreen(), textScaler),
      locale: locale,
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Start a shop'));
  await tester.pump();
  if (tapGenerate) {
    await tester.pumpAndSettle();
    await tester.tap(find.text('Generate list'));
    await tester.pump();
  }
  await _capture(tester, binding, surface, expected);
}

Future<void> _captureCjkDictionaryShoppingList(
  WidgetTester tester,
  IntegrationTestWidgetsFlutterBinding binding, {
  required String surface,
  required Ingredient ingredient,
  required TextScaler textScaler,
  required Locale locale,
  required String label,
}) async {
  const listId = 'visual-cjk-dictionary-list';
  final now = DateTime(2026, 7, 13, 9);
  final list = ShoppingListRecord(
    id: listId,
    householdId: _shopperHousehold.id,
    type: ShoppingListType.shopNow,
    shoppingDate: now,
    generatedForRangeStart: now,
    generatedForRangeEnd: now,
    status: ShoppingListStatus.pending,
    createdAt: now,
    updatedAt: now,
    items: const [
      ShoppingListItemRecord(
        id: 'onion-shallot__piece',
        shoppingListId: listId,
        ingredientId: 'onion-shallot',
        quantityNeeded: 2,
        unit: UnitId.piece,
        status: ShoppingListItemStatus.unchecked,
        sourceMealLinks: [],
      ),
    ],
  );
  await tester.pumpWidget(
    _app(
      controller: _VisualPlanningController(),
      household: _shopperHousehold,
      appKey: ValueKey(surface),
      locale: locale,
      shoppingRepository: _VisualShoppingRepository(list: list),
      ingredientRepository: _VisualIngredientRepository(ingredient),
      child: _withTextScale(
        const ShoppingListScreen(listId: listId),
        textScaler,
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(find.text(label), findsOneWidget);
  expect(find.byType(KsChecklistRow), findsOneWidget);
  await _capture(tester, binding, surface, find.text(label));
}

Future<void> _captureSchedule(
  WidgetTester tester,
  IntegrationTestWidgetsFlutterBinding binding, {
  required String surface,
  required _VisualScheduleRepository repository,
  required Finder expected,
  required bool tapSave,
  bool capture = true,
}) async {
  final controller = _VisualPlanningController();
  await tester.pumpWidget(
    _app(
      controller: controller,
      scheduleRepository: repository,
      appKey: ValueKey(surface),
      child: const ShoppingScheduleScreen(),
    ),
  );
  await tester.pumpAndSettle();
  if (tapSave) {
    await tester.tap(find.byKey(const ValueKey('shopping-schedule-save')));
    await tester.pump();
  }
  if (capture) await _capture(tester, binding, surface, expected);
}

Future<void> _captureScheduleTablet(
  WidgetTester tester,
  IntegrationTestWidgetsFlutterBinding binding, {
  required String surface,
  required _VisualScheduleRepository repository,
  required bool useNativeTabletSurface,
}) async {
  if (!useNativeTabletSurface) {
    await binding.setSurfaceSize(const Size(768, 1024));
  }
  try {
    await _captureSchedule(
      tester,
      binding,
      surface: surface,
      repository: repository,
      expected: find.byKey(const ValueKey('shopping-schedule-form')),
      tapSave: false,
      capture: useNativeTabletSurface,
    );
    for (final weekday in const [
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat',
      'Sun',
    ]) {
      expect(find.text(weekday), findsOneWidget);
    }
  } finally {
    if (!useNativeTabletSurface) {
      await binding.setSurfaceSize(null);
    }
  }
}

Widget _app({
  required _VisualPlanningController controller,
  required Widget child,
  required Key appKey,
  _VisualScheduleRepository? scheduleRepository,
  _VisualShoppingRepository? shoppingRepository,
  _VisualIngredientRepository? ingredientRepository,
  ActiveHouseholdContext household = _household,
  Locale? locale,
}) => ProviderScope(
  overrides: [
    activeUserIdProvider.overrideWithValue('visual-user'),
    activeHouseholdContextProvider.overrideWithValue(household),
    clockProvider.overrideWithValue(FakeClock(DateTime(2026, 7, 13, 9))),
    shoppingRepositoryProvider.overrideWithValue(
      shoppingRepository ?? _VisualShoppingRepository(),
    ),
    ingredientRepositoryProvider.overrideWithValue(
      ingredientRepository ??
          _VisualIngredientRepository(
            Ingredient(
              id: 'visual-fallback-ingredient',
              name: 'Visual fallback ingredient',
              displayNames: const {'en': 'Visual fallback ingredient'},
              category: IngredientCategory.other,
              defaultUnit: UnitId.piece,
              allowedUnits: const [UnitId.piece],
              scope: IngredientScope.global,
              createdAt: DateTime(2026, 7, 13, 9),
              updatedAt: DateTime(2026, 7, 13, 9),
            ),
          ),
    ),
    shoppingPlanningControllerProvider.overrideWithValue(controller),
    calendarRepositoryProvider.overrideWithValue(_EmptyCalendarRepository()),
    shoppingScheduleRepositoryProvider.overrideWithValue(
      scheduleRepository ?? _VisualScheduleRepository(),
    ),
  ],
  child: MaterialApp(
    key: appKey,
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light(),
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    supportedLocales: const [Locale('en'), Locale('zh'), Locale('ko')],
    locale: locale,
    home: Scaffold(body: child),
  ),
);

/// Keeps the device's display-feature and system-bar geometry while varying
/// only the type scale for visual-state coverage.
Widget _withTextScale(Widget child, TextScaler textScaler) => Builder(
  builder: (context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: textScaler),
    child: child,
  ),
);

Future<void> _settleNativeDeviceFrame(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 2));
  await Future<void>.delayed(const Duration(milliseconds: 250));
}

Future<void> _capture(
  WidgetTester tester,
  IntegrationTestWidgetsFlutterBinding binding,
  String surface,
  Finder expected,
) async {
  await tester.pump(const Duration(seconds: 1));
  expect(expected, findsWidgets);
  final platform = defaultTargetPlatform == TargetPlatform.android
      ? 'android'
      : 'ios';
  await binding.takeScreenshot('$platform-$surface');
}

Future<void> _signalInAppCapture({required int signal}) async {
  const port = int.fromEnvironment('VISUAL_CAPTURE_SIGNAL_PORT');
  if (port == 0) {
    throw StateError('VISUAL_CAPTURE_SIGNAL_PORT must be configured');
  }
  final host = defaultTargetPlatform == TargetPlatform.android
      ? '10.0.2.2'
      : InternetAddress.loopbackIPv4.address;
  final socket = await Socket.connect(host, port);
  socket.add(<int>[signal]);
  await socket.flush();
  await socket.first.timeout(const Duration(seconds: 20));
  await socket.close();
}

ShoppingListPlan _preview() => ShoppingListPlan(
  id: 'visual-preview',
  type: ShoppingListType.shopNow,
  startDate: DateTime(2026, 7, 13),
  endDate: DateTime(2026, 7, 13),
  items: const [
    ShoppingListItemPlan(
      ingredientId: 'tomato',
      quantity: 2,
      unit: UnitId.piece,
      sourceMealLinks: [],
    ),
  ],
);

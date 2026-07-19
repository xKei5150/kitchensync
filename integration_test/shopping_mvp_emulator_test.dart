import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:intl/intl.dart';
import 'package:kitchensync/app/theme.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/core/utils/id_generator.dart';
import 'package:kitchensync/features/calendar/domain/entities/shopping_schedule.dart';
import 'package:kitchensync/features/calendar/presentation/providers/shopping_schedule_providers.dart';
import 'package:kitchensync/features/calendar/presentation/screens/shopping_schedule_screen.dart';
import 'package:kitchensync/features/household/domain/entities/household_policy_models.dart';
import 'package:kitchensync/features/ingredient_dictionary/domain/entities/enums.dart';
import 'package:kitchensync/features/shopping/data/datasources/shopping_command_codec.dart';
import 'package:kitchensync/features/shopping/domain/entities/shopping_command.dart';
import 'package:kitchensync/features/shopping/domain/entities/shopping_plan.dart';
import 'package:kitchensync/features/shopping/presentation/controllers/shopping_write_coordinator.dart';
import 'package:kitchensync/features/shopping/presentation/providers/shopping_repository_providers.dart';
import 'package:kitchensync/features/shopping/presentation/screens/shopping_history_screen.dart';
import 'package:kitchensync/features/shopping/presentation/screens/shopping_list_screen.dart';
import 'package:kitchensync/features/shopping/presentation/screens/shopping_screen.dart';

import '_helpers.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const canonicalDateKey = String.fromEnvironment('QA_CANONICAL_DATE');

  testWidgets(
    'shopping MVP uses trusted command writes on the mobile emulator',
    (tester) async {
      _disableDebugPaintForMvpScreenshots();
      expect(debugPaintBaselinesEnabled, isFalse);
      expect(debugPaintPointersEnabled, isFalse);
      await bootEmulatedApp();
      await seedGlobalDictionaryThroughEmulatorAdmin();
      await binding.convertFlutterSurfaceToImage();
      await _prepareMvpScreenshot(tester);
      final user = FirebaseAuth.instance.currentUser;
      expect(user, isNotNull);
      final uid = user!.uid;
      final token = await user.getIdToken();
      expect(token, isNotNull);
      final householdId = 'shopping-mvp-$uid';
      // The runner injects one local calendar date for the fixture and UI
      // assertions so the test cannot silently mix an old seed with today.
      final now = _canonicalQaDate(canonicalDateKey);
      final rangeEnd = now.add(const Duration(days: 6));
      final scheduleWeekday = now.weekday;
      final nowDateKey = DateFormat('yyyy-MM-dd').format(now);
      final rangeEndDateKey = DateFormat('yyyy-MM-dd').format(rangeEnd);
      await withTimeout(
        'seed shopping MVP household',
        () => _seedHousehold(
          uid: uid,
          householdId: householdId,
          token: token!,
          now: now,
        ),
      );

      final container = ProviderContainer(
        overrides: [
          activeUserIdProvider.overrideWithValue(uid),
          activeHouseholdContextProvider.overrideWithValue(
            ActiveHouseholdContext(
              id: householdId,
              name: 'Shopping MVP kitchen',
              role: HouseholdRole.admin,
              isJoint: false,
              hasPremium: false,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      final commands = container.read(shoppingCommandRepositoryProvider);
      await withTimeout(
        'save weekly shopping schedule',
        () => container
            .read(shoppingScheduleRepositoryProvider)
            .save(
              ShoppingSchedule(
                householdId: householdId,
                cadence: ShoppingScheduleCadence.weekly,
                isoWeekday: scheduleWeekday,
                effectiveFrom: now,
                isActive: true,
                createdAt: now,
                updatedAt: now,
                updatedByUserId: uid,
              ),
            ),
      );
      final schedule = await withTimeout(
        'read weekly shopping schedule',
        () => container
            .read(shoppingScheduleRepositoryProvider)
            .watch(householdId)
            .firstWhere((value) => value != null),
      );
      expect(schedule!.isoWeekday, scheduleWeekday);
      final shopNowListId = 'shop_now_${nowDateKey}_$rangeEndDateKey';
      final scheduledListId =
          'scheduled_weekly_${rangeEndDateKey.replaceAll('-', '')}';
      final suggestedListId =
          'suggested_recovery_'
          '${nowDateKey.replaceAll('-', '')}_${nowDateKey.replaceAll('-', '')}';
      final coordinator = ShoppingWriteCoordinator(
        repository: commands,
        householdId: householdId,
        idGenerator: FakeIdGenerator(const [
          'shop-now-command',
          'add-tomato-command',
          'scheduled-command',
          'suggested-command',
        ]),
      );
      final shopNowIntent = ShopNowShoppingAllocationIntent(
        householdId: householdId,
        startDate: now,
        endDate: rangeEnd,
      );
      _expectIntentOnlyPayload(
        ConsumeShoppingAllocationIntent(
          intent: shopNowIntent,
          commandId: 'shop-now-command',
        ),
      );

      final created = await withTimeout(
        'server-derived Shop Now allocation',
        () => coordinator.allocate(intent: shopNowIntent),
      );
      expect(created?.revision, isNotNull);
      expect(created?.listId, shopNowListId);
      final allocatedShopNow = await withTimeout(
        'observe server-derived Shop Now record',
        () => container
            .read(shoppingRepositoryProvider)
            .watchList(householdId: householdId, listId: shopNowListId)
            .firstWhere((value) => value != null),
      );
      expect(allocatedShopNow!.type, ShoppingListType.shopNow);
      expect(allocatedShopNow.generatedForRangeStart, now);
      expect(allocatedShopNow.generatedForRangeEnd, rangeEnd);
      expect(
        allocatedShopNow.items.single.sourceMealLinks.single.mealEntryId,
        'server-meal-${nowDateKey.replaceAll('-', '')}',
      );
      final added = await withTimeout(
        'trusted manual dictionary item mutation',
        () => coordinator.mutate(
          listId: shopNowListId,
          itemId: 'tomato__g',
          expectedRevision: created!.revision!,
          mutation: const AddShoppingListItemMutation(
            ingredientId: 'tomato',
            quantityNeeded: 300,
            purchasedQuantity: null,
            unit: UnitId.g,
            status: ShoppingListItemStatus.unchecked,
            substituteIngredientId: null,
            substituteQuantity: null,
            substituteUnit: null,
          ),
        ),
      );
      expect(added?.revision, isNotNull);
      final stored = await withTimeout(
        'live shopping list update',
        () => container
            .read(shoppingRepositoryProvider)
            .watchList(householdId: householdId, listId: shopNowListId)
            .firstWhere(
              (value) =>
                  value?.revision == 1 &&
                  value!.items.any(
                    (item) =>
                        item.id == 'tomato__g' && item.quantityNeeded == 300,
                  ),
            ),
      );
      expect(stored, isNotNull);
      expect(
        stored!.items
            .firstWhere((item) => item.id == 'tomato__g')
            .quantityNeeded,
        300,
      );
      final authoritativeRevision = await withTimeout(
        'read authoritative revision after item mutation',
        () => _currentRevision(householdId, shopNowListId),
      );
      debugPrint(
        'QA_REVISION created=${created!.revision} added=${added!.revision} '
        'stream=${stored.revision} authoritative=$authoritativeRevision',
      );
      expect(authoritativeRevision, added.revision);
      final bought = await withTimeout(
        'mark checklist item bought',
        () => commands.mutateItem(
          ShoppingListItemMutationCommand(
            householdId: householdId,
            listId: shopNowListId,
            itemId: 'tomato__g',
            commandId: 'mark-tomato-bought',
            expectedRevision: authoritativeRevision,
            mutation: const SetShoppingListItemStatusMutation(
              status: ShoppingListItemStatus.bought,
              purchasedQuantity: 250,
              substituteIngredientId: null,
              substituteQuantity: null,
              substituteUnit: null,
            ),
          ),
        ),
      );
      expect(bought.revision, isNotNull);

      final purchaseCommand = ShoppingListItemMutationCommand(
        householdId: householdId,
        listId: shopNowListId,
        itemId: 'tomato__g',
        commandId: 'purchased-quantity',
        expectedRevision: bought.revision!,
        mutation: const SetShoppingListItemPurchasedQuantityMutation(
          purchasedQuantity: 275,
        ),
      );
      debugPrint(
        'QA_MUTATION_PAYLOAD='
        '${jsonEncode(shoppingListItemMutationRequest(purchaseCommand))}',
      );
      final quantityEdit = await withTimeout(
        'manual purchased quantity edit',
        () => commands.mutateItem(purchaseCommand),
      );
      expect(quantityEdit.revision, isNotNull);
      await withTimeout(
        'dictionary-backed substitution as Shopper command',
        () => commands.mutateItem(
          ShoppingListItemMutationCommand(
            householdId: householdId,
            listId: shopNowListId,
            itemId: 'tomato__g',
            commandId: 'substitute-tomato',
            expectedRevision: quantityEdit.revision!,
            mutation: const SetShoppingListItemStatusMutation(
              status: ShoppingListItemStatus.substituted,
              purchasedQuantity: null,
              substituteIngredientId: 'tomato-cherry',
              substituteQuantity: 275,
              substituteUnit: UnitId.g,
            ),
          ),
        ),
      );

      await _capture(
        tester,
        binding,
        'checklist-substitution',
        container,
        ShoppingListScreen(listId: shopNowListId),
        find.text('Done shopping'),
      );
      await _capture(
        tester,
        binding,
        'shopping-home',
        container,
        const ShoppingScreen(),
        find.text('Start a shop'),
        expectedText: DateFormat('d MMM').format(now),
      );
      await _capture(
        tester,
        binding,
        'schedule-editor',
        container,
        const ShoppingScheduleScreen(),
        find.byKey(const ValueKey('shopping-schedule-form')),
        expectedText: DateFormat('EEEE').format(now),
      );
      await _captureShopNowRange(tester, binding, container, now);

      final completion = await withTimeout(
        'trusted shopping completion',
        () => commands.completeList(
          ShoppingCommandRequest(
            householdId: householdId,
            listId: shopNowListId,
            commandId: 'complete-command',
          ),
        ),
      );
      expect(completion.alreadyApplied, isFalse);
      final replay = await withTimeout(
        'trusted completion replay',
        () => commands.completeList(
          ShoppingCommandRequest(
            householdId: householdId,
            listId: shopNowListId,
            commandId: 'complete-command',
          ),
        ),
      );
      expect(replay.alreadyApplied, isTrue);

      await expectLater(
        FirebaseFirestore.instance
            .collection('households')
            .doc(householdId)
            .collection('shoppingLists')
            .doc('client-write-denied')
            .set({'status': 'completed'}),
        throwsA(isA<FirebaseException>()),
      );
      await withTimeout(
        'server-derived suggested recovery allocation',
        () => coordinator.allocate(
          intent: SuggestedShoppingAllocationIntent(
            householdId: householdId,
            startDate: now,
            endDate: now,
            originId: 'recovery:core:v1',
          ),
        ),
      );
      final suggested = await withTimeout(
        'observe server-derived suggested recovery',
        () => container
            .read(shoppingRepositoryProvider)
            .watchList(householdId: householdId, listId: suggestedListId)
            .firstWhere((value) => value != null),
      );
      expect(suggested!.type, ShoppingListType.suggested);
      expect(suggested.originId, 'recovery:core:v1');
      await _exerciseSuggestionHome(
        tester,
        binding,
        container,
        householdId: householdId,
        suggestedListId: suggestedListId,
      );
      await _capture(
        tester,
        binding,
        'history',
        container,
        const ShoppingHistoryScreen(),
        find.byKey(Key('completed-history-$shopNowListId')),
        expectedText: DateFormat('d MMM y').format(now),
      );
      await withTimeout(
        'server-derived scheduled occurrence allocation',
        () => coordinator.allocate(
          intent: ScheduledShoppingAllocationIntent(
            householdId: householdId,
            startDate: now,
            endDate: rangeEnd,
            scheduleKey: 'weekly-$scheduleWeekday-$nowDateKey',
            occurrenceDate: rangeEnd,
          ),
        ),
      );
      final scheduled = await withTimeout(
        'observe server-derived scheduled occurrence',
        () => container
            .read(shoppingRepositoryProvider)
            .watchList(householdId: householdId, listId: scheduledListId)
            .firstWhere((value) => value != null),
      );
      expect(scheduled!.type, ShoppingListType.scheduled);
      expect(scheduled.generatedForRangeStart, now);
      expect(scheduled.generatedForRangeEnd, rangeEnd);
      final deletion = await withTimeout(
        'trusted delete command',
        () => commands.deleteList(
          ShoppingCommandRequest(
            householdId: householdId,
            listId: scheduledListId,
            commandId: 'delete-command',
          ),
        ),
      );
      expect(deletion.status, ShoppingCommandStatus.deleted);
      if (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android) {
        await _prepareMvpScreenshot(tester);
        await _signalFinalCapture();
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

void _disableDebugPaintForMvpScreenshots() {
  debugPaintBaselinesEnabled = false;
  debugPaintPointersEnabled = false;
}

Future<void> _prepareMvpScreenshot(WidgetTester tester) async {
  _disableDebugPaintForMvpScreenshots();
  late RenderObjectVisitor repaintSubtree;
  repaintSubtree = (RenderObject child) {
    child
      ..markNeedsPaint()
      ..visitChildren(repaintSubtree);
  };
  for (final renderView in RendererBinding.instance.renderViews) {
    renderView.visitChildren(repaintSubtree);
  }
  await _flushRenderedFrame(tester);
  expect(debugPaintBaselinesEnabled, isFalse);
  expect(debugPaintPointersEnabled, isFalse);
}

Future<void> _signalFinalCapture() async {
  const port = int.fromEnvironment('FINAL_CAPTURE_SIGNAL_PORT');
  if (port == 0) {
    throw StateError('FINAL_CAPTURE_SIGNAL_PORT must be configured');
  }
  final host = defaultTargetPlatform == TargetPlatform.android
      ? '10.0.2.2'
      : InternetAddress.loopbackIPv4.address;
  final socket = await Socket.connect(host, port);
  socket.add(<int>[1]);
  await socket.flush();
  await socket.first.timeout(const Duration(seconds: 20));
  await socket.close();
}

Future<void> _capture(
  WidgetTester tester,
  IntegrationTestWidgetsFlutterBinding binding,
  String surface,
  ProviderContainer container,
  Widget screen,
  Finder settledState, {
  String? expectedText,
}) async {
  final platform = defaultTargetPlatform == TargetPlatform.android
      ? 'android'
      : 'ios';
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        key: ValueKey(surface),
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: Scaffold(body: screen),
      ),
    ),
  );
  await _waitForSettledState(tester, settledState);
  expect(settledState, findsWidgets);
  if (expectedText != null) {
    expect(find.textContaining(expectedText), findsWidgets);
  }
  expect(find.byType(CircularProgressIndicator), findsNothing);
  await _prepareMvpScreenshot(tester);
  await binding.takeScreenshot('$platform-$surface-warmup');
  await _prepareMvpScreenshot(tester);
  await binding.takeScreenshot('$platform-$surface');
  await _flushRenderedFrame(tester);
}

Future<void> _exerciseSuggestionHome(
  WidgetTester tester,
  IntegrationTestWidgetsFlutterBinding binding,
  ProviderContainer container, {
  required String householdId,
  required String suggestedListId,
}) async {
  final platform = defaultTargetPlatform == TargetPlatform.android
      ? 'android'
      : 'ios';
  final router = GoRouter(
    initialLocation: '/shop',
    routes: [
      GoRoute(
        path: '/shop',
        builder: (context, state) => const Scaffold(body: ShoppingScreen()),
      ),
      GoRoute(
        path: '/shop/list/:listId',
        builder: (context, state) => Scaffold(
          body: ShoppingListScreen(listId: state.pathParameters['listId']),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        key: const ValueKey('suggestion-home-flow'),
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        routerConfig: router,
      ),
    ),
  );
  await _waitForSettledState(tester, find.byTooltip('Open suggestion'));
  expect(find.text('SUGGESTIONS'), findsOneWidget);
  expect(find.text('Suggested list'), findsOneWidget);
  expect(find.byTooltip('Ignore suggestion'), findsOneWidget);
  await _prepareMvpScreenshot(tester);
  await binding.takeScreenshot('$platform-suggestion-home');

  await tester.tap(find.byTooltip('Open suggestion'));
  await _waitForSettledState(tester, find.text('Suggested shop'));
  expect(find.text('Suggested shop'), findsOneWidget);
  expect(find.text('Done shopping'), findsOneWidget);
  await _prepareMvpScreenshot(tester);
  await binding.takeScreenshot('$platform-suggestion-accepted');

  router.pop();
  await tester.pumpAndSettle();
  final ignoreSuggestion = find.byTooltip('Ignore suggestion');
  await _waitForSettledState(tester, ignoreSuggestion);
  await tester.ensureVisible(ignoreSuggestion);
  await tester.pumpAndSettle();
  await tester.tap(ignoreSuggestion);
  await _waitForSettledState(tester, find.text('Suggested list ignored'));
  expect(find.text('Suggested list ignored'), findsOneWidget);
  final cancelled = await withTimeout(
    'observe ignored recovery suggestion tombstone',
    () => container
        .read(shoppingRepositoryProvider)
        .watchList(householdId: householdId, listId: suggestedListId)
        .firstWhere((list) => list?.status == ShoppingListStatus.cancelled),
  );
  expect(cancelled, isNotNull);
  expect(cancelled?.items, isEmpty);
  await _prepareMvpScreenshot(tester);
  await binding.takeScreenshot('$platform-suggestion-ignored');
}

Future<void> _waitForSettledState(
  WidgetTester tester,
  Finder settledState,
) async {
  for (var attempt = 0; attempt < 40; attempt++) {
    await tester.pump();
    if (settledState.evaluate().isNotEmpty) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 250)),
    );
  }
  expect(settledState, findsWidgets);
}

Future<void> _flushRenderedFrame(WidgetTester tester) async {
  await tester.pump();
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 250)),
  );
  await tester.pump();
}

Future<void> _captureShopNowRange(
  WidgetTester tester,
  IntegrationTestWidgetsFlutterBinding binding,
  ProviderContainer container,
  DateTime now,
) async {
  final platform = defaultTargetPlatform == TargetPlatform.android
      ? 'android'
      : 'ios';
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        key: const ValueKey('shop-now-range'),
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: const Scaffold(body: ShoppingScreen()),
      ),
    ),
  );
  await _waitForSettledState(tester, find.text('Start a shop'));
  expect(find.text('Start a shop'), findsOneWidget);
  await tester.tap(find.text('Start a shop'));
  await _waitForSettledState(
    tester,
    find.text('Nothing to buy for this range.'),
  );
  expect(find.text('Shop how far ahead?'), findsOneWidget);
  expect(find.text('Generate list'), findsOneWidget);
  expect(find.textContaining(DateFormat('d MMM').format(now)), findsWidgets);
  expect(find.byType(CircularProgressIndicator), findsNothing);
  await _prepareMvpScreenshot(tester);
  await binding.takeScreenshot('$platform-shop-now-range-warmup');
  await _prepareMvpScreenshot(tester);
  await binding.takeScreenshot('$platform-shop-now-range');
  await _flushRenderedFrame(tester);
}

DateTime _canonicalQaDate(String value) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
    throw ArgumentError.value(
      value,
      'QA_CANONICAL_DATE',
      'A YYYY-MM-DD canonical QA date is required.',
    );
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null || DateFormat('yyyy-MM-dd').format(parsed) != value) {
    throw ArgumentError.value(
      value,
      'QA_CANONICAL_DATE',
      'Canonical QA date must be a real calendar date.',
    );
  }
  return DateTime(parsed.year, parsed.month, parsed.day);
}

Future<void> _seedHousehold({
  required String uid,
  required String householdId,
  required String token,
  required DateTime now,
}) async {
  await _patch('users/$uid', token, {
    'isPremium': _boolean(false),
    'activeHouseholdId': _string(householdId),
    'updatedAt': _timestamp(now),
  });
  await _patch('households/$householdId', token, {
    'name': _string('Shopping MVP kitchen'),
    'creatorUserId': _string(uid),
    'isJoint': _boolean(false),
    'hasPremium': _boolean(false),
    'maxMembers': _integer(1),
    'createdAt': _timestamp(now),
    'updatedAt': _timestamp(now),
  });
  await _patch('households/$householdId/members/$uid', token, {
    'role': _string('admin'),
    'joinedAt': _timestamp(now),
    'updatedAt': _timestamp(now),
  });
}

Future<void> _patch(
  String path,
  String token,
  Map<String, Map<String, Object?>> fields,
) async {
  const host = String.fromEnvironment(
    'FIRESTORE_EMULATOR_HOST',
    defaultValue: '127.0.0.1',
  );
  const port = int.fromEnvironment(
    'FIRESTORE_EMULATOR_PORT',
    defaultValue: 8080,
  );
  final client = HttpClient();
  try {
    final request = await client.patchUrl(
      Uri.http(
        '$host:$port',
        '/v1/projects/kitchensync-dev-da503/databases/(default)/documents/$path',
      ),
    );
    request.headers.contentType = ContentType.json;
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    request.write(jsonEncode({'fields': fields}));
    final response = await request.close();
    final body = await utf8.decodeStream(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Firestore seed ${response.statusCode}: $body');
    }
  } finally {
    client.close(force: true);
  }
}

Future<int> _currentRevision(String householdId, String listId) async {
  final snapshot = await FirebaseFirestore.instance
      .collection('households')
      .doc(householdId)
      .collection('shoppingLists')
      .doc(listId)
      .get(const GetOptions(source: Source.server));
  final revision = snapshot.data()?['revision'];
  if (revision is! int) {
    throw StateError('Missing authoritative shopping-list revision.');
  }
  return revision;
}

void _expectIntentOnlyPayload(ConsumeShoppingAllocationIntent command) {
  final payload = planShoppingAllocationRequest(command);
  final forbidden = {
    'listId',
    'draftId',
    'list',
    'items',
    'links',
    'meals',
    'recipes',
    'pantry',
  };
  expect(payload.keys.toSet().intersection(forbidden), isEmpty);
  expect(payload.keys, containsAll(['householdId', 'commandId', 'intent']));
  final intent = payload['intent'];
  expect(intent, isA<Map<String, Object?>>());
  debugPrint('QA_ALLOCATION_INTENT_PAYLOAD=${jsonEncode(payload)}');
}

Map<String, Object?> _string(String value) => {'stringValue': value};
Map<String, Object?> _boolean(bool value) => {'booleanValue': value};
Map<String, Object?> _integer(int value) => {'integerValue': '$value'};
Map<String, Object?> _timestamp(DateTime value) => {
  'timestampValue': value.toUtc().toIso8601String(),
};

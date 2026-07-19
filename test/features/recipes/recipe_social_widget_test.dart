import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/app/theme.dart';
import 'package:kitchensync/core/preferences/preferences_providers.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/core/utils/clock.dart';
import 'package:kitchensync/core/utils/id_generator.dart';
import 'package:kitchensync/features/ingredient_dictionary/presentation/providers/ingredient_providers.dart';
import 'package:kitchensync/features/recipes/domain/entities/recipe_models.dart';
import 'package:kitchensync/features/recipes/domain/entities/recipe_social_models.dart';
import 'package:kitchensync/features/recipes/domain/repositories/recipe_social_repository.dart';
import 'package:kitchensync/features/recipes/presentation/providers/recipe_repository_providers.dart';
import 'package:kitchensync/features/recipes/presentation/screens/recipe_detail_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeRecipeSocialRepository implements RecipeSocialRepository {
  RecipeSocialState state = const RecipeSocialState(
    likeCount: 1,
    likedByViewer: false,
    comments: [],
  );
  final _controller = StreamController<RecipeSocialState>.broadcast();

  @override
  Stream<RecipeSocialState> watchSocial({
    required String recipeId,
    required String viewerUserId,
  }) async* {
    yield state;
    yield* _controller.stream;
  }

  @override
  Future<void> setLiked({
    required String recipeId,
    required String userId,
    required bool liked,
    required DateTime now,
  }) async {
    state = RecipeSocialState(
      likeCount: state.likeCount + (liked ? 1 : -1),
      likedByViewer: liked,
      comments: state.comments,
    );
    _controller.add(state);
  }

  @override
  Future<void> addComment(RecipeComment comment) async {
    state = RecipeSocialState(
      likeCount: state.likeCount,
      likedByViewer: state.likedByViewer,
      comments: [...state.comments, comment],
    );
    _controller.add(state);
  }

  @override
  Future<void> deleteComment({
    required String recipeId,
    required String commentId,
  }) async {
    state = RecipeSocialState(
      likeCount: state.likeCount,
      likedByViewer: state.likedByViewer,
      comments: state.comments
          .where((comment) => comment.id != commentId)
          .toList(growable: false),
    );
    _controller.add(state);
  }

  Future<void> dispose() => _controller.close();
}

void main() {
  testWidgets('public recipe supports live likes and owned comments', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final socialRepository = _FakeRecipeSocialRepository();
    addTearDown(socialRepository.dispose);
    final recipe = Recipe(
      id: 'public-recipe',
      authorUserId: 'author',
      householdId: 'household',
      name: 'Public Stew',
      description: 'A recipe shared with the community.',
      defaultServingSize: 4,
      mealTimeTags: const ['Dinner'],
      recipeTags: const ['Stew'],
      priceEstimate: 200,
      location: 'Manila',
      visibility: RecipeVisibility.public,
      monetization: RecipeMonetization.free,
      createdAt: DateTime(2026, 7, 18),
      updatedAt: DateTime(2026, 7, 18),
      ingredients: const [],
      instructions: const ['Simmer.'],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          activeUserIdProvider.overrideWithValue('viewer'),
          recipeSocialRepositoryProvider.overrideWithValue(socialRepository),
          clockProvider.overrideWithValue(FakeClock(DateTime(2026, 7, 18))),
          idGeneratorProvider.overrideWithValue(FakeIdGenerator(['comment-1'])),
          recipeRecordProvider(
            recipe.id,
          ).overrideWith((ref) => Stream.value(recipe)),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: RecipeDetailScreen(recipeId: recipe.id),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Community'));
    expect(find.text('Community'), findsOneWidget);
    expect(find.text('No comments yet.'), findsOneWidget);

    await tester.tap(find.byTooltip('Like recipe'));
    await tester.pump();
    expect(socialRepository.state.likedByViewer, isTrue);
    expect(socialRepository.state.likeCount, 2);

    await tester.enterText(find.byType(TextField), 'Looks delicious');
    await tester.tap(find.byTooltip('Post comment'));
    await tester.pump();
    expect(find.text('Looks delicious'), findsOneWidget);
    expect(socialRepository.state.commentCount, 1);

    await tester.tap(find.byTooltip('Delete comment'));
    await tester.pump();
    expect(find.text('Looks delicious'), findsNothing);
    expect(find.text('No comments yet.'), findsOneWidget);
  });
}

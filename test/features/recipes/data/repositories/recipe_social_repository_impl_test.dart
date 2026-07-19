import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/core/firebase/firestore_refs.dart';
import 'package:kitchensync/features/recipes/data/repositories/recipe_social_repository_impl.dart';
import 'package:kitchensync/features/recipes/domain/entities/recipe_social_models.dart';

void main() {
  late FakeFirebaseFirestore db;
  late RecipeSocialRepositoryImpl repository;

  setUp(() {
    db = FakeFirebaseFirestore();
    repository = RecipeSocialRepositoryImpl(FirestoreRefs(db));
  });

  test('likes and comments produce live viewer-aware social state', () async {
    final now = DateTime(2026, 7, 18, 10);
    await repository.setLiked(
      recipeId: 'recipe-1',
      userId: 'viewer',
      liked: true,
      now: now,
    );
    await repository.setLiked(
      recipeId: 'recipe-1',
      userId: 'another-user',
      liked: true,
      now: now,
    );
    await repository.addComment(
      RecipeComment(
        id: 'comment-1',
        recipeId: 'recipe-1',
        authorUserId: 'viewer',
        body: '  Useful recipe.  ',
        createdAt: now,
        updatedAt: now,
      ),
    );

    final state = await repository
        .watchSocial(recipeId: 'recipe-1', viewerUserId: 'viewer')
        .first;

    expect(state.likeCount, 2);
    expect(state.likedByViewer, isTrue);
    expect(state.commentCount, 1);
    expect(state.comments.single.body, 'Useful recipe.');
  });

  test(
    'unlike and comment deletion remove only the requested records',
    () async {
      final now = DateTime(2026, 7, 18, 10);
      await repository.setLiked(
        recipeId: 'recipe-1',
        userId: 'viewer',
        liked: true,
        now: now,
      );
      await repository.addComment(
        RecipeComment(
          id: 'comment-1',
          recipeId: 'recipe-1',
          authorUserId: 'viewer',
          body: 'First',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await repository.addComment(
        RecipeComment(
          id: 'comment-2',
          recipeId: 'recipe-1',
          authorUserId: 'another-user',
          body: 'Second',
          createdAt: now.add(const Duration(minutes: 1)),
          updatedAt: now.add(const Duration(minutes: 1)),
        ),
      );

      await repository.setLiked(
        recipeId: 'recipe-1',
        userId: 'viewer',
        liked: false,
        now: now,
      );
      await repository.deleteComment(
        recipeId: 'recipe-1',
        commentId: 'comment-1',
      );
      final state = await repository
          .watchSocial(recipeId: 'recipe-1', viewerUserId: 'viewer')
          .first;

      expect(state.likeCount, 0);
      expect(state.likedByViewer, isFalse);
      expect(state.comments.map((comment) => comment.id), ['comment-2']);
    },
  );

  test('comments reject blank and oversized bodies', () async {
    final now = DateTime(2026, 7, 18, 10);
    RecipeComment comment(String body) => RecipeComment(
      id: 'comment-1',
      recipeId: 'recipe-1',
      authorUserId: 'viewer',
      body: body,
      createdAt: now,
      updatedAt: now,
    );

    await expectLater(
      repository.addComment(comment('   ')),
      throwsArgumentError,
    );
    await expectLater(
      repository.addComment(comment('x' * 1001)),
      throwsArgumentError,
    );
  });
}

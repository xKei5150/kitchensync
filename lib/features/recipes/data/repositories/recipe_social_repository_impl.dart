import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kitchensync/core/firebase/firestore_refs.dart';
import 'package:kitchensync/features/recipes/domain/entities/recipe_social_models.dart';
import 'package:kitchensync/features/recipes/domain/repositories/recipe_social_repository.dart';

class RecipeSocialRepositoryImpl implements RecipeSocialRepository {
  const RecipeSocialRepositoryImpl(this._refs);

  final FirestoreRefs _refs;

  @override
  Stream<RecipeSocialState> watchSocial({
    required String recipeId,
    required String viewerUserId,
  }) {
    QuerySnapshot<Map<String, dynamic>>? likes;
    QuerySnapshot<Map<String, dynamic>>? comments;
    late final StreamController<RecipeSocialState> controller;
    late final StreamSubscription<QuerySnapshot<Map<String, dynamic>>>
    likesSubscription;
    late final StreamSubscription<QuerySnapshot<Map<String, dynamic>>>
    commentsSubscription;

    void emit() {
      final currentLikes = likes;
      final currentComments = comments;
      if (currentLikes == null || currentComments == null) return;
      controller.add(
        RecipeSocialState(
          likeCount: currentLikes.docs.length,
          likedByViewer: currentLikes.docs.any(
            (document) => document.id == viewerUserId,
          ),
          comments: List.unmodifiable(
            currentComments.docs.map(
              (document) => _commentFromDocument(recipeId, document),
            ),
          ),
        ),
      );
    }

    controller = StreamController<RecipeSocialState>(
      onCancel: () async {
        await likesSubscription.cancel();
        await commentsSubscription.cancel();
      },
    );
    likesSubscription = _refs.recipeLikes(recipeId).snapshots().listen((
      snapshot,
    ) {
      likes = snapshot;
      emit();
    }, onError: controller.addError);
    commentsSubscription = _refs
        .recipeComments(recipeId)
        .orderBy('createdAt')
        .snapshots()
        .listen((snapshot) {
          comments = snapshot;
          emit();
        }, onError: controller.addError);
    return controller.stream;
  }

  @override
  Future<void> setLiked({
    required String recipeId,
    required String userId,
    required bool liked,
    required DateTime now,
  }) async {
    final reference = _refs.recipeLikes(recipeId).doc(userId);
    if (!liked) {
      await reference.delete();
      return;
    }
    await reference.set({
      'userId': userId,
      'createdAt': Timestamp.fromDate(now),
    });
  }

  @override
  Future<void> addComment(RecipeComment comment) async {
    final body = comment.body.trim();
    if (body.isEmpty || body.length > 1000) {
      throw ArgumentError.value(
        comment.body,
        'body',
        'Comment must contain between 1 and 1000 characters.',
      );
    }
    await _refs.recipeComments(comment.recipeId).doc(comment.id).set({
      'recipeId': comment.recipeId,
      'authorUserId': comment.authorUserId,
      'body': body,
      'createdAt': Timestamp.fromDate(comment.createdAt),
      'updatedAt': Timestamp.fromDate(comment.updatedAt),
    });
  }

  @override
  Future<void> deleteComment({
    required String recipeId,
    required String commentId,
  }) => _refs.recipeComments(recipeId).doc(commentId).delete();

  RecipeComment _commentFromDocument(
    String recipeId,
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    final createdAt =
        (data['createdAt'] as Timestamp?)?.toDate() ??
        DateTime.fromMillisecondsSinceEpoch(0);
    return RecipeComment(
      id: document.id,
      recipeId: recipeId,
      authorUserId: data['authorUserId'] as String? ?? '',
      body: data['body'] as String? ?? '',
      createdAt: createdAt,
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? createdAt,
    );
  }
}

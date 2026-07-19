import 'package:kitchensync/features/recipes/domain/entities/recipe_social_models.dart';

abstract class RecipeSocialRepository {
  Stream<RecipeSocialState> watchSocial({
    required String recipeId,
    required String viewerUserId,
  });

  Future<void> setLiked({
    required String recipeId,
    required String userId,
    required bool liked,
    required DateTime now,
  });

  Future<void> addComment(RecipeComment comment);

  Future<void> deleteComment({
    required String recipeId,
    required String commentId,
  });
}

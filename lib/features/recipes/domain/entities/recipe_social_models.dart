class RecipeComment {
  const RecipeComment({
    required this.id,
    required this.recipeId,
    required this.authorUserId,
    required this.body,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String recipeId;
  final String authorUserId;
  final String body;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class RecipeSocialState {
  const RecipeSocialState({
    required this.likeCount,
    required this.likedByViewer,
    required this.comments,
  });

  static const empty = RecipeSocialState(
    likeCount: 0,
    likedByViewer: false,
    comments: [],
  );

  final int likeCount;
  final bool likedByViewer;
  final List<RecipeComment> comments;

  int get commentCount => comments.length;
}

part of 'recipe_detail_screen.dart';

class _RecipeSocialPanel extends ConsumerStatefulWidget {
  const _RecipeSocialPanel({required this.recipeId});

  final String recipeId;

  @override
  ConsumerState<_RecipeSocialPanel> createState() => _RecipeSocialPanelState();
}

class _RecipeSocialPanelState extends ConsumerState<_RecipeSocialPanel> {
  final _commentController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    final socialAsync = ref.watch(recipeSocialStateProvider(widget.recipeId));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Community',
          style: KsTokens.titleMedium.copyWith(color: ks.textPrimary),
        ),
        const SizedBox(height: KsTokens.space8),
        socialAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) =>
              KsErrorAlert(message: 'Could not load recipe activity: $error'),
          data: (social) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Tooltip(
                    message: social.likedByViewer
                        ? 'Unlike recipe'
                        : 'Like recipe',
                    child: TextButton.icon(
                      onPressed: _submitting
                          ? null
                          : () => _setLiked(!social.likedByViewer),
                      icon: Icon(
                        social.likedByViewer
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                      ),
                      label: Text('${social.likeCount}'),
                    ),
                  ),
                  const SizedBox(width: KsTokens.space8),
                  Icon(
                    Icons.chat_bubble_outline_rounded,
                    color: ks.textTertiary,
                  ),
                  const SizedBox(width: KsTokens.space6),
                  Text(
                    '${social.commentCount}',
                    style: KsTokens.bodyMedium.copyWith(
                      color: ks.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: KsTokens.space8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: 1000,
                      enabled: !_submitting,
                      decoration: const InputDecoration(
                        labelText: 'Add a comment',
                        counterText: '',
                      ),
                    ),
                  ),
                  const SizedBox(width: KsTokens.space8),
                  IconButton.filled(
                    onPressed: _submitting ? null : _submitComment,
                    tooltip: 'Post comment',
                    icon: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
              const SizedBox(height: KsTokens.space12),
              if (social.comments.isEmpty)
                Text(
                  'No comments yet.',
                  style: KsTokens.bodyMedium.copyWith(color: ks.textTertiary),
                )
              else
                for (final comment in social.comments)
                  _RecipeCommentRow(
                    comment: comment,
                    canDelete:
                        comment.authorUserId == ref.watch(activeUserIdProvider),
                    onDelete: () => _deleteComment(comment.id),
                  ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _setLiked(bool liked) async {
    await _runMutation(
      () => ref
          .read(recipeSocialControllerProvider)
          .setLiked(recipeId: widget.recipeId, liked: liked),
      failureMessage: 'Could not update like',
    );
  }

  Future<void> _submitComment() async {
    final body = _commentController.text.trim();
    if (body.isEmpty) return;
    final succeeded = await _runMutation(
      () => ref
          .read(recipeSocialControllerProvider)
          .addComment(recipeId: widget.recipeId, body: body),
      failureMessage: 'Could not post comment',
    );
    if (succeeded) _commentController.clear();
  }

  Future<void> _deleteComment(String commentId) => _runMutation(
    () => ref
        .read(recipeSocialControllerProvider)
        .deleteComment(recipeId: widget.recipeId, commentId: commentId),
    failureMessage: 'Could not delete comment',
  );

  Future<bool> _runMutation(
    Future<void> Function() mutation, {
    required String failureMessage,
  }) async {
    setState(() => _submitting = true);
    try {
      await mutation();
      return true;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$failureMessage: $error')));
      }
      return false;
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

class _RecipeCommentRow extends StatelessWidget {
  const _RecipeCommentRow({
    required this.comment,
    required this.canDelete,
    required this.onDelete,
  });

  final RecipeComment comment;
  final bool canDelete;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: KsTokens.space6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            child: Text(
              comment.authorUserId.isEmpty
                  ? '?'
                  : comment.authorUserId.characters.first.toUpperCase(),
            ),
          ),
          const SizedBox(width: KsTokens.space8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  comment.authorUserId,
                  style: KsTokens.labelSmall.copyWith(color: ks.textTertiary),
                ),
                const SizedBox(height: 2),
                Text(
                  comment.body,
                  style: KsTokens.bodyMedium.copyWith(color: ks.textPrimary),
                ),
              ],
            ),
          ),
          if (canDelete)
            IconButton(
              onPressed: onDelete,
              tooltip: 'Delete comment',
              icon: const Icon(Icons.delete_outline_rounded),
            ),
        ],
      ),
    );
  }
}

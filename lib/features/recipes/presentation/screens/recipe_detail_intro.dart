part of 'recipe_detail_screen.dart';

/// A drop-cap editorial intro — an oversized serif initial that the body text
/// wraps around, set via an inline [WidgetSpan].
class _DropCapIntro extends StatelessWidget {
  const _DropCapIntro({required this.initial, required this.body});

  final String initial;
  final String body;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text.rich(
      TextSpan(
        children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.top,
            child: Padding(
              padding: const EdgeInsets.only(right: 9, top: 5),
              child: Text(
                initial,
                style: KsTokens.displayLarge.copyWith(
                  color: isDark
                      ? KsTokens.brandAccent
                      : KsTokens.brandPrimaryDark,
                  fontSize: 46,
                  height: 0.74,
                ),
              ),
            ),
          ),
          TextSpan(
            text: body,
            style: KsTokens.bodyMedium.copyWith(
              color: ks.textSecondary,
              fontSize: 13.5,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}

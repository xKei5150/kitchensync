part of 'ks_form_field.dart';

/// A field-scoped validation message announced directly beneath its input.
class KsFieldError extends StatelessWidget {
  const KsFieldError(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final danger = context.ksColors.danger;
    return Padding(
      padding: const EdgeInsets.only(
        top: KsTokens.space6,
        left: KsTokens.space2,
      ),
      child: Semantics(
        liveRegion: true,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(Icons.error_outline, size: 13, color: danger),
            ),
            const SizedBox(width: KsTokens.space6),
            Expanded(
              child: Text(
                message,
                style: KsTokens.bodySmall.copyWith(
                  color: danger,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

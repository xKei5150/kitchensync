import 'package:flutter/material.dart';
import 'package:kitchensync/app/design_tokens.dart';

/// An inline error banner — tinted [KsTokens.expired] fill (8%) with a 20%
/// border, an error glyph, and the message.
///
/// Replaces the byte-identical block previously inlined in the mark-as-waste
/// sheet, the add-pantry-item screen, and the create-custom-ingredient screen.
class KsErrorAlert extends StatelessWidget {
  const KsErrorAlert({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: KsTokens.space12,
        vertical: KsTokens.space10,
      ),
      decoration: BoxDecoration(
        color: KsTokens.expired.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(KsTokens.radius12),
        border: Border.all(color: KsTokens.expired.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 18, color: KsTokens.expired),
          const SizedBox(width: KsTokens.space8),
          Expanded(
            child: Text(
              message,
              style: KsTokens.bodySmall.copyWith(color: KsTokens.expired),
            ),
          ),
        ],
      ),
    );
  }
}

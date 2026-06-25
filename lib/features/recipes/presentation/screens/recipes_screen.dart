import 'package:flutter/material.dart';
import 'package:kitchensync/app/design_tokens.dart';
import 'package:kitchensync/core/widgets/widgets.dart';

/// The Recipes tab — a stable spine tab whose surface lands in a later phase
/// (P1+). For now it wears the shared chrome over a calm empty state so the
/// five-tab nav is whole.
class RecipesScreen extends StatelessWidget {
  const RecipesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SafeArea(
      bottom: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          KsTokens.space16,
          KsTokens.space8,
          KsTokens.space16,
          KsTokens.space24,
        ),
        child: Column(
          children: [
            KsFolioHeader(eyebrow: 'The Cookbook', title: 'Recipes'),
            Expanded(
              child: Center(
                child: KsEmptyState(
                  icon: Icons.menu_book_outlined,
                  title: 'Your cookbook is coming',
                  subtitle:
                      'Saved recipes, serving scaling, and the household '
                      'menu sets land in the next phase.',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

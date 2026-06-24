import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kitchensync/app/design_tokens.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _Header()),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                KsTokens.space20,
                KsTokens.space24,
                KsTokens.space20,
                KsTokens.space32,
              ),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 200,
                  mainAxisSpacing: KsTokens.space12,
                  crossAxisSpacing: KsTokens.space12,
                  childAspectRatio: 1.0,
                ),
                delegate: SliverChildListDelegate([
                  _NavCard(
                    label: 'Pantry',
                    icon: Icons.kitchen,
                    color: KsTokens.sectionFood,
                    onTap: () => context.push('/pantry'),
                  ),
                  _NavCard(
                    label: 'Pick ingredient',
                    icon: Icons.search,
                    color: KsTokens.brandAccent,
                    onTap: () => context.push('/ingredient/pick'),
                  ),
                  _NavCard(
                    label: 'Custom ingredient',
                    icon: Icons.add,
                    color: KsTokens.brandPrimaryDark,
                    onTap: () => context.push('/ingredient/create'),
                  ),
                  if (kDebugMode)
                    _NavCard(
                      label: 'Dev tools',
                      icon: Icons.build,
                      color: KsTokens.sectionNonFood,
                      onTap: () => context.push('/dev'),
                    ),
                ]),
              ),
            ),
            if (kDebugMode)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: KsTokens.space20,
                  ),
                  child: TextButton.icon(
                    icon: const Icon(Icons.bug_report, size: 18),
                    label: const Text('Force a test crash'),
                    onPressed: () => FirebaseCrashlytics.instance.crash(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        KsTokens.space20,
        KsTokens.space24,
        KsTokens.space20,
        KsTokens.space4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('KitchenSync', style: Theme.of(context).textTheme.displayLarge),
          const SizedBox(height: KsTokens.space4),
          Text(
            'What is in your kitchen today?',
            style: KsTokens.bodyLarge.copyWith(color: KsTokens.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _NavCard extends StatelessWidget {
  const _NavCard({
    required this.label,
    required this.icon,
    required this.color,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: KsTokens.surfaceRaised,
      borderRadius: BorderRadius.circular(KsTokens.radius16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: KsTokens.border),
            borderRadius: BorderRadius.circular(KsTokens.radius16),
          ),
          padding: const EdgeInsets.all(KsTokens.space16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(KsTokens.radius10),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const Spacer(),
              Text(
                label,
                style: Theme.of(context).textTheme.titleMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

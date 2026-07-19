import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kitchensync/app/design_tokens.dart';
import 'package:kitchensync/core/widgets/widgets.dart';
import 'package:kitchensync/features/notifications/domain/entities/notification_models.dart';
import 'package:kitchensync/features/notifications/presentation/providers/notification_providers.dart';

class NotificationPreferencesScreen extends ConsumerWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ks = context.ksColors;
    final preferences = ref.watch(activeNotificationPreferencesProvider);
    return Scaffold(
      backgroundColor: ks.surfaceBase,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            KsTokens.space16,
            KsTokens.space8,
            KsTokens.space16,
            KsTokens.space24,
          ),
          children: [
            Row(
              children: [
                KsHeaderAction(
                  icon: Icons.arrow_back_rounded,
                  tooltip: 'Back',
                  onTap: () => context.pop(),
                ),
                const Spacer(),
                Text(
                  'Settings'.toUpperCase(),
                  style: KsTokens.labelSmall.copyWith(
                    color: ks.brandPrimary,
                    letterSpacing: 1.4,
                  ),
                ),
              ],
            ),
            const SizedBox(height: KsTokens.space12),
            Text(
              'Notifications',
              style: KsTokens.displayMedium.copyWith(
                color: ks.textPrimary,
                fontSize: 26,
                height: 1,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: KsTokens.space20),
            preferences.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => KsErrorAlert(
                message: 'Could not load notification preferences: $error',
              ),
              data: (value) => _PreferenceList(preferences: value),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreferenceList extends ConsumerWidget {
  const _PreferenceList({required this.preferences});

  final NotificationPreferences preferences;

  Future<void> _save(
    BuildContext context,
    WidgetRef ref,
    NotificationPreferences value,
  ) async {
    try {
      await ref.read(notificationControllerProvider).savePreferences(value);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save preferences: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ks = context.ksColors;
    return Material(
      color: ks.surfaceRaised,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(KsTokens.radius12),
        side: BorderSide(color: ks.border),
      ),
      child: Column(
        children: [
          SwitchListTile.adaptive(
            title: const Text('Emergency shopping'),
            subtitle: const Text('Missing ingredients that need a shopper'),
            value: preferences.emergencyShopping,
            onChanged: (value) => _save(
              context,
              ref,
              preferences.copyWith(emergencyShopping: value),
            ),
          ),
          Divider(height: 1, color: ks.hairline),
          SwitchListTile.adaptive(
            title: const Text('Pantry expiry'),
            subtitle: const Text('Food nearing its safe-use date'),
            value: preferences.pantryExpiry,
            onChanged: (value) =>
                _save(context, ref, preferences.copyWith(pantryExpiry: value)),
          ),
          Divider(height: 1, color: ks.hairline),
          SwitchListTile.adaptive(
            title: const Text('Bulk reminders'),
            subtitle: const Text('Predicted staple replenishments'),
            value: preferences.bulkReminders,
            onChanged: (value) =>
                _save(context, ref, preferences.copyWith(bulkReminders: value)),
          ),
          Divider(height: 1, color: ks.hairline),
          SwitchListTile.adaptive(
            title: const Text('Household activity'),
            subtitle: const Text('Shopping and cooking updates from members'),
            value: preferences.householdActivity,
            onChanged: (value) => _save(
              context,
              ref,
              preferences.copyWith(householdActivity: value),
            ),
          ),
        ],
      ),
    );
  }
}

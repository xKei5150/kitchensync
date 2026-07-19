import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kitchensync/app/design_tokens.dart';
import 'package:kitchensync/core/widgets/widgets.dart';
import 'package:kitchensync/features/notifications/domain/entities/notification_models.dart';
import 'package:kitchensync/features/notifications/presentation/providers/notification_providers.dart';

/// Household-scoped notification inbox backed by Firestore.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ks = context.ksColors;
    final notifications = ref.watch(activeNotificationsProvider);
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
                  onTap: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/today');
                    }
                  },
                ),
                const Spacer(),
                KsHeaderAction(
                  icon: Icons.tune_rounded,
                  tooltip: 'Notification preferences',
                  onTap: () => context.push('/settings/notifications'),
                ),
              ],
            ),
            const SizedBox(height: KsTokens.space8),
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
            notifications.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) =>
                  KsErrorAlert(message: 'Could not load notifications: $error'),
              data: (items) => _NotificationList(items: items),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationList extends ConsumerWidget {
  const _NotificationList({required this.items});

  final List<HouseholdNotification> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) {
      return const KsEmptyState(
        icon: Icons.notifications_none_rounded,
        title: 'Nothing needs your attention',
        subtitle: 'Household reminders and activity will appear here.',
      );
    }
    final today = DateTime.now();
    final current = items
        .where((item) => DateUtils.isSameDay(item.createdAt, today))
        .toList(growable: false);
    final earlier = items
        .where((item) => !DateUtils.isSameDay(item.createdAt, today))
        .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (current.isNotEmpty) ...[
          const _GroupLabel('Today'),
          const SizedBox(height: KsTokens.space8),
          _NotificationGroup(items: current),
        ],
        if (current.isNotEmpty && earlier.isNotEmpty)
          const SizedBox(height: KsTokens.space20),
        if (earlier.isNotEmpty) ...[
          const _GroupLabel('Earlier'),
          const SizedBox(height: KsTokens.space8),
          _NotificationGroup(items: earlier),
        ],
      ],
    );
  }
}

class _NotificationGroup extends ConsumerWidget {
  const _NotificationGroup({required this.items});

  final List<HouseholdNotification> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        for (var index = 0; index < items.length; index++) ...[
          if (index > 0) const SizedBox(height: KsTokens.space8),
          _NotificationItem(
            notification: items[index],
            onTap: () async {
              final item = items[index];
              if (!item.isRead) {
                try {
                  await ref
                      .read(notificationControllerProvider)
                      .markRead(item.id);
                } catch (error) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Could not mark as read: $error')),
                    );
                  }
                  return;
                }
              }
              if (context.mounted && item.route != null) {
                await context.push(item.route!);
              }
            },
          ),
        ],
      ],
    );
  }
}

class _NotificationItem extends StatelessWidget {
  const _NotificationItem({required this.notification, required this.onTap});

  final HouseholdNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = _styleFor(notification.type, context);
    return Opacity(
      opacity: notification.isRead ? 0.72 : 1,
      child: Semantics(
        button: true,
        label: notification.isRead
            ? 'Read notification'
            : 'Unread notification',
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(KsTokens.radius12),
          child: KsNotificationRow.icon(
            icon: style.icon,
            accent: style.color,
            title: notification.title,
            body: notification.body,
            time: _relativeTime(notification.createdAt),
            emphasized:
                !notification.isRead &&
                notification.type ==
                    HouseholdNotificationType.emergencyShopping,
          ),
        ),
      ),
    );
  }
}

({IconData icon, Color color}) _styleFor(
  HouseholdNotificationType type,
  BuildContext context,
) {
  final ks = context.ksColors;
  return switch (type) {
    HouseholdNotificationType.emergencyShopping => (
      icon: Icons.shopping_bag_outlined,
      color: ks.calProblem,
    ),
    HouseholdNotificationType.shoppingCompleted => (
      icon: Icons.check_circle_outline_rounded,
      color: ks.brandPrimary,
    ),
    HouseholdNotificationType.pantryExpiry => (
      icon: Icons.eco_rounded,
      color: KsTokens.expiringSoon,
    ),
    HouseholdNotificationType.bulkReminder => (
      icon: Icons.inventory_2_outlined,
      color: KsTokens.brandAccent,
    ),
    HouseholdNotificationType.householdActivity => (
      icon: Icons.groups_outlined,
      color: ks.brandPrimary,
    ),
  };
}

String _relativeTime(DateTime createdAt) {
  final age = DateTime.now().difference(createdAt);
  if (age.isNegative || age.inMinutes < 1) return 'now';
  if (age.inHours < 1) return '${age.inMinutes}m';
  if (age.inDays < 1) return '${age.inHours}h';
  if (age.inDays < 7) return '${age.inDays}d';
  return '${createdAt.month}/${createdAt.day}';
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: KsTokens.labelSmall.copyWith(
        color: context.ksColors.textTertiary,
        fontWeight: FontWeight.w700,
        fontSize: 10,
        letterSpacing: 1,
      ),
    );
  }
}

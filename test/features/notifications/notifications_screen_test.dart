import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/app/theme.dart';
import 'package:kitchensync/core/widgets/widgets.dart';
import 'package:kitchensync/features/notifications/presentation/screens/notifications_screen.dart';

void main() {
  testWidgets('NotificationsScreen groups alerts by time', (tester) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light(), home: const NotificationsScreen()),
    );

    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('TODAY'), findsOneWidget);
    expect(find.text('EARLIER'), findsOneWidget);
    expect(find.byType(KsNotificationRow), findsNWidgets(3));
    expect(find.text('Spinach is on its last day'), findsOneWidget);
    expect(find.text('Ben finished the shop'), findsOneWidget);
  });

  testWidgets('NotificationsScreen renders in dark theme without error', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.dark(), home: const NotificationsScreen()),
    );
    expect(tester.takeException(), isNull);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchensync/app/design_tokens.dart';
import 'package:kitchensync/app/theme.dart';
import 'package:kitchensync/core/widgets/widgets.dart';

/// Pumps [child] under a bounded width so Row/Expanded-based modules lay out
/// without overflowing the default 800×600 test surface.
Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  double width = 380,
  ThemeData? theme,
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Scaffold(
        body: Center(
          child: SizedBox(width: width, child: child),
        ),
      ),
    ),
  );
}

void main() {
  group('KsFolioHeader', () {
    testWidgets('renders an uppercased eyebrow, the title, and actions', (
      tester,
    ) async {
      await _pump(
        tester,
        const KsFolioHeader(
          eyebrow: 'The Kitchen · 04',
          title: 'Pantry',
          actions: [Icon(Icons.search)],
        ),
      );
      expect(find.text('THE KITCHEN · 04'), findsOneWidget);
      expect(find.text('Pantry'), findsOneWidget);
      expect(find.byIcon(Icons.search), findsOneWidget);
    });
  });

  group('KsBottomNav', () {
    testWidgets('renders the stable dashboard tabs', (tester) async {
      await _pump(
        tester,
        KsBottomNav(
          destinations: KsBottomNav.coreTabs,
          currentIndex: 0,
          onSelect: (_) {},
        ),
      );
      for (final label in [
        'Today',
        'Recipes',
        'Calendar',
        'Shopping List',
        'Pantry',
        'Menu Sets',
        'Settings',
      ]) {
        expect(find.text(label), findsOneWidget);
      }
    });

    testWidgets('selecting a destination reports its index', (tester) async {
      int? picked;
      await _pump(
        tester,
        KsBottomNav(
          destinations: KsBottomNav.coreTabs,
          currentIndex: 0,
          onSelect: (i) => picked = i,
        ),
      );
      await tester.tap(find.text('Shopping List'));
      expect(picked, 3);
    });

    testWidgets('the selected tab swaps to its filled glyph', (tester) async {
      await _pump(
        tester,
        KsBottomNav(
          destinations: KsBottomNav.coreTabs,
          currentIndex: 0,
          onSelect: (_) {},
        ),
      );
      expect(find.byIcon(Icons.home_rounded), findsOneWidget); // active Today
      expect(find.byIcon(Icons.calendar_today_outlined), findsOneWidget);
    });
  });

  group('KsCalendarDayCell', () {
    testWidgets('renders the day number, caption, and planned glyph', (
      tester,
    ) async {
      await _pump(
        tester,
        const KsCalendarDayCell(
          day: 12,
          status: CalendarDayStatus.planned,
          caption: 'Ragù · 4',
        ),
      );
      expect(find.text('12'), findsOneWidget);
      expect(find.text('Ragù · 4'), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    });

    testWidgets('the missed state uses a dashed edge + clock-slash glyph', (
      tester,
    ) async {
      await _pump(
        tester,
        const KsCalendarDayCell(day: 10, status: CalendarDayStatus.missed),
      );
      expect(find.byType(KsDashedBorder), findsOneWidget);
      expect(find.byIcon(Icons.timer_off_outlined), findsOneWidget);
    });

    testWidgets('today recolours the numeral with the brand green', (
      tester,
    ) async {
      await _pump(
        tester,
        const KsCalendarDayCell(
          day: 25,
          status: CalendarDayStatus.planned,
          caption: 'Today',
          isToday: true,
        ),
      );
      final text = tester.widget<Text>(find.text('25'));
      expect(text.style?.color, KsTokens.brandPrimary);
    });
  });

  group('KsAlmanacGrid', () {
    testWidgets('numbers real days, pads blanks, and shows a legend', (
      tester,
    ) async {
      await _pump(
        tester,
        const KsAlmanacGrid(
          days: [
            KsAlmanacDay.blank,
            KsAlmanacDay(CalendarDayStatus.planned),
            KsAlmanacDay(CalendarDayStatus.problem),
            KsAlmanacDay(CalendarDayStatus.shopping),
          ],
        ),
        width: 320,
      );
      // First real day is numbered 1 (the leading blank carries no numeral).
      expect(find.text('1'), findsOneWidget);
      expect(find.text('Planned'), findsOneWidget);
      expect(find.text('Missed'), findsOneWidget);
    });
  });

  group('KsDishChip', () {
    testWidgets('renders title, subtitle, and the state pill', (tester) async {
      await _pump(
        tester,
        const KsDishChip(
          title: 'Roast chicken thighs',
          subtitle: 'Dinner · serves 4',
          state: DishState.cooked,
        ),
      );
      expect(find.text('Roast chicken thighs'), findsOneWidget);
      expect(find.text('COOKED'), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    });

    testWidgets('cancelled strikes the title through', (tester) async {
      await _pump(
        tester,
        const KsDishChip(
          title: 'Pasta night',
          subtitle: 'Dinner · serves 4',
          state: DishState.cancelled,
        ),
      );
      final title = tester.widget<Text>(find.text('Pasta night'));
      expect(title.style?.decoration, TextDecoration.lineThrough);
    });

    testWidgets('waste dims the whole row', (tester) async {
      await _pump(
        tester,
        const KsDishChip(
          title: 'Spinach side',
          subtitle: 'went off',
          state: DishState.waste,
        ),
      );
      final opacity = tester.widget<Opacity>(
        find.ancestor(of: find.text('WASTE'), matching: find.byType(Opacity)),
      );
      expect(opacity.opacity, lessThan(1.0));
    });
  });

  group('KsRecipeCard', () {
    testWidgets('private carries meta, an edit action, and a delete glyph', (
      tester,
    ) async {
      await _pump(
        tester,
        const KsRecipeCard.private(
          title: 'Sunday lentil dal',
          meta: '35 min · serves 4',
        ),
      );
      expect(find.text('Sunday lentil dal'), findsOneWidget);
      expect(find.text('35 min · serves 4'), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    });

    testWidgets('public carries price, byline, and like/comment counts', (
      tester,
    ) async {
      await _pump(
        tester,
        const KsRecipeCard.public(
          title: 'Charred greens orzo',
          author: 'Marco R.',
          price: '£3.20',
          likeCount: 248,
          commentCount: 31,
        ),
      );
      expect(find.text('£3.20'), findsOneWidget);
      expect(find.text('by Marco R.'), findsOneWidget);
      expect(find.text('248'), findsOneWidget);
      expect(find.text('31'), findsOneWidget);
      expect(find.byIcon(Icons.favorite), findsOneWidget);
    });
  });

  group('KsServingScaler', () {
    testWidgets('shows the serving count and base amounts', (tester) async {
      await _pump(
        tester,
        const KsServingScaler(
          baseServings: 4,
          ingredients: [
            KsScalableIngredient(name: 'Orzo', baseAmount: 320, unit: 'g'),
          ],
        ),
      );
      expect(find.text('4'), findsOneWidget);
      expect(find.text('320 g'), findsOneWidget);
      expect(find.text('SERVINGS'), findsOneWidget);
    });

    testWidgets('scales amounts to the initial serving count', (tester) async {
      await _pump(
        tester,
        const KsServingScaler(
          baseServings: 4,
          initialServings: 6,
          ingredients: [
            KsScalableIngredient(name: 'Orzo', baseAmount: 320, unit: 'g'),
          ],
        ),
      );
      expect(find.text('6'), findsOneWidget);
      expect(find.text('480 g'), findsOneWidget); // 320 / 4 * 6
    });
  });

  group('KsChecklistRow', () {
    testWidgets('to-buy shows the quantity', (tester) async {
      await _pump(
        tester,
        const KsChecklistRow(
          name: 'Tomatoes',
          state: ChecklistItemState.toBuy,
          quantity: '1 kg',
        ),
      );
      expect(find.text('Tomatoes'), findsOneWidget);
      expect(find.text('1 kg'), findsOneWidget);
    });

    testWidgets('bought strikes through and shows the member tick', (
      tester,
    ) async {
      await _pump(
        tester,
        const KsChecklistRow(
          name: 'White beans · 2 tins',
          state: ChecklistItemState.bought,
          memberInitial: 'B',
          memberSeat: 1,
        ),
      );
      final label = tester.widget<Text>(find.text('White beans · 2 tins'));
      expect(label.style?.decoration, TextDecoration.lineThrough);
      expect(find.byType(KsMemberAvatar), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
    });

    testWidgets('substituted shows the note with a swap glyph', (tester) async {
      await _pump(
        tester,
        const KsChecklistRow(
          name: 'Orzo',
          state: ChecklistItemState.substituted,
          note: 'got risoni',
          memberSeat: 4,
        ),
      );
      expect(find.text('got risoni'), findsOneWidget);
      expect(find.byIcon(Icons.swap_horiz), findsOneWidget);
    });

    testWidgets('unavailable marks the box with a danger cross', (
      tester,
    ) async {
      await _pump(
        tester,
        const KsChecklistRow(
          name: 'Fresh dill',
          state: ChecklistItemState.unavailable,
          note: "couldn't find",
        ),
      );
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
      expect(find.text("couldn't find"), findsOneWidget);
    });
  });

  group('KsMemberRow & invite', () {
    testWidgets('renders name, handle, role pill, and avatar initial', (
      tester,
    ) async {
      await _pump(
        tester,
        const KsMemberRow(
          name: 'Ana',
          handle: 'ana@home',
          role: HouseholdRole.admin,
          seat: 0,
        ),
      );
      expect(find.text('Ana'), findsOneWidget);
      expect(find.text('ana@home'), findsOneWidget);
      expect(find.text('ADMIN'), findsOneWidget);
      expect(find.text('A'), findsOneWidget);
    });

    testWidgets('invite code shows the code and fires copy', (tester) async {
      var copied = false;
      await _pump(
        tester,
        KsInviteCode(code: 'SAGE-417', onCopy: () => copied = true),
      );
      expect(find.text('SAGE-417'), findsOneWidget);
      expect(find.text('INVITE TO THIS KITCHEN'), findsOneWidget);
      await tester.tap(find.text('Copy'));
      expect(copied, isTrue);
    });
  });

  group('KsMenuSet', () {
    testWidgets('card shows title, meta, premium badge, and actions', (
      tester,
    ) async {
      await _pump(
        tester,
        const KsMenuSetCard(
          title: 'Cosy autumn week',
          meta: '7 days · 14 meals · £61',
          days: [
            KsMenuDay(weekday: 'M', dishColors: [KsTokens.catGrain]),
            KsMenuDay(weekday: 'T', dishColors: [KsTokens.catMeat]),
          ],
        ),
      );
      expect(find.text('Cosy autumn week'), findsOneWidget);
      expect(find.text('7 days · 14 meals · £61'), findsOneWidget);
      expect(find.text('PREMIUM'), findsOneWidget);
      expect(find.text('Apply to calendar'), findsOneWidget);
      expect(find.text('Duplicate'), findsOneWidget);
    });

    testWidgets('slot editor shows a drop target and placed entries', (
      tester,
    ) async {
      await _pump(
        tester,
        const KsMenuSlotEditor(
          slots: [
            KsMenuSlot(
              weekday: 'Mon',
              entries: [
                KsMenuSlotEntry(label: 'Dal', color: KsTokens.catGrain),
              ],
            ),
            KsMenuSlot(weekday: 'Tue', isDropTarget: true),
          ],
          draggingLabel: 'Chilli pasta',
        ),
        width: 320,
      );
      expect(find.text('Dal'), findsOneWidget);
      expect(find.text('Drop here'), findsOneWidget);
      expect(find.text('Chilli pasta'), findsOneWidget);
    });
  });

  group('KsInsightTile', () {
    testWidgets('jar renders its value and caption', (tester) async {
      await _pump(
        tester,
        const KsInsightTile.jar(
          value: '3 days',
          caption: 'until the milk runs out',
        ),
        width: 200,
      );
      expect(find.text('3 days'), findsOneWidget);
      expect(find.text('until the milk runs out'), findsOneWidget);
    });

    testWidgets('almanac renders its value and caption', (tester) async {
      await _pump(
        tester,
        const KsInsightTile.almanac(
          value: '2',
          caption: 'things binned this week',
          wasteDays: [false, false, true, false, false, true, false],
        ),
        width: 200,
      );
      expect(find.text('2'), findsOneWidget);
      expect(find.text('things binned this week'), findsOneWidget);
    });
  });

  group('KsPremiumLock', () {
    testWidgets('veils the working child with a titled invitation', (
      tester,
    ) async {
      await _pump(
        tester,
        const KsPremiumLock(
          title: 'Reuse a week you loved',
          body: 'Save any week as a Menu Set.',
          child: SizedBox(height: 240, child: Text('feature')),
        ),
      );
      expect(find.text('feature'), findsOneWidget); // working beneath the veil
      expect(find.text('Reuse a week you loved'), findsOneWidget);
      expect(find.text('Unlock Premium'), findsOneWidget);
      expect(find.byIcon(Icons.star_rounded), findsOneWidget);
    });
  });

  group('KsNotificationRow', () {
    testWidgets('icon variant renders glyph, title, body, and time', (
      tester,
    ) async {
      await _pump(
        tester,
        const KsNotificationRow.icon(
          icon: Icons.eco,
          accent: KsTokens.expiringSoon,
          title: 'Spinach is on its last day',
          body: 'Soup tonight?',
          time: '2h',
        ),
      );
      expect(find.byIcon(Icons.eco), findsOneWidget);
      expect(find.text('Spinach is on its last day'), findsOneWidget);
      expect(find.text('2h'), findsOneWidget);
    });

    testWidgets('member variant renders an avatar instead of a glyph', (
      tester,
    ) async {
      await _pump(
        tester,
        const KsNotificationRow.member(
          initial: 'B',
          seat: 1,
          title: 'Ben finished the shop',
          body: '11 of 12 items ticked.',
          time: '1d',
        ),
      );
      expect(find.byType(KsMemberAvatar), findsOneWidget);
      expect(find.text('Ben finished the shop'), findsOneWidget);
    });
  });

  group('dark mode', () {
    testWidgets('KsDishChip fills with the dark raised surface', (
      tester,
    ) async {
      await _pump(
        tester,
        const KsDishChip(
          title: 'Tomato braise',
          subtitle: 'Dinner · serves 4',
          state: DishState.scheduled,
        ),
        theme: AppTheme.dark(),
      );
      final container = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(KsDishChip),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(
        (container.decoration! as BoxDecoration).color,
        KsColors.dark.surfaceRaised,
      );
    });

    testWidgets('KsCalendarDayCell today numeral uses the dark brand', (
      tester,
    ) async {
      await _pump(
        tester,
        const KsCalendarDayCell(
          day: 25,
          status: CalendarDayStatus.planned,
          isToday: true,
        ),
        theme: AppTheme.dark(),
      );
      final text = tester.widget<Text>(find.text('25'));
      expect(text.style?.color, KsColors.dark.brandPrimary);
    });
  });
}

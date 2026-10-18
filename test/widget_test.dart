import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bookii/main.dart';
import 'package:bookii/screens/explore_screen.dart';
import 'package:bookii/theme/app_theme.dart';

void main() {
  test('Rethink Sans is the app-wide text family', () {
    final theme = AppTheme.light;

    expect(theme.textTheme.bodyMedium?.fontFamily, 'Rethink Sans');
    expect(theme.primaryTextTheme.bodyMedium?.fontFamily, 'Rethink Sans');
    expect(theme.scaffoldBackgroundColor, Colors.white);
  });

  testWidgets('splash automatically opens the three-screen welcome flow', (
    tester,
  ) async {
    await tester.pumpWidget(const BookiiApp());

    expect(find.text('Bukii'), findsOneWidget);
    expect(find.text('Get started'), findsNothing);

    await tester.pump(const Duration(milliseconds: 2800));
    await tester.pumpAndSettle();

    expect(find.text('Welcome to Bukii'), findsOneWidget);
    await tester.ensureVisible(find.text('Customer'));
    await tester.tap(find.text('Customer'));
    await tester.pumpAndSettle();

    expect(
      find.text('Helping you find good service close to home.'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Welcome screen 1 of 3'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('onboarding-continue')));
    await tester.pumpAndSettle();
    expect(find.text('Pick a time that fits your day.'), findsOneWidget);
    expect(find.bySemanticsLabel('Welcome screen 2 of 3'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('onboarding-continue')));
    await tester.pumpAndSettle();
    expect(find.text('We’ll remind you. You just show up.'), findsOneWidget);
    expect(find.bySemanticsLabel('Welcome screen 3 of 3'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('onboarding-continue')));
    await tester.pumpAndSettle();
    expect(find.text('GOOD SERVICE, RIGHT AROUND YOU'), findsOneWidget);
    expect(find.text('Your time,\nwell spent.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('phone-number-field')),
      '8012345678',
    );
    expect(find.text('801 234 5678'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('phone-continue')));
    await tester.tap(find.byKey(const ValueKey('phone-continue')));
    await tester.pumpAndSettle();

    expect(find.text('Enter the code'), findsOneWidget);
    expect(
      find.text('We sent a 6-digit code to +234 801 234 5678'),
      findsOneWidget,
    );

    for (var index = 0; index < 6; index++) {
      await tester.enterText(
        find.byKey(ValueKey('verification-digit-$index')),
        '${index + 1}',
      );
    }
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('verify-continue')));
    await tester.tap(find.byKey(const ValueKey('verify-continue')));
    await tester.pumpAndSettle();

    expect(find.text('Near you'), findsOneWidget);
    expect(find.textContaining('Amara'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Popular services'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Popular services'), findsOneWidget);
  });

  testWidgets('skip opens Explore from the first welcome screen', (
    tester,
  ) async {
    await tester.pumpWidget(const BookiiApp());
    await tester.pump(const Duration(milliseconds: 2800));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('For Business Owners'));
    await tester.tap(find.text('For Business Owners'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('onboarding-skip')));
    await tester.pumpAndSettle();

    expect(find.text('Near you'), findsOneWidget);
  });

  testWidgets('bottom navigation opens all four booking tabs', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ExploreScreen()));

    expect(find.text('Explore'), findsOneWidget);
    expect(find.text('Bookings'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
    expect(find.byIcon(Icons.home_outlined), findsOneWidget);
    expect(find.byIcon(Icons.event_available_outlined), findsOneWidget);
    expect(find.byIcon(Icons.history_rounded), findsOneWidget);
    expect(find.byIcon(Icons.person_outline_rounded), findsWidgets);

    await tester.tap(find.text('Bookings'));
    await tester.pumpAndSettle();
    expect(find.text('UP NEXT'), findsOneWidget);

    await tester.tap(find.text('History').last);
    await tester.pumpAndSettle();
    expect(find.text('Visit history'), findsOneWidget);
    expect(find.text('FAVOURITE'), findsOneWidget);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('Appointment reminders'), findsOneWidget);
    expect(find.text('Saved businesses'), findsOneWidget);
  });

  testWidgets('customers can complete the service-to-booking flow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(const MaterialApp(home: ExploreScreen()));

    const weekdays = [
      'MONDAY',
      'TUESDAY',
      'WEDNESDAY',
      'THURSDAY',
      'FRIDAY',
      'SATURDAY',
      'SUNDAY',
    ];
    const months = [
      'JANUARY',
      'FEBRUARY',
      'MARCH',
      'APRIL',
      'MAY',
      'JUNE',
      'JULY',
      'AUGUST',
      'SEPTEMBER',
      'OCTOBER',
      'NOVEMBER',
      'DECEMBER',
    ];
    final today = DateTime.now();
    expect(
      find.text(
        '${weekdays[today.weekday - 1]}, ${today.day} '
        '${months[today.month - 1]}',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Amara'), findsOneWidget);
    expect(find.text('Fade Lab'), findsOneWidget);

    await tester.ensureVisible(find.text('Fade Lab'));
    await tester.tap(find.text('Fade Lab'));
    await tester.pumpAndSettle();
    expect(find.text('Choose a service'), findsOneWidget);
    expect(find.text('Opening Hours'), findsOneWidget);

    final haircutAndBeard = find.byKey(
      const ValueKey('service-Haircut + Beard'),
    );
    await tester.scrollUntilVisible(
      haircutAndBeard,
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(haircutAndBeard);
    await tester.ensureVisible(find.text('Book Now'));
    await tester.tap(find.text('Book Now'));
    await tester.pumpAndSettle();

    expect(find.text('Almost there.'), findsOneWidget);
    expect(find.text('Haircut + Beard'), findsOneWidget);
    expect(find.text('₦18,000'), findsOneWidget);

    await tester.tap(find.text('Confirm booking'));
    await tester.pumpAndSettle();
    expect(find.text('It’s booked,\nAmara.'), findsOneWidget);
    expect(find.text('BOOKING REFERENCE'), findsOneWidget);

    await tester.tap(find.text('View my bookings'));
    await tester.pumpAndSettle();
    expect(find.text('UP NEXT'), findsOneWidget);
    expect(find.text('Fade Lab'), findsWidgets);
  });
}

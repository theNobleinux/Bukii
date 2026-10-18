import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bookii/main.dart';
import 'package:bookii/screens/library_screen.dart';
import 'package:bookii/theme/app_theme.dart';

void main() {
  test('Rethink Sans is the app-wide text family', () {
    final theme = AppTheme.light;

    expect(theme.textTheme.bodyMedium?.fontFamily, 'Rethink Sans');
    expect(theme.primaryTextTheme.bodyMedium?.fontFamily, 'Rethink Sans');
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

    expect(find.text('Your little library'), findsOneWidget);
  });

  testWidgets('skip opens the library from the first welcome screen', (
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

    expect(find.text('Your little library'), findsOneWidget);
  });

  testWidgets('search and saved books update the visible shelf', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: LibraryScreen()));

    await tester.enterText(find.byType(TextField), 'Mira');
    await tester.pumpAndSettle();
    expect(find.text('The Quiet Between'), findsWidgets);
    expect(find.text('Small Hours'), findsNothing);

    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();

    expect(find.text('A Map of Elsewhere'), findsWidgets);
    await tester.tap(find.byTooltip('Remove from saved'));
    await tester.pumpAndSettle();
    expect(find.text('Your saved shelf is waiting.'), findsOneWidget);
  });

  testWidgets('library navigation matches the four reference tabs', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: LibraryScreen()));

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
    expect(find.text('Find your next read'), findsOneWidget);

    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(find.text('Your reading history'), findsOneWidget);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('Your profile'), findsOneWidget);
  });
}

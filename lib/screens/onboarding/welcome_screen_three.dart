import 'package:flutter/material.dart';

import 'welcome_artwork.dart';

class WelcomeScreenThree extends StatelessWidget {
  const WelcomeScreenThree({super.key});

  @override
  Widget build(BuildContext context) {
    return const WelcomeSlide(
      screen: 3,
      kicker: 'READY WHEN YOU ARE',
      title: 'We’ll remind you. You just show up.',
      description: 'See real openings and book without calling around.',
    );
  }
}

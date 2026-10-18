import 'package:flutter/material.dart';

import 'welcome_artwork.dart';

class WelcomeScreenOne extends StatelessWidget {
  const WelcomeScreenOne({super.key});

  @override
  Widget build(BuildContext context) {
    return const WelcomeSlide(
      screen: 1,
      kicker: 'LOCAL, TRUSTED, READY',
      title: 'Helping you find good service close to home.',
      description:
          'Discover independent salons, barbers, tutors and more around you.',
    );
  }
}

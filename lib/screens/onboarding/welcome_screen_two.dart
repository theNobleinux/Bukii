import 'package:flutter/material.dart';

import 'welcome_artwork.dart';

class WelcomeScreenTwo extends StatelessWidget {
  const WelcomeScreenTwo({super.key});

  @override
  Widget build(BuildContext context) {
    return const WelcomeSlide(
      screen: 2,
      kicker: 'YOUR TIME, YOURS',
      title: 'Pick a time that fits your day.',
      description: 'See real openings and book without calling around.',
    );
  }
}

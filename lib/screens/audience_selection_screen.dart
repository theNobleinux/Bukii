import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'onboarding_screen.dart';
import 'onboarding/welcome_artwork.dart';

class AudienceSelectionScreen extends StatelessWidget {
  const AudienceSelectionScreen({super.key});

  void _startOnboarding(BuildContext context, String audience) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => OnboardingScreen(audience: audience),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final artworkHeight = (constraints.maxHeight * 0.35)
                .clamp(225.0, 390.0)
                .toDouble();
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(26, 24, 26, 22 + bottomInset),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 46 - bottomInset,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Welcome to Bukii',
                            textAlign: TextAlign.left,
                            style: TextStyle(
                              color: AppColors.ink,
                              fontSize: 30,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -1,
                            ),
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            height: artworkHeight,
                            child: const WelcomeArtwork(screen: 0),
                          ),
                          const SizedBox(height: 28),
                          const Text(
                            'Book local services in seconds & create a website at a click of a button',
                            style: TextStyle(
                              color: AppColors.orange,
                              fontSize: 31,
                              fontWeight: FontWeight.w600,
                              height: 1.18,
                              letterSpacing: -0.8,
                            ),
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            'Find trusted local pros, or get your own business online in minutes.',
                            style: TextStyle(
                              color: AppColors.muted,
                              fontSize: 15,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                      const Expanded(flex: 1, child: SizedBox(height: 90,)),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _AudienceButton(
                            label: 'Customer',
                            backgroundColor: Colors.black,
                            onPressed: () =>
                                _startOnboarding(context, 'Customer'),
                          ),

                          const SizedBox(height: 13),

                          _AudienceButton(
                            label: 'For Business Owners',
                            backgroundColor: AppColors.orange,
                            onPressed: () =>
                                _startOnboarding(context, 'Business owner'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AudienceButton extends StatelessWidget {
  const _AudienceButton({
    required this.label,
    required this.backgroundColor,
    required this.onPressed,
  });

  final String label;
  final Color backgroundColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      ),
      child: Text(label),
    );
  }
}

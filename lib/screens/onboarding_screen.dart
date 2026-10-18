import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'explore_screen.dart';
import 'onboarding/welcome_screen_one.dart';
import 'onboarding/welcome_screen_three.dart';
import 'onboarding/welcome_screen_two.dart';
import 'phone_signin_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.audience});

  final String audience;

  /// Creates the onboarding widget state.
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _pageCount = 3;
  final _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    // Release the page controller when the onboarding flow is removed.
    _pageController.dispose();
    super.dispose();
  }

  /// Skips the introduction and opens the app on its Explore tab.
  void _skip() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const ExploreScreen()),
      (route) => false,
    );
  }

  /// Advances one onboarding page, or opens phone sign-in from the final page.
  void _continue() {
    if (_currentPage == _pageCount - 1) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PhoneSigninScreen(audience: widget.audience),
        ),
      );
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  /// Builds the swipeable onboarding pages, indicator, and continue action.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                key: const ValueKey('onboarding-skip'),
                onPressed: _skip,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.orange,
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                child: const Text('Skip'),
              ),
            ),
            Expanded(
              child: PageView(
                key: const ValueKey('onboarding-page-view'),
                controller: _pageController,
                onPageChanged: (page) => setState(() => _currentPage = page),
                children: const [
                  WelcomeScreenOne(),
                  WelcomeScreenTwo(),
                  WelcomeScreenThree(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(26, 4, 26, 22),
              child: Column(
                children: [
                  _ScreenIndicator(
                    currentPage: _currentPage,
                    pageCount: _pageCount,
                    onSelected: (page) => _pageController.animateToPage(
                      page,
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOutCubic,
                    ),
                  ),

                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      key: const ValueKey('onboarding-continue'),
                      onPressed: _continue,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.orange,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      child: Text(
                        _currentPage == _pageCount - 1
                            ? 'Continue with phone'
                            : 'Continue',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScreenIndicator extends StatelessWidget {
  const _ScreenIndicator({
    required this.currentPage,
    required this.pageCount,
    required this.onSelected,
  });

  final int currentPage;
  final int pageCount;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Welcome screen ${currentPage + 1} of $pageCount',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(pageCount, (index) {
          final selected = index == currentPage;
          return Semantics(
            button: true,
            label: 'Go to welcome screen ${index + 1}',
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: InkWell(
                onTap: () => onSelected(index),
                customBorder: const StadiumBorder(),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: selected ? 26 : 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.orange
                        : const Color(0xFFE3DED8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

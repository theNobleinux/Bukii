import 'dart:async';

import 'package:flutter/material.dart';

import '../data/backend/bukii_backend.dart';
import '../theme/app_theme.dart';
import 'audience_selection_screen.dart';
import 'explore_screen.dart';

class BukiiSplashScreen extends StatefulWidget {
  const BukiiSplashScreen({super.key});

  @override
  State<BukiiSplashScreen> createState() => _BukiiSplashScreenState();
}

class _BukiiSplashScreenState extends State<BukiiSplashScreen>
    with SingleTickerProviderStateMixin {
  static const _splashDuration = Duration(milliseconds: 2800);
  static const _transitionDuration = Duration(milliseconds: 350);

  late final AnimationController _pulseController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _opacityAnimation;
  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.94,
          end: 1,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 65,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1,
          end: 0.98,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 35,
      ),
    ]).animate(_pulseController);
    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.72,
          end: 1,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 65,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1,
          end: 0.82,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 35,
      ),
    ]).animate(_pulseController);
    _pulseController.repeat();
    _navigationTimer = Timer(_splashDuration, _openAudienceSelection);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulseController.stop();
    } else if (!_pulseController.isAnimating) {
      _pulseController.repeat();
    }
  }

  void _openAudienceSelection() {
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: _transitionDuration,
        // Returning users with a saved session go straight to Explore.
        pageBuilder: (_, _, _) => BukiiBackend.instance.isSignedIn
            ? const ExploreScreen()
            : const AudienceSelectionScreen(),
        transitionsBuilder: (_, animation, _, child) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeInOut),
          child: child,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: AnimatedBuilder(
            animation: _pulseController,
            child: Semantics(
              label: 'Bukii',
              child: const Text(
                'Bukii',
                style: TextStyle(
                  color: AppColors.orange,
                  fontSize: 58,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -2.5,
                  height: 1,
                ),
              ),
            ),
            builder: (context, child) => Opacity(
              opacity: _opacityAnimation.value,
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

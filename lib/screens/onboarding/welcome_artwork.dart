import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class WelcomeSlide extends StatelessWidget {
  const WelcomeSlide({
    super.key,
    required this.screen,
    required this.kicker,
    required this.title,
    required this.description,
  });

  final int screen;
  final String kicker;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final artHeight = (constraints.maxHeight * 0.43)
            .clamp(190.0, 330.0)
            .toDouble();
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(26, 8, 26, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: double.infinity,
                height: artHeight,
                child: WelcomeArtwork(screen: screen),
              ),
              const SizedBox(height: 26),
              Text(
                kicker,
                style: const TextStyle(
                  color: AppColors.orange,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                  letterSpacing: -0.9,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                description,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class WelcomeArtwork extends StatelessWidget {
  const WelcomeArtwork({super.key, required this.screen});

  final int screen;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: switch (screen) {
        0 => const _AudienceArtwork(),
        1 => const _FirstArtwork(),
        2 => const _SecondArtwork(),
        _ => const _ThirdArtwork(),
      },
    );
  }
}

class _AudienceArtwork extends StatelessWidget {
  const _AudienceArtwork();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(color: const Color(0xFFF2D5CA)),
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: 0.49 * MediaQuery.sizeOf(context).width,
          child: const _IllustrationTile(
            color: Color(0xFF272422),
            icon: Icons.storefront_rounded,
            iconColor: Color(0xFFF2B7A1),
            radius: BorderRadius.only(bottomRight: Radius.circular(96)),
          ),
        ),
        Positioned(
          right: 0,
          top: 18,
          bottom: 18,
          width: 0.39 * MediaQuery.sizeOf(context).width,
          child: const _IllustrationTile(
            color: Color(0xFFDDDAD5),
            icon: Icons.person_search_rounded,
            iconColor: Color(0xFF8F665B),
            radius: BorderRadius.only(bottomLeft: Radius.circular(110)),
          ),
        ),
        Positioned(
          left: 12,
          bottom: 12,
          child: _FloatingLabel(
            icon: Icons.location_on_rounded,
            label: 'Local pros',
          ),
        ),
      ],
    );
  }
}

class _FirstArtwork extends StatelessWidget {
  const _FirstArtwork();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(color: const Color(0xFF121212)),
        Positioned(
          left: 0,
          top: 0,
          right: 0,
          height: 0.72 * 330,
          child: const _IllustrationTile(
            color: Color(0xFFD9D9D9),
            icon: Icons.storefront_rounded,
            iconColor: Color(0xFF88847E),
            radius: BorderRadius.only(bottomLeft: Radius.circular(120)),
          ),
        ),
        const Positioned(
          left: 20,
          bottom: 18,
          child: _FloatingLabel(
            icon: Icons.check_circle_rounded,
            label: 'Trusted near you',
          ),
        ),
      ],
    );
  }
}

class _SecondArtwork extends StatelessWidget {
  const _SecondArtwork();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(color: AppColors.orange),
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: MediaQuery.sizeOf(context).width * 0.47,
          child: const _IllustrationTile(
            color: Color(0xFFD9D9D9),
            icon: Icons.calendar_month_rounded,
            iconColor: Color(0xFF817D77),
            radius: BorderRadius.only(bottomRight: Radius.circular(110)),
          ),
        ),
        Positioned(
          top: 30,
          right: 26,
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.schedule_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
        ),
      ],
    );
  }
}

class _ThirdArtwork extends StatelessWidget {
  const _ThirdArtwork();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(color: Colors.black),
        Positioned(
          left: 0,
          bottom: 0,
          width: MediaQuery.sizeOf(context).width * 0.48,
          height: 0.78 * 330,
          child: const DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.orange,
              borderRadius: BorderRadius.only(topRight: Radius.circular(130)),
            ),
            child: Icon(
              Icons.notifications_active_rounded,
              color: Colors.white,
              size: 68,
            ),
          ),
        ),
        Positioned(
          right: 26,
          top: 28,
          child: Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              color: Colors.white,
              size: 34,
            ),
          ),
        ),
      ],
    );
  }
}

class _IllustrationTile extends StatelessWidget {
  const _IllustrationTile({
    required this.color,
    required this.icon,
    required this.iconColor,
    required this.radius,
  });

  final Color color;
  final IconData icon;
  final Color iconColor;
  final BorderRadius radius;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: color, borderRadius: radius),
      child: Center(child: Icon(icon, size: 76, color: iconColor)),
    );
  }
}

class _FloatingLabel extends StatelessWidget {
  const _FloatingLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x20000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: AppColors.orange),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

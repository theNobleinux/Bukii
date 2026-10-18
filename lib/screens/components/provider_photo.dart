import 'package:flutter/material.dart';

import '../../data/models/provider.dart';
import '../../theme/app_theme.dart';

class ProviderPhoto extends StatelessWidget {
  const ProviderPhoto({
    super.key,
    required this.provider,
    this.compact = false,
  });

  final ServiceProvider provider;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final radius = compact ? 14.0 : 0.0;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(radius),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            provider.category == 'Barber'
                ? Icons.content_cut_rounded
                : Icons.storefront_outlined,
            color: const Color(0xFFB9AEA2),
            size: compact ? 28 : 38,
          ),
          if (!compact) ...[
            const SizedBox(height: 8),
            const Text(
              'Shop / Store front picture',
              style: TextStyle(color: AppColors.muted, fontSize: 14),
            ),
          ],
        ],
      ),
    );
  }
}

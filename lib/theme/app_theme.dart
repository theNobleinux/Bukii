import 'package:flutter/material.dart';

abstract final class AppColors {
  static const orange = Color(0xFFEF4E12);
  static const ink = Color(0xFF25231F);
  static const paper = Color(0xFFF5F0EA);
  static const canvas = Colors.white;
  static const muted = Color(0xFF77716A);
}

abstract final class AppTheme {
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.canvas,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.orange,
      brightness: Brightness.light,
      surface: AppColors.canvas,
    ),
    fontFamily: 'Rethink Sans',
  );
}

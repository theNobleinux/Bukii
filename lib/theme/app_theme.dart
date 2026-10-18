import 'package:flutter/material.dart';

abstract final class AppColors {
  static const orange = Color(0xFFEF4E12);
  static const ink = Color(0xFF25231F);
  static const paper = Color(0xFFFBF9F6);
  static const muted = Color(0xFF77716A);
}

abstract final class AppTheme {
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.paper,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.orange,
      brightness: Brightness.light,
      surface: AppColors.paper,
    ),
    fontFamily: 'Rethink Sans',
  );
}

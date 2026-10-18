import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/bukii_splash_screen.dart';

void main() {
  LicenseRegistry.addLicense(() async* {
    final license = await rootBundle.loadString('assets/fonts/OFL.txt');
    yield LicenseEntryWithLineBreaks(['Rethink Sans'], license);
  });
  runApp(const BookiiApp());
}

class BookiiApp extends StatelessWidget {
  const BookiiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bukii',
      debugShowCheckedModeBanner: false,
      theme:  ThemeData(fontFamily: 'RethinkSans'),
      home: const BukiiSplashScreen(),
    );
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/supabase_config.dart';
import 'data/backend/bukii_backend.dart';
import 'data/backend/supabase_backend.dart';
import 'screens/bukii_splash_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  LicenseRegistry.addLicense(() async* {
    try {
      final license = await rootBundle.loadString('assets/fonts/OFL.txt');
      yield LicenseEntryWithLineBreaks(['Rethink Sans'], license);
    } catch (_) {
      // OFL.txt not bundled yet; skip instead of crashing the licenses page.
    }
  });

  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.publishableKey,
  );
  BukiiBackend.instance = SupabaseBackend(Supabase.instance.client);

  runApp(const BookiiApp());
}

class BookiiApp extends StatelessWidget {
  const BookiiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bukii',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const BukiiSplashScreen(),
    );
  }
}

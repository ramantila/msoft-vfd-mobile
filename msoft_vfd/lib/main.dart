import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/screens/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const MsoftApp());
}

class MsoftApp extends StatefulWidget {
  const MsoftApp({super.key});

  @override
  State<MsoftApp> createState() => _MsoftAppState();

  // ignore: library_private_types_in_public_api
  static _MsoftAppState of(BuildContext context) =>
      context.findAncestorStateOfType<_MsoftAppState>()!;
}

class _MsoftAppState extends State<MsoftApp> {
  AppThemeMode _themeMode = AppThemeMode.defaultMode;

  AppThemeMode get themeMode => _themeMode;

  void setTheme(AppThemeMode mode) => setState(() => _themeMode = mode);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MSOFT vfd',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
        textTheme: GoogleFonts.plusJakartaSansTextTheme(),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}
import 'package:flutter/material.dart';

import 'core/app_colors.dart';
import 'screens/login_screen.dart';
import 'screens/shell.dart';
import 'state/sage_state.dart';

/// START HERE. Every Flutter app begins at main().
/// runApp() puts our first widget (SageApp) on the screen.
void main() => runApp(const SageApp());

/// The root of the app: sets the theme and decides which screen to show.
class SageApp extends StatelessWidget {
  const SageApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SAGE Control Room',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.bg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.accent,
          brightness: Brightness.dark,
        ),
      ),
      // AnimatedBuilder "listens" to sage. Every time sage calls
      // notifyListeners(), this builder runs again and the screen redraws.
      //   not logged in -> LoginScreen        logged in -> Shell
      home: AnimatedBuilder(
        animation: sage,
        builder: (context, _) => sage.role == null ? LoginScreen() : Shell(),
      ),
    );
  }
}

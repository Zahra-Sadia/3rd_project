import 'package:flutter/material.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/welcome_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'theme/app_theme.dart';
import 'utils/app_routes.dart';

void main() {
  runApp(const AspireXApp());
}

class AspireXApp extends StatelessWidget {
  const AspireXApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      title: 'Fort Vault',

      theme: AppTheme.darkTheme,

      initialRoute: AppRoutes.splash,

      routes: {
        AppRoutes.splash: (context) => const SplashScreen(),

        AppRoutes.onboarding: (context) => const OnboardingScreen(),

        AppRoutes.welcome: (context) => const WelcomeScreen(),

        AppRoutes.login: (context) => const LoginScreen(),

        AppRoutes.register: (context) => const RegisterScreen(),

        AppRoutes.home: (context) => const HomeScreen(),

        AppRoutes.profile: (context) => const ProfileScreen(),
      },
    );
  }
}

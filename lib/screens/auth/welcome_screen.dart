import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/glass_card.dart';

import 'login_screen.dart';
import 'register_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            // -----------------------------------------
            // TOP DECORATIVE GLOW
            // -----------------------------------------
            Positioned(
              top: -130,
              right: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.roseGold.withOpacity(0.08),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.roseGold.withOpacity(0.10),
                      blurRadius: 130,
                      spreadRadius: 40,
                    ),
                  ],
                ),
              ),
            ),

            // -----------------------------------------
            // BOTTOM DECORATIVE GLOW
            // -----------------------------------------
            Positioned(
              bottom: -160,
              left: -120,
              child: Container(
                width: 340,
                height: 340,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.softPeach.withOpacity(0.06),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.softPeach.withOpacity(0.08),
                      blurRadius: 140,
                      spreadRadius: 40,
                    ),
                  ],
                ),
              ),
            ),

            // -----------------------------------------
            // MAIN CONTENT
            // -----------------------------------------
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const Spacer(flex: 2),

                  // LOGO
                  const AppLogo(fontSize: 52),

                  const SizedBox(height: 14),

                  // SMALL ROSE-GOLD LINE
                  Container(
                    width: 42,
                    height: 1.5,
                    decoration: BoxDecoration(
                      color: AppColors.roseGold,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),

                  const SizedBox(height: 18),

                  const Text(
                    'Smarter Money Management Starts Here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.secondaryText,
                      fontSize: 14,
                      fontWeight: FontWeight.w300,
                      height: 1.5,
                    ),
                  ),

                  const Spacer(),

                  // -----------------------------------
                  // SECTION TITLE
                  // -----------------------------------
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "LET'S GET YOU STARTED",
                      style: TextStyle(
                        color: AppColors.primaryText,
                        fontSize: 11,
                        letterSpacing: 2.8,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // -----------------------------------
                  // GUEST
                  // -----------------------------------
                  _buildOption(
                    context: context,
                    icon: Icons.explore_outlined,
                    title: 'Continue as Guest',
                    subtitle: 'Explore opportunities freely',
                    onTap: () {
                      // Guest flow will be connected later.
                    },
                  ),

                  const SizedBox(height: 12),

                  // -----------------------------------
                  // CREATE ACCOUNT
                  // -----------------------------------
                  _buildOption(
                    context: context,
                    icon: Icons.person_add_outlined,
                    title: 'Create Account',
                    subtitle: 'Personalize your experience',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const RegisterScreen(),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 12),

                  // -----------------------------------
                  // LOGIN
                  // -----------------------------------
                  _buildOption(
                    context: context,
                    icon: Icons.login_rounded,
                    title: 'Login',
                    subtitle: 'Welcome back to AspireX',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    },
                  ),

                  const Spacer(flex: 2),

                  // -----------------------------------
                  // TERMS
                  // -----------------------------------
                  const Text(
                    'By continuing, you agree to our',
                    style: TextStyle(color: AppColors.mutedText, fontSize: 10),
                  ),

                  const SizedBox(height: 7),

                  const Text(
                    'Terms of Service  •  Privacy Policy',
                    style: TextStyle(color: AppColors.softPeach, fontSize: 10),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================================================
  // OPTION CARD
  // ==================================================

  Widget _buildOption({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),

        // GlassCard expects a double
        borderRadius: 18,

        child: Row(
          children: [
            // -----------------------------------------
            // ICON
            // -----------------------------------------
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.roseGold.withOpacity(0.10),
                border: Border.all(color: AppColors.roseGold.withOpacity(0.25)),
              ),
              child: Icon(icon, color: AppColors.roseGold, size: 21),
            ),

            const SizedBox(width: 15),

            // -----------------------------------------
            // TEXT
            // -----------------------------------------
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.primaryText,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.mutedText,
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
            ),

            // -----------------------------------------
            // ARROW
            // -----------------------------------------
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: AppColors.secondaryText,
              size: 14,
            ),
          ],
        ),
      ),
    );
  }
}

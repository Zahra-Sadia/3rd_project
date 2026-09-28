import 'dart:ui';

import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../widgets/premium_button.dart';
import '../../widgets/page_indicator.dart';
import 'onboarding_data.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();

  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < onboardingPages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _goToWelcome();
    }
  }

  void _skipOnboarding() {
    _goToWelcome();
  }

  void _goToWelcome() {
    Navigator.pushReplacementNamed(context, '/welcome');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Premium background glow
          Positioned(
            top: -120,
            right: -100,
            child: _glowCircle(
              size: 280,
              color: AppColors.roseGold.withValues(alpha: 0.10),
            ),
          ),

          Positioned(
            bottom: -150,
            left: -100,
            child: _glowCircle(
              size: 320,
              color: AppColors.roseGold.withValues(alpha: 0.07),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Top navigation
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
                  child: Row(
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Text(
                          '0${_currentPage + 1}',
                          key: ValueKey(_currentPage),
                          style: TextStyle(
                            color: AppColors.roseGold,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 2,
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),

                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: LinearProgressIndicator(
                            value: (_currentPage + 1) / onboardingPages.length,
                            minHeight: 2,
                            backgroundColor: Colors.white12,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.roseGold,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 20),

                      GestureDetector(
                        onTap: _skipOnboarding,
                        child: Text(
                          'SKIP',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.65),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Pages
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: onboardingPages.length,
                    onPageChanged: (index) {
                      setState(() {
                        _currentPage = index;
                      });
                    },
                    itemBuilder: (context, index) {
                      return _buildOnboardingPage(onboardingPages[index]);
                    },
                  ),
                ),

                // Bottom section
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                  child: Column(
                    children: [
                      PageIndicator(
                        currentIndex: _currentPage,
                        count: onboardingPages.length,
                      ),

                      const SizedBox(height: 22),

                      PremiumButton(
                        text: 'Get Started',
                        icon: Icons.arrow_forward_rounded,
                        onPressed: _nextPage,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOnboardingPage(OnboardingData data) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image / glass area
          Expanded(
            flex: 6,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.roseGold.withValues(alpha: 0.08),
                    blurRadius: 40,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      data.image,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _imagePlaceholder();
                      },
                    ),

                    // Dark overlay
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.08),
                            Colors.black.withValues(alpha: 0.35),
                            Colors.black.withValues(alpha: 0.80),
                          ],
                        ),
                      ),
                    ),

                    // Glass icon
                    Positioned(
                      left: 20,
                      bottom: 20,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                          child: Container(
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.roseGold.withValues(
                                  alpha: 0.35,
                                ),
                              ),
                            ),
                            child: Icon(
                              data.icon,
                              color: AppColors.roseGold,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 25),

          // Heading
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '${data.title}\n',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 3,
                  ),
                ),
                TextSpan(
                  text: data.highlight,
                  style: TextStyle(
                    color: AppColors.roseGold,
                    fontSize: 31,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Description
          Text(
            data.description,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.62),
              fontSize: 14,
              height: 1.6,
              fontWeight: FontWeight.w300,
            ),
          ),
        ],
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.background,
            AppColors.surface,
            AppColors.roseGold.withValues(alpha: 0.15),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.image_outlined,
          color: AppColors.roseGold.withValues(alpha: 0.5),
          size: 48,
        ),
      ),
    );
  }

  Widget _glowCircle({required double size, required Color color}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

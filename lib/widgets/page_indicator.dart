import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

class PageIndicator extends StatelessWidget {
  final int currentIndex;
  final int count;

  const PageIndicator({
    super.key,
    required this.currentIndex,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        count,
        (index) => AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: index == currentIndex ? 28 : 7,
          height: 7,
          decoration: BoxDecoration(
            color: index == currentIndex
                ? AppColors.roseGold
                : Colors.white.withValues(alpha: 0.20),
            borderRadius: BorderRadius.circular(20),
            boxShadow: index == currentIndex
                ? [
                    BoxShadow(
                      color: AppColors.roseGold.withValues(alpha: 0.30),
                      blurRadius: 10,
                    ),
                  ]
                : null,
          ),
        ),
      ),
    );
  }
}

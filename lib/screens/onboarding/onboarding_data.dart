import 'package:flutter/material.dart';

class OnboardingData {
  final String title;
  final String highlight;
  final String description;
  final String image;
  final IconData icon;

  const OnboardingData({
    required this.title,
    required this.highlight,
    required this.description,
    required this.image,
    required this.icon,
  });
}

const List<OnboardingData> onboardingPages = [
  OnboardingData(
    title: 'Know Where It Goes',
    highlight: 'Every Expense Matters',
    description:
        'Keep track of your spending, understand your habits, and stay clear about where your money goes.',
    image: 'assets/images/1.jpeg',
    icon: Icons.auto_awesome_outlined,
  ),

  OnboardingData(
    title: 'Take Control',
    highlight: 'Plan With Purpose',
    description:
        'Set budgets, manage your goals, and make smarter decisions with your money every day.',
    image: 'assets/images/2.jpeg',
    icon: Icons.tune_rounded,
  ),

  OnboardingData(
    title: 'Turn Goals Into Progress',
    highlight: 'A Stronger Financial Future',
    description:
        'Build better habits, reach your savings goals, and make every financial step count.',
    image: 'assets/images/3.jpeg',
    icon: Icons.trending_up_rounded,
  ),
];

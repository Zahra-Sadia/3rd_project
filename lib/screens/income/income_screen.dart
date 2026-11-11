import 'package:flutter/material.dart';
import '../categories/category_planner_screen.dart';

class IncomeScreen extends StatelessWidget {
  const IncomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const CategoryPlannerScreen(isIncome: true);
  }
}

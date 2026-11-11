import 'package:flutter/material.dart';
import '../categories/category_planner_screen.dart';

class ExpenseScreen extends StatelessWidget {
  const ExpenseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const CategoryPlannerScreen(isIncome: false);
  }
}

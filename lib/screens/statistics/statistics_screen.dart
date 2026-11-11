import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  // Black & rose-gold theme (same values as AppColors)
  static const Color background = Color(0xFF08090D); // AppColors.background
  static const Color card = Color(0xFF10131A); // AppColors.surface
  static const Color peach = Color(0xFFE9A39B); // AppColors.roseGold
  static const Color peachLight = Color(0xFFF2B8AE); // AppColors.softPeach
  static const Color muted = Color(0xFFA39A9C);
  static const Color green = Color(0xFF75D7B0);
  static const Color red = Color(0xFFE58B83);
  static const Color border = Color(0xFF3A3438); // rose-tinted border

  // TODO: change this to the table that your `add_income_expense_record`
  // Supabase function inserts into (it must have: user_id, record_type,
  // amount, record_date).
  static const String recordsTable = 'income_expense_records';

  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> accounts = [];
  List<Map<String, dynamic>> categories = [];

  // Actual income / expense records
  List<Map<String, dynamic>> periodRecords = []; // selected Week/Month/Year
  List<Map<String, dynamic>> sixMonthRecords = []; // last 6 months

  bool isLoading = true;
  String? errorMessage;

  String selectedPeriod = 'Month';

  DateTime get now => DateTime.now();

  DateTime get periodStart {
    if (selectedPeriod == 'Week') {
      final today = DateTime(now.year, now.month, now.day);
      return today.subtract(Duration(days: today.weekday - 1));
    }

    if (selectedPeriod == 'Year') {
      return DateTime(now.year, 1, 1);
    }

    return DateTime(now.year, now.month, 1);
  }

  DateTime get periodEnd {
    if (selectedPeriod == 'Week') {
      return periodStart.add(const Duration(days: 6));
    }

    if (selectedPeriod == 'Year') {
      return DateTime(now.year, 12, 31);
    }

    return DateTime(now.year, now.month + 1, 0);
  }

  String dateKey(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final user = supabase.auth.currentUser;

      if (user == null) {
        throw Exception('Please log in to view your statistics.');
      }

      final accountResponse = await supabase
          .from('financial_accounts')
          .select('id, account_name, account_type, provider, balance, currency')
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      final categoryResponse = await supabase
          .from('categories')
          .select(
            'id, name, category_type, icon, color, planned_amount, period_key',
          )
          .eq('user_id', user.id)
          .gte('period_key', dateKey(periodStart))
          .lte('period_key', dateKey(periodEnd))
          .order('created_at', ascending: false);

      final periodRecordResponse = await supabase
          .from(recordsTable)
          .select('record_type, amount, record_date')
          .eq('user_id', user.id)
          .gte('record_date', dateKey(periodStart))
          .lte('record_date', dateKey(periodEnd));

      final sixMonthStart = DateTime(now.year, now.month - 5, 1);
      final sixMonthEnd = DateTime(now.year, now.month + 1, 0);

      final sixMonthResponse = await supabase
          .from(recordsTable)
          .select('record_type, amount, record_date')
          .eq('user_id', user.id)
          .gte('record_date', dateKey(sixMonthStart))
          .lte('record_date', dateKey(sixMonthEnd));

      accounts = List<Map<String, dynamic>>.from(accountResponse);
      categories = List<Map<String, dynamic>>.from(categoryResponse);
      periodRecords = List<Map<String, dynamic>>.from(periodRecordResponse);
      sixMonthRecords = List<Map<String, dynamic>>.from(sixMonthResponse);
    } catch (e) {
      errorMessage = e.toString();
    }

    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _changePeriod(String period) async {
    if (selectedPeriod == period) return;

    setState(() {
      selectedPeriod = period;
    });

    await _loadStatistics();
  }

  double _amount(Map<String, dynamic> category) {
    return (category['planned_amount'] as num?)?.toDouble() ?? 0;
  }

  double get totalBalance {
    return accounts.fold<double>(
      0,
      (total, account) =>
          total + ((account['balance'] as num?)?.toDouble() ?? 0),
    );
  }

  // Total planned income for the selected week, month, or year.
  double get plannedIncome {
    return categories
        .where((item) => item['category_type'] == 'income')
        .fold<double>(0, (total, item) => total + _amount(item));
  }

  // Total planned expenses for the selected period.
  double get plannedExpenses {
    return categories
        .where((item) => item['category_type'] == 'expense')
        .fold<double>(0, (total, item) => total + _amount(item));
  }

  // Planned savings for the selected period.
  double get plannedSavings {
    return plannedIncome - plannedExpenses;
  }

  // Current recorded account balance after the selected period's
  // planned expenses.
  double get remainingBalance {
    return totalBalance - plannedExpenses;
  }

  // Planned savings percentage for the selected period.
  double get savingsRate {
    if (plannedIncome <= 0) return 0;

    return (plannedSavings / plannedIncome) * 100;
  }

  double _recordAmount(Map<String, dynamic> record) {
    return (record['amount'] as num?)?.toDouble() ?? 0;
  }

  static const List<String> _monthNames = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static const List<String> _weekNames = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  // Actual income & expense grouped by day (Week / Month)
  // or by month (Year).
  List<_ActivityBar> get activityBars {
    final isYear = selectedPeriod == 'Year';

    final count = isYear ? 12 : periodEnd.difference(periodStart).inDays + 1;

    final income = List<double>.filled(count, 0);
    final expense = List<double>.filled(count, 0);

    for (final record in periodRecords) {
      final date = DateTime.tryParse(record['record_date'].toString());
      if (date == null) continue;

      final index = isYear
          ? date.month - 1
          : DateTime(
              date.year,
              date.month,
              date.day,
            ).difference(periodStart).inDays;

      if (index < 0 || index >= count) continue;

      final amount = _recordAmount(record);

      if (record['record_type'] == 'income') {
        income[index] += amount;
      } else if (record['record_type'] == 'expense') {
        expense[index] += amount;
      }
    }

    return List.generate(count, (i) {
      final label = isYear
          ? _monthNames[i]
          : selectedPeriod == 'Week'
          ? _weekNames[i]
          : '${i + 1}';

      return _ActivityBar(label, income[i], expense[i]);
    });
  }

  // Actual savings (income - expense) for each of the last 6 months.
  List<_MonthSaving> get sixMonthSavings {
    final current = now;

    final months = List.generate(
      6,
      (i) => DateTime(current.year, current.month - 5 + i, 1),
    );

    final income = List<double>.filled(6, 0);
    final expense = List<double>.filled(6, 0);

    for (final record in sixMonthRecords) {
      final date = DateTime.tryParse(record['record_date'].toString());
      if (date == null) continue;

      final index =
          (date.year - months.first.year) * 12 +
          (date.month - months.first.month);

      if (index < 0 || index >= 6) continue;

      final amount = _recordAmount(record);

      if (record['record_type'] == 'income') {
        income[index] += amount;
      } else if (record['record_type'] == 'expense') {
        expense[index] += amount;
      }
    }

    return List.generate(
      6,
      (i) => _MonthSaving(
        _monthNames[months[i].month - 1],
        income[i] - expense[i],
      ),
    );
  }

  List<Map<String, dynamic>> get expenseCategories {
    return categories
        .where((item) => item['category_type'] == 'expense')
        .toList()
      ..sort((a, b) => _amount(b).compareTo(_amount(a)));
  }

  String money(double amount) {
    final value = amount.abs().toStringAsFixed(2);
    final parts = value.split('.');
    final digits = parts[0];

    final formatted = digits.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => ',',
    );

    final sign = amount < 0 ? '-' : '';
    return '$sign৳$formatted.${parts[1]}';
  }

  Color _categoryColor(dynamic value) {
    if (value is num) {
      return Color(value.toInt());
    }
    return peach;
  }

  IconData _categoryIcon(dynamic value) {
    if (value is num) {
      return IconData(value.toInt(), fontFamily: 'MaterialIcons');
    }
    return Icons.category_outlined;
  }

  String get periodLabel {
    if (selectedPeriod == 'Week') {
      return 'This week';
    }
    if (selectedPeriod == 'Year') {
      return 'This year';
    }
    return 'This month';
  }

  Widget sectionTitle(String title, {String? subtitle}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(color: muted, fontSize: 11)),
          ],
        ],
      ),
    );
  }

  Widget cardContainer({required Widget child, EdgeInsets? padding}) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border, width: 0.8),
      ),
      child: child,
    );
  }

  Widget emptyMessage(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: muted, fontSize: 12, height: 1.5),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Statistics',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 21,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _loadStatistics,
            icon: const Icon(Icons.refresh, color: peach),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: peach))
          : errorMessage != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, color: red, size: 35),
                    const SizedBox(height: 12),
                    Text(
                      errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: muted),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: peach,
                        foregroundColor: background,
                      ),
                      onPressed: _loadStatistics,
                      child: const Text('Try Again'),
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              color: peach,
              backgroundColor: card,
              onRefresh: _loadStatistics,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
                children: [
                  const Text(
                    'Your money, explained',
                    style: TextStyle(color: muted, fontSize: 13),
                  ),
                  const SizedBox(height: 18),

                  _periodSelector(),

                  const SizedBox(height: 20),

                  _summaryCards(),

                  const SizedBox(height: 25),

                  sectionTitle(
                    'Income vs spending',
                    subtitle: 'Planned amounts · $periodLabel',
                  ),
                  _incomeSpendingCard(),

                  const SizedBox(height: 25),

                  sectionTitle(
                    selectedPeriod == 'Year'
                        ? 'Monthly activity'
                        : 'Daily activity',
                    subtitle: 'Actual income and expenses · $periodLabel',
                  ),
                  _dailyActivityCard(),

                  const SizedBox(height: 25),

                  sectionTitle(
                    'Expense categories',
                    subtitle: 'Where your planned expenses go',
                  ),
                  _categoriesCard(),

                  const SizedBox(height: 25),

                  sectionTitle('Savings rate'),
                  _savingsRateCard(),

                  const SizedBox(height: 25),

                  sectionTitle(
                    'Savings · last 6 months',
                    subtitle: 'Actual income minus actual expenses',
                  ),
                  _sixMonthSavingsCard(),

                  const SizedBox(height: 25),

                  sectionTitle(
                    'Remaining balance',
                    subtitle: 'Current balance after planned expenses',
                  ),
                  _remainingBalanceCard(),

                  const SizedBox(height: 25),

                  sectionTitle(
                    'Net worth',
                    subtitle: 'Your current recorded account balance',
                  ),
                  _netWorthCard(),

                  const SizedBox(height: 15),
                ],
              ),
            ),
    );
  }

  Widget _periodSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        children: ['Week', 'Month', 'Year'].map((period) {
          final isSelected = selectedPeriod == period;

          return Expanded(
            child: GestureDetector(
              onTap: () => _changePeriod(period),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  color: isSelected ? peach : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  period,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isSelected ? background : muted,
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _summaryCards() {
    return Row(
      children: [
        Expanded(
          child: _summaryCard(
            title: 'planned Income',
            amount: money(plannedIncome),
            color: green,
            icon: Icons.arrow_downward_rounded,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: _summaryCard(
            title: 'planned Expenses',
            amount: money(plannedExpenses),
            color: red,
            icon: Icons.arrow_upward_rounded,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: _summaryCard(
            title: 'planned Savings',
            amount: money(plannedSavings),
            color: peach,
            icon: Icons.savings_outlined,
          ),
        ),
      ],
    );
  }

  Widget _summaryCard({
    required String title,
    required String amount,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 13, 8, 13),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: border, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 17),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(color: muted, fontSize: 11)),
          const SizedBox(height: 5),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              amount,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            periodLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: muted, fontSize: 9),
          ),
        ],
      ),
    );
  }

  Widget _incomeSpendingCard() {
    final maximum = [
      plannedIncome,
      plannedExpenses,
      1.0,
    ].reduce((a, b) => a > b ? a : b);

    return cardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _legendDot(green, 'Planned income'),
          const SizedBox(height: 15),
          _amountBar(
            label: 'Income',
            amount: plannedIncome,
            maximum: maximum,
            color: green,
          ),
          const SizedBox(height: 20),
          _amountBar(
            label: 'Expenses',
            amount: plannedExpenses,
            maximum: maximum,
            color: red,
          ),
          const SizedBox(height: 18),
          const Divider(color: border),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Planned savings',
                style: TextStyle(color: muted, fontSize: 12),
              ),
              Text(
                money(plannedSavings),
                style: TextStyle(
                  color: plannedSavings >= 0 ? green : red,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (plannedIncome == 0 && plannedExpenses == 0)
            emptyMessage('Add planned income and expenses to see your chart.'),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: muted, fontSize: 11)),
      ],
    );
  }

  Widget _amountBar({
    required String label,
    required double amount,
    required double maximum,
    required Color color,
  }) {
    final progress = (amount.abs() / maximum).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
            Text(
              money(amount),
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 9,
            backgroundColor: border,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _categoriesCard() {
    if (expenseCategories.isEmpty) {
      return cardContainer(
        child: emptyMessage(
          'No planned expense categories found for $periodLabel.',
        ),
      );
    }

    return cardContainer(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total planned expenses',
                style: TextStyle(color: muted, fontSize: 12),
              ),
              Text(
                money(plannedExpenses),
                style: const TextStyle(
                  color: peach,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          const Divider(color: border),
          ...expenseCategories.map((category) {
            final amount = _amount(category);
            final percentage = plannedExpenses > 0
                ? (amount / plannedExpenses * 100)
                : 0.0;

            final color = _categoryColor(category['color']);

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(
                      _categoryIcon(category['icon']),
                      color: color,
                      size: 19,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          category['name']?.toString() ?? 'Category',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 5),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: (percentage / 100).clamp(0.0, 1.0),
                            minHeight: 5,
                            backgroundColor: border,
                            valueColor: AlwaysStoppedAnimation<Color>(color),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        money(amount),
                        style: const TextStyle(
                          color: peach,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${percentage.toStringAsFixed(1)}%',
                        style: const TextStyle(color: muted, fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _dailyActivityCard() {
    final bars = activityBars;
    final hasData = bars.any((bar) => bar.income > 0 || bar.expense > 0);

    final totalIncome = bars.fold<double>(0, (sum, bar) => sum + bar.income);
    final totalExpense = bars.fold<double>(0, (sum, bar) => sum + bar.expense);

    // Week fits the screen; Month and Year scroll sideways.
    final groupWidth = selectedPeriod == 'Week'
        ? 0.0
        : (selectedPeriod == 'Year' ? 38.0 : 28.0);

    return cardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _legendDot(green, 'Actual income'),
              const SizedBox(width: 16),
              _legendDot(red, 'Actual expense'),
            ],
          ),
          const SizedBox(height: 16),
          if (!hasData)
            emptyMessage(
              'No actual income or expenses recorded for ${periodLabel.toLowerCase()}.',
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final width = math.max(
                  constraints.maxWidth,
                  bars.length * groupWidth,
                );

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: width,
                    height: 200,
                    child: CustomPaint(
                      painter: _ActivityChartPainter(
                        bars: bars,
                        incomeColor: green,
                        expenseColor: red,
                        gridColor: border,
                        labelColor: muted,
                      ),
                    ),
                  ),
                );
              },
            ),
          const SizedBox(height: 14),
          const Divider(color: border),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Actual income',
                style: TextStyle(color: muted, fontSize: 12),
              ),
              Text(
                money(totalIncome),
                style: const TextStyle(
                  color: green,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Actual expenses',
                style: TextStyle(color: muted, fontSize: 12),
              ),
              Text(
                money(totalExpense),
                style: const TextStyle(
                  color: red,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sixMonthSavingsCard() {
    final months = sixMonthSavings;
    final total = months.fold<double>(0, (sum, month) => sum + month.amount);
    final average = total / months.length;

    return cardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (sixMonthRecords.isEmpty)
            emptyMessage('Record income and expenses to see your savings.')
          else
            SizedBox(
              width: double.infinity,
              height: 190,
              child: CustomPaint(
                painter: _SavingsChartPainter(
                  months: months,
                  positiveColor: peach,
                  negativeColor: red,
                  gridColor: border,
                  labelColor: muted,
                ),
              ),
            ),
          const SizedBox(height: 14),
          const Divider(color: border),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '6-month savings',
                style: TextStyle(color: muted, fontSize: 12),
              ),
              Text(
                money(total),
                style: TextStyle(
                  color: total >= 0 ? peach : red,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Monthly average',
                style: TextStyle(color: muted, fontSize: 12),
              ),
              Text(
                money(average),
                style: TextStyle(
                  color: average >= 0 ? Colors.white : red,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _savingsRateCard() {
    final progress = (savingsRate / 100).clamp(0.0, 1.0);

    return cardContainer(
      child: Row(
        children: [
          SizedBox(
            width: 100,
            height: 100,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 100,
                  height: 100,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 8,
                    backgroundColor: border,
                    valueColor: const AlwaysStoppedAnimation<Color>(peach),
                  ),
                ),
                Text(
                  plannedIncome > 0
                      ? '${savingsRate.toStringAsFixed(1)}%'
                      : '—',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your planned savings rate',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  plannedIncome > 0
                      ? 'You plan to save ${money(plannedSavings)} from ${money(plannedIncome)} income.'
                      : 'Add planned income to calculate your savings rate.',
                  style: const TextStyle(
                    color: muted,
                    fontSize: 11,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _remainingBalanceCard() {
    return cardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Current account balance',
            style: TextStyle(color: muted, fontSize: 11),
          ),
          const SizedBox(height: 6),
          Text(
            money(totalBalance),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Planned expenses',
                style: TextStyle(color: muted, fontSize: 12),
              ),
              Text(
                '- ${money(plannedExpenses)}',
                style: const TextStyle(color: red, fontSize: 12),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: border),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Remaining balance',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                money(remainingBalance),
                style: TextStyle(
                  color: remainingBalance >= 0 ? peach : red,
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _netWorthCard() {
    return cardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Total recorded account balance',
            style: TextStyle(color: muted, fontSize: 11),
          ),
          const SizedBox(height: 8),
          Text(
            money(totalBalance),
            style: const TextStyle(
              color: peachLight,
              fontSize: 25,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${accounts.length} financial account${accounts.length == 1 ? '' : 's'}',
            style: const TextStyle(color: muted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Chart data + painters (no extra package needed)
// ---------------------------------------------------------------------------

class _ActivityBar {
  final String label;
  final double income;
  final double expense;

  const _ActivityBar(this.label, this.income, this.expense);
}

class _MonthSaving {
  final String label;
  final double amount;

  const _MonthSaving(this.label, this.amount);
}

String _compactMoney(double value) {
  final absolute = value.abs();
  String text;

  if (absolute >= 1000000) {
    text = '${(absolute / 1000000).toStringAsFixed(1)}M';
  } else if (absolute >= 1000) {
    text = '${(absolute / 1000).toStringAsFixed(1)}k';
  } else {
    text = absolute.toStringAsFixed(0);
  }

  return value < 0 ? '-$text' : text;
}

void _drawText(
  Canvas canvas,
  String text,
  Offset topCenter,
  TextStyle style, {
  bool centered = true,
}) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
  )..layout();

  painter.paint(
    canvas,
    centered
        ? Offset(topCenter.dx - painter.width / 2, topCenter.dy)
        : topCenter,
  );
}

// Grouped bars: green = actual income, red = actual expense.
class _ActivityChartPainter extends CustomPainter {
  final List<_ActivityBar> bars;
  final Color incomeColor;
  final Color expenseColor;
  final Color gridColor;
  final Color labelColor;

  _ActivityChartPainter({
    required this.bars,
    required this.incomeColor,
    required this.expenseColor,
    required this.gridColor,
    required this.labelColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (bars.isEmpty) return;

    const labelHeight = 22.0;
    final plotHeight = size.height - labelHeight;

    final peak = bars.fold<double>(
      0,
      (maxValue, bar) => math.max(maxValue, math.max(bar.income, bar.expense)),
    );

    final top = peak <= 0 ? 1.0 : peak * 1.1;

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 0.8;

    const labelStyle = TextStyle(color: Color(0xFFA39A9C), fontSize: 8.5);

    // Horizontal grid lines with value labels
    for (int i = 0; i <= 3; i++) {
      final y = plotHeight * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);

      if (i < 3) {
        _drawText(
          canvas,
          _compactMoney(top * (1 - i / 3)),
          Offset(2, y + 2),
          labelStyle,
          centered: false,
        );
      }
    }

    final slot = size.width / bars.length;
    final barWidth = math.min(slot * 0.3, 10.0);

    for (int i = 0; i < bars.length; i++) {
      final bar = bars[i];
      final centerX = slot * i + slot / 2;

      void drawBar(double value, double left, Color color) {
        if (value <= 0) return;

        final height = math.max(value / top * plotHeight, 2.0);

        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTWH(left, plotHeight - height, barWidth, height),
            topLeft: const Radius.circular(3),
            topRight: const Radius.circular(3),
          ),
          Paint()..color = color,
        );
      }

      drawBar(bar.income, centerX - barWidth - 1, incomeColor);
      drawBar(bar.expense, centerX + 1, expenseColor);

      _drawText(
        canvas,
        bar.label,
        Offset(centerX, plotHeight + 7),
        TextStyle(color: labelColor, fontSize: 9),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// One bar per month: positive savings above the baseline, negative below.
class _SavingsChartPainter extends CustomPainter {
  final List<_MonthSaving> months;
  final Color positiveColor;
  final Color negativeColor;
  final Color gridColor;
  final Color labelColor;

  _SavingsChartPainter({
    required this.months,
    required this.positiveColor,
    required this.negativeColor,
    required this.gridColor,
    required this.labelColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (months.isEmpty) return;

    const topPadding = 18.0;
    const bottomPadding = 24.0;
    final plotHeight = size.height - topPadding - bottomPadding;

    final maxValue = math.max(
      0.0,
      months.map((m) => m.amount).reduce(math.max),
    );
    final minValue = math.min(
      0.0,
      months.map((m) => m.amount).reduce(math.min),
    );

    final range = (maxValue - minValue) == 0 ? 1.0 : maxValue - minValue;
    final baseline = topPadding + (maxValue / range) * plotHeight;

    canvas.drawLine(
      Offset(0, baseline),
      Offset(size.width, baseline),
      Paint()
        ..color = gridColor
        ..strokeWidth = 1,
    );

    final slot = size.width / months.length;
    final barWidth = math.min(slot * 0.5, 34.0);

    for (int i = 0; i < months.length; i++) {
      final month = months[i];
      final centerX = slot * i + slot / 2;
      final isCurrent = i == months.length - 1;
      final positive = month.amount >= 0;

      final height = month.amount == 0
          ? 0.0
          : math.max(month.amount.abs() / range * plotHeight, 2.0);

      final barColor = (positive ? positiveColor : negativeColor).withValues(
        alpha: isCurrent ? 1.0 : 0.55,
      );

      if (height > 0) {
        final rect = Rect.fromLTWH(
          centerX - barWidth / 2,
          positive ? baseline - height : baseline,
          barWidth,
          height,
        );

        canvas.drawRRect(
          positive
              ? RRect.fromRectAndCorners(
                  rect,
                  topLeft: const Radius.circular(6),
                  topRight: const Radius.circular(6),
                )
              : RRect.fromRectAndCorners(
                  rect,
                  bottomLeft: const Radius.circular(6),
                  bottomRight: const Radius.circular(6),
                ),
          Paint()..color = barColor,
        );
      }

      // Value label
      final labelY = positive ? baseline - height - 14 : baseline + height + 3;

      _drawText(
        canvas,
        _compactMoney(month.amount),
        Offset(centerX, labelY),
        TextStyle(
          color: positive ? Colors.white : negativeColor,
          fontSize: 9.5,
          fontWeight: FontWeight.w600,
        ),
      );

      // Month label
      _drawText(
        canvas,
        month.label,
        Offset(centerX, size.height - bottomPadding + 8),
        TextStyle(
          color: isCurrent ? positiveColor : labelColor,
          fontSize: 10,
          fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

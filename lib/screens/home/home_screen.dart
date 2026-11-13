import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/app_routes.dart';
import '../../widgets/app_logo.dart';
import '../goals/goals_screen.dart';
import '../income/income_screen.dart';
import '../expense/expense_screen.dart';
import '../statistics/statistics_screen.dart';
import '../budget/set_budget_screen.dart';
import '../transactions/transaction_history_screen.dart';
import '../transactions/transfer_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Black & rose-gold theme (same values as AppColors)
  static const Color background = Color(0xFF08090D); // AppColors.background
  static const Color card = Color(0xFF10131A); // AppColors.surface
  static const Color cardLight = Color(0xFF181B22);
  static const Color peach = Color(0xFFE9A39B); // AppColors.roseGold
  static const Color peachLight = Color(0xFFF2B8AE); // AppColors.softPeach
  static const Color roseDeep = Color(0xFFB76E79); // deeper rose-gold
  static const Color border = Color(0xFF3A3438); // rose-tinted border
  static const Color muted = Color(0xFFA39A9C);
  static const Color green = Color(0xFF75D7B0);
  static const Color red = Color(0xFFE58B83);

  // TODO: change this to the table that your `add_income_expense_record`
  // Supabase function inserts into (it must have: user_id, record_type,
  // amount, record_date, category_id).
  static const String _recordsTable = 'income_expense_records';

  int selectedIndex = 0;
  String selectedCurrency = 'BDT';
  List<Map<String, dynamic>> accounts = [];
  List<Map<String, dynamic>> expenseCategories = [];

  // Actual (recorded) data for the current month - used by Spending Overview
  List<Map<String, dynamic>> actualExpenseCategories = [];
  double actualIncome = 0;
  String overviewPeriod = 'Day'; // 'Day' or 'Week'

  // This month's real numbers - used by the balance card trend and badge
  double monthIncome = 0;
  double monthExpense = 0;
  Map<int, double> monthDailyNet = {}; // day of month -> income - expense

  // No-spend calendar (current month)
  Map<int, double> dailyExpense = {}; // day of month -> actual expense
  DateTime? firstRecordDate; // first day the user ever recorded anything
  double actualExpense = 0;

  bool isLoadingData = true;
  String? dataError;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    if (mounted) {
      setState(() {
        isLoadingData = true;
        dataError = null;
      });
    }

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) {
        throw Exception('Please log in to view your financial data.');
      }

      final accountRows = await supabase
          .from('financial_accounts')
          .select('id, account_name, account_type, provider, balance, currency')
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      final today = DateTime.now();

      final todayKey =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-'
          '${today.day.toString().padLeft(2, '0')}';

      final expenseRows = await supabase
          .from('categories')
          .select('name, planned_amount, color, icon')
          .eq('user_id', user.id)
          .eq('category_type', 'expense')
          .eq('period_key', todayKey)
          .order('created_at');

      if (!mounted) return;

      setState(() {
        accounts = List<Map<String, dynamic>>.from(accountRows);

        expenseCategories = List<Map<String, dynamic>>.from(expenseRows);

        isLoadingData = false;
        dataError = null;
      });

      await _loadActualOverview();
      await _loadNoSpendData();
    } catch (error) {
      if (!mounted) return;

      setState(() {
        isLoadingData = false;
        dataError = 'Could not load your financial accounts.';
      });

      debugPrint('Dashboard data loading error: $error');
    }
  }

  // ---------- Spending Overview (actual income & expenses) ----------

  static const List<String> _monthShort = [
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

  DateTime get _overviewStart {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Week starts on Monday
    return overviewPeriod == 'Week'
        ? today.subtract(Duration(days: today.weekday - 1))
        : today;
  }

  DateTime get _overviewEnd {
    return overviewPeriod == 'Week'
        ? _overviewStart.add(const Duration(days: 6))
        : _overviewStart;
  }

  String get _overviewLabel {
    final start = _overviewStart;
    final end = _overviewEnd;

    if (overviewPeriod == 'Week') {
      return '${start.day} ${_monthShort[start.month - 1]} - '
          '${end.day} ${_monthShort[end.month - 1]} · Actual';
    }

    return 'Today, ${start.day} ${_monthShort[start.month - 1]} · Actual';
  }

  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  Future<void> _changeOverviewPeriod(String period) async {
    if (overviewPeriod == period) return;

    setState(() => overviewPeriod = period);

    await _loadActualOverview();
  }

  Future<void> _loadActualOverview() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) return;

      final start = _dateKey(_overviewStart);
      final end = _dateKey(_overviewEnd);

      final recordRows = List<Map<String, dynamic>>.from(
        await supabase
            .from(_recordsTable)
            .select('category_id, record_type, amount')
            .eq('user_id', user.id)
            .gte('record_date', start)
            .lte('record_date', end),
      );

      final categoryRows = List<Map<String, dynamic>>.from(
        await supabase
            .from('categories')
            .select('id, name, color')
            .eq('user_id', user.id)
            .eq('category_type', 'expense')
            .gte('period_key', start)
            .lte('period_key', end),
      );

      final categoryLookup = <String, Map<String, dynamic>>{
        for (final row in categoryRows) row['id'].toString(): row,
      };

      double incomeTotal = 0;
      double expenseTotal = 0;
      final grouped = <String, Map<String, dynamic>>{};

      for (final row in recordRows) {
        final amount = (row['amount'] as num?)?.toDouble() ?? 0;

        if (row['record_type'] == 'income') {
          incomeTotal += amount;
          continue;
        }

        if (row['record_type'] != 'expense') continue;

        expenseTotal += amount;

        final category = categoryLookup[row['category_id']?.toString()];
        final name = category?['name']?.toString() ?? 'Other';

        final entry = grouped.putIfAbsent(
          name,
          () => {
            'name': name,
            'color': category?['color'] ?? 0xFFA39A9C,
            'amount': 0.0,
          },
        );

        entry['amount'] = (entry['amount'] as double) + amount;
      }

      final sorted = grouped.values.toList()
        ..sort(
          (a, b) => (b['amount'] as double).compareTo(a['amount'] as double),
        );

      if (!mounted) return;

      setState(() {
        actualIncome = incomeTotal;
        actualExpense = expenseTotal;
        actualExpenseCategories = sorted;
      });
    } catch (error) {
      debugPrint('Spending overview loading error: $error');
    }
  }

  Future<void> _openSetBudget() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SetBudgetScreen(recordsTable: _recordsTable),
      ),
    );
  }

  // ---------- No-spend days calendar ----------

  Future<void> _loadNoSpendData() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) return;

      final now = DateTime.now();
      final first = DateTime(now.year, now.month, 1);
      final last = DateTime(now.year, now.month + 1, 0);

      // All of this month's records (income and expense)
      final monthRows = List<Map<String, dynamic>>.from(
        await supabase
            .from(_recordsTable)
            .select('record_type, amount, record_date')
            .eq('user_id', user.id)
            .gte('record_date', _dateKey(first))
            .lte('record_date', _dateKey(last)),
      );

      final earliestRows = List<Map<String, dynamic>>.from(
        await supabase
            .from(_recordsTable)
            .select('record_date')
            .eq('user_id', user.id)
            .order('record_date', ascending: true)
            .limit(1),
      );

      final daily = <int, double>{}; // expenses per day (no-spend calendar)
      final net = <int, double>{}; // income - expense per day (trend)
      double incomeTotal = 0;
      double expenseTotal = 0;

      for (final row in monthRows) {
        final date = DateTime.tryParse(
          row['record_date'].toString().substring(0, 10),
        );

        if (date == null) continue;

        final amount = (row['amount'] as num?)?.toDouble() ?? 0;

        if (row['record_type'] == 'income') {
          incomeTotal += amount;
          net[date.day] = (net[date.day] ?? 0) + amount;
        } else if (row['record_type'] == 'expense') {
          expenseTotal += amount;
          daily[date.day] = (daily[date.day] ?? 0) + amount;
          net[date.day] = (net[date.day] ?? 0) - amount;
        }
      }

      DateTime? firstDate;

      if (earliestRows.isNotEmpty) {
        firstDate = DateTime.tryParse(
          earliestRows.first['record_date'].toString().substring(0, 10),
        );
      }

      if (!mounted) return;

      setState(() {
        dailyExpense = daily;
        firstRecordDate = firstDate;
        monthIncome = incomeTotal;
        monthExpense = expenseTotal;
        monthDailyNet = net;
      });
    } catch (error) {
      debugPrint('No-spend days loading error: $error');
    }
  }

  // ---------- Balance card: trend and status (real data) ----------

  // This month's change = income - expenses. Transfers do not change the
  // total, so only income and expenses count.
  double get monthNet => monthIncome - monthExpense;

  // Balance on the 1st of the month = balance today - this month's change
  double get monthStartBalance => totalBalance - monthNet;

  // Only show the trend when there is real data to compare
  bool get hasMonthTrend =>
      accounts.isNotEmpty &&
      (monthIncome > 0 || monthExpense > 0) &&
      monthStartBalance > 0;

  double get monthChangePercent => monthNet / monthStartBalance * 100;

  // One point for the 1st, then one for each day up to today
  List<double> get balanceTrend {
    final today = DateTime.now().day;
    final points = <double>[monthStartBalance];
    double running = monthStartBalance;

    for (int day = 1; day <= today; day++) {
      running += monthDailyNet[day] ?? 0;
      points.add(running);
    }

    return points;
  }

  String _percentText(double value) {
    if (value.abs() < 0.05) return '0%';

    final digits = value.abs() >= 100 ? 0 : 1;
    return '${value > 0 ? '+' : '-'}${value.abs().toStringAsFixed(digits)}%';
  }

  // null = not enough real data to judge, so no badge is shown
  ({String label, Color color, IconData icon})? get healthStatus {
    if (accounts.isEmpty) return null;

    if (remainingBalance < 0) {
      return (label: 'Low balance', color: red, icon: Icons.error_outline);
    }

    if (monthIncome <= 0) return null;

    final spentRatio = monthExpense / monthIncome;

    if (spentRatio >= 1) {
      return (label: 'Overspending', color: red, icon: Icons.error_outline);
    }

    if (spentRatio >= 0.8) {
      return (
        label: 'Watch out',
        color: peachLight,
        icon: Icons.warning_amber_rounded,
      );
    }

    return (label: 'Healthy', color: green, icon: Icons.eco);
  }

  double get totalBalance => accounts.fold<double>(
    0,
    (total, account) => total + ((account['balance'] as num?)?.toDouble() ?? 0),
  );

  double get totalPlannedExpenses {
    return expenseCategories.fold<double>(
      0,
      (total, category) =>
          total + ((category['planned_amount'] as num?)?.toDouble() ?? 0),
    );
  }

  double get remainingBalance {
    return totalBalance - totalPlannedExpenses;
  }

  double get cardBalance => _getCategoryBalance('card');

  double get cashBalance => _getCategoryBalance('cash');

  double get mobileBankingBalance => _getCategoryBalance('mobile_banking');

  double _getCategoryBalance(String type) {
    return accounts
        .where((account) => account['account_type'] == type)
        .fold<double>(
          0,
          (total, account) =>
              total + ((account['balance'] as num?)?.toDouble() ?? 0),
        );
  }

  String get displayName {
    final user = Supabase.instance.client.auth.currentUser;
    final metadataName = user?.userMetadata?['full_name']?.toString().trim();
    if (metadataName != null && metadataName.isNotEmpty) return metadataName;
    final email = user?.email;
    if (email != null && email.contains('@')) return email.split('@').first;
    return 'User';
  }

  final Map<String, double> exchangeRates = {
    'BDT': 1.0,
    'USD': 0.0082,
    'EUR': 0.0070,
    'GBP': 0.0061,
    'INR': 0.72,
    'AED': 0.030,
    'SAR': 0.031,
    'CAD': 0.011,
    'AUD': 0.013,
    'CNY': 0.059,
    'JPY': 1.21,
    'CHF': 0.0057,
  };

  final Map<String, String> currencySymbols = {
    'BDT': '৳',
    'USD': '\$',
    'EUR': '€',
    'GBP': '£',
    'INR': '₹',
    'AED': 'د.إ',
    'SAR': '﷼',
    'CAD': 'C\$',
    'AUD': 'A\$',
    'CNY': '¥',
    'JPY': '¥',
    'CHF': 'CHF ',
  };

  double convert(double amount) =>
      amount * (exchangeRates[selectedCurrency] ?? 1);
  String money(double amount, {bool decimals = false}) {
    final value = convert(amount);
    final formatted = decimals
        ? value.abs().toStringAsFixed(2)
        : value
              .abs()
              .toStringAsFixed(0)
              .replaceAllMapped(
                RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
                (match) => '${match[1]},',
              );
    return '${currencySymbols[selectedCurrency] ?? '৳'}$formatted';
  }

  void _openQuickAction(String action) {
    if (action == 'Add Income') {
      _push(const IncomeScreen());
    } else if (action == 'Add Expense') {
      _push(const ExpenseScreen());
    } else if (action == 'Set Budget') {
      _openSetBudget();
    } else if (action == 'Transfer') {
      _push(const TransferScreen());
    } else if (action == 'History') {
      _push(TransactionHistoryScreen(recordsTable: _recordsTable));
    }
  }

  // Opens a screen, then refreshes the dashboard when you come back.
  Future<void> _push(Widget screen) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );

    if (mounted) {
      await _loadDashboardData();
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showAmountDialog(String action) async {
    final controller = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: cardLight,
        title: Text(action, style: const TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Amount (BDT)',
            labelStyle: const TextStyle(color: muted),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: peach),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel', style: TextStyle(color: muted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: peach,
              foregroundColor: background,
            ),
            onPressed: () {
              Navigator.pop(dialogContext);
              if (controller.text.trim().isNotEmpty) {
                _showMessage(
                  '$action amount entered. Connect this action to your transaction storage to save it.',
                );
              }
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    controller.dispose();
  }

  Future<void> _onNavigationTap(int index) async {
    if (index == 4) {
      await Navigator.pushNamed(context, AppRoutes.menu);

      if (mounted) {
        await _loadDashboardData();
      }
      return;
    }

    if (index == 2) {
      _showAddOptions();
      return;
    }

    if (index == 3) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const GoalsScreen()),
      );
      return;
    }

    if (index == 1) {
      setState(() => selectedIndex = 1);

      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const StatisticsScreen()),
      );

      if (mounted) {
        await _loadDashboardData();
      }
      return;
    }

    setState(() => selectedIndex = 0);
  }

  Future<void> _showAddOptions() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: cardLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 4,
                width: 42,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Quick Add',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _sheetAction(
                      icon: Icons.add_circle_outline,
                      title: 'Income',
                      color: green,
                      onTap: () {
                        Navigator.pop(sheetContext);

                        _push(const IncomeScreen());
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _sheetAction(
                      icon: Icons.remove_circle_outline,
                      title: 'Expense',
                      color: red,
                      onTap: () {
                        Navigator.pop(sheetContext);

                        _push(const ExpenseScreen());
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _topBar(),
              const SizedBox(height: 22),
              const Text(
                'Hello,',
                style: TextStyle(color: muted, fontSize: 13),
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      displayName,
                      style: GoogleFonts.playfairDisplay(
                        color: const Color(0xFFF5F1EF),
                        fontSize: 25,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Icon(Icons.eco_outlined, color: green, size: 20),
                ],
              ),
              const SizedBox(height: 5),
              const Text(
                'Small steps today, big financial freedom tomorrow.',
                style: TextStyle(color: muted, fontSize: 11.5),
              ),
              const SizedBox(height: 18),
              _balanceCard(),
              if (!isLoadingData && accounts.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 7),
                  child: Text(
                    'No accounts yet — add your cash, bank, or mobile money account to start.',
                    style: TextStyle(color: muted, fontSize: 11),
                  ),
                ),
              const SizedBox(height: 14),
              _spendingCard(),
              const SizedBox(height: 14),
              _quickActions(),
              const SizedBox(height: 14),
              _noSpendCard(),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _bottomBar(),
    );
  }

  Widget _topBar() {
    return Row(
      children: [
        Container(
          width: 36,
          height: 40,
          decoration: BoxDecoration(
            border: Border.all(color: peach, width: 1.5),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Center(
            child: Icon(Icons.shield_outlined, color: peach, size: 25),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(child: const AppLogo(fontSize: 22, showTagline: false)),
        _roundIcon(Icons.search, () => _showMessage('Search is coming soon.')),
        const SizedBox(width: 8),
        _roundIcon(
          Icons.notifications_none,
          () => _showMessage('You have no new notifications.'),
          dot: true,
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => Navigator.pushNamed(context, AppRoutes.profile),
          child: CircleAvatar(
            radius: 16,
            backgroundColor: const Color(0xFF2A2326),
            child: Text(
              displayName.trim().isNotEmpty
                  ? displayName.trim()[0].toUpperCase()
                  : 'U',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _roundIcon(IconData icon, VoidCallback onTap, {bool dot = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 34,
        width: 34,
        decoration: BoxDecoration(
          color: card,
          shape: BoxShape.circle,
          border: Border.all(color: border.withOpacity(.7)),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(icon, color: Colors.white70, size: 18),
            if (dot)
              Positioned(
                right: 8,
                top: 7,
                child: Container(
                  height: 5,
                  width: 5,
                  decoration: const BoxDecoration(
                    color: red,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _balanceCard() {
    final status = healthStatus;
    final showTrend = hasMonthTrend;
    final change = showTrend ? monthChangePercent : 0.0;
    final trend = showTrend ? balanceTrend : const <double>[];
    final trendColor = change >= 0 ? green : red;

    return Container(
      padding: const EdgeInsets.fromLTRB(15, 13, 13, 12),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: peach.withOpacity(.35)),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF33252A), Color(0xFF14111A), Color(0xFF0E0F13)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.visibility_outlined,
                color: Colors.white70,
                size: 15,
              ),
              const SizedBox(width: 7),
              const Expanded(
                child: Text(
                  'Remaining Balance After Today’s Planned Expenses',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ),
              const SizedBox(width: 5),
              const Icon(Icons.info_outline, color: muted, size: 11),
              const SizedBox(width: 8),
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selectedCurrency,
                  isDense: true,
                  dropdownColor: cardLight,
                  icon: const Icon(
                    Icons.keyboard_arrow_down,
                    color: peach,
                    size: 14,
                  ),
                  style: const TextStyle(
                    color: peach,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                  items: currencySymbols.keys
                      .map(
                        (currency) => DropdownMenuItem(
                          value: currency,
                          child: Text(currency),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => selectedCurrency = value);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  money(remainingBalance),
                  style: GoogleFonts.dmSans(
                    color: const Color(0xFFF5F1EF),
                    fontSize: 29,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                  ),
                ),
              ),
              if (status != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: status.color.withOpacity(.16),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(status.icon, color: status.color, size: 13),
                      const SizedBox(width: 4),
                      Text(
                        status.label,
                        style: TextStyle(
                          color: status.color,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (showTrend) ...[
            const SizedBox(height: 3),
            Row(
              children: [
                Icon(
                  change >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
                  color: trendColor,
                  size: 14,
                ),
                const SizedBox(width: 3),
                Text(
                  _percentText(change),
                  style: TextStyle(
                    color: trendColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 7),
                const Text(
                  'this month',
                  style: TextStyle(color: muted, fontSize: 11),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 155),
                      child: SizedBox(
                        height: 38,
                        width: double.infinity,
                        child: CustomPaint(
                          painter: _TrendPainter(
                            values: trend,
                            color: change >= 0 ? peach : red,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],

          // Account category balances
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _accountBalanceItem(
                  'Card',
                  cardBalance,
                  Icons.credit_card,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _accountBalanceItem(
                  'Cash',
                  cashBalance,
                  Icons.money_outlined,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _accountBalanceItem(
                  'Mobile Banking',
                  mobileBankingBalance,
                  Icons.phone_android,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _accountBalanceItem(String title, double amount, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 9),
      decoration: BoxDecoration(
        color: cardLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border.withOpacity(.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: peach, size: 13),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: muted, fontSize: 9),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              money(amount),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickActions() {
    final actions = [
      (Icons.add_circle_outline, 'Add\nIncome', green),
      (Icons.remove_circle_outline, 'Add\nExpense', red),
      (Icons.track_changes_outlined, 'Set\nBudget', const Color(0xFFD9C3C0)),
      (Icons.swap_horiz, 'Transfer', peachLight),
      (Icons.receipt_long_outlined, 'History', peach),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: actions.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        mainAxisExtent: 70,
      ),
      itemBuilder: (context, index) {
        final action = actions[index];

        return GestureDetector(
          onTap: () => _openQuickAction(action.$2.replaceAll('\n', ' ')),
          child: Container(
            decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: border.withOpacity(.7)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(action.$1, color: action.$3, size: 21),
                const SizedBox(height: 5),
                Text(
                  action.$2,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _noSpendCard() {
    const weekdays = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

    final now = DateTime.now();
    final today = now.day;
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;

    // Sunday-first calendar, like the design
    final leadingBlanks = DateTime(now.year, now.month, 1).weekday % 7;

    final firstTracked = firstRecordDate;

    // Days before the first ever record are not tracked, so they are
    // never counted as "no spend".
    bool isTracked(int day) =>
        firstTracked != null &&
        !DateTime(now.year, now.month, day).isBefore(firstTracked);

    final maxSpend = dailyExpense.values.fold<double>(
      0,
      (maxValue, value) => math.max(maxValue, value),
    );

    int bestStreak = 0;
    int run = 0;

    for (int day = 1; day <= today; day++) {
      if (isTracked(day) && (dailyExpense[day] ?? 0) <= 0) {
        run++;
        bestStreak = math.max(bestStreak, run);
      } else {
        run = 0;
      }
    }

    final cells = <Widget>[
      for (int i = 0; i < leadingBlanks; i++) const SizedBox.shrink(),
      for (int day = 1; day <= daysInMonth; day++)
        _noSpendCell(
          day: day,
          isToday: day == today,
          isFuture: day > today,
          tracked: isTracked(day),
          spent: dailyExpense[day] ?? 0,
          maxSpend: maxSpend,
        ),
    ];

    while (cells.length % 7 != 0) {
      cells.add(const SizedBox.shrink());
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border.withOpacity(.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'No-spend days',
                  style: TextStyle(
                    color: Color(0xFFF5F1EF),
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                'Best streak: $bestStreak',
                style: const TextStyle(color: muted, fontSize: 11),
              ),
            ],
          ),

          const SizedBox(height: 10),

          Row(
            children: weekdays
                .map(
                  (label) => Expanded(
                    child: Center(
                      child: Text(
                        label,
                        style: const TextStyle(color: muted, fontSize: 10),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),

          const SizedBox(height: 4),

          for (int start = 0; start < cells.length; start += 7)
            Row(
              children: [
                for (final cell in cells.sublist(start, start + 7))
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2.5),
                      child: Center(
                        child: SizedBox(width: 32, height: 32, child: cell),
                      ),
                    ),
                  ),
              ],
            ),

          if (firstTracked == null)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'Record your first income or expense to start tracking '
                'no-spend days.',
                style: TextStyle(color: muted, fontSize: 10.5, height: 1.4),
              ),
            ),

          const SizedBox(height: 10),

          Row(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: peach, width: 1.2),
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'No spend',
                style: TextStyle(color: muted, fontSize: 10.5),
              ),
              const SizedBox(width: 16),
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: const Color(0xFF8A6B66),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'Spent',
                style: TextStyle(color: muted, fontSize: 10.5),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _noSpendCell({
    required int day,
    required bool isToday,
    required bool isFuture,
    required bool tracked,
    required double spent,
    required double maxSpend,
  }) {
    final radius = BorderRadius.circular(9);

    // Future days, or days before tracking started: faint dashed box
    if (isFuture || !tracked) {
      return Container(
        foregroundDecoration: isToday
            ? BoxDecoration(
                borderRadius: radius,
                border: Border.all(color: Colors.white, width: 1.8),
              )
            : null,
        child: CustomPaint(
          painter: const _DashedBorderPainter(
            color: Color(0xFF3A3438),
            radius: 9,
          ),
          child: Center(
            child: Text(
              '$day',
              style: const TextStyle(color: Color(0xFF6B6266), fontSize: 11),
            ),
          ),
        ),
      );
    }

    final bool hasSpend = spent > 0;

    // Darker = lower spending, lighter rose gold = higher spending
    Color? fill;
    Color textColor = peach;

    if (hasSpend) {
      final ratio = maxSpend > 0 ? spent / maxSpend : 1.0;

      if (ratio <= 0.34) {
        fill = const Color(0xFF4A3B3C);
        textColor = const Color(0xFFF5F1EF);
      } else if (ratio <= 0.67) {
        fill = const Color(0xFF8A6B66);
        textColor = const Color(0xFFFFFFFF);
      } else {
        fill = const Color(0xFFE8B7A3);
        textColor = background;
      }
    }

    return GestureDetector(
      onTap: () => _showMessage(
        hasSpend
            ? '${_monthShort[DateTime.now().month - 1]} $day · '
                  'Spent ${money(spent)}'
            : '${_monthShort[DateTime.now().month - 1]} $day · No spend',
      ),
      child: Container(
        decoration: BoxDecoration(
          color: fill,
          borderRadius: radius,
          border: hasSpend ? null : Border.all(color: peach, width: 1.2),
        ),
        foregroundDecoration: isToday
            ? BoxDecoration(
                borderRadius: radius,
                border: Border.all(color: Colors.white, width: 1.8),
              )
            : null,
        child: Center(
          child: Text(
            '$day',
            style: TextStyle(
              color: textColor,
              fontSize: 11,
              fontWeight: hasSpend ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _spendingCard() {
    final chartValues = actualExpenseCategories
        .map<double>((item) => (item['amount'] as num?)?.toDouble() ?? 0)
        .toList();

    final chartColors = actualExpenseCategories
        .map<Color>(
          (item) => Color((item['color'] as num?)?.toInt() ?? 0xFFE9A39B),
        )
        .toList();

    final leftover = actualIncome - actualExpense;

    // The part of the income that is not spent becomes the last ring slice.
    if (leftover > 0) {
      chartValues.add(leftover);
      chartColors.add(green);
    }

    final spentPercent = actualIncome > 0
        ? actualExpense / actualIncome * 100
        : 0.0;

    final hasData = actualIncome > 0 || actualExpense > 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: peach.withOpacity(.4)),
        boxShadow: [
          BoxShadow(
            color: peach.withOpacity(.14),
            blurRadius: 22,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.pie_chart_outline, color: peach, size: 17),
              const SizedBox(width: 7),
              const Expanded(
                child: Text(
                  'Spending Overview',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              _overviewToggle(),
            ],
          ),

          const SizedBox(height: 6),

          Text(
            _overviewLabel,
            style: const TextStyle(color: muted, fontSize: 10),
          ),

          const SizedBox(height: 18),

          if (!hasData)
            SizedBox(
              height: 180,
              child: Center(
                child: Text(
                  'No income or expenses recorded '
                  '${overviewPeriod == 'Week' ? 'this week' : 'today'}.\n'
                  'Record income and expenses to view your chart.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: muted,
                    fontSize: 11,
                    height: 1.6,
                  ),
                ),
              ),
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 155,
                  height: 155,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: const Size(155, 155),
                        painter: _DonutPainter(
                          values: chartValues,
                          colors: chartColors,
                        ),
                      ),

                      SizedBox(
                        width: 96,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Total Income',
                              style: TextStyle(color: muted, fontSize: 10),
                            ),

                            const SizedBox(height: 4),

                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                money(actualIncome),
                                style: const TextStyle(
                                  color: peachLight,
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),

                            const SizedBox(height: 3),

                            Text(
                              actualIncome > 0
                                  ? '${spentPercent.toStringAsFixed(0)}% spent'
                                  : 'No income yet',
                              style: TextStyle(
                                color: spentPercent > 100 ? red : muted,
                                fontSize: 9.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ...actualExpenseCategories.take(4).map((item) {
                        final name = item['name']?.toString() ?? 'Category';

                        final amount =
                            (item['amount'] as num?)?.toDouble() ?? 0;

                        final color = Color(
                          (item['color'] as num?)?.toInt() ?? 0xFFE9A39B,
                        );

                        return _legendRow(name, amount, color);
                      }),

                      if (actualExpenseCategories.length > 4)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            '+ ${actualExpenseCategories.length - 4} more',
                            style: const TextStyle(color: muted, fontSize: 10),
                          ),
                        ),

                      if (leftover > 0)
                        _legendRow('Left to spend', leftover, green),
                    ],
                  ),
                ),
              ],
            ),

          const SizedBox(height: 14),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: cardLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total Income',
                      style: TextStyle(color: muted, fontSize: 10),
                    ),

                    Text(
                      money(actualIncome),
                      style: const TextStyle(
                        color: green,
                        fontSize: 12,
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
                      'Total Actual Expenses',
                      style: TextStyle(color: muted, fontSize: 10),
                    ),

                    Text(
                      money(actualExpense),
                      style: const TextStyle(
                        color: peach,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _overviewToggle() {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: cardLight,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [_toggleChip('Day', 'Today'), _toggleChip('Week', 'Week')],
      ),
    );
  }

  Widget _toggleChip(String value, String label) {
    final selected = overviewPeriod == value;

    return GestureDetector(
      onTap: () => _changeOverviewPeriod(value),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? peach : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? background : muted,
            fontSize: 10.5,
            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _legendRow(String name, double amount, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),

          const SizedBox(width: 6),

          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70, fontSize: 10),
            ),
          ),

          const SizedBox(width: 4),

          Text(
            money(amount),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(7, 7, 7, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0B0A0D),
        border: Border(top: BorderSide(color: border.withOpacity(.7))),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navItem(Icons.home_outlined, 'Home', 0),
            _navItem(Icons.bar_chart_rounded, 'Statistics', 1),
            GestureDetector(
              onTap: _showAddOptions,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [peachLight, peach, roseDeep],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: peach.withOpacity(.35),
                      blurRadius: 14,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: const Icon(Icons.add, color: background, size: 28),
              ),
            ),
            _navItem(Icons.track_changes_outlined, 'Goals', 3),
            _navItem(Icons.grid_view_rounded, 'More', 4),
          ],
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, String label, int index) {
    final selected = selectedIndex == index;
    return GestureDetector(
      onTap: () => _onNavigationTap(index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 58,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 19,
              color: selected ? peach : const Color(0xFF8E8588),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: selected ? peach : const Color(0xFF8E8588),
                fontSize: 8.5,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            const SizedBox(height: 3),
            Container(
              width: 22,
              height: 2,
              decoration: BoxDecoration(
                color: selected ? peach : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sheetAction({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border.withOpacity(.7)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 23),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Line of the balance through this month, drawn from real values
class _TrendPainter extends CustomPainter {
  final List<double> values;
  final Color color;

  const _TrendPainter({required this.values, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;

    final minValue = values.reduce(math.min);
    final maxValue = values.reduce(math.max);
    final range = maxValue - minValue;

    // keep a little room at the top and bottom of the chart
    const pad = 4.0;
    final usable = size.height - pad * 2;

    final points = <Offset>[
      for (int i = 0; i < values.length; i++)
        Offset(
          size.width * i / (values.length - 1),
          range == 0
              ? size.height / 2
              : pad + usable * (1 - (values[i] - minValue) / range),
        ),
    ];

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          colors: [color.withOpacity(.27), color.withOpacity(0)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Offset.zero & size),
    );

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    canvas.drawCircle(points.last, 2.5, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) => true;
}

class _DonutPainter extends CustomPainter {
  final List<double> values;
  final List<Color> colors;
  _DonutPainter({
    this.values = const [32, 18, 15, 12, 23],
    this.colors = const [
      Color(0xFF4D9D8B),
      Color(0xFF6198E7),
      Color(0xFFE36A78),
      Color(0xFFE5B75D),
      Color(0xFF9B6CD0),
    ],
  });
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    if (values.isEmpty || values.every((v) => v <= 0)) {
      canvas.drawArc(
        rect.deflate(4),
        0,
        math.pi * 2,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 15
          ..color = const Color(0xFF2E282B),
      );
      return;
    }
    var start = -math.pi / 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 15;
    final total = values.fold<double>(0, (sum, value) => sum + value);
    for (int i = 0; i < values.length; i++) {
      final sweep = math.pi * 2 * values[i] / total;
      canvas.drawArc(
        rect.deflate(4),
        start,
        sweep - .025,
        false,
        paint..color = colors[i % colors.length],
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;

  const _DashedBorderPainter({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
      );

    for (final metric in path.computeMetrics()) {
      double distance = 0;

      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + 3), paint);
        distance += 6;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

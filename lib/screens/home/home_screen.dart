import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/app_routes.dart';
import '../../widgets/app_logo.dart';
import '../goals/goals_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const Color background = Color(0xFF090B0D);
  static const Color card = Color(0xFF111518);
  static const Color cardLight = Color(0xFF191D20);
  static const Color peach = Color(0xFFE8B77D);
  static const Color peachLight = Color(0xFFFFD9A1);
  static const Color muted = Color(0xFF9AA0A3);
  static const Color green = Color(0xFF75D7B0);
  static const Color red = Color(0xFFFF737A);

  int selectedIndex = 0;
  String selectedCurrency = 'BDT';
  List<Map<String, dynamic>> accounts = [];
  List<Map<String, dynamic>> transactions = [];
  bool isLoadingData = true;
  String? dataError;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) {
        if (mounted)
          setState(() {
            isLoadingData = false;
            dataError = 'Please log in to view your financial data.';
          });
        return;
      }
      final accountRows = await supabase
          .from('financial_accounts')
          .select('id, account_name, account_type, provider, balance, currency')
          .eq('user_id', user.id)
          .order('created_at', ascending: false);
      final transactionRows = await supabase
          .from('transactions')
          .select(
            'id, title, category, transaction_type, amount, transaction_date, account_id',
          )
          .eq('user_id', user.id)
          .order('transaction_date', ascending: false);
      if (!mounted) return;
      setState(() {
        accounts = List<Map<String, dynamic>>.from(accountRows);
        transactions = List<Map<String, dynamic>>.from(transactionRows);
        isLoadingData = false;
        dataError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        isLoadingData = false;
        dataError =
            'Could not load your financial data. Check your connection and database policies.';
      });
      debugPrint('Dashboard data loading error: $error');
    }
  }

  double get totalBalance => accounts.fold<double>(
    0,
    (total, account) => total + ((account['balance'] as num?)?.toDouble() ?? 0),
  );
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

  double get thisMonthExpenses {
    final now = DateTime.now();
    return transactions
        .where((t) {
          if (t['transaction_type'] != 'expense') return false;
          final date = DateTime.tryParse(
            t['transaction_date']?.toString() ?? '',
          );
          return date != null &&
              date.year == now.year &&
              date.month == now.month;
        })
        .fold<double>(
          0,
          (sum, t) => sum + ((t['amount'] as num?)?.toDouble() ?? 0),
        );
  }

  List<MapEntry<String, double>> get spendingByCategory {
    final totals = <String, double>{};
    final now = DateTime.now();
    for (final t in transactions) {
      if (t['transaction_type'] != 'expense') continue;
      final date = DateTime.tryParse(t['transaction_date']?.toString() ?? '');
      if (date == null || date.year != now.year || date.month != now.month)
        continue;
      final category = (t['category'] ?? 'Other').toString();
      totals[category] =
          (totals[category] ?? 0) + ((t['amount'] as num?)?.toDouble() ?? 0);
    }
    final entries = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(5).toList();
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
    if (action == 'Set Budget') {
      _showMessage('Budget setup can be connected to your budget screen.');
    } else if (action == 'Save Goal') {
      _showMessage('Your savings goals can be managed from Goals.');
      setState(() => selectedIndex = 3);
    } else if (action == 'View Reports') {
      setState(() => selectedIndex = 1);
    } else {
      _showAmountDialog(action);
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

  void _onNavigationTap(int index) {
    if (index == 4) {
      Navigator.pushNamed(context, AppRoutes.menu);
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

    setState(() => selectedIndex = index);

    if (index == 1) {
      _showMessage(
        'Statistics selected. You can connect this to a dedicated statistics screen.',
      );
    }
  }

  Future<void> _showAddOptions() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: cardLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
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
                        Navigator.pop(context);
                        _showAmountDialog('Add Income');
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
                        Navigator.pop(context);
                        _showAmountDialog('Add Expense');
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
                'Good morning,',
                style: TextStyle(color: muted, fontSize: 13),
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      displayName,
                      style: GoogleFonts.playfairDisplay(
                        color: const Color(0xFFF4F0E8),
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
              const SizedBox(height: 10),
              _quickActions(),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _spendingCard()),
                  const SizedBox(width: 10),
                  Expanded(child: _goalCard()),
                ],
              ),
              const SizedBox(height: 16),
              _transactionsCard(),
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
            backgroundColor: const Color(0xFF292B2D),
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
          border: Border.all(color: Colors.white.withOpacity(.07)),
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
    return Container(
      padding: const EdgeInsets.fromLTRB(15, 13, 13, 12),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFF3B3935)),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF20201D), Color(0xFF0F1214), Color(0xFF101315)],
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
              const Text(
                'Total Balance',
                style: TextStyle(color: Colors.white70, fontSize: 11),
              ),
              const SizedBox(width: 5),
              const Icon(Icons.info_outline, color: muted, size: 11),
              const Spacer(),
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
                  money(totalBalance),
                  style: GoogleFonts.dmSans(
                    color: const Color(0xFFF7F4ED),
                    fontSize: 29,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF16362C),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.eco, color: green, size: 11),
                    SizedBox(width: 4),
                    Text(
                      'Healthy',
                      style: TextStyle(color: green, fontSize: 9),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              const Icon(Icons.arrow_upward, color: green, size: 14),
              const SizedBox(width: 3),
              const Text('+12%', style: TextStyle(color: green, fontSize: 10)),
              const SizedBox(width: 7),
              const Text(
                'from last month',
                style: TextStyle(color: muted, fontSize: 10),
              ),
              const Spacer(),
              SizedBox(
                width: 155,
                height: 38,
                child: CustomPaint(painter: _LineChartPainter()),
              ),
            ],
          ),

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
        border: Border.all(color: Colors.white.withOpacity(.06)),
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
      (Icons.track_changes_outlined, 'Set\nBudget', const Color(0xFFC7D2D5)),
      (Icons.savings_outlined, 'Save\nGoal', const Color(0xFFD8C7A4)),
      (Icons.bar_chart, 'View\nReports', peach),
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
              border: Border.all(color: Colors.white.withOpacity(.08)),
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

  Widget _spendingCard() {
    const colors = [
      Color(0xFF4D9D8B),
      Color(0xFF6198E7),
      Color(0xFFE36A78),
      Color(0xFFE5B75D),
      Color(0xFF9B6CD0),
    ];
    final categoryEntries = spendingByCategory;
    final total = categoryEntries.fold<double>(
      0,
      (sum, item) => sum + item.value,
    );
    final items = categoryEntries.asMap().entries.map((entry) {
      final value = entry.value.value;
      final percent = total > 0 ? value / total * 100 : 0.0;
      return (
        entry.value.key,
        '${percent.round()}%',
        colors[entry.key % colors.length],
      );
    }).toList();
    return Container(
      height: 155,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.pie_chart_outline, color: peach, size: 15),
              SizedBox(width: 5),
              Expanded(
                child: Text(
                  'Spending Overview',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, color: muted, size: 14),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Row(
              children: [
                SizedBox(
                  width: 72,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: const Size(67, 67),
                        painter: _DonutPainter(
                          values: categoryEntries
                              .map(
                                (e) => total == 0 ? 0.0 : e.value / total * 100,
                              )
                              .toList(),
                          colors: items.map((e) => e.$3).toList(),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            money(thisMonthExpenses),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Text(
                            'This Month',
                            style: TextStyle(color: muted, fontSize: 7),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: items.isEmpty
                      ? const Center(
                          child: Text(
                            'No expenses yet',
                            style: TextStyle(color: muted, fontSize: 10),
                          ),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: items
                              .map(
                                (item) => Row(
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: item.$3,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        item.$1,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 9,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      item.$2,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 8,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                              .toList(),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _goalCard() {
    return Container(
      height: 145,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.track_changes_outlined, color: peach, size: 14),
              SizedBox(width: 5),
              Expanded(
                child: Text(
                  'Savings Goal',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, color: muted, size: 14),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF53665B),
                    Color(0xFF243C3B),
                    Color(0xFF1C2928),
                  ],
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: 8,
                    top: 6,
                    child: Icon(
                      Icons.landscape_outlined,
                      size: 54,
                      color: Colors.white.withOpacity(.28),
                    ),
                  ),
                  const Positioned(
                    left: 7,
                    bottom: 7,
                    child: Row(
                      children: [
                        Icon(Icons.flight, color: peachLight, size: 13),
                        SizedBox(width: 4),
                        Text(
                          'Vacation Trip',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${money(18000)} / ${money(50000)}',
                  style: const TextStyle(color: Colors.white70, fontSize: 7.5),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A3A31),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '36%',
                  style: TextStyle(color: green, fontSize: 7),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _transactionsCard() {
    const transactionColors = [
      red,
      Color(0xFF75B6FF),
      green,
      Color(0xFFC48BEE),
      peach,
    ];
    IconData iconFor(String category, String type) {
      if (type == 'income') return Icons.account_balance_wallet_outlined;
      final value = category.toLowerCase();
      if (value.contains('food') || value.contains('dining'))
        return Icons.restaurant;
      if (value.contains('transport')) return Icons.directions_bus;
      if (value.contains('shop')) return Icons.shopping_bag_outlined;
      if (value.contains('bill')) return Icons.receipt_long;
      return Icons.payments_outlined;
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 5),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(.07)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.access_time, color: Colors.white70, size: 16),
              const SizedBox(width: 7),
              const Expanded(
                child: Text(
                  'Recent Transactions',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => selectedIndex = 1),
                child: const Text(
                  'See All',
                  style: TextStyle(color: Colors.white70, fontSize: 10),
                ),
              ),
              const SizedBox(width: 3),
              const Icon(Icons.chevron_right, color: muted, size: 14),
            ],
          ),
          const SizedBox(height: 5),
          if (isLoadingData)
            const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(color: peach, strokeWidth: 2),
            )
          else if (dataError != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text(
                dataError!,
                style: const TextStyle(color: muted, fontSize: 11),
              ),
            )
          else if (transactions.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'No transactions yet. Add an account and record your first transaction.',
                style: TextStyle(color: muted, fontSize: 11),
              ),
            )
          else
            ...transactions.take(5).map((t) {
              final type = (t['transaction_type'] ?? 'expense').toString();
              final category = (t['category'] ?? 'Other').toString();
              final title = (t['title'] ?? 'Transaction').toString();
              final amount = (t['amount'] as num?)?.toDouble() ?? 0;
              final date = DateTime.tryParse(
                t['transaction_date']?.toString() ?? '',
              );
              final dateLabel = date == null
                  ? ''
                  : '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
              final isIncome = type == 'income';
              final color =
                  transactionColors[isIncome
                      ? 2
                      : (category.hashCode.abs() % transactionColors.length)];
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Colors.white.withOpacity(.045)),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 31,
                      height: 31,
                      decoration: BoxDecoration(
                        color: color.withOpacity(.13),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        iconFor(category, type),
                        color: color,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            category,
                            style: const TextStyle(color: muted, fontSize: 9),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${isIncome ? '+' : '-'}${money(amount)}',
                      style: TextStyle(
                        color: isIncome ? green : red,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 62,
                      child: Text(
                        dateLabel,
                        textAlign: TextAlign.right,
                        style: const TextStyle(color: muted, fontSize: 8),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _bottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(7, 7, 7, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1012),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(.07))),
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
                  color: const Color(0xFF17191A),
                  shape: BoxShape.circle,
                  border: Border.all(color: peach, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: peach.withOpacity(.24),
                      blurRadius: 13,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: const Icon(Icons.add, color: peachLight, size: 30),
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
              color: selected ? peach : const Color(0xFF879096),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: selected ? peach : const Color(0xFF879096),
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
          border: Border.all(color: Colors.white.withOpacity(.08)),
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

class _LineChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final points = <Offset>[
      Offset(0, size.height * .82),
      Offset(size.width * .10, size.height * .70),
      Offset(size.width * .18, size.height * .77),
      Offset(size.width * .27, size.height * .56),
      Offset(size.width * .36, size.height * .64),
      Offset(size.width * .46, size.height * .45),
      Offset(size.width * .56, size.height * .50),
      Offset(size.width * .66, size.height * .34),
      Offset(size.width * .76, size.height * .38),
      Offset(size.width * .86, size.height * .20),
      Offset(size.width * .94, size.height * .23),
      Offset(size.width, size.height * .05),
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
        ..shader = const LinearGradient(
          colors: [Color(0x44E8B77D), Color(0x00E8B77D)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFE8B77D)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawCircle(
      points.last,
      2.5,
      Paint()..color = const Color(0xFFFFD9A1),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
          ..strokeWidth = 8
          ..color = const Color(0xFF33383B),
      );
      return;
    }
    var start = -math.pi / 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8;
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
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// "Safe to Spend Today" budget setup.
/// Pops with `true` when a budget was saved.
class SetBudgetScreen extends StatefulWidget {
  /// Table your `add_income_expense_record` function writes into.
  final String recordsTable;

  const SetBudgetScreen({super.key, required this.recordsTable});

  @override
  State<SetBudgetScreen> createState() => _SetBudgetScreenState();
}

class _SetBudgetScreenState extends State<SetBudgetScreen> {
  // Black & rose-gold theme (same values as AppColors)
  static const Color background = Color(0xFF08090D);
  static const Color card = Color(0xFF10131A);
  static const Color cardLight = Color(0xFF181B22);
  static const Color peach = Color(0xFFE9A39B);
  static const Color peachLight = Color(0xFFF2B8AE);
  static const Color border = Color(0xFF3A3438);
  static const Color muted = Color(0xFFA39A9C);
  static const Color green = Color(0xFF75D7B0);

  final supabase = Supabase.instance.client;
  final limitController = TextEditingController();

  double savingsPercent = 0;
  double alertPercent = 80;
  bool rollover = true;

  double monthIncome = 0;
  double spentBeforeToday = 0;

  bool isLoading = true;
  bool isSaving = false;
  bool isSuggesting = false;

  @override
  void initState() {
    super.initState();
    limitController.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    limitController.dispose();
    super.dispose();
  }

  // ---------- helpers ----------

  String _key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  String _money(double amount) {
    final text = amount
        .abs()
        .toStringAsFixed(0)
        .replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (match) => '${match[1]},',
        );
    return '৳$text';
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  double get limit => double.tryParse(limitController.text.trim()) ?? 0;

  int get daysInMonth {
    final now = DateTime.now();
    return DateTime(now.year, now.month + 1, 0).day;
  }

  int get daysLeft => daysInMonth - DateTime.now().day + 1;

  double get protectedSavings => monthIncome * savingsPercent / 100;

  // The limit can never be bigger than income minus the savings target.
  double get effectiveLimit {
    if (savingsPercent > 0 && monthIncome > 0) {
      return math.max(
        0,
        math.min(limit, monthIncome * (1 - savingsPercent / 100)),
      );
    }
    return limit;
  }

  double get perDay {
    if (!rollover) return effectiveLimit / daysInMonth;
    return math.max(0, effectiveLimit - spentBeforeToday) / daysLeft;
  }

  // ---------- data ----------

  Future<void> _load() async {
    try {
      final user = supabase.auth.currentUser;

      if (user == null) {
        throw Exception('Please log in first.');
      }

      final now = DateTime.now();
      final first = DateTime(now.year, now.month, 1);
      final last = DateTime(now.year, now.month + 1, 0);
      final todayKey = _key(DateTime(now.year, now.month, now.day));

      final budgetRows = List<Map<String, dynamic>>.from(
        await supabase
            .from('budgets')
            .select()
            .eq('user_id', user.id)
            .lte('month', _key(first))
            .order('month', ascending: false)
            .limit(1),
      );

      final recordRows = List<Map<String, dynamic>>.from(
        await supabase
            .from(widget.recordsTable)
            .select('record_type, amount, record_date')
            .eq('user_id', user.id)
            .gte('record_date', _key(first))
            .lte('record_date', _key(last)),
      );

      double income = 0;
      double before = 0;

      for (final row in recordRows) {
        final amount = (row['amount'] as num?)?.toDouble() ?? 0;
        final date = row['record_date'].toString().substring(0, 10);

        if (row['record_type'] == 'income') {
          income += amount;
        } else if (row['record_type'] == 'expense' &&
            date.compareTo(todayKey) < 0) {
          before += amount;
        }
      }

      if (!mounted) return;

      setState(() {
        monthIncome = income;
        spentBeforeToday = before;

        if (budgetRows.isNotEmpty) {
          final saved = budgetRows.first;
          final savedLimit = (saved['limit_amount'] as num?)?.toDouble() ?? 0;

          limitController.text = savedLimit == savedLimit.roundToDouble()
              ? savedLimit.toStringAsFixed(0)
              : savedLimit.toString();

          savingsPercent =
              (saved['savings_target_percent'] as num?)?.toDouble() ?? 0;
          alertPercent = (saved['alert_percent'] as num?)?.toDouble() ?? 80;
          rollover = saved['rollover'] as bool? ?? true;
        }

        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => isLoading = false);
      _message('Could not load your budget: $e');
    }
  }

  // Average actual expenses of the last 3 full months.
  Future<void> _suggest() async {
    setState(() => isSuggesting = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('Please log in first.');

      final now = DateTime.now();
      final start = DateTime(now.year, now.month - 3, 1);
      final end = DateTime(now.year, now.month, 0);

      final rows = List<Map<String, dynamic>>.from(
        await supabase
            .from(widget.recordsTable)
            .select('amount')
            .eq('user_id', user.id)
            .eq('record_type', 'expense')
            .gte('record_date', _key(start))
            .lte('record_date', _key(end)),
      );

      final total = rows.fold<double>(
        0,
        (sum, row) => sum + ((row['amount'] as num?)?.toDouble() ?? 0),
      );

      if (!mounted) return;

      if (total <= 0) {
        _message('Not enough spending history yet. Enter a limit manually.');
      } else {
        final average = total / 3;
        final rounded = (average / 100).round() * 100;
        final value = rounded > 0
            ? rounded.toDouble()
            : average.roundToDouble();

        setState(() => limitController.text = value.toStringAsFixed(0));
      }
    } catch (e) {
      if (mounted) _message('Could not calculate a suggestion: $e');
    } finally {
      if (mounted) setState(() => isSuggesting = false);
    }
  }

  Future<void> _save() async {
    if (limit <= 0) {
      _message('Enter a monthly spending limit.');
      return;
    }

    final user = supabase.auth.currentUser;

    if (user == null) {
      _message('Please log in first.');
      return;
    }

    setState(() => isSaving = true);

    try {
      final now = DateTime.now();

      await supabase.from('budgets').upsert({
        'user_id': user.id,
        'month': _key(DateTime(now.year, now.month, 1)),
        'limit_amount': limit,
        'savings_target_percent': savingsPercent,
        'rollover': rollover,
        'alert_percent': alertPercent.round(),
      }, onConflict: 'user_id,month');

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      setState(() => isSaving = false);
      _message('Could not save your budget: $e');
    }
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        elevation: 0,
        foregroundColor: Colors.white,
        title: const Text(
          'Set Budget',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 21),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: peach))
          : ListView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
              children: [
                _previewCard(),
                const SizedBox(height: 24),

                _label('Monthly spending limit'),
                TextField(
                  controller: limitController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                  decoration: _decoration('Enter amount').copyWith(
                    prefixText: '৳ ',
                    prefixStyle: const TextStyle(color: peach, fontSize: 18),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: isSuggesting ? null : _suggest,
                    style: TextButton.styleFrom(foregroundColor: peach),
                    icon: isSuggesting
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: peach,
                            ),
                          )
                        : const Icon(Icons.auto_awesome_outlined, size: 17),
                    label: const Text('Suggest from my last 3 months'),
                  ),
                ),

                const SizedBox(height: 18),
                _sectionCard(
                  title: 'Pay yourself first',
                  trailing: '${savingsPercent.round()}% of income',
                  description: savingsPercent == 0
                      ? 'Set a savings target and your daily limit will '
                            'protect it.'
                      : monthIncome > 0
                      ? '${_money(protectedSavings)} of this month\u2019s '
                            '${_money(monthIncome)} income stays protected.'
                      : 'Record income this month to protect your savings.',
                  child: _slider(
                    value: savingsPercent,
                    min: 0,
                    max: 50,
                    divisions: 10,
                    onChanged: (v) => setState(() => savingsPercent = v),
                  ),
                ),

                const SizedBox(height: 14),
                _sectionCard(
                  title: 'Warn me at',
                  trailing: '${alertPercent.round()}% used',
                  description:
                      'You will see a warning on the home screen once this '
                      'much of your monthly limit is spent.',
                  child: _slider(
                    value: alertPercent,
                    min: 50,
                    max: 100,
                    divisions: 10,
                    onChanged: (v) => setState(() => alertPercent = v),
                  ),
                ),

                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
                  decoration: _cardDecoration(),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Roll over unspent money',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              rollover
                                  ? 'Money you do not spend today is added to '
                                        'tomorrow\u2019s limit.'
                                  : 'Every day gets the same fixed amount.',
                              style: const TextStyle(
                                color: muted,
                                fontSize: 11.5,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: rollover,
                        onChanged: (v) => setState(() => rollover = v),
                        thumbColor: WidgetStateProperty.resolveWith(
                          (states) => states.contains(WidgetState.selected)
                              ? background
                              : muted,
                        ),
                        trackColor: WidgetStateProperty.resolveWith(
                          (states) => states.contains(WidgetState.selected)
                              ? peach
                              : border,
                        ),
                        trackOutlineColor: WidgetStateProperty.all(
                          Colors.transparent,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 26),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: isSaving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: peach,
                      foregroundColor: background,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: isSaving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: background,
                            ),
                          )
                        : const Text(
                            'Save Budget',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _previewCard() {
    final hasLimit = limit > 0;
    final capped = hasLimit && effectiveLimit < limit;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
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
          const Text(
            'SAFE TO SPEND PER DAY',
            style: TextStyle(color: muted, letterSpacing: 1.3, fontSize: 11.5),
          ),
          const SizedBox(height: 8),
          Text(
            hasLimit ? _money(perDay) : '৳ --',
            style: const TextStyle(
              color: peachLight,
              fontSize: 34,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hasLimit
                ? '${_money(effectiveLimit)} for this month · $daysLeft '
                      '${daysLeft == 1 ? 'day' : 'days'} left'
                : 'Enter a monthly limit to see your daily number.',
            style: const TextStyle(color: muted, fontSize: 12),
          ),
          if (capped) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.shield_outlined, color: green, size: 14),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Limit lowered to protect your savings target.',
                    style: const TextStyle(color: green, fontSize: 11.5),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required String trailing,
    required String description,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                trailing,
                style: const TextStyle(
                  color: peach,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: const TextStyle(color: muted, fontSize: 11.5, height: 1.4),
          ),
          child,
        ],
      ),
    );
  }

  Widget _slider({
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
  }) {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        activeTrackColor: peach,
        inactiveTrackColor: border,
        thumbColor: peachLight,
        overlayColor: peach.withOpacity(.15),
        trackHeight: 4,
      ),
      child: Slider(
        value: value,
        min: min,
        max: max,
        divisions: divisions,
        onChanged: onChanged,
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: card,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: border.withOpacity(.7)),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    );
  }

  InputDecoration _decoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: muted, fontSize: 14),
      filled: true,
      fillColor: cardLight,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: border.withOpacity(.8)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: peach),
      ),
    );
  }
}

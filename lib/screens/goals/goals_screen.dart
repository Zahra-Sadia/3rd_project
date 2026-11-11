import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../constants/app_colors.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;

  static const Color _bg = Color(0xFF0D0C0F);
  static const Color _panel = Color(0xFF171518);
  static const Color _panel2 = Color(0xFF211D20);
  static const Color _muted = Color(0xFFAAA1A6);
  static const Color _peach = Color(0xFFE8B8A9);
  static const Color _mint = Color(0xFF39DDA7);
  static const Color _blue = Color(0xFF47C8E8);
  static const Color _purple = Color(0xFFA77BFF);
  static const Color _pink = Color(0xFFF16DAF);
  static const Color _orange = Color(0xFFFF895D);

  final List<Color> _colors = [_peach, _mint, _blue, _purple, _pink, _orange];

  List<Map<String, dynamic>> _goals = [];
  List<Map<String, dynamic>> _transactions = [];
  List<Map<String, dynamic>> _rules = [];

  bool _loading = true;
  bool _saving = false;
  bool _detailed = true;

  double _extraMonthly = 50;

  String? get _userId => _supabase.auth.currentUser?.id;

  double get _totalSaved =>
      _goals.fold(0, (sum, goal) => sum + _number(goal['saved_amount']));

  double get _totalTarget =>
      _goals.fold(0, (sum, goal) => sum + _number(goal['target_amount']));

  double get _overallProgress =>
      _totalTarget <= 0 ? 0 : (_totalSaved / _totalTarget).clamp(0.0, 1.0);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  double _number(dynamic value) {
    if (value == null) return 0;
    return double.tryParse(value.toString()) ?? 0;
  }

  String _amount(double value) {
    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(2);
  }

  Color _colorFromHex(dynamic value) {
    if (value == null) return _peach;

    try {
      String hex = value.toString().replaceAll('#', '');
      if (hex.length == 6) hex = 'FF$hex';
      return Color(int.parse(hex, radix: 16));
    } catch (_) {
      return _peach;
    }
  }

  String _hexFromColor(Color color) {
    return '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
  }

  void _message(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: _panel2,
      ),
    );
  }

  Future<void> _loadData() async {
    if (_userId == null) {
      setState(() => _loading = false);
      _message('Please log in to view your goals.');
      return;
    }

    setState(() => _loading = true);

    try {
      final results = await Future.wait([
        _supabase
            .from('goals')
            .select()
            .eq('user_id', _userId!)
            .order('created_at', ascending: false),

        _supabase
            .from('goal_transactions')
            .select()
            .eq('user_id', _userId!)
            .order('transaction_date', ascending: false)
            .limit(30),

        _supabase.from('goal_saving_rules').select().eq('user_id', _userId!),
      ]);

      if (!mounted) return;

      setState(() {
        _goals = List<Map<String, dynamic>>.from(results[0]);
        _transactions = List<Map<String, dynamic>>.from(results[1]);
        _rules = List<Map<String, dynamic>>.from(results[2]);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      _message('Could not load goals: $error');
    }
  }

  // CREATE GOAL

  Future<void> _createGoal({
    required String name,
    required String category,
    required double target,
    required double saved,
    required double monthly,
    required String priority,
    required DateTime? deadline,
    required Color color,
  }) async {
    if (_userId == null) {
      _message('Please log in first.');
      return;
    }

    if (saved > target) {
      _message('Saved amount cannot exceed the target.');
      return;
    }

    setState(() => _saving = true);

    try {
      final created = await _supabase
          .from('goals')
          .insert({
            'user_id': _userId,
            'name': name,
            'category': category,
            'target_amount': target,
            'saved_amount': saved,
            'monthly_contribution': monthly,
            'priority': priority,
            'deadline': deadline == null
                ? null
                : '${deadline.year}-${deadline.month.toString().padLeft(2, '0')}-${deadline.day.toString().padLeft(2, '0')}',
            'color': _hexFromColor(color),
          })
          .select()
          .single();

      if (saved > 0) {
        await _supabase.from('goal_transactions').insert({
          'goal_id': created['id'],
          'user_id': _userId,
          'transaction_type': 'deposit',
          'amount': saved,
          'note': 'Initial savings',
        });
      }

      await _loadData();
      _message('Goal created successfully.');
    } catch (error) {
      _message('Could not create goal: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // DELETE GOAL

  Future<void> _deleteGoal(Map<String, dynamic> goal) async {
    try {
      await _supabase
          .from('goals')
          .delete()
          .eq('id', goal['id'])
          .eq('user_id', _userId!);

      await _loadData();
      _message('Goal deleted.');
    } catch (error) {
      _message('Could not delete goal: $error');
      await _loadData();
    }
  }

  // ADD MONEY / WITHDRAW

  Future<void> _addTransaction({
    required Map<String, dynamic> goal,
    required double amount,
    required String type,
    required String note,
  }) async {
    if (_userId == null) return;

    final oldSaved = _number(goal['saved_amount']);

    if (amount <= 0) {
      _message('Enter a valid amount.');
      return;
    }

    final newSaved = type == 'deposit' ? oldSaved + amount : oldSaved - amount;

    if (type == 'withdraw' && amount > oldSaved) {
      _message('Not enough saved money to withdraw.');
      return;
    }

    setState(() => _saving = true);

    String? transactionId;

    try {
      final transaction = await _supabase
          .from('goal_transactions')
          .insert({
            'goal_id': goal['id'],
            'user_id': _userId,
            'transaction_type': type,
            'amount': amount,
            'note': note.isEmpty ? null : note,
          })
          .select('id')
          .single();

      transactionId = transaction['id'].toString();

      await _supabase
          .from('goals')
          .update({
            'saved_amount': newSaved,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', goal['id'])
          .eq('user_id', _userId!);

      await _loadData();

      _message(
        type == 'deposit'
            ? 'Money added successfully.'
            : 'Money withdrawn successfully.',
      );
    } catch (error) {
      // Remove the transaction if the balance update failed.
      if (transactionId != null) {
        try {
          await _supabase
              .from('goal_transactions')
              .delete()
              .eq('id', transactionId)
              .eq('user_id', _userId!);
        } catch (_) {}
      }

      _message('Transaction failed: $error');
      await _loadData();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // SAVING RULES

  Future<void> _toggleRule(
    Map<String, dynamic>? rule,
    String name,
    String subtitle,
    bool enabled,
  ) async {
    if (_userId == null) return;

    try {
      if (rule == null) {
        await _supabase.from('goal_saving_rules').insert({
          'user_id': _userId,
          'rule_name': name,
          'amount': 0,
          'frequency': 'weekly',
          'is_enabled': enabled,
        });
      } else {
        await _supabase
            .from('goal_saving_rules')
            .update({'is_enabled': enabled})
            .eq('id', rule['id'])
            .eq('user_id', _userId!);
      }

      await _loadData();
    } catch (error) {
      _message('Could not update saving rule: $error');
    }
  }

  // ADD GOAL DIALOG

  void _showAddGoalDialog({String? template}) {
    final nameController = TextEditingController(
      text: template == null ? '' : '$template goal',
    );
    final categoryController = TextEditingController(
      text: template ?? 'General',
    );
    final targetController = TextEditingController();
    final savedController = TextEditingController(text: '0');
    final monthlyController = TextEditingController(text: '0');

    Color chosenColor = _peach;
    String priority = 'Medium';
    DateTime? deadline;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: _panel2,
          title: const Text(
            'Create a goal',
            style: TextStyle(color: Colors.white),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dialogField(nameController, 'Goal name', text: true),
                const SizedBox(height: 10),
                _dialogField(categoryController, 'Category', text: true),
                const SizedBox(height: 10),
                _dialogField(targetController, 'Target amount'),
                const SizedBox(height: 10),
                _dialogField(savedController, 'Already saved'),
                const SizedBox(height: 10),
                _dialogField(monthlyController, 'Monthly contribution'),
                const SizedBox(height: 12),

                DropdownButtonFormField<String>(
                  value: priority,
                  dropdownColor: _panel2,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration('Priority'),
                  items: ['Low', 'Medium', 'High']
                      .map(
                        (value) =>
                            DropdownMenuItem(value: value, child: Text(value)),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => priority = value);
                    }
                  },
                ),

                const SizedBox(height: 12),

                OutlinedButton.icon(
                  onPressed: () async {
                    final selected = await showDatePicker(
                      context: dialogContext,
                      initialDate: DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 3650)),
                    );

                    if (selected != null) {
                      setDialogState(() => deadline = selected);
                    }
                  },
                  icon: const Icon(Icons.calendar_month),
                  label: Text(
                    deadline == null
                        ? 'Choose deadline'
                        : '${deadline!.day}/${deadline!.month}/${deadline!.year}',
                  ),
                ),

                const SizedBox(height: 12),

                Row(
                  children: [
                    const Text(
                      'Color',
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(width: 10),
                    ..._colors.map(
                      (color) => GestureDetector(
                        onTap: () => setDialogState(() => chosenColor = color),
                        child: Container(
                          margin: const EdgeInsets.only(right: 7),
                          width: 25,
                          height: 25,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: chosenColor == color
                                  ? Colors.white
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: _saving
                  ? null
                  : () async {
                      final name = nameController.text.trim();
                      final category = categoryController.text.trim();
                      final target = double.tryParse(
                        targetController.text.trim(),
                      );
                      final saved =
                          double.tryParse(savedController.text.trim()) ?? 0;
                      final monthly =
                          double.tryParse(monthlyController.text.trim()) ?? 0;

                      if (name.isEmpty ||
                          target == null ||
                          target <= 0 ||
                          saved < 0 ||
                          monthly < 0 ||
                          saved > target) {
                        _message('Please enter valid goal information.');
                        return;
                      }

                      Navigator.pop(dialogContext);

                      await _createGoal(
                        name: name,
                        category: category.isEmpty ? 'General' : category,
                        target: target,
                        saved: saved,
                        monthly: monthly,
                        priority: priority,
                        deadline: deadline,
                        color: chosenColor,
                      );
                    },
              child: const Text('Create goal'),
            ),
          ],
        ),
      ),
    ).then((_) {
      nameController.dispose();
      categoryController.dispose();
      targetController.dispose();
      savedController.dispose();
      monthlyController.dispose();
    });
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _muted),
      filled: true,
      fillColor: _bg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }

  Widget _dialogField(
    TextEditingController controller,
    String hint, {
    bool text = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: text
          ? TextInputType.text
          : const TextInputType.numberWithOptions(decimal: true),
      style: const TextStyle(color: Colors.white),
      decoration: _inputDecoration(hint),
    );
  }

  // MONEY DIALOG

  void _showMoneyDialog(
    Map<String, dynamic> goal, {
    String initialType = 'deposit',
  }) {
    final amountController = TextEditingController();
    final noteController = TextEditingController();

    String type = initialType;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: _panel2,
          title: Text(
            type == 'deposit' ? 'Add money' : 'Withdraw money',
            style: const TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                goal['name'].toString(),
                style: const TextStyle(color: _peach),
              ),
              const SizedBox(height: 14),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'deposit',
                    label: Text('Deposit'),
                    icon: Icon(Icons.add),
                  ),
                  ButtonSegment(
                    value: 'withdraw',
                    label: Text('Withdraw'),
                    icon: Icon(Icons.remove),
                  ),
                ],
                selected: {type},
                onSelectionChanged: (value) {
                  setDialogState(() => type = value.first);
                },
              ),
              const SizedBox(height: 12),
              _dialogField(amountController, 'Amount'),
              const SizedBox(height: 10),
              _dialogField(noteController, 'Note (optional)', text: true),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(amountController.text.trim());

                if (amount == null || amount <= 0) {
                  _message('Enter a valid amount.');
                  return;
                }

                Navigator.pop(dialogContext);

                await _addTransaction(
                  goal: goal,
                  amount: amount,
                  type: type,
                  note: noteController.text.trim(),
                );
              },
              child: const Text('Confirm'),
            ),
          ],
        ),
      ),
    ).then((_) {
      amountController.dispose();
      noteController.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    final roseGold = AppColors.roseGold;

    return MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: const TextScaler.linear(1.12)),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: _peach))
              : RefreshIndicator(
                  color: _peach,
                  onRefresh: _loadData,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 25),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            _header(roseGold),
                            const SizedBox(height: 18),
                            _overviewCard(),
                            const SizedBox(height: 17),
                            _modeSwitch(),
                            const SizedBox(height: 18),
                            _topGoalCard(),
                            const SizedBox(height: 20),
                            _heading('Start a new goal', 'Pick a template'),
                            const SizedBox(height: 11),
                            _templates(),
                            const SizedBox(height: 20),
                            _heading('Your goals', '${_goals.length} goals'),
                            const SizedBox(height: 11),
                            if (_goals.isEmpty)
                              _emptyGoals()
                            else
                              ..._goals.map(
                                (goal) => Padding(
                                  padding: const EdgeInsets.only(bottom: 9),
                                  child: _goalCard(goal),
                                ),
                              ),
                            const SizedBox(height: 10),
                            if (_goals.isNotEmpty) ...[
                              _whatIfCard(),
                              const SizedBox(height: 15),
                              _timelineCard(),
                              const SizedBox(height: 15),
                              _thisWeekCard(),
                              const SizedBox(height: 15),
                              _streakCard(),
                              const SizedBox(height: 15),
                              _recentSavingsCard(),
                              const SizedBox(height: 15),
                              _milestonesCard(),
                              const SizedBox(height: 15),
                            ],
                            _autoSaveCard(),
                          ]),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
        bottomNavigationBar: _bottomNavigation(),
      ),
    );
  }

  Widget _header(Color roseGold) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '\$${_amount(_totalSaved)} saved across ${_goals.length} goals',
                style: const TextStyle(color: _muted, fontSize: 13),
              ),
              const SizedBox(height: 3),
              const Text(
                'Goals',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 29,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        OutlinedButton.icon(
          onPressed: () => _showAddGoalDialog(),
          icon: const Icon(Icons.add, size: 17),
          label: const Text('New goal'),
          style: OutlinedButton.styleFrom(
            foregroundColor: roseGold,
            side: BorderSide(color: roseGold.withOpacity(.7)),
            shape: const StadiumBorder(),
          ),
        ),
      ],
    );
  }

  Widget _overviewCard() {
    return _card(
      borderColor: _peach,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TOTAL SAVINGS',
            style: TextStyle(
              color: _peach,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '\$${_amount(_totalSaved)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 29,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Target: \$${_amount(_totalTarget)}',
            style: const TextStyle(color: _muted, fontSize: 14),
          ),
          const SizedBox(height: 13),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: _overallProgress,
              minHeight: 9,
              backgroundColor: _panel2,
              valueColor: const AlwaysStoppedAnimation(_peach),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            '${(_overallProgress * 100).toStringAsFixed(1)}% of your combined targets',
            style: const TextStyle(color: _muted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _modeSwitch() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          _modeOption('Simple', !_detailed, () {
            setState(() => _detailed = false);
          }),
          _modeOption('Detailed', _detailed, () {
            setState(() => _detailed = true);
          }),
        ],
      ),
    );
  }

  Widget _modeOption(String label, bool selected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: selected ? _peach : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: selected ? _bg : Colors.white70,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _topGoalCard() {
    if (_goals.isEmpty) {
      return _card(
        child: const Text(
          'Create your first goal to see it featured here.',
          style: TextStyle(color: _muted, fontSize: 14),
        ),
      );
    }

    final goal = _goals.first;
    final saved = _number(goal['saved_amount']);
    final target = _number(goal['target_amount']);
    final progress = target <= 0 ? 0.0 : (saved / target).clamp(0.0, 1.0);
    final color = _colorFromHex(goal['color']);

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(19),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF0C4B6), Color(0xFFDDA293)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TOP GOAL',
            style: TextStyle(
              color: Color(0xFF4B302D),
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              Expanded(
                child: Text(
                  goal['name'].toString(),
                  style: const TextStyle(
                    color: Color(0xFF271C20),
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '\$${_amount(saved)} / \$${_amount(target)}',
                style: const TextStyle(
                  color: Color(0xFF271C20),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: const Color(0x668E625C),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${(progress * 100).toStringAsFixed(1)}% completed',
                  style: const TextStyle(
                    color: Color(0xFF4B302D),
                    fontSize: 13,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () => _showMoneyDialog(goal),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2B2023),
                  foregroundColor: Colors.white,
                  shape: const StadiumBorder(),
                ),
                child: const Text('Add money'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heading(String title, String trailing) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(trailing, style: const TextStyle(color: _muted, fontSize: 12)),
      ],
    );
  }

  Widget _templates() {
    final templates = [
      (Icons.flight_takeoff_outlined, 'Trip', _peach),
      (Icons.shield_outlined, 'Emergency', _mint),
      (Icons.laptop_outlined, 'Gadget', _blue),
      (Icons.home_outlined, 'Home', _purple),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: templates.map((item) {
          return Padding(
            padding: const EdgeInsets.only(right: 9),
            child: InkWell(
              onTap: () => _showAddGoalDialog(template: item.$2),
              borderRadius: BorderRadius.circular(30),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: _panel,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  children: [
                    Icon(item.$1, color: item.$3, size: 17),
                    const SizedBox(width: 7),
                    Text(
                      item.$2,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _emptyGoals() {
    return _card(
      child: Column(
        children: [
          const Icon(Icons.savings_outlined, color: _peach, size: 42),
          const SizedBox(height: 12),
          const Text(
            'No goals yet',
            style: TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Start building your savings journey by creating your first goal.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _muted, fontSize: 14),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: () => _showAddGoalDialog(),
            icon: const Icon(Icons.add),
            label: const Text('Create your first goal'),
          ),
        ],
      ),
    );
  }

  Widget _goalCard(Map<String, dynamic> goal) {
    final saved = _number(goal['saved_amount']);
    final target = _number(goal['target_amount']);
    final monthly = _number(goal['monthly_contribution']);
    final progress = target <= 0 ? 0.0 : (saved / target).clamp(0.0, 1.0);
    final color = _colorFromHex(goal['color']);

    final deadline = goal['deadline']?.toString();

    return Dismissible(
      key: ValueKey(goal['id']),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        return await showDialog<bool>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                backgroundColor: _panel2,
                title: const Text(
                  'Delete goal?',
                  style: TextStyle(color: Colors.white),
                ),
                content: Text(
                  'Delete "${goal['name']}" and its transaction history?',
                  style: const TextStyle(color: Colors.white70),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: const Text(
                      'Delete',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                  ),
                ],
              ),
            ) ??
            false;
      },
      onDismissed: (_) => _deleteGoal(goal),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 22),
        decoration: BoxDecoration(
          color: Colors.redAccent.withOpacity(.15),
          borderRadius: BorderRadius.circular(17),
        ),
        child: const Icon(
          Icons.delete_outline,
          color: Colors.redAccent,
          size: 25,
        ),
      ),
      child: InkWell(
        onTap: () => _showMoneyDialog(goal),
        borderRadius: BorderRadius.circular(17),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _panel,
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: Colors.white.withOpacity(.045)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 45,
                height: 45,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 4.5,
                        backgroundColor: const Color(0xFF343035),
                        valueColor: AlwaysStoppedAnimation(color),
                      ),
                    ),
                    Text(
                      '${(progress * 100).round()}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      goal['name'].toString(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '\$${_amount(saved)} of \$${_amount(target)}',
                      style: const TextStyle(color: _muted, fontSize: 13),
                    ),
                    if (_detailed) ...[
                      const SizedBox(height: 5),
                      Text(
                        '${goal['priority'] ?? 'Medium'} priority'
                        '${deadline == null ? '' : ' · $deadline'}',
                        style: TextStyle(color: color, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '+\$${_amount(monthly)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Text(
                    'per month',
                    style: TextStyle(color: _muted, fontSize: 11),
                  ),
                  const SizedBox(height: 5),
                  const Icon(Icons.add_circle_outline, color: _peach, size: 19),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(16),
    Color? borderColor,
  }) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: (borderColor ?? Colors.white).withOpacity(
            borderColor == null ? .045 : .35,
          ),
        ),
      ),
      child: child,
    );
  }

  Widget _whatIfCard() {
    final goal = _goals.first;
    final monthly = _number(goal['monthly_contribution']);
    final target = _number(goal['target_amount']);
    final saved = _number(goal['saved_amount']);
    final remaining = (target - saved).clamp(0.0, double.infinity);
    final combined = monthly + _extraMonthly;
    final months = combined <= 0 ? null : (remaining / combined).ceil();

    return _card(
      borderColor: _peach,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'WHAT IF I SAVE MORE?',
            style: TextStyle(
              color: _peach,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: .8,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Extra per month',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ),
              Text(
                '+\$${_extraMonthly.round()}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          Slider(
            value: _extraMonthly,
            min: 0,
            max: 500,
            divisions: 50,
            activeColor: _peach,
            onChanged: (value) {
              setState(() => _extraMonthly = value);
            },
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _bg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              months == null
                  ? 'Add a monthly contribution to calculate an estimated finish time.'
                  : remaining == 0
                  ? 'This goal is already completed!'
                  : 'At this saving rate, you could reach "${goal['name']}" in approximately $months months.',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _timelineCard() {
    final sorted = [..._goals];

    sorted.sort((a, b) {
      final aDate = a['deadline']?.toString() ?? '9999-12-31';
      final bDate = b['deadline']?.toString() ?? '9999-12-31';
      return aDate.compareTo(bDate);
    });

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Goal timeline',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${sorted.where((g) => g['deadline'] != null).length} deadlines',
                style: const TextStyle(color: _muted, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 15),
          ...sorted.map((goal) {
            final deadline = goal['deadline']?.toString();
            final color = _colorFromHex(goal['color']);

            return Padding(
              padding: const EdgeInsets.only(bottom: 13),
              child: Row(
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      goal['name'].toString(),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Text(
                    deadline == null ? 'No deadline' : deadline,
                    style: const TextStyle(color: _muted, fontSize: 12),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _thisWeekCard() {
    final now = DateTime.now();
    final start = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    final end = start.add(const Duration(days: 7));

    final weekly = _transactions
        .where((transaction) {
          final date = DateTime.tryParse(
            transaction['transaction_date']?.toString() ?? '',
          );

          return date != null &&
              !date.isBefore(start) &&
              date.isBefore(end) &&
              transaction['transaction_type'] == 'deposit';
        })
        .fold<double>(
          0,
          (sum, transaction) => sum + _number(transaction['amount']),
        );

    return _card(
      borderColor: _peach,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'THIS WEEK',
            style: TextStyle(
              color: _peach,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: .8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You have saved \$${_amount(weekly)} this week.',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Every small contribution moves you closer to your goals.',
            style: TextStyle(color: _muted, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _streakCard() {
    final depositDates = _transactions
        .where((t) => t['transaction_type'] == 'deposit')
        .map((t) => DateTime.tryParse(t['transaction_date']?.toString() ?? ''))
        .whereType<DateTime>()
        .map((date) => DateTime(date.year, date.month, date.day))
        .toSet();

    int streak = 0;
    DateTime week = DateTime.now();
    week = DateTime(
      week.year,
      week.month,
      week.day,
    ).subtract(Duration(days: week.weekday - 1));

    for (int i = 0; i < 52; i++) {
      final weekEnd = week.add(const Duration(days: 7));
      final hasDeposit = depositDates.any(
        (date) => !date.isBefore(week) && date.isBefore(weekEnd),
      );

      if (!hasDeposit) {
        if (i == 0) {
          week = week.subtract(const Duration(days: 7));
          continue;
        }
        break;
      }

      streak++;
      week = week.subtract(const Duration(days: 7));
    }

    return _card(
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF3D2824),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.local_fire_department,
              color: _orange,
              size: 27,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Saving streak',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$streak consecutive active weeks',
                  style: const TextStyle(color: _muted, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _recentSavingsCard() {
    final goalNames = {
      for (final goal in _goals) goal['id'].toString(): goal['name'].toString(),
    };

    if (_transactions.isEmpty) {
      return _card(
        child: const Text(
          'No savings transactions yet.',
          style: TextStyle(color: _muted, fontSize: 14),
        ),
      );
    }

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent savings',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 13),
          ..._transactions.take(8).map((transaction) {
            final deposit = transaction['transaction_type'] == 'deposit';
            final amount = _number(transaction['amount']);
            final goalName =
                goalNames[transaction['goal_id']?.toString()] ?? 'Goal';

            final date = DateTime.tryParse(
              transaction['transaction_date']?.toString() ?? '',
            );

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    width: 37,
                    height: 37,
                    decoration: BoxDecoration(
                      color: (deposit ? _mint : _orange).withOpacity(.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      deposit ? Icons.add : Icons.remove,
                      color: deposit ? _mint : _orange,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          goalName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          date == null
                              ? 'Date unavailable'
                              : '${date.day}/${date.month}/${date.year}',
                          style: const TextStyle(color: _muted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${deposit ? '+' : '-'}\$${_amount(amount)}',
                    style: TextStyle(
                      color: deposit ? _mint : _orange,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
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

  Widget _milestonesCard() {
    if (_goals.isEmpty) return const SizedBox.shrink();

    final goal = _goals.first;
    final saved = _number(goal['saved_amount']);
    final target = _number(goal['target_amount']);
    final progress = target <= 0 ? 0.0 : (saved / target).clamp(0.0, 1.0);

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${goal['name']} milestones',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 15),
          Row(
            children: [25, 50, 75, 100].map((milestone) {
              final reached = progress * 100 >= milestone;
              return Expanded(
                child: Column(
                  children: [
                    Container(
                      width: 43,
                      height: 43,
                      decoration: BoxDecoration(
                        color: reached ? _peach : _panel2,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: reached ? _peach : Colors.white24,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '$milestone%',
                          style: TextStyle(
                            color: reached ? _bg : Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      reached ? 'Reached' : 'Pending',
                      style: const TextStyle(color: _muted, fontSize: 11),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _autoSaveCard() {
    final definitions = [
      ('Round up purchases', 'Spare change savings'),
      ('Friday savings', 'Weekly contribution'),
      ('Save raise money', 'Save part of a pay increase'),
    ];

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Auto-save rules',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Manage your saving preferences.',
            style: TextStyle(color: _muted, fontSize: 13),
          ),
          const SizedBox(height: 12),
          ...definitions.map((definition) {
            final rule = _rules.cast<Map<String, dynamic>?>().firstWhere(
              (r) => r?['rule_name'] == definition.$1,
              orElse: () => null,
            );

            final enabled = rule?['is_enabled'] == true;

            return Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: _peach,
                  title: Text(
                    definition.$1,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  subtitle: Text(
                    definition.$2,
                    style: const TextStyle(color: _muted, fontSize: 12),
                  ),
                  value: enabled,
                  onChanged: (value) =>
                      _toggleRule(rule, definition.$1, definition.$2, value),
                ),
                const Divider(color: Color(0xFF302B30), height: 1),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _bottomNavigation() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: _panel,
        border: Border(top: BorderSide(color: Colors.white.withOpacity(.06))),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navItem(Icons.home_outlined, 'Home', () {
              Navigator.maybePop(context);
            }),
            _navItem(Icons.bar_chart_outlined, 'Stats', () {
              _message('Connect your Statistics screen here.');
            }),
            GestureDetector(
              onTap: () => _showAddGoalDialog(),
              child: Container(
                width: 47,
                height: 47,
                decoration: const BoxDecoration(
                  color: _peach,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.add,
                  color: Color(0xFF2C2023),
                  size: 26,
                ),
              ),
            ),
            _navItem(Icons.track_changes_outlined, 'Goals', () {}),
            _navItem(Icons.tune, 'Settings', () {
              _message('Connect your Settings screen here.');
            }),
          ],
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, String label, VoidCallback onTap) {
    final selected = label == 'Goals';

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 21, color: selected ? _peach : Colors.white60),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: selected ? _peach : Colors.white60,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

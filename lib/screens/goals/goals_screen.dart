import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _Goal {
  _Goal({
    required this.name,
    required this.saved,
    required this.target,
    required this.monthly,
    required this.priority,
    required this.deadline,
    required this.color,
  });

  final String name;
  double saved;
  final double target;
  final double monthly;
  final int priority;
  final String deadline;
  final Color color;

  double get progress =>
      target <= 0 ? 0.0 : (saved / target).clamp(0.0, 1.0).toDouble();
}

class _GoalsScreenState extends State<GoalsScreen> {
  static const Color _bg = Color(0xFF0D0C0F);
  static const Color _panel = Color(0xFF171518);
  static const Color _panel2 = Color(0xFF211D20);
  static const Color _muted = Color(0xFF8C858A);
  static const Color _peach = Color(0xFFE8B8A9);
  static const Color _mint = Color(0xFF39DDA7);
  static const Color _blue = Color(0xFF47C8E8);
  static const Color _purple = Color(0xFFA77BFF);
  static const Color _pink = Color(0xFFF16DAF);
  static const Color _orange = Color(0xFFFF895D);

  int _navIndex = 3;
  bool _detailed = true;
  bool _roundUps = true;
  bool _fridaySave = true;
  bool _saveRaise = false;
  bool _pauseApplied = false;
  double _extraMonthly = 50;

  final List<_Goal> _goals = [
    _Goal(
      name: 'Emergency fund',
      saved: 4200,
      target: 6000,
      monthly: 300,
      priority: 2,
      deadline: 'Mar 2027',
      color: _mint,
    ),
    _Goal(
      name: 'New laptop',
      saved: 640,
      target: 1400,
      monthly: 150,
      priority: 3,
      deadline: 'Feb 2027',
      color: _blue,
    ),
    _Goal(
      name: 'Move-out deposit',
      saved: 900,
      target: 3000,
      monthly: 200,
      priority: 4,
      deadline: 'Aug 2027',
      color: _purple,
    ),
    _Goal(
      name: 'Birthday gift',
      saved: 55,
      target: 150,
      monthly: 40,
      priority: 5,
      deadline: 'Dec 2026',
      color: _pink,
    ),
    _Goal(
      name: 'Credit card payoff',
      saved: 800,
      target: 2000,
      monthly: 250,
      priority: 6,
      deadline: 'Jul 2027',
      color: _orange,
    ),
  ];

  final List<Map<String, dynamic>> _recentSavings = [
    {
      'title': 'Lisbon trip',
      'day': 'Friday',
      'amount': '+\$20',
      'color': _peach,
      'icon': Icons.add,
    },
    {
      'title': 'Emergency fund',
      'day': 'Thursday',
      'amount': '+\$75',
      'color': _mint,
      'icon': Icons.add,
    },
    {
      'title': 'Round-ups',
      'day': 'Wednesday',
      'amount': '+\$1.20',
      'color': _purple,
      'icon': Icons.add,
    },
    {
      'title': 'New laptop',
      'day': 'Monday',
      'amount': '+\$40',
      'color': _blue,
      'icon': Icons.add,
    },
  ];

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  void _showAddGoalDialog() {
    final nameController = TextEditingController();
    final targetController = TextEditingController();
    final savedController = TextEditingController(text: '0');
    Color chosenColor = _peach;

    showDialog<void>(
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
                _dialogField(targetController, 'Target amount'),
                const SizedBox(height: 10),
                _dialogField(savedController, 'Already saved'),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Text(
                      'Color',
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(width: 12),
                    for (final color in [
                      _peach,
                      _mint,
                      _blue,
                      _purple,
                      _pink,
                      _orange,
                    ])
                      GestureDetector(
                        onTap: () => setDialogState(() => chosenColor = color),
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          width: 23,
                          height: 23,
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
              onPressed: () {
                final name = nameController.text.trim();
                final target = double.tryParse(targetController.text.trim());
                final saved = double.tryParse(savedController.text.trim()) ?? 0;

                if (name.isEmpty ||
                    target == null ||
                    target <= 0 ||
                    saved < 0) {
                  _showMessage('Enter a goal name and a valid target amount.');
                  return;
                }

                setState(() {
                  _goals.add(
                    _Goal(
                      name: name,
                      saved: saved,
                      target: target,
                      monthly: 0,
                      priority: _goals.length + 2,
                      deadline: 'Not set',
                      color: chosenColor,
                    ),
                  );
                });

                Navigator.pop(dialogContext);
              },
              child: const Text('Create goal'),
            ),
          ],
        ),
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
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: _muted),
        filled: true,
        fillColor: _bg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
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
          child: Stack(
            children: [
              Positioned(
                right: -90,
                bottom: 5,
                child: IgnorePointer(
                  child: Container(
                    width: 210,
                    height: 210,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          roseGold.withOpacity(0.10),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 22),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _header(roseGold),
                        const SizedBox(height: 17),
                        _modeSwitch(roseGold),
                        const SizedBox(height: 16),
                        _topGoalCard(),
                        const SizedBox(height: 19),
                        _sectionHeading(
                          'Start a new goal',
                          trailing: 'Pick a template',
                        ),
                        const SizedBox(height: 10),
                        _templates(),
                        const SizedBox(height: 18),
                        _sectionHeading(
                          'Your goals',
                          trailing: 'Hold to reorder',
                        ),
                        const SizedBox(height: 10),
                        ..._goals.asMap().entries.map(
                          (entry) => Padding(
                            padding: const EdgeInsets.only(bottom: 7),
                            child: _goalCard(entry.value, entry.key),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _whatIfCard(),
                        const SizedBox(height: 14),
                        _timelineCard(),
                        const SizedBox(height: 14),
                        _thisWeekCard(),
                        const SizedBox(height: 14),
                        _streakCard(),
                        const SizedBox(height: 14),
                        _recentSavingsCard(),
                        const SizedBox(height: 14),
                        _ideasCard(),
                        const SizedBox(height: 14),
                        _milestonesCard(),
                        const SizedBox(height: 14),
                        _autoSaveCard(),
                        const SizedBox(height: 14),
                      ]),
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

  Widget _header(Color roseGold) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                '\$7,975 saved across 6 goals',
                style: TextStyle(
                  color: _muted,
                  fontSize: 12,
                  letterSpacing: .2,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Goals',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 27,
                  height: 1,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        OutlinedButton.icon(
          onPressed: _showAddGoalDialog,
          icon: const Icon(Icons.add, size: 13),
          label: const Text('New goal', style: TextStyle(fontSize: 12)),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.roseGold,
            side: BorderSide(color: AppColors.roseGold.withOpacity(.7)),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: const StadiumBorder(),
          ),
        ),
      ],
    );
  }

  Widget _modeSwitch(Color roseGold) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          _modeOption(
            'Simple',
            !_detailed,
            () => setState(() => _detailed = false),
          ),
          _modeOption(
            'Detailed',
            _detailed,
            () => setState(() => _detailed = true),
            selectedColor: _peach,
          ),
        ],
      ),
    );
  }

  Widget _modeOption(
    String label,
    bool selected,
    VoidCallback onTap, {
    Color selectedColor = _peach,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: selected ? selectedColor : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              color: selected ? _bg : Colors.white60,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _topGoalCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF0C4B6), Color(0xFFDDA293)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'TOP GOAL',
                style: TextStyle(
                  color: Color(0xFF4B302D),
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(width: 8),
              ...['N', 'M', 'S'].map(
                (s) => Container(
                  width: 16,
                  height: 16,
                  margin: const EdgeInsets.only(right: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF35252A),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFE7B7A8)),
                  ),
                  child: Center(
                    child: Text(
                      s,
                      style: const TextStyle(
                        color: _peach,
                        fontSize: 7,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 5),
              const Expanded(
                child: Text(
                  'Shared with 2',
                  style: TextStyle(color: Color(0xFF4B302D), fontSize: 8),
                ),
              ),
              const Icon(Icons.more_horiz, color: Color(0xFF69443E), size: 18),
            ],
          ),
          const SizedBox(height: 7),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: const [
              Expanded(
                child: Text(
                  'Lisbon trip',
                  style: TextStyle(
                    color: Color(0xFF271C20),
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '\$1,380 / \$2,000',
                style: TextStyle(
                  color: Color(0xFF271C20),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: const LinearProgressIndicator(
              value: .69,
              minHeight: 7,
              backgroundColor: Color(0x668E625C),
              valueColor: AlwaysStoppedAnimation(Color(0xFF2A2223)),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'On track for March 2',
                  style: TextStyle(color: Color(0xFF4B302D), fontSize: 9),
                ),
              ),
              ElevatedButton(
                onPressed: () => _showMessage('Add money to Lisbon trip'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2B2023),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 8,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: const StadiumBorder(),
                  elevation: 0,
                ),
                child: const Text('Add money', style: TextStyle(fontSize: 9)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionHeading(String title, {String? trailing}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (trailing != null)
          Text(trailing, style: const TextStyle(color: _muted, fontSize: 8)),
      ],
    );
  }

  Widget _templates() {
    final templates = [
      (Icons.flight_takeoff_outlined, 'Trip', _peach),
      (Icons.shield_outlined, 'Emergency', _mint),
      (Icons.smartphone_outlined, 'Gadget', _blue),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ...templates.map(
            (item) => Padding(
              padding: const EdgeInsets.only(right: 7),
              child: InkWell(
                onTap: () => _showTemplate(item.$2),
                borderRadius: BorderRadius.circular(30),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _panel,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.white.withOpacity(.04)),
                  ),
                  child: Row(
                    children: [
                      Icon(item.$1, color: item.$3, size: 12),
                      const SizedBox(width: 6),
                      Text(
                        item.$2,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          InkWell(
            onTap: _showAddGoalDialog,
            borderRadius: BorderRadius.circular(30),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
              decoration: BoxDecoration(
                color: _panel,
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Icon(Icons.add, color: Colors.white70, size: 13),
            ),
          ),
        ],
      ),
    );
  }

  void _showTemplate(String template) {
    _showMessage(
      '$template goal template selected. Add a target to create it.',
    );
    _showAddGoalDialog();
  }

  Widget _goalCard(_Goal goal, int index) {
    final percent = (goal.progress * 100).round();

    return Dismissible(
      key: ValueKey('${goal.name}-$index'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.redAccent.withOpacity(.16),
          borderRadius: BorderRadius.circular(17),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.redAccent),
      ),
      onDismissed: (_) => setState(() => _goals.removeAt(index)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
        decoration: BoxDecoration(
          color: _panel,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: Colors.white.withOpacity(.035)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 36,
              height: 36,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox.expand(
                    child: CircularProgressIndicator(
                      value: goal.progress,
                      strokeWidth: 4.5,
                      backgroundColor: const Color(0xFF343035),
                      valueColor: AlwaysStoppedAnimation(goal.color),
                    ),
                  ),
                  Text(
                    '$percent%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    goal.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '\$${_amount(goal.saved)} of \$${_amount(goal.target)}',
                    style: const TextStyle(color: _muted, fontSize: 8),
                  ),
                  if (_detailed) ...[
                    const SizedBox(height: 3),
                    Text(
                      'Priority ${goal.priority} · by ${goal.deadline}',
                      style: TextStyle(color: goal.color, fontSize: 8),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 7),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '+${_amount(goal.monthly)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Text(
                  'per month',
                  style: TextStyle(color: _muted, fontSize: 7),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _amount(double amount) => amount == amount.roundToDouble()
      ? amount.toInt().toString()
      : amount.toStringAsFixed(2);

  Widget _card({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(13),
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
            borderColor == null ? .035 : .35,
          ),
        ),
      ),
      child: child,
    );
  }

  Widget _whatIfCard() {
    return _card(
      borderColor: _peach,
      padding: const EdgeInsets.all(13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'WHAT IF I SAVE MORE?',
            style: TextStyle(
              color: _peach,
              fontSize: 8,
              fontWeight: FontWeight.w800,
              letterSpacing: .8,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Lisbon trip, extra per month',
                  style: TextStyle(color: Colors.white70, fontSize: 9),
                ),
              ),
              Text(
                '+\$${_extraMonthly.round()}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              activeTrackColor: _peach,
              inactiveTrackColor: const Color(0xFF5D5659),
              thumbColor: _peach,
              overlayColor: _peach.withOpacity(.12),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4),
            ),
            child: Slider(
              value: _extraMonthly,
              min: 0,
              max: 200,
              divisions: 20,
              onChanged: (v) => setState(() => _extraMonthly = v),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _bg,
              borderRadius: BorderRadius.circular(11),
            ),
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 9,
                  height: 1.45,
                ),
                children: [
                  const TextSpan(text: 'Finishes '),
                  TextSpan(
                    text: _extraMonthly >= 50
                        ? '6 weeks earlier'
                        : 'a little earlier',
                    style: const TextStyle(
                      color: _mint,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const TextSpan(text: ', on\nJanuary 19 instead of March 2.'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _showMessage(
                    'Extra monthly savings applied to Lisbon trip.',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _peach,
                    foregroundColor: _bg,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: const StadiumBorder(),
                  ),
                  child: const Text('Apply', style: TextStyle(fontSize: 9)),
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: OutlinedButton(
                  onPressed: () =>
                      setState(() => _pauseApplied = !_pauseApplied),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _peach,
                    side: const BorderSide(color: _peach),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: const StadiumBorder(),
                  ),
                  child: Text(
                    _pauseApplied ? 'Resume saving' : 'Pause a month',
                    style: const TextStyle(fontSize: 9),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _timelineCard() {
    final rows = [
      ('Birthday gift', 'Dec 2026', _pink),
      ('New laptop', 'Feb 2027', _blue),
      ('Lisbon trip', 'Mar 2027', _peach),
      ('Emergency fund', 'Mar 2027', _mint),
      ('Credit card cleared', 'Jul 2027', _orange),
      ('Move-out deposit', 'Aug 2027', _purple),
    ];

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Expanded(
                child: Text(
                  'Your next 12 months',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '6 finish lines',
                style: TextStyle(color: _muted, fontSize: 8),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...rows.map(
            (r) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: r.$3,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      r.$1,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 9,
                      ),
                    ),
                  ),
                  Text(
                    r.$2,
                    style: const TextStyle(color: _muted, fontSize: 8),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _thisWeekCard() {
    return _card(
      borderColor: _peach,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            'THIS WEEK',
            style: TextStyle(
              color: _peach,
              fontSize: 8,
              fontWeight: FontWeight.w800,
              letterSpacing: .8,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'You are \$120 away from 75% on Lisbon. '
            'Skipping two takeaways would get you there by Friday.',
            style: TextStyle(color: Colors.white70, fontSize: 9, height: 1.45),
          ),
        ],
      ),
    );
  }

  Widget _streakCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Expanded(
                child: Text(
                  'Saving streak',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                'Best: 9 weeks',
                style: TextStyle(color: _muted, fontSize: 8),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              Container(
                width: 37,
                height: 37,
                decoration: BoxDecoration(
                  color: const Color(0xFF3D2824),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.local_fire_department,
                  color: _orange,
                  size: 21,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '6 weeks in a row',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Save any amount this week to keep it going.',
                      style: TextStyle(color: _muted, fontSize: 8),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: List.generate(
              8,
              (i) => Expanded(
                child: Container(
                  margin: const EdgeInsets.only(right: 4),
                  height: 20,
                  decoration: BoxDecoration(
                    color: i < 6 ? _peach : _panel2,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: i < 6
                      ? const Icon(
                          Icons.check,
                          size: 12,
                          color: Color(0xFF3D2927),
                        )
                      : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _recentSavingsCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Expanded(
                child: Text(
                  'Recent savings',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text('This week', style: TextStyle(color: _muted, fontSize: 8)),
            ],
          ),
          const SizedBox(height: 10),
          ..._recentSavings.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Row(
                children: [
                  Container(
                    width: 31,
                    height: 31,
                    decoration: BoxDecoration(
                      color: (item['color'] as Color).withOpacity(.14),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(
                      item['icon'] as IconData,
                      color: item['color'] as Color,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['title'] as String,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item['day'] as String,
                          style: const TextStyle(color: _muted, fontSize: 8),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    item['amount'] as String,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ideasCard() {
    final ideas = [
      (
        Icons.weekend_outlined,
        'Cancel the gym app',
        'Unused for 47 days',
        '+\$12/mo',
        const Color(0xFFB67C61),
      ),
      (
        Icons.savings_outlined,
        'Round up to the next \$5',
        'Instead of the next dollar',
        '+\$18/mo',
        const Color(0xFF258CA8),
      ),
      (
        Icons.sell_outlined,
        'Sell something unused',
        'One-time boost for your laptop',
        '+\$40',
        _purple,
      ),
    ];

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Expanded(
                child: Text(
                  'Reach your goals faster',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text('3 ideas', style: TextStyle(color: _muted, fontSize: 8)),
            ],
          ),
          const SizedBox(height: 11),
          ...ideas.map(
            (idea) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    width: 31,
                    height: 31,
                    decoration: BoxDecoration(
                      color: idea.$5.withOpacity(.16),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(idea.$1, color: idea.$5, size: 15),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          idea.$2,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          idea.$3,
                          style: const TextStyle(color: _muted, fontSize: 8),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF123B2E),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Text(
                      idea.$4,
                      style: const TextStyle(
                        color: _mint,
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _milestonesCard() {
    final milestones = [
      ('25%', 'Reached', _peach),
      ('50%', 'Reached', _peach),
      ('75%', '\$120 away', _peach),
      ('100%', 'Lisbon', const Color(0xFF4A4549)),
    ];

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Expanded(
                child: Text(
                  'Lisbon milestones',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text('75% is next', style: TextStyle(color: _muted, fontSize: 8)),
            ],
          ),
          const SizedBox(height: 13),
          Row(
            children: milestones.map((m) {
              final isNext = m.$1 == '75%';
              final isFinal = m.$1 == '100%';

              return Expanded(
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isNext ? Colors.transparent : m.$3,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isNext ? _peach : m.$3,
                          width: isNext ? 1.2 : 0,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          m.$1,
                          style: TextStyle(
                            color: isFinal || isNext
                                ? Colors.white70
                                : const Color(0xFF4B302D),
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      m.$2,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: _muted, fontSize: 7),
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
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Expanded(
                child: Text(
                  'Auto-save rules',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text('2 on', style: TextStyle(color: _muted, fontSize: 8)),
            ],
          ),
          const SizedBox(height: 8),
          _autoSaveRow(
            'Round up purchases',
            'Spare change goes to Lisbon',
            _roundUps,
            (v) => setState(() => _roundUps = v),
          ),
          const Divider(color: Color(0xFF302B30), height: 12),
          _autoSaveRow(
            '\$20 every Friday',
            'Split across your goals',
            _fridaySave,
            (v) => setState(() => _fridaySave = v),
          ),
          const Divider(color: Color(0xFF302B30), height: 12),
          _autoSaveRow(
            'Save raise money',
            'Half of any pay increase',
            _saveRaise,
            (v) => setState(() => _saveRaise = v),
          ),
        ],
      ),
    );
  }

  Widget _autoSaveRow(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 9),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(color: _muted, fontSize: 8),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 27,
          child: Transform.scale(
            scale: .8,
            child: Checkbox(
              value: value,
              onChanged: (v) => onChanged(v ?? false),
              activeColor: _peach,
              checkColor: _bg,
              side: const BorderSide(color: _muted),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _bottomNavigation(Color roseGold) {
    final items = [
      (Icons.home_outlined, 'Home'),
      (Icons.bar_chart_outlined, 'Stats'),
      (Icons.add, 'Add'),
      (Icons.track_changes_outlined, 'Goals'),
      (Icons.tune, 'Settings'),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 7),
      decoration: BoxDecoration(
        color: const Color(0xFF171518),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(.06))),
      ),
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF211E22),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withOpacity(.12)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (i) {
              final item = items[i];
              final selected = i == _navIndex;

              if (i == 2) {
                return GestureDetector(
                  onTap: _showAddGoalDialog,
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: const BoxDecoration(
                      color: _peach,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.add,
                      color: Color(0xFF2C2023),
                      size: 23,
                    ),
                  ),
                );
              }

              return GestureDetector(
                onTap: () {
                  setState(() => _navIndex = i);

                  if (i == 0) {
                    Navigator.maybePop(context);
                  } else if (i == 1) {
                    _showMessage('Statistics screen can be connected here.');
                  } else if (i == 3) {
                    setState(() => _navIndex = 3);
                  } else if (i == 4) {
                    _showMessage('Settings screen can be connected here.');
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFF45383B)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        item.$1,
                        size: 17,
                        color: selected ? _peach : Colors.white60,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.$2,
                        style: TextStyle(
                          fontSize: 7,
                          color: selected ? _peach : Colors.white60,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../records/actual_record_screen.dart';

const Color background = Color(0xFF08090D);
const Color card = Color(0xFF211E22);
const Color peach = Color(0xFFE79A91);
const Color muted = Color(0xFF969196);

class CategoryPlannerScreen extends StatefulWidget {
  final bool isIncome;

  const CategoryPlannerScreen({super.key, required this.isIncome});

  @override
  State<CategoryPlannerScreen> createState() => _CategoryPlannerScreenState();
}

class _CategoryPlannerScreenState extends State<CategoryPlannerScreen> {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> categories = [];

  bool isLoading = true;
  DateTime selectedDate = DateTime.now();

  final nameController = TextEditingController();
  final amountController = TextEditingController();

  int selectedIcon = Icons.category.codePoint;
  Color selectedColor = peach;

  final List<IconData> availableIcons = [
    Icons.work,
    Icons.laptop,
    Icons.business,
    Icons.school,
    Icons.card_giftcard,
    Icons.restaurant,
    Icons.directions_bus,
    Icons.shopping_bag,
    Icons.home,
    Icons.health_and_safety,
    Icons.movie,
    Icons.flight,
    Icons.savings,
    Icons.category,
    Icons.star,
    Icons.pets,
  ];

  final List<Color> availableColors = [
    const Color(0xFFE79A91),
    const Color(0xFFB58AE8),
    const Color(0xFF75CFA9),
    const Color(0xFFF3B45F),
    const Color(0xFF78A8F5),
    const Color(0xFFE77FA9),
    const Color(0xFF72C9D0),
  ];

  String get categoryType => widget.isIncome ? 'income' : 'expense';

  String get periodKey {
    return '${selectedDate.year}-'
        '${selectedDate.month.toString().padLeft(2, '0')}-'
        '${selectedDate.day.toString().padLeft(2, '0')}';
  }

  double get totalAmount {
    return categories.fold<double>(
      0,
      (sum, item) => sum + ((item['planned_amount'] as num?)?.toDouble() ?? 0),
    );
  }

  @override
  void initState() {
    super.initState();
    loadCategories();
  }

  @override
  void dispose() {
    nameController.dispose();
    amountController.dispose();
    super.dispose();
  }

  Future<void> selectDate() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(primary: peach, surface: card),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate == null || !mounted) return;

    setState(() {
      selectedDate = pickedDate;
      isLoading = true;
    });

    await loadCategories();
  }

  Future<void> loadCategories() async {
    try {
      final user = supabase.auth.currentUser;

      if (user == null) {
        throw Exception('User not logged in');
      }

      final result = await supabase
          .from('categories')
          .select()
          .eq('user_id', user.id)
          .eq('category_type', categoryType)
          .eq('period_key', periodKey)
          .order('created_at');

      if (!mounted) return;

      setState(() {
        categories = List<Map<String, dynamic>>.from(result);
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => isLoading = false);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not load categories: $e')));
    }
  }

  Future<double> loadAvailableMoney() async {
    final user = supabase.auth.currentUser;

    if (user == null) return 0;

    final result = await supabase
        .from('financial_accounts')
        .select('balance')
        .eq('user_id', user.id);

    double total = 0;

    for (final account in result) {
      total += (account['balance'] as num?)?.toDouble() ?? 0;
    }

    return total;
  }

  // Open the screen for recording actual income or expense.
  Future<void> openActualRecordScreen() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => ActualRecordScreen(isIncome: widget.isIncome),
      ),
    );

    if (!mounted) return;

    if (result == true) {
      await loadCategories();
      setState(() {});
    }
  }

  Future<void> saveCategory({String? id}) async {
    final user = supabase.auth.currentUser;

    final name = nameController.text.trim();
    final amount = double.tryParse(amountController.text.trim());

    if (user == null) return;

    if (name.isEmpty || amount == null || amount < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid category name and amount.'),
        ),
      );
      return;
    }

    final data = {
      'name': name,
      'planned_amount': amount,
      'icon': selectedIcon,
      'color': selectedColor.toARGB32(),
      'period_key': periodKey,
    };

    try {
      if (id == null) {
        await supabase.from('categories').insert({
          ...data,
          'user_id': user.id,
          'category_type': categoryType,
        });
      } else {
        await supabase
            .from('categories')
            .update(data)
            .eq('id', id)
            .eq('user_id', user.id);
      }

      if (!mounted) return;

      Navigator.pop(context);
      await loadCategories();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            id == null
                ? 'Category added successfully'
                : 'Category updated successfully',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not save category: $e')));
    }
  }

  Future<void> deleteCategory(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: card,
        title: const Text(
          'Delete Category?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to delete this category?',
          style: TextStyle(color: muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: peach)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      await supabase
          .from('categories')
          .delete()
          .eq('id', id)
          .eq('user_id', user.id);

      await loadCategories();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not delete category: $e')));
    }
  }

  void openCategoryDialog({Map<String, dynamic>? category}) {
    nameController.text = category?['name'] ?? '';
    amountController.text = category?['planned_amount']?.toString() ?? '';

    selectedIcon = category?['icon'] ?? Icons.category.codePoint;

    selectedColor = category != null
        ? Color((category['color'] as num).toInt())
        : peach;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, dialogSetState) {
          return AlertDialog(
            backgroundColor: card,
            title: Text(
              category == null ? 'Add Category' : 'Edit Category',
              style: const TextStyle(color: Colors.white),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _field(nameController, 'Category Name'),
                  const SizedBox(height: 12),
                  _field(
                    amountController,
                    'Expected / Planned Amount',
                    number: true,
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Choose Icon',
                    style: TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: availableIcons.map((icon) {
                      final selected = selectedIcon == icon.codePoint;

                      return GestureDetector(
                        onTap: () {
                          dialogSetState(() {
                            selectedIcon = icon.codePoint;
                          });
                        },
                        child: CircleAvatar(
                          backgroundColor: selected ? peach : background,
                          child: Icon(
                            icon,
                            color: selected ? Colors.black : Colors.white,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Choose Color',
                    style: TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 12,
                    children: availableColors.map((color) {
                      final selected =
                          selectedColor.toARGB32() == color.toARGB32();

                      return GestureDetector(
                        onTap: () {
                          dialogSetState(() {
                            selectedColor = color;
                          });
                        },
                        child: CircleAvatar(
                          backgroundColor: color,
                          child: selected
                              ? const Icon(Icons.check, color: Colors.black)
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                ],
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
                  foregroundColor: Colors.black,
                ),
                onPressed: () {
                  saveCategory(id: category?['id']);
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String hint, {
    bool number = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: number
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: muted),
        filled: true,
        fillColor: background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  String money(double amount) => '৳${amount.toStringAsFixed(0)}';

  @override
  Widget build(BuildContext context) {
    final title = widget.isIncome ? 'Income Categories' : 'Expense Categories';

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(title),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: peach))
          : RefreshIndicator(
              color: peach,
              onRefresh: loadCategories,
              child: ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: card,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Selected Date',
                          style: TextStyle(color: muted, fontSize: 14),
                        ),
                        TextButton.icon(
                          onPressed: selectDate,
                          icon: const Icon(Icons.calendar_month, color: peach),
                          label: Text(
                            '${selectedDate.day.toString().padLeft(2, '0')}/'
                            '${selectedDate.month.toString().padLeft(2, '0')}/'
                            '${selectedDate.year}',
                            style: const TextStyle(
                              color: peach,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  if (widget.isIncome)
                    _incomeSummary()
                  else
                    FutureBuilder<double>(
                      future: loadAvailableMoney(),
                      builder: (context, snapshot) {
                        final available = snapshot.data ?? 0;
                        final remaining = available - totalAmount;

                        return Column(
                          children: [
                            _summaryCard(
                              'Total Expense',
                              money(totalAmount),
                              peach,
                            ),
                            const SizedBox(height: 12),
                            _summaryCard(
                              'Available Money',
                              money(available),
                              const Color(0xFF75CFA9),
                            ),
                            const SizedBox(height: 12),
                            _summaryCard(
                              'Remaining Money',
                              money(remaining),
                              remaining < 0
                                  ? Colors.redAccent
                                  : const Color(0xFF75CFA9),
                            ),
                          ],
                        );
                      },
                    ),

                  const SizedBox(height: 22),

                  if (widget.isIncome) ...[
                    const Text(
                      'Income Distribution',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    ...categories.map((item) {
                      final amount = (item['planned_amount'] as num).toDouble();

                      final percentage = totalAmount == 0
                          ? 0.0
                          : amount / totalAmount;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item['name'],
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                                Text(
                                  '${(percentage * 100).toStringAsFixed(1)}%',
                                  style: const TextStyle(color: peach),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  money(amount),
                                  style: const TextStyle(color: muted),
                                ),
                              ],
                            ),
                            const SizedBox(height: 7),
                            LinearProgressIndicator(
                              value: percentage,
                              minHeight: 7,
                              backgroundColor: card,
                              valueColor: AlwaysStoppedAnimation(
                                Color((item['color'] as num).toInt()),
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Categories',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${categories.length} categories',
                        style: const TextStyle(color: muted),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  if (categories.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(30),
                      child: Center(
                        child: Text(
                          'No categories added yet.',
                          style: TextStyle(color: muted),
                        ),
                      ),
                    ),

                  ...categories.map((item) {
                    final amount = (item['planned_amount'] as num).toDouble();

                    final color = Color((item['color'] as num).toInt());

                    final icon = IconData(
                      item['icon'] as int,
                      fontFamily: 'MaterialIcons',
                    );

                    final percentage = totalAmount == 0
                        ? 0.0
                        : amount / totalAmount;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: card,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: color.withOpacity(.15),
                            child: Icon(icon, color: color),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['name'],
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${widget.isIncome ? 'Expected' : 'Planned'}: '
                                  '${money(amount)}',
                                  style: const TextStyle(
                                    color: muted,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 9),
                                LinearProgressIndicator(
                                  value: percentage,
                                  minHeight: 6,
                                  backgroundColor: background,
                                  valueColor: AlwaysStoppedAnimation(color),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            children: [
                              IconButton(
                                onPressed: () =>
                                    openCategoryDialog(category: item),
                                icon: const Icon(
                                  Icons.edit_outlined,
                                  color: peach,
                                ),
                              ),
                              IconButton(
                                onPressed: () => deleteCategory(item['id']),
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: muted,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),

                  const SizedBox(height: 18),

                  // Button for recording actual income or expense.
                  SizedBox(
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: openActualRecordScreen,
                      icon: const Icon(Icons.add_circle_outline),
                      label: Text(
                        widget.isIncome
                            ? 'Record Actual Income'
                            : 'Record Actual Expense',
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: peach,
                        side: const BorderSide(color: peach),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: () => openCategoryDialog(),
                      icon: const Icon(Icons.add),
                      label: const Text('Add Category'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: peach,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _incomeSummary() {
    return _summaryCard('Total Expected Income', money(totalAmount), peach);
  }

  Widget _summaryCard(String title, String amount, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: muted)),
          const SizedBox(height: 8),
          Text(
            amount,
            style: TextStyle(
              color: color,
              fontSize: 27,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

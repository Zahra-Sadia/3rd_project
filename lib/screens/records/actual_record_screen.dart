import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ActualRecordScreen extends StatefulWidget {
  final bool isIncome;

  const ActualRecordScreen({super.key, required this.isIncome});

  @override
  State<ActualRecordScreen> createState() => _ActualRecordScreenState();
}

class _ActualRecordScreenState extends State<ActualRecordScreen> {
  // TODO: change this to the table that your `add_income_expense_record`
  // Supabase function inserts into (it must have: id, user_id, account_id,
  // category_id, record_type, amount, description, record_date).
  static const String recordsTable = 'income_expense_records';

  final supabase = Supabase.instance.client;

  final amountController = TextEditingController();
  final descriptionController = TextEditingController();

  List<Map<String, dynamic>> accounts = [];
  List<Map<String, dynamic>> categories = [];

  String? selectedAccountId;
  String? selectedCategoryId;

  DateTime selectedDate = DateTime.now();

  // Actual records already saved for the selected date
  List<Map<String, dynamic>> records = [];
  bool isLoadingRecords = false;

  // Tells the planner screen that something was saved while this screen
  // was open (it is returned when this screen closes).
  bool didSave = false;

  bool isLoading = true;
  bool isSaving = false;

  Color get accent =>
      widget.isIncome ? const Color(0xFF75CFA9) : const Color(0xFFE79A91);

  String get recordType => widget.isIncome ? 'income' : 'expense';

  String get selectedDateKey =>
      '${selectedDate.year}-'
      '${selectedDate.month.toString().padLeft(2, '0')}-'
      '${selectedDate.day.toString().padLeft(2, '0')}';

  double get recordsTotal => records.fold<double>(
    0,
    (sum, item) => sum + ((item['amount'] as num?)?.toDouble() ?? 0),
  );

  String _money(double amount) {
    final fixed = amount == amount.roundToDouble()
        ? amount.toStringAsFixed(0)
        : amount.toStringAsFixed(2);

    final parts = fixed.split('.');
    final whole = parts[0].replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]},',
    );

    return '৳$whole${parts.length > 1 ? '.${parts[1]}' : ''}';
  }

  @override
  void initState() {
    super.initState();
    loadData();
  }

  @override
  void dispose() {
    amountController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  Future<void> loadData() async {
    try {
      final user = supabase.auth.currentUser;

      if (user == null) {
        throw Exception('Please log in first.');
      }

      final accountResponse = await supabase
          .from('financial_accounts')
          .select('id, account_name, account_type, balance, currency')
          .eq('user_id', user.id)
          .order('created_at');

      final dateKey =
          '${selectedDate.year}-'
          '${selectedDate.month.toString().padLeft(2, '0')}-'
          '${selectedDate.day.toString().padLeft(2, '0')}';

      final categoryResponse = await supabase
          .from('categories')
          .select('id, name, category_type, period_key, icon, color')
          .eq('user_id', user.id)
          .eq('category_type', recordType)
          .eq('period_key', dateKey)
          .order('name');

      if (!mounted) return;

      final loadedAccounts = List<Map<String, dynamic>>.from(accountResponse);

      final loadedCategories = List<Map<String, dynamic>>.from(
        categoryResponse,
      );

      setState(() {
        accounts = loadedAccounts;
        categories = loadedCategories;

        selectedAccountId = loadedAccounts.isNotEmpty
            ? loadedAccounts.first['id'].toString()
            : null;

        selectedCategoryId = null;
        isLoading = false;
      });

      await loadRecords();
    } catch (e) {
      if (!mounted) return;

      setState(() => isLoading = false);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not load data: $e')));
    }
  }

  // Actual income / expenses already recorded for the selected date
  Future<void> loadRecords() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      if (mounted) setState(() => isLoadingRecords = true);

      final rows = await supabase
          .from(recordsTable)
          .select('id, account_id, category_id, amount, description')
          .eq('user_id', user.id)
          .eq('record_type', recordType)
          .eq('record_date', selectedDateKey)
          .order('amount', ascending: false);

      if (!mounted) return;

      setState(() {
        records = List<Map<String, dynamic>>.from(rows);
        isLoadingRecords = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => isLoadingRecords = false);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not load records: $e')));
    }
  }

  // Needs the delete_income_expense_record function from transactions_setup.sql
  Future<void> deleteRecord(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF211E22),
        title: const Text(
          'Delete record?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'This removes it from your records and adjusts your account '
          'balance.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('Delete', style: TextStyle(color: accent)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await supabase.rpc(
        'delete_income_expense_record',
        params: {'p_record_id': id},
      );

      didSave = true;

      if (!mounted) return;

      await loadRecords();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not delete record: $e')));
    }
  }

  Future<void> chooseDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked == null) return;

    setState(() {
      selectedDate = picked;
      isLoading = true;
    });

    await loadData();
  }

  Future<void> saveRecord() async {
    final amount = double.tryParse(amountController.text.trim());

    if (selectedAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add a financial account first.')),
      );
      return;
    }

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter a valid amount.')));
      return;
    }

    setState(() => isSaving = true);

    try {
      final dateKey =
          '${selectedDate.year}-'
          '${selectedDate.month.toString().padLeft(2, '0')}-'
          '${selectedDate.day.toString().padLeft(2, '0')}';

      await supabase.rpc(
        'add_income_expense_record',
        params: {
          'p_account_id': selectedAccountId,
          'p_category_id': selectedCategoryId,
          'p_record_type': recordType,
          'p_amount': amount,
          'p_description': descriptionController.text.trim().isEmpty
              ? null
              : descriptionController.text.trim(),
          'p_record_date': dateKey,
        },
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isIncome
                ? 'Actual income recorded successfully!'
                : 'Actual expense recorded successfully!',
          ),
        ),
      );

      // Stay on this screen so the new record shows in the list below.
      didSave = true;
      amountController.clear();
      descriptionController.clear();

      await loadRecords();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not save record: $e')));
    } finally {
      if (mounted) {
        setState(() => isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isIncome
        ? 'Record Actual Income'
        : 'Record Actual Expense';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) Navigator.pop(context, didSave);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF08090D),
        appBar: AppBar(
          backgroundColor: const Color(0xFF08090D),
          foregroundColor: Colors.white,
          title: Text(title),
        ),
        body: isLoading
            ? Center(child: CircularProgressIndicator(color: accent))
            : accounts.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No financial accounts found.\nPlease add an account first.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    widget.isIncome
                        ? 'Enter the money you actually received.'
                        : 'Enter the money you actually spent.',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 24),

                  _label('Actual Amount'),
                  _input(amountController, 'Enter amount', number: true),

                  const SizedBox(height: 20),

                  _label('Financial Account'),
                  DropdownButtonFormField<String>(
                    value: selectedAccountId,
                    dropdownColor: const Color(0xFF211E22),
                    style: const TextStyle(color: Colors.white),
                    decoration: _decoration('Select account'),
                    items: accounts.map((account) {
                      return DropdownMenuItem<String>(
                        value: account['id'].toString(),
                        child: Text(
                          '${account['account_name']} '
                          '(${account['currency'] ?? 'BDT'})',
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => selectedAccountId = value);
                    },
                  ),

                  const SizedBox(height: 20),

                  _label('Category (Optional)'),
                  DropdownButtonFormField<String>(
                    value: selectedCategoryId,
                    dropdownColor: const Color(0xFF211E22),
                    style: const TextStyle(color: Colors.white),
                    decoration: _decoration('Select category'),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('No category'),
                      ),
                      ...categories.map((category) {
                        return DropdownMenuItem<String>(
                          value: category['id'].toString(),
                          child: Text(category['name'].toString()),
                        );
                      }),
                    ],
                    onChanged: (value) {
                      setState(() => selectedCategoryId = value);
                    },
                  ),

                  const SizedBox(height: 20),

                  _label('Description'),
                  _input(
                    descriptionController,
                    'e.g. Monthly salary or groceries',
                  ),

                  const SizedBox(height: 20),

                  _label('Record Date'),
                  OutlinedButton.icon(
                    onPressed: chooseDate,
                    icon: const Icon(Icons.calendar_month),
                    label: Text(
                      '${selectedDate.day.toString().padLeft(2, '0')}/'
                      '${selectedDate.month.toString().padLeft(2, '0')}/'
                      '${selectedDate.year}',
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: accent,
                      side: BorderSide(color: accent),
                      padding: const EdgeInsets.all(15),
                    ),
                  ),

                  const SizedBox(height: 30),

                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: isSaving ? null : saveRecord,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.black,
                      ),
                      child: isSaving
                          ? const CircularProgressIndicator(color: Colors.black)
                          : Text(
                              widget.isIncome
                                  ? 'Save Actual Income'
                                  : 'Save Actual Expense',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 30),

                  ..._recordsSection(),
                ],
              ),
      ),
    );
  }

  // ---------- Recorded (actual) data list ----------

  List<Widget> _recordsSection() {
    final dateText =
        '${selectedDate.day.toString().padLeft(2, '0')}/'
        '${selectedDate.month.toString().padLeft(2, '0')}/'
        '${selectedDate.year}';

    return [
      Row(
        children: [
          Expanded(
            child: Text(
              widget.isIncome ? 'Recorded Income' : 'Recorded Expenses',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Text(
            '${records.length} ${records.length == 1 ? 'record' : 'records'}',
            style: const TextStyle(color: Colors.white54),
          ),
        ],
      ),
      const SizedBox(height: 4),
      Text(
        'For $dateText',
        style: const TextStyle(color: Colors.white54, fontSize: 12),
      ),
      const SizedBox(height: 14),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF211E22),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accent.withOpacity(.25)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              widget.isIncome ? 'Total Actual Income' : 'Total Actual Expense',
              style: const TextStyle(color: Colors.white70),
            ),
            Text(
              _money(recordsTotal),
              style: TextStyle(
                color: accent,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      if (isLoadingRecords)
        Padding(
          padding: const EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator(color: accent)),
        )
      else if (records.isEmpty)
        Padding(
          padding: const EdgeInsets.all(28),
          child: Center(
            child: Text(
              widget.isIncome
                  ? 'No actual income recorded for this date.'
                  : 'No actual expense recorded for this date.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54),
            ),
          ),
        )
      else
        ...records.map(_recordTile),
    ];
  }

  Widget _recordTile(Map<String, dynamic> record) {
    final category = categories
        .where((c) => c['id'].toString() == record['category_id']?.toString())
        .firstOrNull;

    final account = accounts
        .where((a) => a['id'].toString() == record['account_id']?.toString())
        .firstOrNull;

    final color = category?['color'] is num
        ? Color((category!['color'] as num).toInt())
        : accent;

    final icon = category?['icon'] is int
        ? IconData(category!['icon'] as int, fontFamily: 'MaterialIcons')
        : (widget.isIncome ? Icons.south_west : Icons.north_east);

    final amount = (record['amount'] as num?)?.toDouble() ?? 0;
    final description = record['description']?.toString().trim() ?? '';
    final categoryName = category?['name']?.toString();

    final title = description.isNotEmpty
        ? description
        : (categoryName ?? (widget.isIncome ? 'Income' : 'Expense'));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(15, 12, 6, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF211E22),
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
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${categoryName ?? 'No category'} · '
                  '${account?['account_name'] ?? 'Account'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${widget.isIncome ? '+' : '-'}${_money(amount)}',
            style: TextStyle(
              color: accent,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          IconButton(
            onPressed: () => deleteRecord(record['id'].toString()),
            icon: const Icon(Icons.delete_outline, color: Colors.white38),
          ),
        ],
      ),
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
        ),
      ),
    );
  }

  Widget _input(
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
      decoration: _decoration(hint),
    );
  }

  InputDecoration _decoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white38),
      filled: true,
      fillColor: const Color(0xFF211E22),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }
}

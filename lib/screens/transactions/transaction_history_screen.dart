import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'transfer_screen.dart';

/// All income, expenses and transfers for a month, grouped by day.
/// Search, filter, edit and delete.
class TransactionHistoryScreen extends StatefulWidget {
  /// Table your `add_income_expense_record` function writes into.
  final String recordsTable;

  const TransactionHistoryScreen({super.key, required this.recordsTable});

  @override
  State<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

// One row in the list: an income, an expense or a transfer.
class _Entry {
  final String kind; // 'income' | 'expense' | 'transfer'
  final String id;
  final double amount;
  final DateTime date;
  final String title;
  final String? accountId;
  final String accountName;
  final String? toAccountId;
  final String? toAccountName;
  final String? categoryName;
  final String? note;

  const _Entry({
    required this.kind,
    required this.id,
    required this.amount,
    required this.date,
    required this.title,
    required this.accountId,
    required this.accountName,
    this.toAccountId,
    this.toAccountName,
    this.categoryName,
    this.note,
  });
}

class _DayHeader {
  final DateTime date;
  final double spent;

  const _DayHeader(this.date, this.spent);
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  // Black & rose-gold theme (same values as AppColors)
  static const Color background = Color(0xFF08090D);
  static const Color card = Color(0xFF10131A);
  static const Color cardLight = Color(0xFF181B22);
  static const Color peach = Color(0xFFE9A39B);
  static const Color peachLight = Color(0xFFF2B8AE);
  static const Color border = Color(0xFF3A3438);
  static const Color muted = Color(0xFFA39A9C);
  static const Color green = Color(0xFF75D7B0);
  static const Color red = Color(0xFFE58B83);

  static const List<String> _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  static const List<String> _monthsShort = [
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
  static const List<String> _weekdays = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  final supabase = Supabase.instance.client;
  final searchController = TextEditingController();

  late DateTime month;

  List<_Entry> entries = [];
  List<Map<String, dynamic>> accounts = [];

  bool isLoading = true;
  String? errorMessage;

  // filters
  String typeFilter = 'all'; // all | income | expense | transfer
  String? accountFilter;
  String? categoryFilter;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    month = DateTime(now.year, now.month, 1);
    searchController.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  // ---------- helpers ----------

  String _key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  String _money(double amount) {
    final fixed = amount == amount.roundToDouble()
        ? amount.abs().toStringAsFixed(0)
        : amount.abs().toStringAsFixed(2);

    final parts = fixed.split('.');
    final whole = parts[0].replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]},',
    );

    return '${amount < 0 ? '-' : ''}৳$whole${parts.length > 1 ? '.${parts[1]}' : ''}';
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _dayLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (_sameDay(date, today)) return 'Today';
    if (_sameDay(date, today.subtract(const Duration(days: 1)))) {
      return 'Yesterday';
    }

    return '${_weekdays[date.weekday - 1]}, ${date.day} '
        '${_monthsShort[date.month - 1]}';
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  String _errorText(Object error) {
    if (error is PostgrestException) return error.message;
    return error.toString().replaceFirst('Exception: ', '');
  }

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return month.year == now.year && month.month == now.month;
  }

  // ---------- data ----------

  Future<void> _load() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('Please log in first.');

      final start = _key(month);
      final end = _key(DateTime(month.year, month.month + 1, 0));

      final accountRows = List<Map<String, dynamic>>.from(
        await supabase
            .from('financial_accounts')
            .select('id, account_name, account_type')
            .eq('user_id', user.id)
            .order('created_at'),
      );

      final accountNames = <String, String>{
        for (final a in accountRows)
          a['id'].toString(): a['account_name']?.toString() ?? 'Account',
      };

      final recordRows = List<Map<String, dynamic>>.from(
        await supabase
            .from(widget.recordsTable)
            .select(
              'id, account_id, category_id, record_type, amount, '
              'description, record_date',
            )
            .eq('user_id', user.id)
            .gte('record_date', start)
            .lte('record_date', end)
            .order('record_date', ascending: false),
      );

      // category names
      final categoryIds = recordRows
          .map((r) => r['category_id'])
          .where((id) => id != null)
          .map((id) => id.toString())
          .toSet()
          .toList();

      final categoryNames = <String, String>{};

      if (categoryIds.isNotEmpty) {
        final categoryRows = List<Map<String, dynamic>>.from(
          await supabase
              .from('categories')
              .select('id, name')
              .inFilter('id', categoryIds),
        );

        for (final c in categoryRows) {
          categoryNames[c['id'].toString()] = c['name']?.toString() ?? '';
        }
      }

      // transfers (the table may not exist until the SQL has been run)
      var transferRows = <Map<String, dynamic>>[];

      try {
        transferRows = List<Map<String, dynamic>>.from(
          await supabase
              .from('account_transfers')
              .select(
                'id, from_account_id, to_account_id, amount, note, '
                'transfer_date',
              )
              .eq('user_id', user.id)
              .gte('transfer_date', start)
              .lte('transfer_date', end)
              .order('transfer_date', ascending: false),
        );
      } catch (e) {
        debugPrint('Transfers not available: $e');
      }

      final built = <_Entry>[];

      for (final row in recordRows) {
        final date = DateTime.tryParse(
          row['record_date'].toString().substring(0, 10),
        );
        if (date == null) continue;

        final kind = row['record_type'] == 'income' ? 'income' : 'expense';
        final accountId = row['account_id']?.toString();
        final categoryId = row['category_id']?.toString();
        final categoryName = categoryId == null
            ? null
            : categoryNames[categoryId];
        final description = row['description']?.toString().trim() ?? '';

        built.add(
          _Entry(
            kind: kind,
            id: row['id'].toString(),
            amount: (row['amount'] as num?)?.toDouble() ?? 0,
            date: date,
            title: description.isNotEmpty
                ? description
                : (categoryName != null && categoryName.isNotEmpty
                      ? categoryName
                      : (kind == 'income' ? 'Income' : 'Expense')),
            accountId: accountId,
            accountName: accountNames[accountId] ?? 'Account',
            categoryName: categoryName,
            note: description.isEmpty ? null : description,
          ),
        );
      }

      for (final row in transferRows) {
        final date = DateTime.tryParse(
          row['transfer_date'].toString().substring(0, 10),
        );
        if (date == null) continue;

        final fromId = row['from_account_id']?.toString();
        final toId = row['to_account_id']?.toString();

        built.add(
          _Entry(
            kind: 'transfer',
            id: row['id'].toString(),
            amount: (row['amount'] as num?)?.toDouble() ?? 0,
            date: date,
            title: 'Transfer',
            accountId: fromId,
            accountName: accountNames[fromId] ?? 'Account',
            toAccountId: toId,
            toAccountName: accountNames[toId] ?? 'Account',
            note: row['note']?.toString(),
          ),
        );
      }

      built.sort((a, b) => b.date.compareTo(a.date));

      if (!mounted) return;

      setState(() {
        accounts = accountRows;
        entries = built;
        isLoading = false;

        // drop filters that no longer exist in this month
        if (categoryFilter != null &&
            !built.any((e) => e.categoryName == categoryFilter)) {
          categoryFilter = null;
        }
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        errorMessage = _errorText(e);
      });
    }
  }

  void _changeMonth(int delta) {
    setState(() => month = DateTime(month.year, month.month + delta, 1));
    _load();
  }

  List<_Entry> get _filtered {
    final query = searchController.text.trim().toLowerCase();

    return entries.where((e) {
      if (typeFilter != 'all' && e.kind != typeFilter) return false;

      if (accountFilter != null &&
          e.accountId != accountFilter &&
          e.toAccountId != accountFilter) {
        return false;
      }

      if (categoryFilter != null && e.categoryName != categoryFilter) {
        return false;
      }

      if (query.isNotEmpty) {
        final text =
            '${e.title} ${e.accountName} ${e.toAccountName ?? ''} '
                    '${e.categoryName ?? ''} ${e.note ?? ''}'
                .toLowerCase();

        if (!text.contains(query)) return false;
      }

      return true;
    }).toList();
  }

  List<Object> _rows(List<_Entry> items) {
    final rows = <Object>[];
    DateTime? current;

    for (final entry in items) {
      if (current == null || !_sameDay(current, entry.date)) {
        current = entry.date;

        final spent = items
            .where((x) => x.kind == 'expense' && _sameDay(x.date, entry.date))
            .fold<double>(0, (sum, x) => sum + x.amount);

        rows.add(_DayHeader(entry.date, spent));
      }

      rows.add(entry);
    }

    return rows;
  }

  // ---------- actions ----------

  Future<void> _openTransfer() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const TransferScreen()),
    );

    if (saved == true && mounted) await _load();
  }

  Future<void> _delete(_Entry entry) async {
    final isTransfer = entry.kind == 'transfer';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: card,
        title: Text(
          isTransfer ? 'Delete transfer?' : 'Delete transaction?',
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          isTransfer
              ? 'The ${_money(entry.amount)} will be moved back to '
                    '${entry.accountName}.'
              : 'This removes it from your records and adjusts your account '
                    'balance.',
          style: const TextStyle(color: muted, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel', style: TextStyle(color: muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete', style: TextStyle(color: red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      if (isTransfer) {
        await supabase.rpc(
          'delete_account_transfer',
          params: {'p_transfer_id': entry.id},
        );
      } else {
        await supabase.rpc(
          'delete_income_expense_record',
          params: {'p_record_id': entry.id},
        );
      }

      if (!mounted) return;

      _message('Deleted.');
      await _load();
    } catch (e) {
      if (mounted) _message('Could not delete: ${_errorText(e)}');
    }
  }

  Future<void> _showEdit(_Entry entry) async {
    final amountController = TextEditingController(
      text: entry.amount == entry.amount.roundToDouble()
          ? entry.amount.toStringAsFixed(0)
          : entry.amount.toString(),
    );
    final descriptionController = TextEditingController(text: entry.note ?? '');

    String? accountId = entry.accountId;
    bool saving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> save() async {
              final amount = double.tryParse(amountController.text.trim());

              if (amount == null || amount <= 0) {
                _message('Enter a valid amount.');
                return;
              }

              if (accountId == null) {
                _message('Choose an account.');
                return;
              }

              setSheetState(() => saving = true);

              try {
                await supabase.rpc(
                  'update_income_expense_record',
                  params: {
                    'p_record_id': entry.id,
                    'p_account_id': accountId,
                    'p_amount': amount,
                    'p_description': descriptionController.text.trim().isEmpty
                        ? null
                        : descriptionController.text.trim(),
                  },
                );

                if (!sheetContext.mounted) return;
                Navigator.pop(sheetContext);

                if (!mounted) return;
                _message('Transaction updated.');
                await _load();
              } catch (e) {
                setSheetState(() => saving = false);
                _message('Could not update: ${_errorText(e)}');
              }
            }

            final inset = MediaQuery.of(context).viewInsets.bottom;

            return Padding(
              padding: EdgeInsets.fromLTRB(20, 22, 20, 20 + inset),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.kind == 'income' ? 'Edit income' : 'Edit expense',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text('Amount', style: TextStyle(color: muted)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: const TextStyle(color: Colors.white),
                      decoration: _decoration('Enter amount').copyWith(
                        prefixText: '৳ ',
                        prefixStyle: const TextStyle(color: peach),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Account', style: TextStyle(color: muted)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: accountId,
                      isExpanded: true,
                      dropdownColor: cardLight,
                      style: const TextStyle(color: Colors.white),
                      decoration: _decoration('Select account'),
                      items: accounts.map((a) {
                        return DropdownMenuItem<String>(
                          value: a['id'].toString(),
                          child: Text(a['account_name']?.toString() ?? ''),
                        );
                      }).toList(),
                      onChanged: saving
                          ? null
                          : (value) => setSheetState(() => accountId = value),
                    ),
                    const SizedBox(height: 16),
                    const Text('Description', style: TextStyle(color: muted)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: descriptionController,
                      style: const TextStyle(color: Colors.white),
                      decoration: _decoration('e.g. Groceries'),
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: saving ? null : save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: peach,
                          foregroundColor: background,
                        ),
                        child: saving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: background,
                                ),
                              )
                            : const Text(
                                'Save changes',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    amountController.dispose();
    descriptionController.dispose();
  }

  Future<void> _showDetails(_Entry entry) async {
    final isTransfer = entry.kind == 'transfer';
    final color = _kindColor(entry.kind);

    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    _kindIcon(entry.kind, size: 46),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            entry.kind == 'income'
                                ? 'Income'
                                : entry.kind == 'expense'
                                ? 'Expense'
                                : 'Transfer',
                            style: const TextStyle(color: muted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  '${entry.kind == 'income'
                      ? '+'
                      : entry.kind == 'expense'
                      ? '-'
                      : ''}${_money(entry.amount)}',
                  style: TextStyle(
                    color: color,
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 14),
                const Divider(color: border),
                _detailRow(
                  'Date',
                  '${entry.date.day} ${_monthsShort[entry.date.month - 1]} '
                      '${entry.date.year}',
                ),
                if (isTransfer) ...[
                  _detailRow('From', entry.accountName),
                  _detailRow('To', entry.toAccountName ?? ''),
                ] else ...[
                  _detailRow('Account', entry.accountName),
                  _detailRow('Category', entry.categoryName ?? 'No category'),
                ],
                if ((entry.note ?? '').isNotEmpty && isTransfer)
                  _detailRow('Note', entry.note!),
                const SizedBox(height: 14),
                Row(
                  children: [
                    if (!isTransfer) ...[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.pop(sheetContext, 'edit'),
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          label: const Text('Edit'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: peach,
                            side: const BorderSide(color: peach),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.pop(sheetContext, 'delete'),
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('Delete'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: red,
                          side: const BorderSide(color: red),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted) return;

    if (action == 'edit') {
      await _showEdit(entry);
    } else if (action == 'delete') {
      await _delete(entry);
    }
  }

  // ---------- UI ----------

  Color _kindColor(String kind) {
    if (kind == 'income') return green;
    if (kind == 'expense') return red;
    return peach;
  }

  Widget _kindIcon(String kind, {double size = 42}) {
    final color = _kindColor(kind);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withOpacity(.13),
        borderRadius: BorderRadius.circular(size * .32),
      ),
      child: Icon(
        kind == 'income'
            ? Icons.south_west
            : kind == 'expense'
            ? Icons.north_east
            : Icons.swap_horiz,
        color: color,
        size: size * .5,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _filtered;
    final rows = _rows(items);

    final income = items
        .where((e) => e.kind == 'income')
        .fold<double>(0, (sum, e) => sum + e.amount);
    final expense = items
        .where((e) => e.kind == 'expense')
        .fold<double>(0, (sum, e) => sum + e.amount);

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Transactions',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 21),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: const Icon(Icons.refresh, color: peach),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: peach,
        foregroundColor: background,
        onPressed: _openTransfer,
        icon: const Icon(Icons.swap_horiz),
        label: const Text(
          'Transfer',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
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
                    const Icon(Icons.error_outline, color: red, size: 38),
                    const SizedBox(height: 12),
                    Text(
                      errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: muted),
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: peach,
                        foregroundColor: background,
                      ),
                      onPressed: _load,
                      child: const Text('Try Again'),
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              color: peach,
              backgroundColor: card,
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                children: [
                  _searchField(),
                  const SizedBox(height: 12),
                  _monthBar(),
                  const SizedBox(height: 12),
                  _typeChips(),
                  const SizedBox(height: 10),
                  _filterRow(),
                  const SizedBox(height: 14),
                  _summaryRow(income, expense),
                  const SizedBox(height: 16),
                  if (rows.isEmpty)
                    _emptyState()
                  else
                    for (final row in rows)
                      if (row is _DayHeader)
                        _dayHeader(row)
                      else
                        _entryTile(row as _Entry),
                ],
              ),
            ),
    );
  }

  Widget _searchField() {
    return TextField(
      controller: searchController,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: _decoration('Search transactions').copyWith(
        prefixIcon: const Icon(Icons.search, color: muted, size: 20),
        suffixIcon: searchController.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close, color: muted, size: 18),
                onPressed: searchController.clear,
              ),
      ),
    );
  }

  Widget _monthBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border.withOpacity(.7)),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Previous month',
            onPressed: () => _changeMonth(-1),
            icon: const Icon(Icons.chevron_left, color: peach),
          ),
          Expanded(
            child: Text(
              '${_months[month.month - 1]} ${month.year}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Next month',
            onPressed: _isCurrentMonth ? null : () => _changeMonth(1),
            icon: Icon(
              Icons.chevron_right,
              color: _isCurrentMonth ? border : peach,
            ),
          ),
        ],
      ),
    );
  }

  Widget _typeChips() {
    const types = [
      ['all', 'All'],
      ['income', 'Income'],
      ['expense', 'Expense'],
      ['transfer', 'Transfer'],
    ];

    return Row(
      children: [
        for (final type in types) ...[
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => typeFilter = type[0]),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: typeFilter == type[0] ? peach : card,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: typeFilter == type[0]
                        ? peach
                        : border.withOpacity(.7),
                  ),
                ),
                child: Text(
                  type[1],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: typeFilter == type[0] ? background : muted,
                    fontSize: 12,
                    fontWeight: typeFilter == type[0]
                        ? FontWeight.bold
                        : FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
          if (type[0] != 'transfer') const SizedBox(width: 8),
        ],
      ],
    );
  }

  Widget _filterRow() {
    final categories =
        entries
            .map((e) => e.categoryName)
            .whereType<String>()
            .where((name) => name.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    final accountName = accountFilter == null
        ? 'All accounts'
        : accounts
                  .where((a) => a['id'].toString() == accountFilter)
                  .firstOrNull?['account_name']
                  ?.toString() ??
              'Account';

    return Row(
      children: [
        Expanded(
          child: _filterPill(
            icon: Icons.account_balance_wallet_outlined,
            label: accountName,
            active: accountFilter != null,
            items: [
              const PopupMenuItem(
                value: '__all__',
                child: Text('All accounts'),
              ),
              for (final a in accounts)
                PopupMenuItem(
                  value: a['id'].toString(),
                  child: Text(a['account_name']?.toString() ?? 'Account'),
                ),
            ],
            onSelected: (value) => setState(
              () => accountFilter = value == '__all__' ? null : value,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _filterPill(
            icon: Icons.category_outlined,
            label: categoryFilter ?? 'All categories',
            active: categoryFilter != null,
            items: [
              const PopupMenuItem(
                value: '__all__',
                child: Text('All categories'),
              ),
              for (final name in categories)
                PopupMenuItem(value: name, child: Text(name)),
            ],
            onSelected: (value) => setState(
              () => categoryFilter = value == '__all__' ? null : value,
            ),
          ),
        ),
      ],
    );
  }

  Widget _filterPill({
    required IconData icon,
    required String label,
    required bool active,
    required List<PopupMenuEntry<String>> items,
    required ValueChanged<String> onSelected,
  }) {
    return PopupMenuButton<String>(
      color: cardLight,
      onSelected: onSelected,
      itemBuilder: (context) => items,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: active ? peach : border.withOpacity(.7)),
        ),
        child: Row(
          children: [
            Icon(icon, color: active ? peach : muted, size: 16),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: active ? peachLight : muted,
                  fontSize: 12,
                ),
              ),
            ),
            const Icon(Icons.keyboard_arrow_down, color: muted, size: 17),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(double income, double expense) {
    final net = income - expense;

    Widget item(String label, String value, Color color) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border.withOpacity(.7)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: muted, fontSize: 10.5)),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        item('Income', _money(income), green),
        const SizedBox(width: 8),
        item('Expense', _money(expense), red),
        const SizedBox(width: 8),
        item('Net', _money(net), net >= 0 ? peachLight : red),
      ],
    );
  }

  Widget _dayHeader(_DayHeader header) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 8),
      child: Row(
        children: [
          Text(
            _dayLabel(header.date),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          if (header.spent > 0)
            Text(
              'Spent ${_money(header.spent)}',
              style: const TextStyle(color: muted, fontSize: 11),
            ),
        ],
      ),
    );
  }

  Widget _entryTile(_Entry entry) {
    final isTransfer = entry.kind == 'transfer';

    final subtitle = isTransfer
        ? '${entry.accountName} → ${entry.toAccountName}'
        : '${entry.categoryName ?? 'No category'} · ${entry.accountName}';

    final sign = entry.kind == 'income'
        ? '+'
        : entry.kind == 'expense'
        ? '-'
        : '';

    return GestureDetector(
      onTap: () => _showDetails(entry),
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border.withOpacity(.7)),
        ),
        child: Row(
          children: [
            _kindIcon(entry.kind),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: muted, fontSize: 11.5),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '$sign${_money(entry.amount)}',
              style: TextStyle(
                color: entry.kind == 'income'
                    ? green
                    : entry.kind == 'transfer'
                    ? peach
                    : Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Padding(
      padding: const EdgeInsets.only(top: 50),
      child: Column(
        children: [
          const Icon(Icons.receipt_long_outlined, color: peach, size: 44),
          const SizedBox(height: 12),
          const Text(
            'No transactions found',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(
            typeFilter != 'all' ||
                    accountFilter != null ||
                    categoryFilter != null ||
                    searchController.text.isNotEmpty
                ? 'Try changing or clearing your filters.'
                : 'Nothing was recorded in ${_months[month.month - 1]}.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: muted, fontSize: 12.5),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 84,
            child: Text(
              label,
              style: const TextStyle(color: muted, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _decoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: muted, fontSize: 14),
      filled: true,
      fillColor: cardLight,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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

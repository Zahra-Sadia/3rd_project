import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Moves money between two of the user's OWN accounts.
/// It is not counted as income or expense. Pops with `true` when saved.
class TransferScreen extends StatefulWidget {
  const TransferScreen({super.key});

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  // Black & rose-gold theme (same values as AppColors)
  static const Color background = Color(0xFF08090D);
  static const Color card = Color(0xFF10131A);
  static const Color cardLight = Color(0xFF181B22);
  static const Color peach = Color(0xFFE9A39B);
  static const Color peachLight = Color(0xFFF2B8AE);
  static const Color border = Color(0xFF3A3438);
  static const Color muted = Color(0xFFA39A9C);
  static const Color red = Color(0xFFE58B83);

  final supabase = Supabase.instance.client;
  final amountController = TextEditingController();
  final noteController = TextEditingController();

  List<Map<String, dynamic>> accounts = [];
  String? fromId;
  String? toId;
  DateTime selectedDate = DateTime.now();

  bool isLoading = true;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    amountController.addListener(() => setState(() {}));
    _loadAccounts();
  }

  @override
  void dispose() {
    amountController.dispose();
    noteController.dispose();
    super.dispose();
  }

  // ---------- helpers ----------

  String _dateKey(DateTime d) =>
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

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  String _errorText(Object error) {
    if (error is PostgrestException) return error.message;
    return error.toString().replaceFirst('Exception: ', '');
  }

  Map<String, dynamic>? _account(String? id) {
    if (id == null) return null;
    return accounts.where((a) => a['id'].toString() == id).firstOrNull;
  }

  double _balance(String? id) =>
      (_account(id)?['balance'] as num?)?.toDouble() ?? 0;

  String _currency(String? id) =>
      _account(id)?['currency']?.toString() ?? 'BDT';

  double get amount => double.tryParse(amountController.text.trim()) ?? 0;

  bool get currenciesMatch => _currency(fromId) == _currency(toId);

  // ---------- data ----------

  Future<void> _loadAccounts() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('Please log in first.');

      final rows = List<Map<String, dynamic>>.from(
        await supabase
            .from('financial_accounts')
            .select('id, account_name, account_type, balance, currency')
            .eq('user_id', user.id)
            .order('created_at'),
      );

      if (!mounted) return;

      setState(() {
        accounts = rows;
        fromId = rows.isNotEmpty ? rows[0]['id'].toString() : null;
        toId = rows.length > 1 ? rows[1]['id'].toString() : null;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => isLoading = false);
      _message('Could not load your accounts: ${_errorText(e)}');
    }
  }

  Future<void> _chooseDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null) setState(() => selectedDate = picked);
  }

  void _swap() {
    setState(() {
      final temp = fromId;
      fromId = toId;
      toId = temp;
    });
  }

  void _onFromChanged(String? value) {
    if (value == null) return;

    setState(() {
      fromId = value;

      if (toId == value) {
        toId = accounts
            .map((a) => a['id'].toString())
            .where((id) => id != value)
            .firstOrNull;
      }
    });
  }

  void _onToChanged(String? value) {
    if (value == null) return;

    setState(() {
      toId = value;

      if (fromId == value) {
        fromId = accounts
            .map((a) => a['id'].toString())
            .where((id) => id != value)
            .firstOrNull;
      }
    });
  }

  Future<void> _save() async {
    if (fromId == null || toId == null || fromId == toId) {
      _message('Choose two different accounts.');
      return;
    }

    if (amount <= 0) {
      _message('Enter a valid amount.');
      return;
    }

    if (!currenciesMatch) {
      _message('Both accounts must use the same currency.');
      return;
    }

    if (amount > _balance(fromId)) {
      _message('Not enough balance in the source account.');
      return;
    }

    setState(() => isSaving = true);

    try {
      await supabase.rpc(
        'transfer_between_accounts',
        params: {
          'p_from_account_id': fromId,
          'p_to_account_id': toId,
          'p_amount': amount,
          'p_note': noteController.text.trim().isEmpty
              ? null
              : noteController.text.trim(),
          'p_transfer_date': _dateKey(selectedDate),
        },
      );

      if (!mounted) return;

      _message('Transfer completed.');
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      setState(() => isSaving = false);
      _message('Could not transfer: ${_errorText(e)}');
    }
  }

  // ---------- UI ----------

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
          'Transfer Money',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 21),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: peach))
          : accounts.length < 2
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: Text(
                  'You need at least two accounts to make a transfer.\n'
                  'Add another account from My Funds first.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: muted, height: 1.6),
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: peach.withOpacity(.35)),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.swap_horiz, color: peach, size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Move money between your own accounts. A transfer '
                          'is not counted as income or expense.',
                          style: TextStyle(
                            color: muted,
                            fontSize: 12,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 22),
                _label('From'),
                _accountDropdown(fromId, _onFromChanged),
                const SizedBox(height: 6),
                Text(
                  'Available: ${_money(_balance(fromId))}',
                  style: const TextStyle(color: muted, fontSize: 11.5),
                ),

                const SizedBox(height: 10),
                Center(
                  child: GestureDetector(
                    onTap: _swap,
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: card,
                        shape: BoxShape.circle,
                        border: Border.all(color: peach.withOpacity(.5)),
                      ),
                      child: const Icon(
                        Icons.swap_vert,
                        color: peach,
                        size: 22,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                _label('To'),
                _accountDropdown(toId, _onToChanged),
                const SizedBox(height: 6),
                Text(
                  'Current: ${_money(_balance(toId))}',
                  style: const TextStyle(color: muted, fontSize: 11.5),
                ),

                const SizedBox(height: 22),
                _label('Amount'),
                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                  decoration: _decoration('Enter amount').copyWith(
                    prefixText: '৳ ',
                    prefixStyle: const TextStyle(color: peach, fontSize: 18),
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    style: TextButton.styleFrom(foregroundColor: peach),
                    onPressed: () {
                      final full = _balance(fromId);
                      amountController.text = full == full.roundToDouble()
                          ? full.toStringAsFixed(0)
                          : full.toStringAsFixed(2);
                    },
                    child: const Text('Transfer full balance'),
                  ),
                ),

                if (!currenciesMatch)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: Text(
                      'These accounts use different currencies, so money '
                      'cannot be moved between them.',
                      style: TextStyle(color: red, fontSize: 12, height: 1.5),
                    ),
                  )
                else if (amount > 0)
                  _afterTransferPreview(),

                const SizedBox(height: 12),
                _label('Note (optional)'),
                TextField(
                  controller: noteController,
                  style: const TextStyle(color: Colors.white),
                  decoration: _decoration('e.g. Cash deposited to bKash'),
                ),

                const SizedBox(height: 18),
                _label('Date'),
                OutlinedButton.icon(
                  onPressed: _chooseDate,
                  icon: const Icon(Icons.calendar_month, size: 18),
                  label: Text(
                    '${selectedDate.day.toString().padLeft(2, '0')}/'
                    '${selectedDate.month.toString().padLeft(2, '0')}/'
                    '${selectedDate.year}',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: peach,
                    side: const BorderSide(color: peach),
                    padding: const EdgeInsets.all(15),
                  ),
                ),

                const SizedBox(height: 28),
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
                            'Transfer',
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

  Widget _afterTransferPreview() {
    final enough = amount <= _balance(fromId);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border.withOpacity(.7)),
      ),
      child: enough
          ? Column(
              children: [
                _previewRow(
                  _account(fromId)?['account_name']?.toString() ?? 'From',
                  _money(_balance(fromId) - amount),
                ),
                const SizedBox(height: 6),
                _previewRow(
                  _account(toId)?['account_name']?.toString() ?? 'To',
                  _money(_balance(toId) + amount),
                ),
              ],
            )
          : const Text(
              'This is more than the available balance.',
              style: TextStyle(color: red, fontSize: 12),
            ),
    );
  }

  Widget _previewRow(String name, String after) {
    return Row(
      children: [
        Expanded(
          child: Text(
            '$name after transfer',
            style: const TextStyle(color: muted, fontSize: 12),
          ),
        ),
        Text(
          after,
          style: const TextStyle(
            color: peachLight,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _accountDropdown(String? value, ValueChanged<String?> onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      dropdownColor: cardLight,
      style: const TextStyle(color: Colors.white),
      decoration: _decoration('Select account'),
      items: accounts.map((account) {
        return DropdownMenuItem<String>(
          value: account['id'].toString(),
          child: Text(
            account['account_name']?.toString() ?? 'Account',
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: onChanged,
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

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  static const Color background = Color(0xFF090B0D);
  static const Color cardColor = Color(0xFF151719);
  static const Color peach = Color(0xFFE8B77D);
  static const Color muted = Color(0xFF9AA0A3);

  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> accounts = [];
  bool isLoading = true;
  String? errorMessage;
  String? selectedCategory;

  final List<Map<String, dynamic>> categories = [
    {'type': 'card', 'name': 'Cards', 'icon': Icons.credit_card},
    {
      'type': 'cash',
      'name': 'Cash',
      'icon': Icons.account_balance_wallet_outlined,
    },
    {
      'type': 'mobile_banking',
      'name': 'Mobile Banking',
      'icon': Icons.phone_android,
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    try {
      final user = supabase.auth.currentUser;

      if (user == null) {
        if (!mounted) return;
        setState(() {
          isLoading = false;
          errorMessage = 'Please log in to view your funds.';
        });
        return;
      }

      final result = await supabase
          .from('financial_accounts')
          .select('id, account_name, account_type, provider, balance, currency')
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      if (!mounted) return;

      setState(() {
        accounts = List<Map<String, dynamic>>.from(result);
        isLoading = false;
        errorMessage = null;
      });
    } catch (e) {
      debugPrint('Fund loading error: $e');

      if (!mounted) return;

      setState(() {
        isLoading = false;
        errorMessage = 'Could not load your funds. Please try again.';
      });
    }
  }

  double _categoryBalance(String type) {
    return accounts
        .where((account) => account['account_type'] == type)
        .fold<double>(
          0,
          (sum, account) =>
              sum + ((account['balance'] as num?)?.toDouble() ?? 0),
        );
  }

  double get _totalBalance {
    return accounts.fold<double>(
      0,
      (sum, account) => sum + ((account['balance'] as num?)?.toDouble() ?? 0),
    );
  }

  String _money(num amount) {
    return '৳${amount.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+\.)'), (match) => '${match[1]},')}';
  }

  String _categoryName(String type) {
    return categories.firstWhere(
          (category) => category['type'] == type,
          orElse: () => {'name': 'Fund'},
        )['name']
        as String;
  }

  IconData _categoryIcon(String type) {
    return categories.firstWhere(
          (category) => category['type'] == type,
          orElse: () => {'icon': Icons.account_balance_wallet},
        )['icon']
        as IconData;
  }

  Future<void> _showAddAccount({String? initialCategory}) async {
    final nameController = TextEditingController();
    final providerController = TextEditingController();
    final balanceController = TextEditingController();

    String selectedType = initialCategory ?? 'card';
    bool saving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> saveAccount() async {
              final name = nameController.text.trim();
              final provider = providerController.text.trim();
              final balanceText = balanceController.text.trim();
              final balance = double.tryParse(balanceText);

              if (name.isEmpty || balance == null || balance < 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Enter a fund name and a valid balance.'),
                  ),
                );
                return;
              }

              final user = supabase.auth.currentUser;
              if (user == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please log in first.')),
                );
                return;
              }

              setSheetState(() => saving = true);

              try {
                await supabase.from('financial_accounts').insert({
                  'user_id': user.id,
                  'account_name': name,
                  'account_type': selectedType,
                  'provider': provider.isEmpty ? null : provider,
                  'balance': balance,
                  'currency': 'BDT',
                });

                if (!mounted) return;

                Navigator.pop(sheetContext);

                await _loadAccounts();

                if (!mounted) return;
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(
                    content: Text('Fund source added successfully.'),
                  ),
                );
              } catch (e) {
                debugPrint('Saving fund source error: $e');

                setSheetState(() => saving = false);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Could not save the fund source. Please try again.',
                    ),
                  ),
                );
              }
            }

            final bottomInset = MediaQuery.of(context).viewInsets.bottom;

            return Padding(
              padding: EdgeInsets.fromLTRB(20, 22, 20, 20 + bottomInset),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Add Fund Source',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 23,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text('Fund Category', style: TextStyle(color: muted)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: selectedType,
                      dropdownColor: cardColor,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration('Choose a category'),
                      items: categories.map((category) {
                        return DropdownMenuItem<String>(
                          value: category['type'] as String,
                          child: Text(category['name'] as String),
                        );
                      }).toList(),
                      onChanged: saving
                          ? null
                          : (value) {
                              if (value != null) {
                                setSheetState(() => selectedType = value);
                              }
                            },
                    ),
                    const SizedBox(height: 16),
                    Text(
                      selectedType == 'card'
                          ? 'Card Name'
                          : selectedType == 'cash'
                          ? 'Cash Name'
                          : 'Mobile Banking Name',
                      style: const TextStyle(color: muted),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: nameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration(
                        selectedType == 'card'
                            ? 'e.g. Visa Card, Debit Card'
                            : selectedType == 'cash'
                            ? 'e.g. Home Cash, Wallet'
                            : 'e.g. bKash, Nagad, Rocket',
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Provider (Optional)',
                      style: TextStyle(color: muted),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: providerController,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration(
                        'e.g. DBBL, City Bank, Nagad',
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Available Balance (৳)',
                      style: TextStyle(color: muted),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: balanceController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration('Enter available amount'),
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: peach,
                          foregroundColor: background,
                        ),
                        onPressed: saving ? null : saveAccount,
                        child: saving
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: background,
                                ),
                              )
                            : const Text(
                                'Save Fund',
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

    nameController.dispose();
    providerController.dispose();
    balanceController.dispose();
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: muted, fontSize: 14),
      filled: true,
      fillColor: background,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.white12),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: peach),
      ),
    );
  }

  Future<void> _deleteAccount(Map<String, dynamic> account) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: cardColor,
        title: const Text(
          'Delete fund source?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to delete "${account['account_name']}"?',
          style: const TextStyle(color: muted),
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
    );

    if (confirm != true) return;

    try {
      await supabase
          .from('financial_accounts')
          .delete()
          .eq('id', account['id']);

      await _loadAccounts();

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Fund source deleted.')));
    } catch (e) {
      debugPrint('Delete fund source error: $e');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not delete this fund source. It may have linked transactions.',
          ),
        ),
      );
    }
  }

  Widget _categoryCard(Map<String, dynamic> category) {
    final type = category['type'] as String;
    final name = category['name'] as String;
    final count = accounts
        .where((account) => account['account_type'] == type)
        .length;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => setState(() => selectedCategory = type),
      child: Container(
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            Container(
              height: 48,
              width: 48,
              decoration: BoxDecoration(
                color: peach.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(category['icon'] as IconData, color: peach, size: 25),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '$count ${count == 1 ? 'fund' : 'funds'}',
                    style: const TextStyle(color: muted, fontSize: 13),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    _money(_categoryBalance(type)),
                    style: const TextStyle(
                      color: peach,
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: muted, size: 27),
          ],
        ),
      ),
    );
  }

  Widget _accountTile(Map<String, dynamic> account) {
    final provider = account['provider']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Icon(
            _categoryIcon(account['account_type'] as String),
            color: peach,
            size: 25,
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account['account_name']?.toString() ?? 'Fund',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (provider.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    provider,
                    style: const TextStyle(color: muted, fontSize: 12),
                  ),
                ],
                const SizedBox(height: 5),
                Text(
                  _categoryName(account['account_type'] as String),
                  style: const TextStyle(color: muted, fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _money((account['balance'] as num?) ?? 0),
                style: const TextStyle(
                  color: peach,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              IconButton(
                tooltip: 'Delete fund source',
                visualDensity: VisualDensity.compact,
                onPressed: () => _deleteAccount(account),
                icon: const Icon(
                  Icons.delete_outline,
                  color: Colors.redAccent,
                  size: 21,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDetail = selectedCategory != null;
    final visibleAccounts = isDetail
        ? accounts
              .where((account) => account['account_type'] == selectedCategory)
              .toList()
        : <Map<String, dynamic>>[];

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            if (isDetail) {
              setState(() => selectedCategory = null);
            } else {
              Navigator.pop(context);
            }
          },
        ),
        automaticallyImplyLeading: false,
        title: Text(
          isDetail ? _categoryName(selectedCategory!) : 'My Funds',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 21,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh funds',
            onPressed: _loadAccounts,
            icon: const Icon(Icons.refresh, color: peach),
          ),
        ],
      ),
      floatingActionButton: isLoading || errorMessage != null
          ? null
          : FloatingActionButton.extended(
              backgroundColor: peach,
              foregroundColor: background,
              onPressed: () =>
                  _showAddAccount(initialCategory: selectedCategory),
              icon: const Icon(Icons.add),
              label: const Text(
                'Add Funds',
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
                    const Icon(Icons.error_outline, color: peach, size: 42),
                    const SizedBox(height: 12),
                    Text(
                      errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _loadAccounts,
                      child: const Text('Try Again'),
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              color: peach,
              onRefresh: _loadAccounts,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 100),
                children: [
                  if (!isDetail) ...[
                    Container(
                      padding: const EdgeInsets.all(21),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF342A21), Color(0xFF171717)],
                        ),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: peach.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'TOTAL BALANCE',
                            style: TextStyle(
                              color: muted,
                              letterSpacing: 1.4,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 9),
                          Text(
                            _money(_totalBalance),
                            style: const TextStyle(
                              color: peach,
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${accounts.length} ${accounts.length == 1 ? 'fund source' : 'fund sources'} across all categories',
                            style: const TextStyle(color: muted, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'YOUR FUND SOURCES',
                      style: TextStyle(
                        color: muted,
                        letterSpacing: 1.3,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 13),
                    for (final category in categories) ...[
                      _categoryCard(category),
                      const SizedBox(height: 12),
                    ],
                    const SizedBox(height: 5),
                    const Text(
                      'Tap a fund source to view its individual details.',
                      style: TextStyle(color: muted, fontSize: 12),
                    ),
                  ] else ...[
                    Text(
                      'Total ${_categoryName(selectedCategory!)} balance',
                      style: const TextStyle(color: muted, fontSize: 14),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _money(_categoryBalance(selectedCategory!)),
                      style: const TextStyle(
                        color: peach,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 22),
                    if (visibleAccounts.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 35),
                        child: Column(
                          children: [
                            Icon(
                              Icons.account_balance_wallet_outlined,
                              color: peach,
                              size: 48,
                            ),
                            SizedBox(height: 12),
                            Text(
                              'No funds added yet',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Tap Add Funds to add your first fund source.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: muted),
                            ),
                          ],
                        ),
                      )
                    else
                      for (final account in visibleAccounts)
                        _accountTile(account),
                  ],
                ],
              ),
            ),
    );
  }
}

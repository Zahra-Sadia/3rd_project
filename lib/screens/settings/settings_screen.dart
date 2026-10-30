import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../constants/app_colors.dart';
import '../../theme/app_settings.dart';
import 'settings_widgets.dart';
import 'settings_dialogs.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String selectedCurrency = 'BDT (৳)';
  String selectedTheme = 'Dark';
  String selectedLanguage = 'English';

  bool hideBalances = false;
  bool billReminders = true;
  bool dailySafeToSpend = true;
  bool goalMilestones = true;
  bool unusualSpending = true;
  bool autoLock = true;
  bool autoBackup = true;
  String monthlyIncome = '';
  String payday = '1';
  String hourlyRate = '';
  String monthlyBudget = '';

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      selectedCurrency =
          prefs.getString('settings_currency') ?? selectedCurrency;
      selectedTheme = prefs.getString('settings_theme') ?? selectedTheme;
      selectedLanguage =
          prefs.getString('settings_language') ?? selectedLanguage;
      hideBalances = prefs.getBool('settings_hide_balances') ?? hideBalances;
      billReminders = prefs.getBool('settings_bill_reminders') ?? billReminders;
      dailySafeToSpend =
          prefs.getBool('settings_daily_safe') ?? dailySafeToSpend;
      goalMilestones =
          prefs.getBool('settings_goal_milestones') ?? goalMilestones;
      unusualSpending =
          prefs.getBool('settings_unusual_spending') ?? unusualSpending;
      autoLock = prefs.getBool('settings_auto_lock') ?? autoLock;
      autoBackup = prefs.getBool('settings_auto_backup') ?? autoBackup;
      monthlyIncome = prefs.getString('settings_monthly_income') ?? '';
      payday = prefs.getString('settings_payday') ?? '1';
      hourlyRate = prefs.getString('settings_hourly_rate') ?? '';
      monthlyBudget = prefs.getString('settings_monthly_budget') ?? '';
    });
  }

  Future<void> _savePreference(String key, Object value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is String) await prefs.setString(key, value);
    if (value is bool) await prefs.setBool(key, value);
  }

  void showChoiceDialog({
    required String title,
    required List<String> choices,
    required String selected,
    required ValueChanged<String> onSelected,
  }) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          title,
          style: const TextStyle(color: AppColors.primaryText),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: choices.map((choice) {
            return RadioListTile<String>(
              value: choice,
              groupValue: selected,
              activeColor: AppColors.roseGold,
              title: Text(
                choice,
                style: const TextStyle(color: AppColors.primaryText),
              ),
              onChanged: (value) {
                if (value != null) {
                  onSelected(value);
                  Navigator.pop(dialogContext);
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void showEditDialog({
    required String title,
    required String hint,
    required String initialValue,
    required ValueChanged<String> onSave,
  }) {
    final controller = TextEditingController(text: initialValue);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          title,
          style: const TextStyle(color: AppColors.primaryText),
        ),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: AppColors.primaryText),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppColors.secondaryText),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.roseGold),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.roseGold),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              onSave(controller.text.trim());
              Navigator.pop(dialogContext);
            },
            child: const Text(
              'Save',
              style: TextStyle(color: AppColors.roseGold),
            ),
          ),
        ],
      ),
    ).then((_) => controller.dispose());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D12),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D12),
        elevation: 0,
        title: const Text(
          'Settings',
          style: TextStyle(
            color: AppColors.primaryText,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          // ACCOUNT
          sectionTitle('Account'),
          cardContainer(
            children: [
              settingsItem(
                icon: Icons.currency_exchange_rounded,
                title: 'Currency',
                subtitle: selectedCurrency,
                onTap: () {
                  showCurrencyDialog(context, selectedCurrency, (currency) {
                    setState(() {
                      selectedCurrency = currency;
                    });
                    _savePreference('settings_currency', currency);
                  });
                },
              ),
            ],
          ),

          const SizedBox(height: 20),

          // MONEY RULES
          sectionTitle('Money Rules'),
          cardContainer(
            children: [
              settingsItem(
                icon: Icons.calendar_month_rounded,
                title: 'Income and payday',
                subtitle:
                    'Income: ${monthlyIncome.isEmpty ? 'not set' : monthlyIncome} · Payday: $payday',
                onTap: () {
                  showEditDialog(
                    title: 'Monthly Income',
                    hint: 'Monthly income (number)',
                    initialValue: monthlyIncome,
                    onSave: (value) {
                      setState(() => monthlyIncome = value);
                      _savePreference('settings_monthly_income', value);
                      showMessage(
                        context,
                        'Monthly income saved on this device.',
                      );
                    },
                  );
                },
              ),
              cardDivider(),
              settingsItem(
                icon: Icons.account_balance_wallet_outlined,
                title: 'Monthly budgets',
                subtitle:
                    '${monthlyBudget.isEmpty ? 'Set spending limit' : 'Budget: $monthlyBudget'}',
                onTap: () {
                  showEditDialog(
                    title: 'Monthly Budget',
                    hint: 'Enter total monthly budget',
                    initialValue: monthlyBudget,
                    onSave: (value) {
                      setState(() => monthlyBudget = value);
                      _savePreference('settings_monthly_budget', value);
                      showMessage(
                        context,
                        'Budget saved on this device; it is not linked to transactions yet.',
                      );
                    },
                  );
                },
              ),
              cardDivider(),
              settingsItem(
                icon: Icons.schedule_rounded,
                title: 'Hourly rate',
                subtitle:
                    '${hourlyRate.isEmpty ? 'Set your hourly earning rate' : 'Rate: $hourlyRate'}',
                onTap: () {
                  showEditDialog(
                    title: 'Hourly Rate',
                    hint: 'Enter hourly rate',
                    initialValue: hourlyRate,
                    onSave: (value) {
                      setState(() => hourlyRate = value);
                      _savePreference('settings_hourly_rate', value);
                      showMessage(context, 'Hourly rate saved on this device.');
                    },
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 20),

          // NOTIFICATIONS
          sectionTitle('Notifications'),
          cardContainer(
            children: [
              switchItem(
                icon: Icons.notifications_active_outlined,
                title: 'Bill reminders',
                subtitle: 'Reminders for upcoming bills',
                value: billReminders,
                onChanged: (value) {
                  setState(() => billReminders = value);
                  _savePreference('settings_bill_reminders', value);
                },
              ),
              cardDivider(),
              switchItem(
                icon: Icons.savings_outlined,
                title: 'Daily safe-to-spend',
                subtitle: 'Receive your daily spending update',
                value: dailySafeToSpend,
                onChanged: (value) {
                  setState(() => dailySafeToSpend = value);
                  _savePreference('settings_daily_safe', value);
                },
              ),
              cardDivider(),
              switchItem(
                icon: Icons.flag_outlined,
                title: 'Goal milestones',
                subtitle: 'Get updates on your savings goals',
                value: goalMilestones,
                onChanged: (value) {
                  setState(() => goalMilestones = value);
                  _savePreference('settings_goal_milestones', value);
                },
              ),
              cardDivider(),
              switchItem(
                icon: Icons.warning_amber_rounded,
                title: 'Unusual spending',
                subtitle: 'Alerts for unusual activity',
                value: unusualSpending,
                onChanged: (value) {
                  setState(() => unusualSpending = value);
                  _savePreference('settings_unusual_spending', value);
                },
              ),
            ],
          ),

          const SizedBox(height: 20),

          // APPEARANCE
          sectionTitle('Appearance'),
          cardContainer(
            children: [
              settingsItem(
                icon: Icons.palette_outlined,
                title: 'Theme',
                subtitle: 'Fort Vault Dark Theme',
                onTap: () {
                  showMessage(
                    context,
                    'Fort Vault uses its signature dark and peach theme.',
                  );
                },
              ),
              cardDivider(),

              // FONT
              ValueListenableBuilder<String>(
                valueListenable: appFontNotifier,
                builder: (context, currentFont, child) {
                  return settingsItem(
                    icon: Icons.text_fields_rounded,
                    title: 'Font',
                    subtitle: currentFont,
                    onTap: () {
                      showFontDialog(context, currentFont, (font) {
                        appFontNotifier.value = font;
                        _savePreference('settings_font', font);
                      });
                    },
                  );
                },
              ),

              cardDivider(),

              // LANGUAGE
              settingsItem(
                icon: Icons.language_rounded,
                title: 'Language',
                subtitle: selectedLanguage,
                onTap: () {
                  showLanguageDialog(context, selectedLanguage, (language) {
                    setState(() {
                      selectedLanguage = language;
                    });
                    _savePreference('settings_language', language);
                  });
                },
              ),
            ],
          ),

          const SizedBox(height: 20),

          // PRIVACY & SECURITY
          sectionTitle('Privacy & Security'),
          cardContainer(
            children: [
              switchItem(
                icon: Icons.visibility_off_outlined,
                title: 'Hide balances',
                subtitle: 'Keep your balances private',
                value: hideBalances,
                onChanged: (value) {
                  setState(() => hideBalances = value);
                  _savePreference('settings_hide_balances', value);
                },
              ),
              cardDivider(),

              // CHANGE PIN
              settingsItem(
                icon: Icons.lock_outline_rounded,
                title: 'Change PIN',
                subtitle: 'Update your security PIN',
                onTap: () {
                  showChangePinDialog(context);
                },
              ),
              cardDivider(),

              // TWO-FACTOR AUTHENTICATION
              settingsItem(
                icon: Icons.verified_user_outlined,
                title: 'Two-Factor Authentication',
                subtitle: 'Add an extra layer of security',
                onTap: () {
                  showMessage(
                    context,
                    'Two-Factor Authentication is not implemented yet.',
                  );
                },
              ),
              cardDivider(),

              // AUTO LOCK
              switchItem(
                icon: Icons.lock_clock_outlined,
                title: 'Auto Lock',
                subtitle: 'Lock the app automatically',
                value: autoLock,
                onChanged: (value) {
                  setState(() => autoLock = value);
                  _savePreference('settings_auto_lock', value);
                },
              ),
              cardDivider(),

              // AUTO BACKUP
              switchItem(
                icon: Icons.backup_outlined,
                title: 'Auto Backup',
                subtitle: 'Automatically back up your data',
                value: autoBackup,
                onChanged: (value) {
                  setState(() => autoBackup = value);
                  _savePreference('settings_auto_backup', value);
                },
              ),
              cardDivider(),

              // EXPORT DATA
              settingsItem(
                icon: Icons.file_download_outlined,
                title: 'Export my data',
                subtitle: 'Export your financial records',
                onTap: () {
                  showExportDialog(context);
                },
              ),
              cardDivider(),

              // DELETE ACCOUNT
              settingsItem(
                icon: Icons.delete_outline_rounded,
                title: 'Delete account',
                subtitle: 'Permanently delete your account',
                onTap: () {
                  showDeleteAccountDialog(context);
                },
              ),
            ],
          ),

          const SizedBox(height: 20),

          // HELP
          sectionTitle('Help'),
          cardContainer(
            children: [
              settingsItem(
                icon: Icons.support_agent_rounded,
                title: 'Support center',
                subtitle: 'Get help with Fort Vault',
                onTap: () {
                  showMessage(context, 'Support center is not connected yet.');
                },
              ),
            ],
          ),

          const SizedBox(height: 28),

          const Center(
            child: Text(
              'YOUR FUTURE, WITHIN REACH',
              style: TextStyle(
                color: AppColors.secondaryText,
                fontSize: 11,
                letterSpacing: 2,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

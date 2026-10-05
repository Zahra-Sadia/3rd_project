import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Background and UI colors
  static const Color background = Color(0xFF08090D);
  static const Color cardColor = Color(0xFF211E22);
  static const Color accent = Color(0xFFE79A91);
  static const Color textColor = Color(0xFFF5F1F2);
  static const Color subTextColor = Color(0xFF969196);
  static const Color borderColor = Color(0xFF3B373C);

  bool isEditing = false;

  // Personal Information
  final nameController = TextEditingController();
  final emailController = TextEditingController();

  // Financial Information
  final incomeController = TextEditingController(text: "50000");
  final savingsController = TextEditingController(text: "10000");

  // Financial Goal
  final goalAmountController = TextEditingController(text: "100000");

  String currency = "BDT";
  String financialGoal = "Emergency Fund";

  @override
  void initState() {
    super.initState();

    final user = Supabase.instance.client.auth.currentUser;

    if (user != null) {
      nameController.text = user.userMetadata?['full_name']?.toString() ?? '';

      emailController.text = user.email ?? '';
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    incomeController.dispose();
    savingsController.dispose();
    goalAmountController.dispose();
    super.dispose();
  }

  Future<void> saveChanges() async {
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(data: {'full_name': nameController.text.trim()}),
      );

      if (!mounted) return;

      setState(() {
        isEditing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profile saved successfully")),
      );
    } on AuthException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not save profile changes.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,

      appBar: AppBar(
        backgroundColor: background,
        elevation: 0,

        title: const Text(
          "Profile",
          style: TextStyle(
            color: textColor,
            fontSize: 24,
            fontWeight: FontWeight.w600,
          ),
        ),

        actions: [
          IconButton(
            onPressed: () {
              setState(() {
                isEditing = true;
              });
            },
            icon: const Icon(Icons.edit_outlined, color: accent),
          ),
        ],
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ==============================
            // PROFILE HEADER
            // ==============================
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),

              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: borderColor),
              ),

              child: Row(
                children: [
                  CircleAvatar(
                    radius: 35,
                    backgroundColor: accent.withOpacity(0.15),

                    child: Text(
                      nameController.text.isNotEmpty
                          ? nameController.text[0].toUpperCase()
                          : "",

                      style: const TextStyle(
                        color: accent,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  const SizedBox(width: 15),

                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [
                      Text(
                        nameController.text,
                        style: const TextStyle(
                          color: textColor,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      const SizedBox(height: 5),

                      Text(
                        emailController.text,
                        style: const TextStyle(
                          color: subTextColor,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // ==============================
            // PERSONAL INFORMATION
            // ==============================
            sectionTitle("Personal Information", Icons.person_outline),

            const SizedBox(height: 12),

            profileCard(
              Column(
                children: [
                  textField("Full Name", Icons.person_outline, nameController),

                  const SizedBox(height: 15),

                  TextField(
                    controller: emailController,
                    enabled: false,
                    style: const TextStyle(color: textColor),
                    decoration: inputDecoration("Email", Icons.email_outlined),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // ==============================
            // FINANCIAL PREFERENCES
            // ==============================
            sectionTitle(
              "Financial Preferences",
              Icons.account_balance_wallet_outlined,
            ),

            const SizedBox(height: 12),

            profileCard(
              Column(
                children: [
                  DropdownButtonFormField<String>(
                    value: currency,

                    onChanged: isEditing
                        ? (value) {
                            setState(() {
                              currency = value!;
                            });
                          }
                        : null,

                    dropdownColor: cardColor,

                    style: const TextStyle(color: textColor),

                    decoration: inputDecoration(
                      "Currency",
                      Icons.currency_exchange,
                    ),

                    items: const [
                      DropdownMenuItem(
                        value: "BDT",
                        child: Text("BDT - Bangladeshi Taka"),
                      ),
                      DropdownMenuItem(
                        value: "USD",
                        child: Text("USD - US Dollar"),
                      ),
                      DropdownMenuItem(value: "EUR", child: Text("EUR - Euro")),
                      DropdownMenuItem(
                        value: "GBP",
                        child: Text("GBP - Pound"),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // ==============================
            // FINANCIAL GOALS
            // ==============================
            sectionTitle("Financial Goals", Icons.flag_outlined),

            const SizedBox(height: 12),

            profileCard(
              Column(
                children: [
                  DropdownButtonFormField<String>(
                    value: financialGoal,

                    onChanged: isEditing
                        ? (value) {
                            setState(() {
                              financialGoal = value!;
                            });
                          }
                        : null,

                    dropdownColor: cardColor,

                    style: const TextStyle(color: textColor),

                    decoration: inputDecoration(
                      "Financial Goal",
                      Icons.flag_outlined,
                    ),

                    items: const [
                      DropdownMenuItem(
                        value: "Emergency Fund",
                        child: Text("Emergency Fund"),
                      ),
                      DropdownMenuItem(
                        value: "Buy a House",
                        child: Text("Buy a House"),
                      ),
                      DropdownMenuItem(
                        value: "Education",
                        child: Text("Education"),
                      ),
                      DropdownMenuItem(value: "Travel", child: Text("Travel")),
                      DropdownMenuItem(
                        value: "Investment",
                        child: Text("Investment"),
                      ),
                    ],
                  ),

                  const SizedBox(height: 15),

                  textField(
                    "Target Amount",
                    Icons.track_changes_outlined,
                    goalAmountController,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // ==============================
            // INCOME & SAVINGS
            // ==============================
            sectionTitle("Financial Information", Icons.savings_outlined),

            const SizedBox(height: 12),

            profileCard(
              Column(
                children: [
                  textField(
                    "Monthly Income",
                    Icons.payments_outlined,
                    incomeController,
                  ),

                  const SizedBox(height: 15),

                  textField(
                    "Monthly Savings",
                    Icons.savings_outlined,
                    savingsController,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // ==============================
            // SAVE BUTTON
            // ==============================
            if (isEditing)
              SizedBox(
                width: double.infinity,
                height: 55,

                child: ElevatedButton(
                  onPressed: saveChanges,

                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: background,

                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),

                  child: const Text(
                    "Save Changes",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // SECTION TITLE
  // ============================================================

  Widget sectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: accent, size: 20),

        const SizedBox(width: 8),

        Text(
          title,
          style: const TextStyle(
            color: textColor,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // CARD
  // ============================================================

  Widget profileCard(Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),

      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),

        border: Border.all(color: borderColor),
      ),

      child: child,
    );
  }

  // ============================================================
  // TEXT FIELD
  // ============================================================

  Widget textField(
    String label,
    IconData icon,
    TextEditingController controller,
  ) {
    return TextField(
      controller: controller,
      enabled: isEditing,

      onChanged: (value) {
        setState(() {});
      },

      style: const TextStyle(color: textColor),

      decoration: inputDecoration(label, icon),
    );
  }

  // ============================================================
  // INPUT DECORATION
  // ============================================================

  InputDecoration inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,

      labelStyle: const TextStyle(color: subTextColor),

      prefixIcon: Icon(icon, color: accent),

      filled: true,
      fillColor: background,

      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: borderColor),
      ),

      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: borderColor),
      ),

      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: accent),
      ),
    );
  }
}

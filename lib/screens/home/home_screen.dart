import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../utils/app_routes.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // =========================================================
  // COLORS
  // =========================================================

  final Color backgroundColor = const Color(0xFF0D0D12);
  final Color cardColor = const Color(0xFF17151D);
  final Color purpleColor = const Color(0xFFB84DFF);
  final Color lightPurple = const Color(0xFFD26AFF);

  int selectedIndex = 0;

  // =========================================================
  // SELECTED CURRENCY
  // =========================================================

  String selectedCurrency = "BDT";

  // =========================================================
  // CURRENCY RATES
  // These are example/demo rates based on BDT.
  // =========================================================

  final Map<String, double> exchangeRates = {
    "BDT": 1.0,
    "USD": 0.0082,
    "EUR": 0.0070,
    "GBP": 0.0061,
    "INR": 0.72,
    "AED": 0.030,
    "SAR": 0.031,
    "CAD": 0.011,
    "AUD": 0.013,
    "CNY": 0.059,
    "JPY": 1.21,
    "CHF": 0.0057,
  };

  // =========================================================
  // CURRENCY SYMBOLS
  // =========================================================

  final Map<String, String> currencySymbols = {
    "BDT": "৳",
    "USD": "\$",
    "EUR": "€",
    "GBP": "£",
    "INR": "₹",
    "AED": "د.إ",
    "SAR": "﷼",
    "CAD": "C\$",
    "AUD": "A\$",
    "CNY": "¥",
    "JPY": "¥",
    "CHF": "CHF ",
  };

  // =========================================================
  // CURRENCY FLAGS
  // =========================================================

  final Map<String, String> currencyFlags = {
    "BDT": "🇧🇩",
    "USD": "🇺🇸",
    "EUR": "🇪🇺",
    "GBP": "🇬🇧",
    "INR": "🇮🇳",
    "AED": "🇦🇪",
    "SAR": "🇸🇦",
    "CAD": "🇨🇦",
    "AUD": "🇦🇺",
    "CNY": "🇨🇳",
    "JPY": "🇯🇵",
    "CHF": "🇨🇭",
  };

  // =========================================================
  // CURRENCY NAMES
  // =========================================================

  final Map<String, String> currencyNames = {
    "BDT": "Bangladeshi Taka",
    "USD": "US Dollar",
    "EUR": "Euro",
    "GBP": "British Pound",
    "INR": "Indian Rupee",
    "AED": "UAE Dirham",
    "SAR": "Saudi Riyal",
    "CAD": "Canadian Dollar",
    "AUD": "Australian Dollar",
    "CNY": "Chinese Yuan",
    "JPY": "Japanese Yen",
    "CHF": "Swiss Franc",
  };

  // =========================================================
  // CONVERT BDT TO SELECTED CURRENCY
  // =========================================================

  double convert(double amountInBDT) {
    return amountInBDT * exchangeRates[selectedCurrency]!;
  }

  // =========================================================
  // FORMAT MONEY
  // =========================================================

  String money(double amountInBDT) {
    double convertedAmount = convert(amountInBDT);

    return "${currencySymbols[selectedCurrency]}"
        "${convertedAmount.abs().toStringAsFixed(2)}";
  }

  // =========================================================
  // HOME SCREEN
  // =========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,

      // =====================================================
      // BODY
      // =====================================================
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              // =================================================
              // TOP BAR
              // =================================================
              Row(
                children: [
                  // -------------------------------------------------
                  // FORT VAULT LOGO / NAME
                  // -------------------------------------------------
                  Text(
                    "Fort Vault",
                    style: GoogleFonts.playwriteUsModern(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),

                  const Spacer(),

                  // -------------------------------------------------
                  // SEARCH BUTTON
                  // -------------------------------------------------
                  Container(
                    height: 45,
                    width: 45,

                    decoration: BoxDecoration(
                      color: cardColor,
                      shape: BoxShape.circle,
                    ),

                    child: const Icon(Icons.search, color: Colors.white),
                  ),

                  const SizedBox(width: 10),

                  // -------------------------------------------------
                  // NOTIFICATION BUTTON
                  // -------------------------------------------------
                  Container(
                    height: 45,
                    width: 45,

                    decoration: BoxDecoration(
                      color: cardColor,
                      shape: BoxShape.circle,
                    ),

                    child: const Icon(
                      Icons.notifications_none,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 25),

              // =================================================
              // GREETING
              // =================================================
              const Text(
                "Good evening!",
                style: TextStyle(color: Colors.white70, fontSize: 15),
              ),

              const SizedBox(height: 5),

              const Text(
                "Your Financial Overview",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 20),

              Container(
                width: double.infinity,

                padding: const EdgeInsets.all(22),

                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(25),

                  gradient: const LinearGradient(
                    colors: [Color(0xFF8D32C7), Color(0xFFC650FF)],

                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),

                  boxShadow: [
                    BoxShadow(
                      color: purpleColor.withOpacity(0.25),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    // =================================================
                    // BALANCE TITLE + CURRENCY SELECTOR
                    // =================================================
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,

                      children: [
                        const Text(
                          "Total Balance",
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),

                        // =================================================
                        // CURRENCY DROPDOWN
                        // =================================================
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8),

                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(15),
                          ),

                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: selectedCurrency,

                              dropdownColor: const Color(0xFF29202F),

                              icon: const Icon(
                                Icons.keyboard_arrow_down,
                                color: Colors.white,
                                size: 18,
                              ),

                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),

                              items: currencyNames.keys.map((currency) {
                                return DropdownMenuItem<String>(
                                  value: currency,

                                  child: Row(
                                    children: [
                                      Text(
                                        currencyFlags[currency]!,
                                        style: const TextStyle(fontSize: 17),
                                      ),

                                      const SizedBox(width: 6),

                                      Text(
                                        currency,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),

                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    selectedCurrency = value;
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // =================================================
                    // TOTAL BALANCE
                    // =================================================
                    Text(
                      money(8890),

                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // =================================================
                    // CARD INFORMATION
                    // =================================================
                    Container(
                      padding: const EdgeInsets.all(15),

                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(15),
                      ),

                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,

                        children: const [
                          Text(
                            "•••• 9154",
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),

                          Text(
                            "12/24",
                            style: TextStyle(color: Colors.white70),
                          ),

                          Text(
                            "●●",
                            style: TextStyle(
                              color: Colors.orange,
                              fontSize: 20,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // =================================================
              // SAVINGS CARD
              // =================================================
              Container(
                padding: const EdgeInsets.all(18),

                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(20),

                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),

                child: Row(
                  children: [
                    Container(
                      height: 50,
                      width: 50,

                      decoration: BoxDecoration(
                        color: purpleColor.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(15),
                      ),

                      child: Icon(
                        Icons.savings_outlined,
                        color: lightPurple,
                        size: 27,
                      ),
                    ),

                    const SizedBox(width: 15),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,

                        children: [
                          const Text(
                            "Savings",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 5),

                          Text(
                            money(620),

                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Icon(Icons.arrow_upward, color: Colors.greenAccent),
                  ],
                ),
              ),

              const SizedBox(height: 25),

              // =================================================
              // FINANCIAL OVERVIEW
              // =================================================
              const Text(
                "Financial Overview",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 15),

              Row(
                children: [
                  // =================================================
                  // INCOME
                  // =================================================
                  Expanded(
                    child: _statCard(
                      title: "Income",

                      amount: money(2300),

                      icon: Icons.arrow_downward,

                      iconColor: Colors.greenAccent,
                    ),
                  ),

                  const SizedBox(width: 12),

                  // =================================================
                  // EXPENSES
                  // =================================================
                  Expanded(
                    child: _statCard(
                      title: "Expenses",

                      amount: money(2460),

                      icon: Icons.arrow_upward,

                      iconColor: Colors.redAccent,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 25),

              // =================================================
              // SPENDING STATISTICS
              // =================================================
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,

                children: [
                  const Text(
                    "Spending Statistics",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),

                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(20),
                    ),

                    child: const Row(
                      children: [
                        Text(
                          "Week",
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),

                        SizedBox(width: 5),

                        Icon(
                          Icons.keyboard_arrow_down,
                          color: Colors.white70,
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 15),

              // =================================================
              // SPENDING CHART
              // =================================================
              Container(
                height: 210,
                width: double.infinity,

                padding: const EdgeInsets.all(20),

                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(22),
                ),

                child: Column(
                  children: [
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,

                        mainAxisAlignment: MainAxisAlignment.spaceAround,

                        children: [
                          _bar(80),
                          _bar(120),
                          _bar(95),
                          _bar(145),
                          _bar(70),
                          _bar(125),
                          _bar(100),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,

                      children: [
                        Text("Mon", style: TextStyle(color: Colors.white38)),

                        Text("Tue", style: TextStyle(color: Colors.white38)),

                        Text("Wed", style: TextStyle(color: Colors.white38)),

                        Text("Thu", style: TextStyle(color: Colors.white38)),

                        Text("Fri", style: TextStyle(color: Colors.white38)),

                        Text("Sat", style: TextStyle(color: Colors.white38)),

                        Text("Sun", style: TextStyle(color: Colors.white38)),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 25),

              // =================================================
              // RECENT TRANSACTIONS
              // =================================================
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,

                children: const [
                  Text(
                    "Recent Transactions",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  Text(
                    "See All",
                    style: TextStyle(color: Color(0xFFC650FF), fontSize: 14),
                  ),
                ],
              ),

              const SizedBox(height: 15),

              // =================================================
              // SHOPPING
              // =================================================
              _transaction(
                icon: Icons.shopping_bag_outlined,

                title: "Shopping",

                date: "Today, 10:30 AM",

                amount: 85,

                positive: false,
              ),

              // =================================================
              // FOOD
              // =================================================
              _transaction(
                icon: Icons.restaurant_outlined,

                title: "Food & Restaurant",

                date: "Yesterday, 8:20 PM",

                amount: 42.50,

                positive: false,
              ),

              // =================================================
              // SALARY
              // =================================================
              _transaction(
                icon: Icons.account_balance_wallet_outlined,

                title: "Salary",

                date: "Sep 25, 2026",

                amount: 2300,

                positive: true,
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),

      // =========================================================
      // BOTTOM NAVIGATION BAR
      // =========================================================
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),

        decoration: BoxDecoration(
          color: const Color(0xFF121117),

          border: Border(
            top: BorderSide(color: Colors.white.withOpacity(0.05)),
          ),
        ),

        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,

          children: [
            // HOME
            _bottomIcon(Icons.home_outlined, 0),

            // STATISTICS
            _bottomIcon(Icons.bar_chart_outlined, 1),

            // =================================================
            // CENTER WALLET BUTTON
            // =================================================
            GestureDetector(
              onTap: () {
                setState(() {
                  selectedIndex = 2;
                });
              },

              child: Container(
                height: 55,
                width: 55,

                decoration: BoxDecoration(
                  color: purpleColor,
                  shape: BoxShape.circle,

                  boxShadow: [
                    BoxShadow(
                      color: purpleColor.withOpacity(0.4),
                      blurRadius: 15,
                    ),
                  ],
                ),

                child: const Icon(
                  Icons.account_balance_wallet_outlined,
                  color: Colors.white,
                ),
              ),
            ),

            // CARDS
            _bottomIcon(Icons.credit_card_outlined, 3),

            // MENU
            _bottomIcon(Icons.menu, 4),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // STAT CARD
  // =========================================================

  Widget _statCard({
    required String title,
    required String amount,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(17),

      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,

            children: [
              Icon(icon, color: iconColor, size: 22),

              Text(title, style: const TextStyle(color: Colors.white70)),
            ],
          ),

          const SizedBox(height: 12),

          Text(
            amount,

            style: const TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // CHART BAR
  // =========================================================

  Widget _bar(double height) {
    return Container(
      width: 20,
      height: height,

      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),

        gradient: const LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,

          colors: [Color(0xFF7E28B5), Color(0xFFD75EFF)],
        ),
      ),
    );
  }

  // =========================================================
  // TRANSACTION
  // =========================================================

  Widget _transaction({
    required IconData icon,
    required String title,
    required String date,
    required double amount,
    required bool positive,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),

      padding: const EdgeInsets.all(15),

      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
      ),

      child: Row(
        children: [
          // -------------------------------------------------
          // TRANSACTION ICON
          // -------------------------------------------------
          Container(
            height: 45,
            width: 45,

            decoration: BoxDecoration(
              color: purpleColor.withOpacity(0.15),

              borderRadius: BorderRadius.circular(13),
            ),

            child: Icon(icon, color: lightPurple),
          ),

          const SizedBox(width: 12),

          // -------------------------------------------------
          // TRANSACTION INFORMATION
          // -------------------------------------------------
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Text(
                  title,

                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  date,

                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ),

          // -------------------------------------------------
          // TRANSACTION AMOUNT
          // -------------------------------------------------
          Text(
            positive ? "+${money(amount)}" : "-${money(amount)}",

            style: TextStyle(
              color: positive ? Colors.greenAccent : Colors.white,

              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // BOTTOM NAVIGATION ICON
  // =========================================================

  Widget _bottomIcon(IconData icon, int index) {
    bool selected = selectedIndex == index;

    return GestureDetector(
      onTap: () {
        if (index == 4) {
          Navigator.pushNamed(context, AppRoutes.menu);
          return;
        }

        setState(() {
          selectedIndex = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? purpleColor.withOpacity(0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Icon(
          icon,
          color: selected ? purpleColor : Colors.white38,
          size: 25,
        ),
      ),
    );
  }
}

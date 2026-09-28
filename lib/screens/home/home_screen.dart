import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF08090D),

      appBar: AppBar(
        backgroundColor: const Color(0xFF08090D),
        elevation: 0,

        title: const Text(
          'Fort Vault',
          style: TextStyle(
            color: Color(0xFFF5F1F2),
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      drawer: Drawer(
        backgroundColor: const Color(0xFF211E22),
        child: ListView(
          children: const [
            DrawerHeader(
              child: Text(
                'Fort Vault',
                style: TextStyle(
                  color: Color(0xFFF5F1F2),
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),

      body: const SizedBox(),
    );
  }
}

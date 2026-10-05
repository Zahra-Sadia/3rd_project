import 'package:flutter/material.dart';

import '../../utils/app_routes.dart';

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  static const Color background = Color(0xFF08090D);
  static const Color cardColor = Color(0xFF211E22);
  static const Color accent = Color(0xFFE79A91);
  static const Color textColor = Color(0xFFF5F1F2);
  static const Color subTextColor = Color(0xFF969196);
  static const Color borderColor = Color(0xFF3B373C);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,

      appBar: AppBar(
        backgroundColor: background,
        elevation: 0,
        title: const Text(
          'Menu',
          style: TextStyle(
            color: textColor,
            fontSize: 24,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: const IconThemeData(color: textColor),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Account section
            const Text(
              'Account',
              style: TextStyle(
                color: subTextColor,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),

            const SizedBox(height: 12),

            menuItem(
              context,
              icon: Icons.person_outline,
              title: 'Profile',
              subtitle: 'View and edit your profile',
              onTap: () {
                Navigator.pushNamed(context, AppRoutes.profile);
              },
            ),

            const SizedBox(height: 12),

            menuItem(
              context,
              icon: Icons.settings_outlined,
              title: 'Settings',
              subtitle: 'Manage your app settings',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Settings coming soon')),
                );
              },
            ),

            const SizedBox(height: 28),

            // Security section
            const Text(
              'Security',
              style: TextStyle(
                color: subTextColor,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),

            const SizedBox(height: 12),

            menuItem(
              context,
              icon: Icons.notifications_none_outlined,
              title: 'Notifications',
              subtitle: 'Manage your notifications',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Notifications coming soon')),
                );
              },
            ),

            const SizedBox(height: 12),

            menuItem(
              context,
              icon: Icons.lock_outline,
              title: 'Security',
              subtitle: 'Password and security options',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Security settings coming soon'),
                  ),
                );
              },
            ),

            const SizedBox(height: 28),

            // Other section
            const Text(
              'Other',
              style: TextStyle(
                color: subTextColor,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),

            const SizedBox(height: 12),

            menuItem(
              context,
              icon: Icons.info_outline,
              title: 'About Fort Vault',
              subtitle: 'Information about the app',
              onTap: () {
                showAboutDialog(
                  context: context,
                  applicationName: 'Fort Vault',
                  applicationVersion: '1.0.0',
                  applicationLegalese: 'Personal Money Management App',
                );
              },
            ),

            const SizedBox(height: 12),

            menuItem(
              context,
              icon: Icons.logout,
              title: 'Logout',
              subtitle: 'Sign out of your account',
              iconColor: Colors.redAccent,
              titleColor: Colors.redAccent,
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Logout will be added soon')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget menuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color iconColor = accent,
    Color titleColor = textColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: accent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),

            const SizedBox(width: 15),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: titleColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    subtitle,
                    style: const TextStyle(color: subTextColor, fontSize: 12),
                  ),
                ],
              ),
            ),

            const Icon(Icons.arrow_forward_ios, color: subTextColor, size: 16),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';

Widget sectionTitle(String title) {
  return Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 10),
    child: Text(
      title,
      style: const TextStyle(
        color: AppColors.roseGold,
        fontSize: 14,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.6,
      ),
    ),
  );
}

Widget cardContainer({required List<Widget> children}) {
  return Container(
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.roseGold.withOpacity(0.12)),
    ),
    child: Column(children: children),
  );
}

Widget cardDivider() {
  return Divider(
    height: 1,
    thickness: 0.5,
    indent: 56,
    endIndent: 16,
    color: AppColors.secondaryText.withOpacity(0.18),
  );
}

Widget settingsItem({
  required IconData icon,
  required String title,
  required String subtitle,
  required VoidCallback onTap,
}) {
  return ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
    leading: Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.roseGold.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: AppColors.roseGold, size: 21),
    ),
    title: Text(
      title,
      style: const TextStyle(
        color: AppColors.primaryText,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    ),
    subtitle: Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        subtitle,
        style: const TextStyle(color: AppColors.secondaryText, fontSize: 12),
      ),
    ),
    trailing: const Icon(
      Icons.chevron_right_rounded,
      color: AppColors.secondaryText,
    ),
    onTap: onTap,
  );
}

Widget switchItem({
  required IconData icon,
  required String title,
  required String subtitle,
  required bool value,
  required ValueChanged<bool> onChanged,
}) {
  return ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
    leading: Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.roseGold.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: AppColors.roseGold, size: 21),
    ),
    title: Text(
      title,
      style: const TextStyle(
        color: AppColors.primaryText,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    ),
    subtitle: Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        subtitle,
        style: const TextStyle(color: AppColors.secondaryText, fontSize: 12),
      ),
    ),
    trailing: Switch(
      value: value,
      activeColor: AppColors.roseGold,
      onChanged: onChanged,
    ),
  );
}

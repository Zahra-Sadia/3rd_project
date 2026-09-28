import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_colors.dart';

class AppLogo extends StatelessWidget {
  final double fontSize;
  final bool showTagline;

  const AppLogo({super.key, this.fontSize = 52, this.showTagline = true});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Fort Vault',
          style: GoogleFonts.playwriteUsModern(
            color: AppColors.primaryText,
            fontSize: fontSize,
            fontWeight: FontWeight.w400,
            letterSpacing: -1.5,
          ),
        ),

        if (showTagline) ...[
          const SizedBox(height: 5),
          Text(
            'YOUR MONEY, YOUR FORTRESS',
            style: TextStyle(
              color: AppColors.roseGold,
              fontSize: 8,
              fontWeight: FontWeight.w500,
              letterSpacing: 2.5,
            ),
          ),
        ],
      ],
    );
  }
}

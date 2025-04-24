import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Color? iconColor;
  final Widget? actionButton;

  const EmptyStateWidget({
    Key? key,
    required this.icon,
    required this.title,
    required this.message,
    this.iconColor,
    this.actionButton,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    final Color defaultIconColor = iconColor ?? (isDarkTheme ? Colors.grey.shade600 : Colors.grey.shade400);
    final Color textColor = isDarkTheme ? Colors.white70 : Colors.black54;

    return Center(
      child: SingleChildScrollView( // Ensure content is scrollable if it overflows
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: defaultIconColor,
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600, // Use w600 for slightly bolder title
                color: textColor.withOpacity(0.9),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: textColor.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            if (actionButton != null) ...[
              const SizedBox(height: 24),
              actionButton!,
            ]
          ],
        ),
      ),
    );
  }
} 
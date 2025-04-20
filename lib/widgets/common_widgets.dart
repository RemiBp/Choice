import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';

/// Classe d'utilitaires pour les widgets communs utilisés dans l'application
class CommonWidgets {
  /// Construit un avatar d'utilisateur standard à partir d'une URL d'image
  static Widget buildUserAvatar({
    required String? imageUrl, 
    double radius = 24, 
    Color defaultBackgroundColor = Colors.blue,
    IconData defaultIcon = Icons.person,
    Color defaultIconColor = Colors.white,
  }) {
    return CircleAvatar(
      radius: radius,
      backgroundImage: imageUrl != null && imageUrl.isNotEmpty
        ? getImageProvider(imageUrl)
        : null,
      backgroundColor: imageUrl == null || imageUrl.isEmpty
        ? defaultBackgroundColor
        : null,
      child: imageUrl == null || imageUrl.isEmpty
        ? Icon(defaultIcon, color: defaultIconColor, size: radius * 0.8)
        : null,
    );
  }

  /// Construit un bouton standard de style Material avec des options configurables
  static Widget buildButton({
    required String text,
    required VoidCallback onPressed,
    Color backgroundColor = Colors.blue,
    Color textColor = Colors.white,
    double horizontalPadding = 24.0,
    double verticalPadding = 12.0,
    bool isFullWidth = false,
    IconData? prefixIcon,
    bool isLoading = false,
  }) {
    final buttonChild = isLoading
      ? SizedBox(
          width: 24, 
          height: 24, 
          child: CircularProgressIndicator(
            color: textColor,
            strokeWidth: 2.0,
          ),
        )
      : Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (prefixIcon != null) ...[
              Icon(prefixIcon, color: textColor),
              const SizedBox(width: 8),
            ],
            Text(
              text,
              style: GoogleFonts.montserrat(
                color: textColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );

    return SizedBox(
      width: isFullWidth ? double.infinity : null,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: textColor,
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding, 
            vertical: verticalPadding
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: buttonChild,
      ),
    );
  }

  /// Construit un message d'erreur standard
  static Widget buildErrorMessage(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade700),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: Colors.red.shade700),
            ),
          ),
        ],
      ),
    );
  }

  /// Construit un indicateur de chargement standard
  static Widget buildLoadingIndicator({
    Color color = Colors.blue, 
    String? message,
    double size = 36.0,
  }) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(color: color),
          ),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
} 
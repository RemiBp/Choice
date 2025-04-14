import 'package:flutter/material.dart';

/// Constantes de couleurs utilisées dans l'application
class AppColors {
  // Couleurs générales de l'application
  static const Color primary = Color(0xFF2196F3);
  static const Color secondary = Color(0xFF4CAF50);
  static const Color accent = Color(0xFFFFC107);
  static const Color background = Color(0xFFF5F7FA);
  static const Color surface = Colors.white;
  static const Color error = Color(0xFFD32F2F);
  static const Color warning = Color(0xFFFF9800);
  static const Color success = Color(0xFF4CAF50);
  static const Color info = Color(0xFF2196F3);

  // Couleurs de texte
  static const Color textPrimary = Color(0xFF333333);
  static const Color textSecondary = Color(0xFF666666);
  static const Color textMuted = Color(0xFF999999);
  static const Color textDisabled = Color(0xFFCCCCCC);
  static const Color textLight = Colors.white;
  static const Color textDark = Colors.black;

  // Couleurs des éléments d'interface
  static const Color cardBackground = Colors.white;
  static const Color divider = Color(0xFFEEEEEE);
  static const Color buttonPrimary = primary;
  static const Color buttonSecondary = Color(0xFF757575);
  static const Color inputBackground = Color(0xFFF5F7FA);
  static const Color inputBorder = Color(0xFFDFE1E6);
  static const Color overlay = Color(0x80000000);
  static const Color shadow = Color(0x26000000);
  
  // Couleurs spécifiques aux fonctionnalités
  static const Color restaurantPrimary = Color(0xFFFF5722);
  static const Color leisurePrimary = Color(0xFF673AB7);
  static const Color wellnessPrimary = Color(0xFF009688);
  static const Color friendsPrimary = Color(0xFF2196F3);
  
  // Couleurs des émotions
  static const Color joy = Color(0xFFFFC107);
  static const Color surprise = Color(0xFF8BC34A);
  static const Color nostalgia = Color(0xFF9C27B0);
  static const Color fascination = Color(0xFF3F51B5);
  static const Color inspiration = Color(0xFF00BCD4);
  static const Color amusement = Color(0xFFFF9800);
  static const Color relaxation = Color(0xFF4CAF50);
  static const Color excitement = Color(0xFFE91E63);

  // Couleurs des ratings
  static const Color ratingExcellent = Color(0xFF4CAF50);
  static const Color ratingGood = Color(0xFF8BC34A);
  static const Color ratingAverage = Color(0xFFFFC107);
  static const Color ratingBelowAverage = Color(0xFFFF9800);
  static const Color ratingPoor = Color(0xFFD32F2F);
  
  // Dégradés
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient restaurantGradient = LinearGradient(
    colors: [Color(0xFFFF5722), Color(0xFFE64A19)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient leisureGradient = LinearGradient(
    colors: [Color(0xFF673AB7), Color(0xFF512DA8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient wellnessGradient = LinearGradient(
    colors: [Color(0xFF009688), Color(0xFF00796B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient friendsGradient = LinearGradient(
    colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
} 
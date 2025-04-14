import 'package:flutter/material.dart';

/// Configuration standardisée des couleurs des cartes
class MapColors {
  // Couleurs primaires pour chaque type de carte
  static const Color restaurantPrimary = Color(0xFFFF8C00); // Orange
  static const Color leisurePrimary = Color(0xFF9370DB);    // Violet
  static const Color wellnessPrimary = Color(0xFF3CB371);   // Vert
  static const Color friendsPrimary = Color(0xFFFFD700);    // Jaune

  // Couleurs secondaires et accent pour chaque type
  static const Color restaurantSecondary = Color(0xFFFFA500); // Orange plus clair
  static const Color leisureSecondary = Color(0xFFB19CD9);    // Violet plus clair
  static const Color wellnessSecondary = Color(0xFF66CDAA);   // Vert plus clair
  static const Color friendsSecondary = Color(0xFFFFC125);    // Jaune plus clair
  
  // Méthode pour obtenir la couleur primaire par indice
  static Color getPrimaryColorByIndex(int index) {
    switch (index) {
      case 0:
        return restaurantPrimary;
      case 1:
        return leisurePrimary;
      case 2:
        return wellnessPrimary;
      case 3:
        return friendsPrimary;
      default:
        return restaurantPrimary;
    }
  }
  
  // Méthode pour obtenir la couleur secondaire par indice
  static Color getSecondaryColorByIndex(int index) {
    switch (index) {
      case 0:
        return restaurantSecondary;
      case 1:
        return leisureSecondary;
      case 2:
        return wellnessSecondary;
      case 3:
        return friendsSecondary;
      default:
        return restaurantSecondary;
    }
  }
} 
import 'package:flutter/material.dart';

/// Classe définissant les couleurs standardisées pour les différentes cartes
class MapColors {
  // Couleurs pour la carte des restaurants
  static const Color restaurantPrimary = Color(0xFFE53935);
  static const Color restaurantSecondary = Color(0xFFEF5350);
  static const Color restaurantAccent = Color(0xFFFF7043);
  static const Color restaurantBackground = Color(0xFFFFF3E0);
  
  // Couleurs pour la carte des loisirs
  static const Color leisurePrimary = Color(0xFF8E24AA);
  static const Color leisureSecondary = Color(0xFFAB47BC);
  static const Color leisureAccent = Color(0xFF7B1FA2);
  static const Color leisureBackground = Color(0xFFF3E5F5);
  
  // Couleurs pour la carte bien-être
  static const Color wellnessPrimary = Color(0xFF00897B);
  static const Color wellnessSecondary = Color(0xFF26A69A);
  static const Color wellnessAccent = Color(0xFF00796B);
  static const Color wellnessBackground = Color(0xFFE0F2F1);
  
  // Couleurs pour la carte des amis
  static const Color friendsPrimary = Color(0xFF1E88E5);
  static const Color friendsSecondary = Color(0xFF42A5F5);
  static const Color friendsAccent = Color(0xFF1976D2);
  static const Color friendsBackground = Color(0xFFE3F2FD);
  
  // Couleurs communes
  static const Color mapBackground = Color(0xFFF5F5F5);
  static const Color cardBackground = Colors.white;
  static const Color textDark = Color(0xFF212121);
  static const Color textLight = Colors.white;
  static const Color divider = Color(0xFFE0E0E0);
  
  // Obtenir la couleur primaire selon le type de carte
  static Color getPrimaryColorForType(String type) {
    switch (type) {
      case 'restaurant':
        return Colors.orange;
      case 'leisure':
        return Colors.purple;
      case 'beautyPlace':
        return Colors.pink;
      case 'friends':
        return Colors.blue;
      default:
        return Colors.blue;
    }
  }
} 
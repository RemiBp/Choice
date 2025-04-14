import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Classe utilitaire pour standardiser les paramètres des cartes dans l'application
class MapHelper {
  /// Dimensions standard pour les conteneurs de carte
  static const double mapHeight = double.infinity;
  static const double mapWidth = double.infinity;
  
  /// Padding standard pour les cartes
  static const EdgeInsets mapPadding = EdgeInsets.only(
    top: 8.0,
    bottom: 8.0,
    left: 8.0,
    right: 8.0
  );
  
  /// Valeurs par défaut pour Google Maps
  static const CameraPosition defaultCameraPosition = CameraPosition(
    target: LatLng(48.866667, 2.333333), // Paris par défaut
    zoom: 12.0,
  );
  
  /// Calcule un ratio d'aspect cohérent pour les cartes
  static double getMapAspectRatio(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    // Ratio d'aspect 16:9 standard pour les cartes
    return screenSize.width / (screenSize.height * 0.75);
  }
  
  /// Obtient une taille standard pour le conteneur de carte
  static BoxConstraints getMapConstraints(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    return BoxConstraints(
      minWidth: screenSize.width,
      minHeight: screenSize.height * 0.75,
      maxWidth: double.infinity,
      maxHeight: double.infinity,
    );
  }
  
  /// Obtient un style de carte standardisé pour tous les types de carte
  static Widget buildMapContainer({
    required Widget child,
    required BuildContext context,
    Color? backgroundColor
  }) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      constraints: getMapConstraints(context),
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
} 
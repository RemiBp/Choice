import '../screens/map_restaurant_screen.dart' as restaurant_map;
import '../screens/map_leisure_screen.dart' as leisure_map;
import '../screens/map_wellness_screen.dart' as wellness_map;
import '../screens/map_friends_screen.dart' as friends_map;
import 'package:flutter/material.dart';
import '../models/map_selector.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Énumération des types de cartes disponibles
enum MapType {
  restaurant,
  leisure,
  wellness,
  friends,
}

/// Classe pour définir la configuration d'une carte
class MapConfig {
  final String label;
  final String icon;      // Chemin vers l'icône
  final Color color;      // Couleur primaire pour ce type de carte
  final MapType mapType;  // Type de carte (défini dans map_selector.dart)
  final String route;     // Route pour la navigation
  final String? name;     // Nom alternatif (optionnel)
  final String? description; // Description (optionnelle)

  const MapConfig({
    required this.label,
    required this.icon,
    required this.color,
    required this.mapType,
    required this.route,
    this.name,
    this.description,
  });

  /// Crée une copie de cette configuration avec les propriétés modifiées
  MapConfig copyWith({
    String? label,
    String? icon,
    Color? color,
    MapType? mapType,
    String? route,
    String? name,
    String? description,
  }) {
    return MapConfig(
      label: label ?? this.label,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      mapType: mapType ?? this.mapType,
      route: route ?? this.route,
      name: name ?? this.name,
      description: description ?? this.description,
    );
  }
}

/// Liste des configurations par défaut pour les différentes cartes
final List<MapConfig> MAP_CONFIGS = [
  // Restaurant map
  MapConfig(
    label: 'Restaurant',
    icon: 'restaurant',
    color: Colors.orange,
    mapType: MapType.restaurant,
    route: '',
  ),
  
  // Leisure map
  MapConfig(
    label: 'Loisir',
    icon: 'theater_comedy',
    color: Colors.purple,
    mapType: MapType.leisure,
    route: '',
  ),
  
  // Wellness map
  MapConfig(
    label: 'Bien-être',
    icon: 'spa',
    color: Colors.teal,
    mapType: MapType.wellness,
    route: '',
  ),
  
  // Friends map
  MapConfig(
    label: 'Amis',
    icon: 'people',
    color: Colors.blue,
    mapType: MapType.friends,
    route: '',
  ),
];

/// Obtenir l'index de la carte par type
int getMapIndexByType(MapType type) {
  for (int i = 0; i < MAP_CONFIGS.length; i++) {
    if (MAP_CONFIGS[i].mapType == type) {
      return i;
    }
  }
  return 0; // Par défaut, retourner la carte des restaurants
}

/// Obtenir la configuration de carte par type
MapConfig getMapConfigByType(MapType type) {
  for (var config in MAP_CONFIGS) {
    if (config.mapType == type) {
      return config;
    }
  }
  return MAP_CONFIGS[0]; // Par défaut, retourner la carte des restaurants
} 
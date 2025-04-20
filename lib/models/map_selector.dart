import 'package:flutter/material.dart';
import '../constants/colors.dart';

/// Types de cartes disponibles
enum MapType {
  restaurant,
  leisure,
  wellness,
  friends,
}

/// Configuration pour chaque type de carte
class MapConfig {
  final String label;
  final String icon;
  final Color color;
  final MapType mapType;
  final String route;
  final String? imageIcon;

  const MapConfig({
    required this.label,
    required this.icon,
    required this.color,
    required this.mapType,
    required this.route,
    this.imageIcon,
  });
}

/// Classe pour gérer la sélection de carte
class MapSelector {
  final int initialMapIndex;
  final Function(int) onMapChanged;
  final List<MapConfig> mapConfigs;

  MapSelector({
    this.initialMapIndex = 0,
    required this.onMapChanged,
    required this.mapConfigs,
  });

  /// Récupère le type de carte actuel
  MapType get currentMapType => mapConfigs[initialMapIndex].mapType;

  /// Récupère la configuration de carte actuelle
  MapConfig get currentConfig => mapConfigs[initialMapIndex];

  /// Récupère l'index pour un type de carte donné
  int getIndexForMapType(MapType type) {
    for (int i = 0; i < mapConfigs.length; i++) {
      if (mapConfigs[i].mapType == type) {
        return i;
      }
    }
    return 0; // Par défaut, retourne le premier index
  }
}

// Widget sélecteur de carte réutilisable
class MapSelectorWidget extends StatelessWidget {
  final int currentIndex;
  final int mapCount;
  final Function(String) onMapSelected;
  final List<String> mapTypes = ['restaurant', 'leisure', 'wellness', 'friends'];
  final List<IconData> mapIcons = [
    Icons.restaurant,
    Icons.theater_comedy,
    Icons.spa,
    Icons.people,
  ];
  final List<String> mapLabels = [
    'Restaurant',
    'Loisir',
    'Bien-être',
    'Amis',
  ];
  final List<Color> mapColors = [
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.blue,
  ];

  MapSelectorWidget({
    Key? key,
    required this.currentIndex,
    required this.mapCount,
    required this.onMapSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          mapCount,
          (index) => _buildMapItem(index),
        ),
      ),
    );
  }

  Widget _buildMapItem(int index) {
    final bool isSelected = index == currentIndex;
    final Color color = mapColors[index];
    final IconData icon = mapIcons[index];
    final String label = mapLabels[index];
    final String mapType = mapTypes[index];

    return GestureDetector(
      onTap: () => onMapSelected(mapType),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? color : Colors.grey,
              size: 20,
            ),
            if (isSelected) ...[
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
} 
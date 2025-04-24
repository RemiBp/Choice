import 'package:flutter/material.dart';

/// Widget permettant de sélectionner une carte différente
class MapSelector extends StatelessWidget {
  final int currentIndex;
  final int mapCount;
  final Function(String) onMapSelected;
  final List<String> mapTypes = ['restaurant', 'leisure', 'beautyPlace', 'friends'];
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

  MapSelector({
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        constraints: BoxConstraints(
          minWidth: isSelected ? 100 : 44,
        ),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
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
import 'package:flutter/material.dart';

class EmotionSelector extends StatelessWidget {
  final List<String> emotions;
  final List<String> selectedEmotions;
  final Function(String) onEmotionToggled;
  final Map<String, int>? emotionCounts; // Optional counts for showing popularity

  const EmotionSelector({
    Key? key,
    required this.emotions,
    required this.selectedEmotions,
    required this.onEmotionToggled,
    this.emotionCounts,
  }) : super(key: key);

  // Map des émotions aux icônes et aux couleurs
  static final Map<String, IconData> _emotionIcons = {
    'intense': Icons.bolt,
    'émouvant': Icons.favorite,
    'captivant': Icons.remove_red_eye,
    'enrichissant': Icons.lightbulb,
    'profond': Icons.psychology,
    'drôle': Icons.mood,
    'amusant': Icons.sentiment_very_satisfied,
    'divertissant': Icons.theater_comedy,
    'léger': Icons.air,
    'enjoué': Icons.celebration,
    'agréable': Icons.thumb_up,
    'intéressant': Icons.stars,
    'satisfaisant': Icons.sentiment_satisfied_alt,
    'relaxant': Icons.spa,
    'apaisant': Icons.self_improvement,
    'énergisant': Icons.flash_on,
    'revitalisant': Icons.battery_charging_full,
    'ressourçant': Icons.battery_full,
    'rajeunissant': Icons.auto_awesome,
  };

  static final Map<String, Color> _emotionColors = {
    'intense': Colors.redAccent,
    'émouvant': Colors.pinkAccent,
    'captivant': Colors.purpleAccent,
    'enrichissant': Colors.amber,
    'profond': Colors.indigo,
    'drôle': Colors.orangeAccent,
    'amusant': Colors.orange,
    'divertissant': Colors.lime,
    'léger': Colors.lightBlue,
    'enjoué': Colors.deepOrange,
    'agréable': Colors.teal,
    'intéressant': Colors.blue,
    'satisfaisant': Colors.green,
    'relaxant': Colors.lightBlue,
    'apaisant': Colors.cyan,
    'énergisant': Colors.deepOrange,
    'revitalisant': Colors.green,
    'ressourçant': Colors.teal,
    'rajeunissant': Colors.purple,
  };

  // Obtenir l'icône pour une émotion donnée
  IconData _getEmotionIcon(String emotion) {
    return _emotionIcons[emotion.toLowerCase()] ?? Icons.mood;
  }

  // Obtenir la couleur pour une émotion donnée
  Color _getEmotionColor(String emotion, BuildContext context) {
    return _emotionColors[emotion.toLowerCase()] ?? Theme.of(context).primaryColor;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sélectionnez vos ressentis',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Appuyez sur les émotions qui correspondent à votre expérience',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 12,
              children: emotions.map((emotion) {
                final isSelected = selectedEmotions.contains(emotion);
                final count = emotionCounts?[emotion] ?? 0;
                final isPopular = count >= 10;
                final color = _getEmotionColor(emotion, context);
                final icon = _getEmotionIcon(emotion);

                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => onEmotionToggled(emotion),
                    borderRadius: BorderRadius.circular(24),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? color
                            : (isPopular ? color.withOpacity(0.15) : Colors.grey[100]),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: color.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            icon,
                            size: 18,
                            color: isSelected ? Colors.white : color,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            emotion,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.black87,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          if (count > 0) ...[
                            const SizedBox(width: 6),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.white.withOpacity(0.3)
                                    : color.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                count.toString(),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isSelected ? Colors.white : color,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                          if (isPopular && !isSelected) ...[
                            const SizedBox(width: 4),
                            Icon(
                              Icons.trending_up,
                              size: 14,
                              color: color,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            if (selectedEmotions.isNotEmpty) ...[
              const SizedBox(height: 20),
              Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    '${selectedEmotions.length} ${selectedEmotions.length > 1 ? 'émotions sélectionnées' : 'émotion sélectionnée'}',
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A widget that shows a single emotion chip with optional count and popularity indicator
class EmotionChip extends StatelessWidget {
  final String emotion;
  final bool isSelected;
  final int count;
  final VoidCallback onTap;
  final IconData icon;
  final Color color;

  const EmotionChip({
    Key? key,
    required this.emotion,
    required this.isSelected,
    required this.count,
    required this.onTap,
    required this.icon,
    required this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isPopular = count >= 10;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? color
                : (isPopular ? color.withOpacity(0.15) : Colors.grey[100]),
            borderRadius: BorderRadius.circular(20),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: color.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : color,
              ),
              const SizedBox(width: 6),
              Text(
                emotion,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black87,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withOpacity(0.3)
                        : color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    count.toString(),
                    style: TextStyle(
                      fontSize: 12,
                      color: isSelected ? Colors.white : color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
              if (isPopular && !isSelected) ...[
                const SizedBox(width: 4),
                Icon(
                  Icons.trending_up,
                  size: 14,
                  color: color,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
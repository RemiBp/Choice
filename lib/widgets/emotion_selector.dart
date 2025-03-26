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

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: emotions.map((emotion) {
        final isSelected = selectedEmotions.contains(emotion);
        final count = emotionCounts?[emotion] ?? 0;
        final isPopular = count >= 10;

        return InkWell(
          onTap: () => onEmotionToggled(emotion),
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? Theme.of(context).primaryColor
                  : (isPopular
                      ? Theme.of(context).primaryColor.withOpacity(0.1)
                      : Colors.grey[100]),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? Theme.of(context).primaryColor
                    : (isPopular
                        ? Theme.of(context).primaryColor
                        : Colors.grey[300]!),
                width: isSelected || isPopular ? 2 : 1,
              ),
              boxShadow: isSelected || isPopular
                  ? [
                      BoxShadow(
                        color: Theme.of(context).primaryColor.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Emotion text
                Text(
                  emotion,
                  style: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : (isPopular
                            ? Theme.of(context).primaryColor
                            : Colors.grey[800]),
                    fontWeight: isSelected || isPopular
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
                // Show count if available and greater than 0
                if (count > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.white.withOpacity(0.2)
                          : Theme.of(context).primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      count.toString(),
                      style: TextStyle(
                        fontSize: 12,
                        color: isSelected
                            ? Colors.white
                            : Theme.of(context).primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
                // Popular indicator
                if (isPopular && !isSelected) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.trending_up,
                    size: 16,
                    color: Theme.of(context).primaryColor,
                  ),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// A widget that shows a single emotion chip with optional count and popularity indicator
class EmotionChip extends StatelessWidget {
  final String emotion;
  final bool isSelected;
  final int count;
  final VoidCallback onTap;

  const EmotionChip({
    Key? key,
    required this.emotion,
    required this.isSelected,
    required this.count,
    required this.onTap,
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
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context).primaryColor
                : (isPopular
                    ? Theme.of(context).primaryColor.withOpacity(0.1)
                    : Colors.grey[100]),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? Theme.of(context).primaryColor
                  : (isPopular
                      ? Theme.of(context).primaryColor
                      : Colors.grey[300]!),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                emotion,
                style: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : (isPopular
                          ? Theme.of(context).primaryColor
                          : Colors.grey[800]),
                  fontWeight:
                      isSelected || isPopular ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withOpacity(0.2)
                        : Theme.of(context).primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    count.toString(),
                    style: TextStyle(
                      fontSize: 12,
                      color: isSelected
                          ? Colors.white
                          : Theme.of(context).primaryColor,
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
                  color: Theme.of(context).primaryColor,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
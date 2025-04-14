import 'package:flutter/material.dart';

/// Widget représentant une section de filtres avec titre et contenu
class FilterSection extends StatelessWidget {
  final String title;
  final Widget child;
  final VoidCallback? onTap;

  const FilterSection({
    super.key,
    required this.title,
    required this.child,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                if (onTap != null)
                  IconButton(
                    icon: const Icon(Icons.info_outline, color: Colors.white70),
                    onPressed: onTap,
                    tooltip: 'Plus d\'informations',
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: child,
          ),
        ],
      ),
    );
  }
} 
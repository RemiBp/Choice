import 'package:flutter/material.dart';

/// Bouton flottant pour activer/désactiver les filtres
class FloatingFilterButton extends StatelessWidget {
  final bool isActive;
  final VoidCallback onTap;
  final String label;
  final Color? activeColor;
  final Color? inactiveColor;
  
  const FloatingFilterButton({
    super.key,
    required this.isActive,
    required this.onTap,
    required this.label,
    this.activeColor,
    this.inactiveColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final buttonColor = isActive
        ? activeColor ?? theme.primaryColor
        : inactiveColor ?? Colors.grey[200];
    final textColor = isActive ? Colors.white : Colors.black87;
    
    return Positioned(
      right: 16,
      top: MediaQuery.of(context).padding.top + 16,
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(20),
        color: buttonColor,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isActive ? Icons.filter_list : Icons.filter_list_outlined,
                  color: textColor,
                  size: 20,
                ),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                if (isActive) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Actif',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
} 
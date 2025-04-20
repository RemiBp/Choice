import 'package:flutter/material.dart';
import '../constants/colors.dart';

/// Widget pour le panneau de filtres
class FilterPanel extends StatelessWidget {
  final bool isVisible;
  final VoidCallback onClose;
  final VoidCallback onReset;
  final VoidCallback onApply;
  final List<FilterSection> filterSections;

  const FilterPanel({
    Key? key,
    required this.isVisible,
    required this.onClose,
    required this.onReset,
    required this.onApply,
    required this.filterSections,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox.shrink();

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with close button
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Filtres',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: onClose,
                  ),
                ],
              ),
            ),

            // Filter sections
            Flexible(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: filterSections,
                  ),
                ),
              ),
            ),

            // Action buttons
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  OutlinedButton(
                    onPressed: onReset,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.grey[300]!),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: const Text('Réinitialiser'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: onApply,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    ),
                    child: const Text('Appliquer'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FilterSection extends StatelessWidget {
  final String title;
  final Widget child;
  final bool isCollapsible;
  final bool isInitiallyExpanded;

  const FilterSection({
    Key? key,
    required this.title,
    required this.child,
    this.isCollapsible = false,
    this.isInitiallyExpanded = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (isCollapsible) {
      return ExpansionTile(
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        initiallyExpanded: isInitiallyExpanded,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: child,
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: child,
        ),
        const Divider(),
      ],
    );
  }
} 
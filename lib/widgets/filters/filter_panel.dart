import 'package:flutter/material.dart';

class FilterPanel extends StatelessWidget {
  final bool isVisible;
  final VoidCallback onClose;
  final VoidCallback onReset;
  final VoidCallback onApply;
  final List<Widget> filterSections;

  const FilterPanel({
    Key? key,
    required this.isVisible,
    required this.onClose,
    required this.onReset,
    required this.filterSections,
    required this.onApply,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!isVisible) {
      return const SizedBox.shrink();
    }

    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // En-tête
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
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
          
          // Contenu des filtres (scrollable)
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: filterSections,
              ),
            ),
          ),
          
          // Boutons d'actions
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                OutlinedButton(
                  onPressed: onReset,
                  child: const Text('Réinitialiser'),
                ),
                ElevatedButton(
                  onPressed: onApply,
                  child: const Text('Appliquer'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 
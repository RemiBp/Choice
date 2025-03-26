import 'package:flutter/material.dart';

class FilterPanel extends StatelessWidget {
  final bool isVisible;
  final VoidCallback onClose;
  final VoidCallback onReset;
  final List<Widget> filterSections;

  const FilterPanel({
    Key? key,
    required this.isVisible,
    required this.onClose,
    required this.onReset,
    required this.filterSections,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      top: isVisible ? 0 : MediaQuery.of(context).size.height,
      left: 0,
      right: 0,
      bottom: 0,
      child: Material(
        color: Colors.white,
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Text(
                      'Filtres',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: onReset,
                      child: const Text('Réinitialiser'),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: onClose,
                    ),
                  ],
                ),
              ),
              
              // Filter sections
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: filterSections,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 
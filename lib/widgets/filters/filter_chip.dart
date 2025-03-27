import 'package:flutter/material.dart';

class CustomFilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onSelected;
  final Color? selectedColor;

  const CustomFilterChip({
    Key? key,
    required this.label,
    required this.isSelected,
    required this.onSelected,
    this.selectedColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (bool selected) {
        onSelected();
      },
      selectedColor: selectedColor ?? Theme.of(context).primaryColor.withOpacity(0.2),
      checkmarkColor: selectedColor ?? Theme.of(context).primaryColor,
      labelStyle: TextStyle(
        color: isSelected ? selectedColor ?? Theme.of(context).primaryColor : null,
      ),
    );
  }
} 
import 'package:flutter/material.dart';

/// Un widget FilterChip personnalisé avec un style cohérent pour l'application
class CustomFilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Function(bool) onToggle;
  final Color? backgroundColor;
  final Color? selectedColor;
  final EdgeInsetsGeometry? padding;

  const CustomFilterChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onToggle,
    this.backgroundColor,
    this.selectedColor,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      child: FilterChip(
        label: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        selected: isSelected,
        onSelected: onToggle,
        backgroundColor: backgroundColor ?? Colors.grey[200],
        selectedColor: selectedColor ?? Theme.of(context).primaryColor,
        checkmarkColor: Colors.white,
        padding: padding ?? const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        labelPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: isSelected
              ? BorderSide(color: selectedColor ?? Theme.of(context).primaryColor)
              : BorderSide.none,
        ),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        elevation: 0,
        pressElevation: 2,
      ),
    );
  }
} 
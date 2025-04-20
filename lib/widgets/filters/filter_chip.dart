import 'package:flutter/material.dart';

class FilterChip extends StatelessWidget {
  final Widget label;
  final bool selected;
  final Function(bool) onSelected;
  final Color? selectedColor;
  final Color? backgroundColor;
  final Color? checkmarkColor;
  final EdgeInsets? padding;
  final double? elevation;
  final double? pressElevation;
  final ShapeBorder? shape;
  final MaterialStateProperty<Color?>? fillColor;

  const FilterChip({
    Key? key,
    required this.label,
    required this.selected,
    required this.onSelected,
    this.selectedColor,
    this.backgroundColor,
    this.checkmarkColor,
    this.padding,
    this.elevation,
    this.pressElevation,
    this.shape,
    this.fillColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Si fillColor est fourni, l'utiliser pour déterminer la couleur
    final effectiveBackgroundColor = selected
        ? selectedColor ?? Theme.of(context).colorScheme.primary
        : backgroundColor ?? Theme.of(context).colorScheme.surface;

    final effectiveShape = shape ??
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: selected
                ? selectedColor ?? Theme.of(context).colorScheme.primary
                : Colors.grey.shade300,
            width: 1,
          ),
        );

    return Material(
      color: fillColor != null 
            ? null  // We'll handle color via InkWell if fillColor is provided
            : effectiveBackgroundColor,
      elevation: selected ? (elevation ?? 0) + 1 : elevation ?? 0,
      shape: effectiveShape,
      child: InkWell(
        onTap: () => onSelected(!selected),
        customBorder: effectiveShape,
        child: Padding(
          padding: padding ?? const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) 
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Icon(
                    Icons.check,
                    size: 16,
                    color: checkmarkColor ?? Colors.white,
                  ),
                ),
              DefaultTextStyle(
                style: TextStyle(
                  color: selected ? Colors.white : Colors.black87,
                  fontWeight: selected ? FontWeight.w500 : FontWeight.normal,
                ),
                child: label,
              ),
            ],
          ),
        ),
      ),
    );
  }
} 
import 'package:flutter/material.dart';

/// Widget représentant une option de filtre sous forme de puce interactive
class FilterChip extends StatelessWidget {
  final Widget label;
  final bool selected;
  final Function(bool) onSelected;
  final Widget? avatar;
  final Color? selectedColor;
  final Color? backgroundColor;
  final EdgeInsetsGeometry? padding;
  final OutlinedBorder? shape;
  final Color? checkmarkColor;
  final double elevation;
  final Color? shadowColor;

  const FilterChip({
    Key? key,
    required this.label,
    required this.selected,
    required this.onSelected,
    this.avatar,
    this.selectedColor,
    this.backgroundColor,
    this.padding,
    this.shape,
    this.checkmarkColor,
    this.elevation = 0,
    this.shadowColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Material(
      elevation: elevation,
      shadowColor: shadowColor,
      shape: shape ?? StadiumBorder(
        side: BorderSide(
          color: selected ? theme.primaryColor : Colors.grey.shade300,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      color: selected 
          ? selectedColor ?? theme.primaryColor.withOpacity(0.1)
          : backgroundColor ?? Colors.white,
      child: InkWell(
        onTap: () => onSelected(!selected),
        child: Padding(
          padding: padding ?? const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (avatar != null) ...[
                avatar!,
                const SizedBox(width: 6),
              ],
              label,
              if (selected) ...[
                const SizedBox(width: 6),
                Icon(
                  Icons.check,
                  size: 16,
                  color: checkmarkColor ?? theme.primaryColor,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
} 
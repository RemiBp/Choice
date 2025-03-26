import 'package:flutter/material.dart';

class FilterChipItem extends StatelessWidget {
  final String text;
  final Function()? onTap;
  final bool? isActive;
  final Color? activeColor;
  final bool showCheckmark;
  final EdgeInsets padding;
  final TextStyle? textStyle;

  const FilterChipItem({
    Key? key,
    required this.text,
    this.onTap,
    this.isActive = false,
    this.activeColor,
    this.showCheckmark = true,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    this.textStyle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).primaryColor;
    final Color chipColor = isActive == true 
      ? (activeColor ?? primaryColor) 
      : Theme.of(context).cardColor;
    final Color textColor = isActive == true 
      ? Colors.white 
      : Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: padding,
        decoration: BoxDecoration(
          color: chipColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive == true 
              ? (activeColor ?? primaryColor) 
              : Theme.of(context).dividerColor,
            width: 1.0,
          ),
          boxShadow: isActive == true
              ? [
                  BoxShadow(
                    color: (activeColor ?? primaryColor).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isActive == true && showCheckmark)
              Padding(
                padding: const EdgeInsets.only(right: 4.0),
                child: Icon(
                  Icons.check,
                  size: 16,
                  color: Colors.white,
                ),
              ),
            Text(
              text,
              style: textStyle?.copyWith(color: textColor) ?? 
                TextStyle(
                  color: textColor,
                  fontWeight: isActive == true ? FontWeight.bold : FontWeight.normal,
                ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
} 
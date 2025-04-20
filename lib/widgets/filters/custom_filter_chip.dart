import 'package:flutter/material.dart';

class CustomFilterChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Function(bool) onToggle;
  final bool isSelected;
  final Color? selectedColor;
  final Widget? avatar;

  const CustomFilterChip({
    Key? key,
    required this.label,
    this.icon,
    required this.onToggle,
    required this.isSelected,
    this.selectedColor,
    this.avatar,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 16,
                color: isSelected
                    ? (selectedColor ?? Theme.of(context).primaryColor)
                    : Colors.grey,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? (selectedColor ?? Theme.of(context).primaryColor)
                    : Colors.grey[700],
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
        avatar: avatar,
        backgroundColor: Colors.white,
        shadowColor: isSelected 
            ? (selectedColor ?? Theme.of(context).primaryColor).withOpacity(0.3) 
            : Colors.transparent,
        elevation: isSelected ? 2 : 0,
        onPressed: () => onToggle(!isSelected),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isSelected
                ? (selectedColor ?? Theme.of(context).primaryColor)
                : Colors.grey[300]!,
            width: 1,
          ),
        ),
      ),
    );
  }
} 
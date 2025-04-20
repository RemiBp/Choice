import 'package:flutter/material.dart';

class FloatingFilterButton extends StatelessWidget {
  final bool isActive;
  final VoidCallback onTap;
  final String label;
  final Color? activeColor;
  final Color? inactiveColor;

  const FloatingFilterButton({
    Key? key,
    required this.isActive,
    required this.onTap,
    required this.label,
    this.activeColor,
    this.inactiveColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 16,
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.filter_list,
                  color: isActive
                      ? (activeColor ?? Theme.of(context).primaryColor)
                      : (inactiveColor ?? Colors.grey),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: isActive
                        ? (activeColor ?? Theme.of(context).primaryColor)
                        : (inactiveColor ?? Colors.grey),
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 
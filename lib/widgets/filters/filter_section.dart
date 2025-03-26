import 'package:flutter/material.dart';

class FilterSection extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final Widget? trailing;

  const FilterSection({
    Key? key,
    required this.title,
    required this.children,
    this.trailing,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (trailing != null) ...[
                const Spacer(),
                trailing!,
              ],
            ],
          ),
        ),
        ...children,
        const Divider(height: 32),
      ],
    );
  }
} 
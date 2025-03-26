import 'package:flutter/material.dart';
import 'filter_chip.dart';

class FilterChipGroup extends StatelessWidget {
  final String title;
  final List<FilterChipItem> filters;
  final VoidCallback? onReset;

  const FilterChipGroup({
    Key? key,
    required this.title,
    required this.filters,
    this.onReset,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              if (onReset != null)
                GestureDetector(
                  onTap: onReset,
                  child: Text(
                    'Réinitialiser',
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: filters,
          ),
        ),
      ],
    );
  }
} 
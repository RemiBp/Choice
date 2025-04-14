import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../constants/styles.dart';

/// Widget de filtre sous forme de puces (chips) sélectionnables
class FilterChips extends StatelessWidget {
  final List<String> options;
  final List<String> selectedOptions;
  final Function(List<String>) onSelectionChanged;
  final Color? selectedColor;
  final Color? backgroundColor;
  final bool multiSelect;
  final String? title;
  final double? height;
  final bool scrollable;

  const FilterChips({
    Key? key,
    required this.options,
    required this.selectedOptions,
    required this.onSelectionChanged,
    this.selectedColor,
    this.backgroundColor,
    this.multiSelect = true,
    this.title,
    this.height,
    this.scrollable = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Color chipSelectedColor = selectedColor ?? AppColors.primary;
    final Color chipBackgroundColor = backgroundColor ?? Colors.grey.shade200;

    final chips = options.map((option) {
      final bool isSelected = selectedOptions.contains(option);
      
      return FilterChip(
        label: Text(
          option,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
          ),
        ),
        selected: isSelected,
        onSelected: (bool selected) {
          List<String> newSelection = List.from(selectedOptions);
          
          if (selected) {
            // Si on sélectionne une nouvelle option
            if (!multiSelect) {
              // En mode single select, on remplace la sélection
              newSelection = [option];
            } else {
              // En mode multi select, on ajoute à la sélection
              newSelection.add(option);
            }
          } else {
            // Si on désélectionne une option
            newSelection.remove(option);
          }
          
          onSelectionChanged(newSelection);
        },
        backgroundColor: chipBackgroundColor,
        selectedColor: chipSelectedColor,
        checkmarkColor: Colors.white,
        elevation: 0,
        pressElevation: 2,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isSelected ? chipSelectedColor : Colors.grey.shade300,
            width: 1,
          ),
        ),
      );
    }).toList();

    Widget chipWidget;
    if (scrollable) {
      chipWidget = SizedBox(
        height: height ?? 50.0,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            for (var chip in chips)
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: chip,
              ),
          ],
        ),
      );
    } else {
      chipWidget = Wrap(
        spacing: 8.0,
        runSpacing: 8.0,
        children: chips,
      );
    }

    if (title != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title!,
            style: AppStyles.subtitle1,
          ),
          const SizedBox(height: 8.0),
          chipWidget,
        ],
      );
    }

    return chipWidget;
  }
}

/// Widget de filtre avec une seule sélection possible
class SingleSelectFilterChips extends StatelessWidget {
  final List<String> options;
  final String? selectedOption;
  final Function(String?) onSelectionChanged;
  final Color? selectedColor;
  final Color? backgroundColor;
  final String? title;
  final double? height;
  final bool scrollable;

  const SingleSelectFilterChips({
    Key? key,
    required this.options,
    required this.selectedOption,
    required this.onSelectionChanged,
    this.selectedColor,
    this.backgroundColor,
    this.title,
    this.height,
    this.scrollable = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FilterChips(
      options: options,
      selectedOptions: selectedOption != null ? [selectedOption!] : [],
      onSelectionChanged: (newSelection) {
        // S'il n'y a aucune sélection ou plus d'une sélection (ce qui ne devrait pas arriver),
        // on considère qu'il n'y a pas de sélection
        if (newSelection.isEmpty) {
          onSelectionChanged(null);
        } else {
          onSelectionChanged(newSelection.first);
        }
      },
      selectedColor: selectedColor,
      backgroundColor: backgroundColor,
      multiSelect: false,
      title: title,
      height: height,
      scrollable: scrollable,
    );
  }
} 
import 'package:flutter/material.dart';

class FilterPanel extends StatelessWidget {
  final bool isVisible;
  final VoidCallback onClose;
  final VoidCallback onReset;
  final List<Widget> filterSections;
  final String title;
  final Color primaryColor;

  const FilterPanel({
    Key? key,
    required this.isVisible,
    required this.onClose,
    required this.onReset,
    required this.filterSections,
    this.title = "Filtres",
    this.primaryColor = Colors.blue,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: isVisible ? screenWidth * 0.85 : 0,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(2, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: const BorderRadius.only(topRight: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  // Close button
                  Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: onClose,
                      tooltip: "Fermer les filtres",
                    ),
                  ),
                  // Title
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.filter_list, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Reset button
                  Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: TextButton.icon(
                      icon: const Icon(Icons.refresh, color: Colors.white, size: 16),
                      label: const Text(
                        "Réinitialiser",
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                      onPressed: onReset,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        minimumSize: Size.zero,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Filter content
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: filterSections,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FilterSection extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final Widget? trailing;
  final EdgeInsetsGeometry? contentPadding;

  const FilterSection({
    Key? key,
    required this.title,
    required this.children,
    this.trailing,
    this.contentPadding,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            if (trailing != null) trailing!,
          ],
        ),
        const SizedBox(height: 12),
        Padding(
          padding: contentPadding ?? EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class FilterChipGroup extends StatelessWidget {
  final List<Widget> chips;
  final double spacing;
  final double runSpacing;

  const FilterChipGroup({
    Key? key,
    required this.chips,
    this.spacing = 8,
    this.runSpacing = 8,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: spacing,
      runSpacing: runSpacing,
      children: chips,
    );
  }
}

class FilterToggleCard extends StatelessWidget {
  final bool isSelected;
  final VoidCallback onTap;
  final IconData icon;
  final String title;
  final String subtitle;
  final Color selectedColor;
  final Color unselectedColor;

  const FilterToggleCard({
    Key? key,
    required this.isSelected,
    required this.onTap,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.selectedColor = Colors.blue,
    this.unselectedColor = Colors.grey,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected 
            ? selectedColor.withOpacity(0.1) 
            : unselectedColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected 
              ? selectedColor 
              : unselectedColor.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? selectedColor : unselectedColor,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isSelected ? selectedColor : unselectedColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
} 
import 'package:flutter/material.dart';
import '../models/map_filter.dart';

/// Panneau de filtres pour les cartes
class MapFilterPanel extends StatefulWidget {
  final String title;
  final Color themeColor;
  final List<FilterSection> sections;
  final VoidCallback onClose;
  final Function(List<FilterSection>) onApply;
  final VoidCallback onReset;

  const MapFilterPanel({
    Key? key,
    required this.title,
    required this.themeColor,
    required this.sections,
    required this.onClose,
    required this.onApply,
    required this.onReset,
  }) : super(key: key);

  @override
  _MapFilterPanelState createState() => _MapFilterPanelState();
}

class _MapFilterPanelState extends State<MapFilterPanel> {
  late List<FilterSection> _sections;

  @override
  void initState() {
    super.initState();
    // Copier les sections pour éviter de modifier les originales
    _sections = List.from(widget.sections);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête du panneau
          Row(
            children: [
              Icon(Icons.filter_list, color: widget.themeColor),
              const SizedBox(width: 8),
              Text(
                widget.title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: widget.themeColor,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: widget.onClose,
              ),
            ],
          ),
          const Divider(),
          
          // Liste des sections de filtres avec défilement
          Expanded(
            child: ListView.builder(
              itemCount: _sections.length,
              itemBuilder: (context, index) {
                final section = _sections[index];
                
                return _buildFilterSection(section, index);
              },
            ),
          ),
          
          // Boutons d'action en bas du panneau
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              OutlinedButton(
                onPressed: () {
                  setState(() {
                    _sections = List.from(DefaultFilters.getFiltersByType(widget.title));
                  });
                  widget.onReset();
                },
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: widget.themeColor),
                  foregroundColor: widget.themeColor,
                ),
                child: const Text('Réinitialiser'),
              ),
              ElevatedButton(
                onPressed: () => widget.onApply(_sections),
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.themeColor,
                ),
                child: const Text('Appliquer'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection(FilterSection section, int sectionIndex) {
    switch (section.type) {
      case FilterType.range:
        return _buildSliderSection(section, sectionIndex);
      case FilterType.multiSelect:
        return _buildChipsSection(section, sectionIndex);
      case FilterType.singleSelect:
        return _buildCheckboxSection(section, sectionIndex);
      case FilterType.search:
        return _buildDropdownSection(section, sectionIndex);
      case FilterType.toggle:
        return _buildToggleSection(section, sectionIndex);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildSliderSection(FilterSection section, int sectionIndex) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(section.icon, color: widget.themeColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  section.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  section.type == FilterType.range && 
                      section.title.contains('Rayon')
                      ? '${(section.value / 1000).toStringAsFixed(1)} km'
                      : section.value.toStringAsFixed(1),
                  style: TextStyle(
                    color: widget.themeColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Slider(
              value: section.value.toDouble(),
              min: section.min ?? 0,
              max: section.max ?? 10,
              divisions: ((section.max ?? 10) - (section.min ?? 0)).round(),
              label: section.title.contains('Rayon')
                  ? '${(section.value / 1000).toStringAsFixed(1)} km'
                  : section.value.toStringAsFixed(1),
              activeColor: widget.themeColor,
              onChanged: (value) {
                setState(() {
                  _sections[sectionIndex] = section.copyWith(value: value);
                });
              },
            ),
            if (section.min != null && section.max != null)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    section.title.contains('Rayon')
                        ? '${(section.min! / 1000).toStringAsFixed(1)} km'
                        : section.min!.toStringAsFixed(1),
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                  Text(
                    section.title.contains('Rayon')
                        ? '${(section.max! / 1000).toStringAsFixed(1)} km'
                        : section.max!.toStringAsFixed(1),
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildChipsSection(FilterSection section, int sectionIndex) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(section.icon, color: widget.themeColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  section.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '${section.selectedValues.length} sélectionné${section.selectedValues.length > 1 ? 's' : ''}',
                  style: TextStyle(
                    color: widget.themeColor,
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: section.options.map((option) {
                final bool isSelected = section.selectedValues.contains(option.value);
                
                return FilterChip(
                  label: Text(option.label),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      final List<String> newSelectedValues = List.from(section.selectedValues);
                      if (selected) {
                        newSelectedValues.add(option.value);
                      } else {
                        newSelectedValues.remove(option.value);
                      }
                      _sections[sectionIndex] = section.copyWith(
                        selectedValues: newSelectedValues
                      );
                    });
                  },
                  selectedColor: option.color ?? widget.themeColor.withOpacity(0.2),
                  checkmarkColor: widget.themeColor,
                  backgroundColor: Colors.grey.shade200,
                  labelStyle: TextStyle(
                    color: isSelected ? widget.themeColor : Colors.black87,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckboxSection(FilterSection section, int sectionIndex) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(section.icon, color: widget.themeColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  section.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...section.options.map((option) {
              final bool isSelected = section.selectedValues.contains(option.value);
              
              return CheckboxListTile(
                title: Text(option.label),
                value: isSelected,
                activeColor: widget.themeColor,
                onChanged: (selected) {
                  if (selected == null) return;
                  
                  setState(() {
                    final List<String> newSelectedValues = List.from(section.selectedValues);
                    if (selected) {
                      newSelectedValues.add(option.value);
                    } else {
                      newSelectedValues.remove(option.value);
                    }
                    _sections[sectionIndex] = section.copyWith(selectedValues: newSelectedValues);
                  });
                },
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownSection(FilterSection section, int sectionIndex) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(section.icon, color: widget.themeColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  section.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: section.value as String?,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
              items: section.options.map((option) {
                return DropdownMenuItem<String>(
                  value: option.value,
                  child: Text(option.label),
                );
              }).toList(),
              onChanged: (value) {
                if (value == null) return;
                
                setState(() {
                  _sections[sectionIndex] = section.copyWith(
                    value: value
                  );
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleSection(FilterSection section, int sectionIndex) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(section.icon, color: widget.themeColor, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                section.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Switch(
              value: section.value as bool? ?? false,
              activeColor: widget.themeColor,
              onChanged: (value) {
                setState(() {
                  _sections[sectionIndex] = section.copyWith(
                    value: value
                  );
                });
              },
            ),
          ],
        ),
      ),
    );
  }
} 
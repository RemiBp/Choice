import 'package:flutter/material.dart';

class FilteredItemsList extends StatelessWidget {
  final Map<String, dynamic> producer;
  final String selectedCarbon;
  final String selectedNutriScore;
  final double selectedMaxCalories;
  final bool hasActivePromotion;
  final double promotionDiscount;

  const FilteredItemsList({
    Key? key,
    required this.producer,
    required this.selectedCarbon,
    required this.selectedNutriScore,
    required this.selectedMaxCalories,
    required this.hasActivePromotion,
    required this.promotionDiscount,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Vérifier et sécuriser l'accès aux données structurées
    final prod = producer;
    if (!prod.containsKey('structured_data') || prod['structured_data'] == null) {
      prod['structured_data'] = {'Items Indépendants': []};
    } else if (prod['structured_data'] is! Map) {
      prod['structured_data'] = {'Items Indépendants': []};
    }
    final structuredData = prod['structured_data'] as Map<String, dynamic>;
    final items = structuredData['Items Indépendants'];

    if (items == null || !(items is List) || items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.no_food, size: 60, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Aucun item disponible',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    // Filtrer et traiter les items de manière sécurisée
    final filteredItems = <String, List<Map<String, dynamic>>>{};
    for (var category in items) {
      if (category is! Map<String, dynamic>) continue;
      final categoryName = category['catégorie']?.toString().trim() ?? 'Autres';
      final categoryItems = category['items'];
      if (categoryItems == null || !(categoryItems is List) || categoryItems.isEmpty) continue;
      for (var item in categoryItems) {
        if (item is! Map<String, dynamic>) continue;
        double carbonFootprint = 0;
        String nutriScore = 'N/A';
        double calories = 0;
        try {
          final carbonValue = item['carbon_footprint'];
          if (carbonValue != null) {
            if (carbonValue is num) {
              carbonFootprint = carbonValue.toDouble();
            } else {
              carbonFootprint = double.tryParse(carbonValue.toString()) ?? 0;
            }
          }
          nutriScore = item['nutri_score']?.toString() ?? 'N/A';
          if (item['nutrition'] is Map<String, dynamic>) {
            final nutritionData = item['nutrition'] as Map<String, dynamic>;
            final caloriesValue = nutritionData['calories'];
            if (caloriesValue != null) {
              if (caloriesValue is num) {
                calories = caloriesValue.toDouble();
              } else {
                calories = double.tryParse(caloriesValue.toString()) ?? 0;
              }
            }
          } else if (item['calories'] != null) {
            final caloriesValue = item['calories'];
            if (caloriesValue is num) {
              calories = caloriesValue.toDouble();
            } else {
              calories = double.tryParse(caloriesValue.toString()) ?? 0;
            }
          }
        } catch (e) {}
        if (carbonFootprint <= (selectedCarbon == "<3kg" ? 3 : 5) && 
            (nutriScore.compareTo(selectedNutriScore == "A-B" ? 'C' : 'D') <= 0) && 
            calories <= selectedMaxCalories) {
          filteredItems.putIfAbsent(categoryName, () => []);
          filteredItems[categoryName]!.add(item);
        }
      }
    }

    if (filteredItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.filter_alt_off, size: 60, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Aucun item ne correspond aux critères',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.tune),
              label: const Text('Modifier les filtres'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orangeAccent,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Utilisez les filtres en haut de la page')),
                );
              },
            ),
          ],
        ),
      );
    }

    int catIndex = 0;
    // --- FIX: Changed from ListView.separated to Column --- 
    // The outer CustomScrollView handles scrolling.
    final categoryWidgets = <Widget>[];
    filteredItems.forEach((categoryName, categoryItemsList) {
      final isFirst = catIndex == 0;
      categoryWidgets.add(
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: isFirst, // Expand the first category by default
            tilePadding: const EdgeInsets.symmetric(horizontal: 16.0), // Adjust padding
            title: Row(
              children: [
                Icon(Icons.category_outlined, size: 20, color: Theme.of(context).colorScheme.primary), // Use theme color
                const SizedBox(width: 12),
                Expanded( // Allow category name to take space
                  child: Text(
                    categoryName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          // color: Colors.black87,
                        ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${categoryItemsList.length}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
            childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8), // Padding for the children ListTiles
            children: categoryItemsList.map<Widget>((item) {
              // Ensure item is a Map
              final itemData = item as Map<String, dynamic>; 
              final originalPrice = double.tryParse(itemData['prix']?.toString() ?? '0') ?? 0;
              final discountedPrice = hasActivePromotion
                  ? originalPrice * (1 - promotionDiscount / 100)
                  : null;
              final itemName = itemData['nom']?.toString() ?? 'Nom non spécifié';
              final itemDesc = itemData['description']?.toString();
              final itemRating = itemData['note']; // Keep original type for rating widget
              final carbonFootprint = itemData['carbon_footprint']?.toString();
              final nutriScore = itemData['nutri_score']?.toString();
              // Safe access to nested calories
              final caloriesData = itemData['nutrition']?['calories'] ?? itemData['calories'];
              final calories = caloriesData?.toString();

              // Use ListTile for each item
              return ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                title: Text(
                  itemName,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (itemDesc != null && itemDesc.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          itemDesc,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    // Nutritional Info Row (better layout with Wrap)
                    Padding(
                      padding: const EdgeInsets.only(top: 6.0),
                      child: Wrap(
                        spacing: 12.0, // Horizontal space between chips
                        runSpacing: 4.0, // Vertical space between lines
                        children: [
                          if (carbonFootprint != null && carbonFootprint.isNotEmpty)
                            _buildInfoChip(context, Icons.eco, '$carbonFootprint kg CO2e', Colors.green),
                          if (nutriScore != null && nutriScore.isNotEmpty && nutriScore != 'N/A')
                            _buildInfoChip(context, Icons.health_and_safety, 'Nutri: $nutriScore', Colors.blue),
                          if (calories != null && calories.isNotEmpty && calories != 'N/A')
                            _buildInfoChip(context, Icons.local_fire_department, '$calories cal', Colors.orange),
                        ],
                      ),
                    ),
                  ],
                ),
                trailing: originalPrice > 0
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (hasActivePromotion && discountedPrice != null)
                          Text(
                            '${originalPrice.toStringAsFixed(2)} €',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  decoration: TextDecoration.lineThrough,
                                  color: Colors.grey,
                                ),
                          ),
                        Text(
                          hasActivePromotion && discountedPrice != null
                              ? '${discountedPrice.toStringAsFixed(2)} €'
                              : '${originalPrice.toStringAsFixed(2)} €',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: hasActivePromotion ? Colors.redAccent : Theme.of(context).colorScheme.onSurface,
                              ),
                        ),
                        if (hasActivePromotion)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.redAccent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '-${promotionDiscount.toStringAsFixed(0)}%',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),
                      ],
                    )
                  : null,
              );
            }).toList(),
          ),
        ),
      );
      // Add a divider between categories if not the last one
      if (catIndex < filteredItems.length - 1) {
        categoryWidgets.add(const Divider(height: 16, indent: 16, endIndent: 16));
      }
      catIndex++;
    });

    return Column(
      children: categoryWidgets,
    );
    // --- END FIX ---
  }

  // Helper widget for nutritional info chips
  Widget _buildInfoChip(BuildContext context, IconData icon, String label, Color color) {
    return Chip(
      avatar: Icon(icon, size: 14, color: color),
      label: Text(label),
      labelStyle: TextStyle(fontSize: 11, color: Colors.black87),
      backgroundColor: color.withOpacity(0.1),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
      side: BorderSide.none,
    );
  }

  Widget _buildCompactRatingStars(dynamic rating) {
    double ratingValue = 0.0;
    if (rating is int) {
      ratingValue = rating.toDouble();
    } else if (rating is double) {
      ratingValue = rating;
    } else if (rating is String) {
      ratingValue = double.tryParse(rating) ?? 0.0;
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.star, color: Colors.amber, size: 16),
        const SizedBox(width: 2),
        Text(
          ratingValue.toStringAsFixed(1),
          style: const TextStyle(
            fontSize: 14, 
            fontWeight: FontWeight.bold, 
            color: Colors.amber,
          ),
        ),
      ],
    );
  }
} 
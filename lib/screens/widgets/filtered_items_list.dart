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
    return Container(
      margin: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.restaurant, color: Colors.green),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Plats Filtrés',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                Chip(
                  label: Text('Carbone: $selectedCarbon'),
                  avatar: const Icon(Icons.eco, size: 16, color: Colors.green),
                  backgroundColor: Colors.green.withOpacity(0.1),
                ),
                const SizedBox(width: 8),
                Chip(
                  label: Text('NutriScore: $selectedNutriScore'),
                  avatar: const Icon(Icons.health_and_safety, size: 16, color: Colors.blue),
                  backgroundColor: Colors.blue.withOpacity(0.1),
                ),
                const SizedBox(width: 8),
                Chip(
                  label: Text('Max: ${selectedMaxCalories.toInt()} cal'),
                  avatar: const Icon(Icons.local_fire_department, size: 16, color: Colors.orange),
                  backgroundColor: Colors.orange.withOpacity(0.1),
                ),
              ],
            ),
          ),
          ...filteredItems.entries.map((entry) {
            final categoryName = entry.key;
            final categoryItems = entry.value;
            final isFirst = catIndex == 0;
            catIndex++;
            return Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                initiallyExpanded: isFirst,
                title: Row(
                  children: [
                    const Icon(Icons.category, size: 18, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      categoryName,
                      style: const TextStyle(
                        fontSize: 16, 
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${categoryItems.length}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.black54,
                        ),
                      ),
                    ),
                  ],
                ),
                children: categoryItems.map<Widget>((item) {
                  final originalPrice = double.tryParse(item['prix']?.toString() ?? '0') ?? 0;
                  final discountedPrice = hasActivePromotion 
                      ? originalPrice * (1 - promotionDiscount / 100) 
                      : null;
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    elevation: 2,
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey[200]!),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            item['nom'] ?? 'Nom non spécifié',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        if (item['note'] != null)
                                          _buildCompactRatingStars(item['note']),
                                      ],
                                    ),
                                    if (item['description'] != null && item['description'].toString().isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          item['description'],
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[700],
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              if (originalPrice > 0)
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    if (hasActivePromotion && discountedPrice != null)
                                      Text(
                                        '${originalPrice.toStringAsFixed(2)} €',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          decoration: TextDecoration.lineThrough,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    Text(
                                      hasActivePromotion && discountedPrice != null
                                          ? '${discountedPrice.toStringAsFixed(2)} €'
                                          : '${originalPrice.toStringAsFixed(2)} €',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: hasActivePromotion ? Colors.red : Colors.black87,
                                      ),
                                    ),
                                    if (hasActivePromotion)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.red,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          '-${promotionDiscount.toStringAsFixed(0)}%',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Divider(height: 1),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.eco, size: 16, color: Colors.green),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${item['carbon_footprint']} kg',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.green,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  const Icon(Icons.health_and_safety, size: 16, color: Colors.blue),
                                  const SizedBox(width: 4),
                                  Text(
                                    'NutriScore: ${item['nutri_score'] ?? 'N/A'}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.blue,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  const Icon(Icons.local_fire_department, size: 16, color: Colors.orange),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${item['nutrition']?['calories'] ?? 'N/A'} cal',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.orange,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            );
          }).toList(),
        ],
      ),
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
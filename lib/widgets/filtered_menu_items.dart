import 'package:flutter/material.dart';

class FilteredMenuItems extends StatefulWidget {
  final Map<String, dynamic> producer;
  final String selectedCarbon;
  final String selectedNutriScore;
  final double selectedMaxCalories;
  final bool hasActivePromotion;
  final double promotionDiscount;

  const FilteredMenuItems({
    Key? key,
    required this.producer,
    required this.selectedCarbon,
    required this.selectedNutriScore,
    required this.selectedMaxCalories,
    required this.hasActivePromotion,
    required this.promotionDiscount,
  }) : super(key: key);

  @override
  State<FilteredMenuItems> createState() => _FilteredMenuItemsState();
}

class _FilteredMenuItemsState extends State<FilteredMenuItems> {
  final Map<String, List<Map<String, dynamic>>> _filteredItems = {};
  
  @override
  void initState() {
    super.initState();
    _filterItems();
  }
  
  @override
  void didUpdateWidget(FilteredMenuItems oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedCarbon != widget.selectedCarbon ||
        oldWidget.selectedNutriScore != widget.selectedNutriScore ||
        oldWidget.selectedMaxCalories != widget.selectedMaxCalories) {
      _filterItems();
    }
  }
  
  void _filterItems() {
    _filteredItems.clear();
    
    // Vérifier et sécuriser l'accès aux données structurées
    if (!widget.producer.containsKey('structured_data') || widget.producer['structured_data'] == null) {
      return;
    } else if (widget.producer['structured_data'] is! Map) {
      return;
    }
    
    // Vérifier et sécuriser l'accès aux items indépendants
    final structuredData = widget.producer['structured_data'] as Map<String, dynamic>;
    final items = structuredData['Items Indépendants'];
    
    if (items == null || !(items is List) || items.isEmpty) {
      return;
    }

    // Filtrer et traiter les items de manière sécurisée
    for (var category in items) {
      if (category is! Map<String, dynamic>) continue;
      
      final categoryName = category['catégorie']?.toString().trim() ?? 'Autres';
      final categoryItems = category['items'];
      
      if (categoryItems == null || !(categoryItems is List) || categoryItems.isEmpty) continue;
      
      for (var item in categoryItems) {
        if (item is! Map<String, dynamic>) continue;
        
        // Extraire les valeurs nutritionnelles de façon sécurisée
        double carbonFootprint = 0;
        String nutriScore = 'N/A';
        double calories = 0;
        
        try {
          // Récupérer le bilan carbone
          final carbonValue = item['carbon_footprint'];
          if (carbonValue != null) {
            if (carbonValue is num) {
              carbonFootprint = carbonValue.toDouble();
            } else {
              carbonFootprint = double.tryParse(carbonValue.toString()) ?? 0;
            }
          }
          
          // Récupérer le nutriscore
          nutriScore = item['nutri_score']?.toString() ?? 'N/A';
          
          // Récupérer les calories
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
            // Alternative si les calories sont directement dans l'item
            final caloriesValue = item['calories'];
            if (caloriesValue is num) {
              calories = caloriesValue.toDouble();
            } else {
              calories = double.tryParse(caloriesValue.toString()) ?? 0;
            }
          }
        } catch (e) {
          print('❌ Erreur lors de l\'extraction des données nutritionnelles: $e');
        }
        
        // Appliquer les filtres
        double carbonLimit = widget.selectedCarbon == "<3kg" ? 3 : 5;
        String nutriScoreLimit = widget.selectedNutriScore == "A-B" ? 'C' : 'D';
        
        if (carbonFootprint <= carbonLimit && 
            (nutriScore.compareTo(nutriScoreLimit) <= 0) && 
            calories <= widget.selectedMaxCalories) {
          
          _filteredItems.putIfAbsent(categoryName, () => []);
          _filteredItems[categoryName]!.add(item);
        }
      }
    }
    
    setState(() {}); // Refresh the widget
  }

  @override
  Widget build(BuildContext context) {
    if (_filteredItems.isEmpty) {
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
                // Scroll vers les options de filtres - fonctionnalité simplifiée
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Utilisez les filtres en haut de la page')),
                );
              },
            ),
          ],
        ),
      );
    }

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
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Chip(
                    label: Text('Carbone: ${widget.selectedCarbon}'),
                    avatar: const Icon(Icons.eco, size: 16, color: Colors.green),
                    backgroundColor: Colors.green.withOpacity(0.1),
                  ),
                  const SizedBox(width: 8),
                  Chip(
                    label: Text('NutriScore: ${widget.selectedNutriScore}'),
                    avatar: const Icon(Icons.health_and_safety, size: 16, color: Colors.blue),
                    backgroundColor: Colors.blue.withOpacity(0.1),
                  ),
                  const SizedBox(width: 8),
                  Chip(
                    label: Text('Max: ${widget.selectedMaxCalories.toInt()} cal'),
                    avatar: const Icon(Icons.local_fire_department, size: 16, color: Colors.orange),
                    backgroundColor: Colors.orange.withOpacity(0.1),
                  ),
                ],
              ),
            ),
          ),
          
          ..._filteredItems.entries.map((entry) {
            final categoryName = entry.key;
            final categoryItems = entry.value;
            return ExpansionTile(
              initiallyExpanded: true,
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
                // Calculer le prix après réduction si une promotion est active
                final originalPrice = double.tryParse(item['prix']?.toString() ?? '0') ?? 0;
                final discountedPrice = widget.hasActivePromotion 
                    ? originalPrice * (1 - widget.promotionDiscount / 100) 
                    : null;
                
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  elevation: 0,
                  color: Colors.grey[50],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey[200]!),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // En-tête avec nom du plat, prix et éventuellement notation
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Nom et notation
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
                            
                            // Prix avec éventuelle réduction
                            if (originalPrice > 0)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  if (widget.hasActivePromotion && discountedPrice != null)
                                    Text(
                                      '${originalPrice.toStringAsFixed(2)} €',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        decoration: TextDecoration.lineThrough,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  Text(
                                    widget.hasActivePromotion && discountedPrice != null
                                        ? '${discountedPrice.toStringAsFixed(2)} €'
                                        : '${originalPrice.toStringAsFixed(2)} €',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: widget.hasActivePromotion ? Colors.red : Colors.black87,
                                    ),
                                  ),
                                  if (widget.hasActivePromotion)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.red,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '-${widget.promotionDiscount.toStringAsFixed(0)}%',
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
                        
                        // Informations nutritionnelles
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Bilan carbone
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
                            
                            // NutriScore
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
                            
                            // Calories
                            Row(
                              children: [
                                const Icon(Icons.local_fire_department, size: 16, color: Colors.orange),
                                const SizedBox(width: 4),
                                Text(
                                  _getCaloriesText(item),
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
                        
                        // Boutons d'action (éditer, supprimer)
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton.icon(
                              icon: const Icon(Icons.edit, size: 16),
                              label: const Text('Modifier'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.blue,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                side: const BorderSide(color: Colors.blue),
                              ),
                              onPressed: () {
                                // Fonctionnalité d'édition
                                // Navigator.push vers écran d'édition d'item
                              },
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.delete, size: 16),
                              label: const Text('Supprimer'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                side: const BorderSide(color: Colors.red),
                              ),
                              onPressed: () {
                                // Fonctionnalité de suppression avec confirmation
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Supprimer cet item ?'),
                                    content: const Text('Cette action est irréversible.'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('Annuler'),
                                      ),
                                      ElevatedButton.icon(
                                        icon: const Icon(Icons.delete),
                                        label: const Text('Supprimer'),
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                        onPressed: () {
                                          // Logique de suppression
                                          Navigator.pop(context);
                                          // Appeler API de suppression
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          }).toList(),
        ],
      ),
    );
  }
  
  String _getCaloriesText(Map<String, dynamic> item) {
    // Check if nutrition map exists and has calories
    if (item['nutrition'] is Map && item['nutrition']['calories'] != null) {
      return '${item['nutrition']['calories']} cal';
    }
    // Or if calories are directly in the item
    else if (item['calories'] != null) {
      return '${item['calories']} cal';
    }
    // Default case
    return 'N/A cal';
  }
  
  // Widget pour afficher les étoiles de notation en format compact
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
        const Icon(Icons.star, color: Colors.amber, size: 16),
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
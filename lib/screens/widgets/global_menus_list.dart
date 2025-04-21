import 'package:flutter/material.dart';

class GlobalMenusList extends StatelessWidget {
  final Map<String, dynamic> producer;
  final bool hasActivePromotion;
  final double promotionDiscount;

  const GlobalMenusList({
    Key? key,
    required this.producer,
    required this.hasActivePromotion,
    required this.promotionDiscount,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final menus = producer['structured_data'] != null && producer['structured_data']['Menus Globaux'] != null
        ? producer['structured_data']['Menus Globaux']
        : [];
    if (menus.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.restaurant_menu, size: 60, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Aucun menu disponible',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.restaurant_menu, color: Colors.orangeAccent),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Menus Disponibles',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...menus.map<Widget>((menu) {
            final inclus = menu['inclus'] ?? [];
            final originalPrice = double.tryParse(menu['prix']?.toString() ?? '0') ?? 0;
            final discountedPrice = hasActivePromotion 
                ? originalPrice * (1 - promotionDiscount / 100) 
                : null;
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8.0),
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            menu['nom'] ?? 'Menu sans nom',
                            style: const TextStyle(
                              fontSize: 18, 
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (hasActivePromotion && discountedPrice != null)
                              Text(
                                '${originalPrice.toStringAsFixed(2)} €',
                                style: const TextStyle(
                                  fontSize: 14,
                                  decoration: TextDecoration.lineThrough,
                                  color: Colors.grey,
                                ),
                              ),
                            Text(
                              hasActivePromotion && discountedPrice != null
                                  ? '${discountedPrice.toStringAsFixed(2)} €'
                                  : '${originalPrice.toStringAsFixed(2)} €',
                              style: TextStyle(
                                fontSize: 18,
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
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  ExpansionTile(
                    title: const Text(
                      'Voir le détail',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.orangeAccent,
                      ),
                    ),
                    tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                    children: inclus.map<Widget>((inclusItem) {
                      final items = inclusItem['items'] ?? [];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                inclusItem['catégorie'] ?? 'Non spécifié',
                                style: const TextStyle(
                                  fontSize: 14, 
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...items.map<Widget>((item) {
                              return Card(
                                elevation: 0,
                                color: Colors.grey[50],
                                margin: const EdgeInsets.only(bottom: 8),
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
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
                                      const SizedBox(height: 4),
                                      Text(
                                        item['description'] ?? 'Pas de description',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
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
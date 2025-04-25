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
        ? producer['structured_data']['Menus Globaux'] as List<dynamic>
        : [];
    if (menus.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32.0),
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
        ),
      );
    }
    return Column(
      children: menus.map((menuData) {
        final menu = menuData as Map<String, dynamic>;
        final inclus = (menu['inclus'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
        final originalPrice = double.tryParse(menu['prix']?.toString() ?? '0') ?? 0;
        final discountedPrice = hasActivePromotion
            ? originalPrice * (1 - promotionDiscount / 100)
            : null;

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Material(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          menu['nom'] ?? 'Menu sans nom',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          if (hasActivePromotion && discountedPrice != null)
                            Text(
                              '${originalPrice.toStringAsFixed(2)} €',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    decoration: TextDecoration.lineThrough,
                                    color: Colors.grey[600],
                                  ),
                            ),
                          Text(
                            hasActivePromotion && discountedPrice != null
                                ? '${discountedPrice.toStringAsFixed(2)} €'
                                : '${originalPrice.toStringAsFixed(2)} €',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: hasActivePromotion ? Colors.redAccent : Theme.of(context).colorScheme.onSurface,
                                ),
                          ),
                          if (hasActivePromotion)
                            Container(
                              margin: const EdgeInsets.only(top: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.redAccent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'PROMO -${promotionDiscount.toStringAsFixed(0)}%',
                                style: const TextStyle(
                                  fontSize: 11,
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
              ),
              if (inclus.isNotEmpty)
                ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 0),
                  iconColor: Theme.of(context).colorScheme.primary,
                  collapsedIconColor: Colors.grey[600],
                  title: Text(
                    'Voir le détail du menu',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  children: inclus.map<Widget>((inclusItem) {
                    final items = (inclusItem['items'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
                    final categoryName = inclusItem['catégorie']?.toString() ?? 'Section';

                    if (items.isEmpty) return const SizedBox.shrink();

                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.secondary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              categoryName,
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.secondary,
                                  ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...items.map<Widget>((item) {
                            final itemName = item['nom']?.toString() ?? 'Item inconnu';
                            final itemDesc = item['description']?.toString();
                            final itemRating = item['note'];

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                              dense: true,
                              title: Text(
                                itemName,
                                style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
                              ),
                              subtitle: itemDesc != null && itemDesc.isNotEmpty
                                ? Text(
                                    itemDesc,
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
                                  )
                                : null,
                              trailing: itemRating != null
                                ? _buildCompactRatingStars(itemRating)
                                : null,
                            );
                          }).toList(),
                          const SizedBox(height: 8),
                        ],
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
        );
      }).toList(),
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
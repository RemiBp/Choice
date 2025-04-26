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
    print('🔍 GlobalMenusList build - hasActivePromotion: $hasActivePromotion (${hasActivePromotion.runtimeType}), promotionDiscount: $promotionDiscount (${promotionDiscount.runtimeType})');
    
    final menus = producer['structured_data'] != null && producer['structured_data']['Menus Globaux'] != null
        ? producer['structured_data']['Menus Globaux'] as List<dynamic>
        : [];
    
    print('🔍 Nombre de menus trouvés: ${menus.length}');
    
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
        print('🔍 Traitement du menu: ${menu['nom']} (ID: ${menu['_id'] ?? 'sans ID'})');
        
        List<Map<String, dynamic>> inclus = [];
        try {
          inclus = (menu['inclus'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
          print('🔍 Menu ${menu['nom']} - items inclus: ${inclus.length}');
        } catch (e) {
          print('❌ Erreur lors de la conversion des items inclus: $e');
        }
        
        final originalPrice = double.tryParse(menu['prix']?.toString() ?? '0') ?? 0;
        final discountedPrice = hasActivePromotion
            ? originalPrice * (1 - promotionDiscount / 100)
            : null;

        print('🔍 Menu ${menu['nom']} - prix original: $originalPrice, prix avec remise: $discountedPrice');

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
                                    color: const Color(0xFF757575),
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
                CustomMenuExpansion(
                  title: 'Voir le détail du menu',
                  primaryColor: Theme.of(context).colorScheme.primary,
                  items: inclus,
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCompactRatingStars(dynamic rating) {
    print('🔍 Construction rating stars avec valeur: $rating (${rating.runtimeType})');
    double ratingValue = 0.0;
    if (rating is int) {
      ratingValue = rating.toDouble();
    } else if (rating is double) {
      ratingValue = rating;
    } else if (rating is String) {
      ratingValue = double.tryParse(rating) ?? 0.0;
    }
    print('🔍 Valeur finale de rating: $ratingValue');
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

// Widget personnalisé pour remplacer ExpansionTile et éviter le problème de casting
class CustomMenuExpansion extends StatefulWidget {
  final String title;
  final Color primaryColor;
  final List<Map<String, dynamic>> items;

  const CustomMenuExpansion({
    Key? key,
    required this.title,
    required this.primaryColor,
    required this.items,
  }) : super(key: key);

  @override
  _CustomMenuExpansionState createState() => _CustomMenuExpansionState();
}

class _CustomMenuExpansionState extends State<CustomMenuExpansion> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () {
            setState(() {
              _isExpanded = !_isExpanded;
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: widget.primaryColor,
                  ),
                ),
                Icon(
                  _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: _isExpanded ? widget.primaryColor : const Color(0xFF757575),
                ),
              ],
            ),
          ),
        ),
        if (_isExpanded)
          Column(
            children: widget.items.map((item) {
              print('🔍 Construction item personnalisé: ${item['nom']}');
              return ListTile(
                title: Text(item['nom'] ?? 'Item sans nom'),
                subtitle: item['description'] != null && item['description'].toString().isNotEmpty
                    ? Text(item['description'].toString())
                    : null,
                leading: item['rating'] != null && item['rating'] is num
                    ? _buildRatingStars(item['rating'])
                    : null,
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildRatingStars(dynamic rating) {
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
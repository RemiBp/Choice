import 'package:flutter/material.dart';

class ProducerMenuCard extends StatefulWidget {
  final Map<String, dynamic> menu;
  final bool hasActivePromotion;
  final double promotionDiscount;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const ProducerMenuCard({
    Key? key,
    required this.menu,
    required this.hasActivePromotion,
    required this.promotionDiscount,
    this.onEdit,
    this.onDelete,
  }) : super(key: key);

  @override
  State<ProducerMenuCard> createState() => _ProducerMenuCardState();
}

class _ProducerMenuCardState extends State<ProducerMenuCard> {
  @override
  Widget build(BuildContext context) {
    final inclus = widget.menu['inclus'] ?? [];
    // Calculer le prix après réduction si une promotion est active
    final originalPrice = double.tryParse(widget.menu['prix']?.toString() ?? '0') ?? 0;
    final discountedPrice = widget.hasActivePromotion 
        ? originalPrice * (1 - widget.promotionDiscount / 100) 
        : null;
            
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête du menu avec prix et éventuelle réduction
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.menu['nom'] ?? 'Menu sans nom',
                        style: const TextStyle(
                          fontSize: 18, 
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      if (widget.menu['description'] != null && widget.menu['description'].toString().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            widget.menu['description'].toString(),
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (widget.hasActivePromotion && discountedPrice != null)
                      Text(
                        '${originalPrice.toStringAsFixed(2)} €',
                        style: const TextStyle(
                          fontSize: 14,
                          decoration: TextDecoration.lineThrough,
                          color: Colors.grey,
                        ),
                      ),
                    Text(
                      widget.hasActivePromotion && discountedPrice != null
                          ? '${discountedPrice.toStringAsFixed(2)} €'
                          : '${originalPrice.toStringAsFixed(2)} €',
                      style: TextStyle(
                        fontSize: 18,
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
          
          // Contenu du menu avec les items inclus
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
          
          // Boutons d'action
          if (widget.onEdit != null || widget.onDelete != null)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (widget.onEdit != null)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text('Modifier'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        side: const BorderSide(color: Colors.blue),
                      ),
                      onPressed: widget.onEdit,
                    ),
                  if (widget.onEdit != null && widget.onDelete != null)
                    const SizedBox(width: 8),
                  if (widget.onDelete != null)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.delete, size: 16),
                      label: const Text('Supprimer'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        side: const BorderSide(color: Colors.red),
                      ),
                      onPressed: () {
                        // Confirmation de suppression
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Supprimer ce menu ?'),
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
                                  Navigator.pop(context);
                                  if (widget.onDelete != null) {
                                    widget.onDelete!();
                                  }
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
        ],
      ),
    );
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
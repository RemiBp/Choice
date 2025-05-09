import 'package:flutter/material.dart';
import 'producer_menu_card.dart';

class ProducerMenuTab extends StatelessWidget {
  final List<dynamic> menus;
  final Map<String, dynamic> categorizedItems;
  final bool isLoadingMenus;
  final VoidCallback? onManageMenu;

  const ProducerMenuTab({
    Key? key,
    required this.menus,
    required this.categorizedItems,
    required this.isLoadingMenus,
    this.onManageMenu,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (isLoadingMenus) {
      return _buildMenuShimmer();
    }

    bool hasGlobalMenus = menus.isNotEmpty;
    bool hasIndependentItems = categorizedItems.isNotEmpty;

    if (!hasGlobalMenus && !hasIndependentItems) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.menu_book_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'Aucun menu ou article disponible',
              style: TextStyle(fontSize: 18, color: Colors.grey[700], fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Ce producteur n\'a pas encore ajouté son menu.',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            if (onManageMenu != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onManageMenu,
                icon: const Icon(Icons.edit),
                label: const Text('Gérer le menu'),
              ),
            ],
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (onManageMenu != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: onManageMenu,
                icon: const Icon(Icons.edit),
                label: const Text('Gérer le menu'),
              ),
            ),
          ),
        if (hasGlobalMenus) ...[
          _buildSectionHeader('Menus', Icons.menu_book, Colors.amber),
          const SizedBox(height: 16),
          ...menus.map((menu) => _buildGlobalMenuCard(menu)).toList(),
          if (hasIndependentItems) const SizedBox(height: 24),
        ],
        if (hasIndependentItems) ...[
          _buildSectionHeader('À la carte', Icons.restaurant_menu, Colors.deepPurple),
          const SizedBox(height: 16),
          ...categorizedItems.entries.map((entry) {
            return _buildCategoryExpansionTile(entry.key, entry.value);
          }).toList(),
        ],
      ],
    );
  }

  Widget _buildMenuShimmer() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 6,
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: Container(
          height: 100,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildGlobalMenuCard(Map<String, dynamic> menu) {
    return ProducerMenuCard(
      menu: menu,
      hasActivePromotion: false,
      promotionDiscount: 0,
      onEdit: onManageMenu,
    );
  }

  Widget _buildMenuItemRow(Map<String, dynamic> item, Color? backgroundColor) {
    final String name = item['name'] ?? item['nom'] ?? 'Item sans nom';
    final String description = item['description'] ?? '';
    final double? rating = (item['note'] is num) ? (item['note'] as num).toDouble() : null;
    final double? carbon = (item['carbon_footprint'] is num) ? (item['carbon_footprint'] as num).toDouble() : null;
    final String? nutriScore = item['nutri_score']?.toString();
    final double? calories = (item['nutrition'] is Map && item['nutrition']['calories'] is num)
        ? (item['nutrition']['calories'] as num).toDouble()
        : (item['calories'] is num ? (item['calories'] as num).toDouble() : null);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
              if (rating != null) _buildCompactRatingStars(rating),
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
            ),
          ],
          if (carbon != null || nutriScore != null || calories != null) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (carbon != null) _buildNutritionalChip('${carbon.toStringAsFixed(1)} kg CO2', Icons.eco_outlined, Colors.green),
                if (nutriScore != null && nutriScore.isNotEmpty && nutriScore != 'N/A') _buildNutritionalChip('Nutri: $nutriScore', Icons.health_and_safety_outlined, _getNutriScoreColor(nutriScore)),
                if (calories != null) _buildNutritionalChip('${calories.toInt()} cal', Icons.local_fire_department_outlined, Colors.orange),
              ],
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildCategoryExpansionTile(String category, List<dynamic> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        backgroundColor: Colors.white,
        collapsedBackgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        title: Text(
          category,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.deepPurple),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: items.map((item) {
          if (item is Map<String, dynamic>) {
            return _buildDetailedItemCard(item);
          }
          return const SizedBox.shrink();
        }).toList(),
      ),
    );
  }

  Widget _buildDetailedItemCard(Map<String, dynamic> item) {
    final String name = item['name'] ?? item['nom'] ?? 'Item sans nom';
    final String description = item['description'] ?? '';
    final dynamic price = item['price'] ?? item['prix'];
    final String formattedPrice = (price != null && price.toString().isNotEmpty)
        ? price is num
            ? '${(price as num).toStringAsFixed(2)} €'
            : '$price €'
        : '';
    final double? rating = (item['note'] is num) ? (item['note'] as num).toDouble() : null;
    final double? carbon = (item['carbon_footprint'] is num) ? (item['carbon_footprint'] as num).toDouble() : null;
    final String? nutriScore = item['nutri_score']?.toString();
    final double? calories = (item['nutrition'] is Map && item['nutrition']['calories'] is num)
        ? (item['nutrition']['calories'] as num).toDouble()
        : (item['calories'] is num ? (item['calories'] as num).toDouble() : null);

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
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
                        name,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (rating != null) _buildCompactRatingStars(rating),
                  ],
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                  ),
                ],
                if (carbon != null || nutriScore != null || calories != null) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      if (carbon != null) _buildNutritionalChip('${carbon.toStringAsFixed(1)} kg CO2', Icons.eco_outlined, Colors.green),
                      if (nutriScore != null && nutriScore.isNotEmpty && nutriScore != 'N/A') _buildNutritionalChip('Nutri: $nutriScore', Icons.health_and_safety_outlined, _getNutriScoreColor(nutriScore)),
                      if (calories != null) _buildNutritionalChip('${calories.toInt()} cal', Icons.local_fire_department_outlined, Colors.orange),
                    ],
                  ),
                ]
              ],
            ),
          ),
          if (formattedPrice.isNotEmpty) ...[
            const SizedBox(width: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.deepPurple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                formattedPrice,
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple, fontSize: 15),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNutritionalChip(String label, IconData icon, Color color) {
    return Chip(
      avatar: Icon(icon, color: color, size: 16),
      label: Text(label, style: TextStyle(fontSize: 11, color: color)),
      backgroundColor: color.withOpacity(0.1),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      side: BorderSide.none,
    );
  }

  Color _getNutriScoreColor(String score) {
    switch (score.toUpperCase()) {
      case 'A':
        return Colors.green.shade700;
      case 'B':
        return Colors.lightGreen.shade700;
      case 'C':
        return Colors.yellow.shade800;
      case 'D':
        return Colors.orange.shade700;
      case 'E':
        return Colors.red.shade700;
      default:
        return Colors.grey;
    }
  }

  Widget _buildCompactRatingStars(dynamic rating) {
    double ratingValue = 0.0;
    if (rating is num) {
      ratingValue = rating.toDouble();
    } else if (rating is String) {
      ratingValue = double.tryParse(rating) ?? 0.0;
    }
    if (ratingValue <= 0) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.star, color: Colors.amber, size: 16),
        const SizedBox(width: 2),
        Text(
          ratingValue.toStringAsFixed(1),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
} 
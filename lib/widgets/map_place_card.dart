import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../models/map_filter.dart';

/// Carte affichant les détails d'un lieu sélectionné sur la carte
class MapPlaceCard extends StatelessWidget {
  final Map<String, dynamic> place;
  final Color themeColor;
  final VoidCallback onClose;
  final Function(String) onFavorite;
  final Function(String) onChoice;
  final bool isFavorite;
  final bool isChoice;

  const MapPlaceCard({
    Key? key,
    required this.place,
    required this.themeColor,
    required this.onClose,
    required this.onFavorite,
    required this.onChoice,
    this.isFavorite = false,
    this.isChoice = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Extraire les données de l'établissement
    final String id = place['_id'] ?? place['id'] ?? '';
    final String name = place['name'] ?? 'Sans nom';
    final String imageUrl = place['image_url'] ?? place['main_image'] ?? '';
    final double rating = (place['rating'] ?? 0).toDouble();
    final String category = place['category'] ?? place['sub_category'] ?? '';
    final String address = place['address'] ?? '';
    final String description = place['description'] ?? '';
    
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // En-tête avec image et bouton de fermeture
          Stack(
            children: [
              // Image de couverture
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                child: imageUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: imageUrl,
                        height: 150,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          height: 150,
                          color: Colors.grey.shade200,
                          child: Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(themeColor),
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          height: 150,
                          color: themeColor.withOpacity(0.2),
                          child: Icon(
                            Icons.image_not_supported,
                            color: themeColor,
                            size: 48,
                          ),
                        ),
                      )
                    : Container(
                        height: 150,
                        color: themeColor.withOpacity(0.2),
                        child: Icon(
                          Icons.image_not_supported,
                          color: themeColor,
                          size: 48,
                        ),
                      ),
              ),
              
              // Bouton de fermeture
              Positioned(
                top: 8,
                right: 8,
                child: CircleAvatar(
                  backgroundColor: Colors.white,
                  radius: 16,
                  child: IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    color: Colors.black,
                    onPressed: onClose,
                  ),
                ),
              ),
              
              // Nom et catégorie
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.7),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (category.isNotEmpty)
                        Text(
                          category,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          
          // Contenu de la carte
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Notation
                if (rating > 0) ...[
                  Row(
                    children: [
                      ...List.generate(
                        5,
                        (index) => Icon(
                          index < rating.floor()
                              ? Icons.star
                              : (index < rating)
                                  ? Icons.star_half
                                  : Icons.star_border,
                          color: Colors.amber,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        rating.toStringAsFixed(1),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                
                // Adresse
                if (address.isNotEmpty) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.location_on,
                        size: 16,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          address,
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                
                // Description courte
                if (description.isNotEmpty) ...[
                  Text(
                    description.length > 100
                        ? '${description.substring(0, 100)}...'
                        : description,
                    style: TextStyle(
                      color: Colors.grey.shade800,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                
                // Actions (Choice, Favori, Directions)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Bouton Choice
                    _buildActionButton(
                      label: 'Choice',
                      icon: isChoice 
                          ? FontAwesomeIcons.solidStar
                          : FontAwesomeIcons.star,
                      color: isChoice ? Colors.amber : Colors.grey,
                      onPressed: () => onChoice(id),
                    ),
                    
                    // Bouton Favori
                    _buildActionButton(
                      label: 'Favori',
                      icon: isFavorite 
                          ? Icons.favorite
                          : Icons.favorite_border,
                      color: isFavorite ? Colors.red : Colors.grey,
                      onPressed: () => onFavorite(id),
                    ),
                    
                    // Bouton Directions
                    _buildActionButton(
                      label: 'Itinéraire',
                      icon: Icons.directions,
                      color: themeColor,
                      onPressed: () {
                        // Ouvrir l'itinéraire Google Maps
                        _launchDirections(place);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: color,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Lancer l'application Google Maps pour l'itinéraire
  void _launchDirections(Map<String, dynamic> place) {
    // Implementation à compléter avec un plugin comme url_launcher
    print('Lancement de l\'itinéraire vers: ${place['name']}');
  }
} 
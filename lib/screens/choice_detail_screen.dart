import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart'; // Pour formater la date
import '../utils.dart' as utils; // Correction: Importer le bon fichier utils.dart
import 'package:choice_app/screens/producer_screen.dart'; // Pour naviguer vers le lieu
// Import d'autres écrans de lieu si nécessaire (Event, Wellness...)

class ChoiceDetailScreen extends StatelessWidget {
  final Map<String, dynamic> choiceData;
  // Note: placeDetails pourrait être null si le lieu a été supprimé
  final Map<String, dynamic>? placeDetails;

  const ChoiceDetailScreen({
    Key? key,
    required this.choiceData,
    required this.placeDetails,
  }) : super(key: key);

  // Helper pour déterminer l'icône et la couleur en fonction du type de lieu
  ({IconData icon, Color color, String typeLabel}) _getPlaceTypeInfo(String? type) {
    switch (type?.toLowerCase()) {
      case 'restaurant':
        return (icon: Icons.restaurant, color: Colors.orange, typeLabel: 'Restaurant');
      case 'event':
        return (icon: Icons.event, color: Colors.blue, typeLabel: 'Événement');
      case 'leisureproducer':
      case 'leisure':
        return (icon: Icons.museum, color: Colors.purple, typeLabel: 'Loisir');
      case 'wellness':
        return (icon: Icons.spa, color: Colors.green, typeLabel: 'Bien-être');
      default:
        return (icon: Icons.place, color: Colors.grey, typeLabel: 'Lieu');
    }
  }

  // Helper pour formater la date
  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'Date inconnue';
    try {
      final dateTime = DateTime.parse(dateStr);
      // Correction: Éviter l'apostrophe directe dans le format
      // Utiliser un format standard ou construire la chaîne
      final formattedDate = DateFormat('EEE d MMMM yyyy', 'fr_FR').format(dateTime);
      final formattedTime = DateFormat('HH:mm', 'fr_FR').format(dateTime);
      return '$formattedDate à $formattedTime'; // Construire la chaîne
    } catch (e) {
      return dateStr; // Retourner la string originale si le parsing échoue
    }
  }

  // Helper pour afficher une note d'aspect
  Widget _buildRatingDisplay(String aspectKey, dynamic ratingValue) {
    // Normaliser le nom de l'aspect pour affichage
    final displayAspect = aspectKey
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isNotEmpty ? w[0].toUpperCase() + w.substring(1) : '')
        .join(' ');
        
    final double rating = (ratingValue is num) ? ratingValue.toDouble() : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Expanded(
            flex: 3, // Donner plus de place au label
            child: Text(
              displayAspect,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            flex: 5, // Donner plus de place à la barre/note
            child: Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: rating / 10.0, // Normaliser la valeur entre 0 et 1
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.teal.shade400),
                    minHeight: 6, // Hauteur de la barre
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  rating.toStringAsFixed(1), // Afficher avec une décimale
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.teal),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  // Helper pour afficher une liste (émotions, tags, menu)
   Widget _buildChipList(String title, IconData icon, List<dynamic>? items) {
     if (items == null || items.isEmpty) return const SizedBox.shrink();
     final stringItems = items.map((item) => item.toString()).where((s) => s.isNotEmpty).toList();
     if (stringItems.isEmpty) return const SizedBox.shrink();

     return Padding(
       padding: const EdgeInsets.only(top: 16.0),
       child: Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
           Row(
             children: [
               Icon(icon, size: 18, color: Colors.grey[700]),
               const SizedBox(width: 8),
               Text(
                 title,
                 style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[800]),
               ),
             ],
           ),
           const SizedBox(height: 10),
           Wrap(
             spacing: 8,
             runSpacing: 8,
             children: stringItems.map((item) => Chip(
               label: Text(item, style: TextStyle(fontSize: 12, color: Colors.teal.shade800)),
               backgroundColor: Colors.teal.withOpacity(0.1),
               materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
               padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
               side: BorderSide.none,
             )).toList(),
           ),
         ],
       ),
     );
   }


  @override
  Widget build(BuildContext context) {
    // Extraire les données du choice et du lieu
    final placeName = placeDetails?['name'] ?? choiceData['targetName'] ?? 'Lieu inconnu';
    final placeAddress = placeDetails?['address'] ?? placeDetails?['adresse'] ?? '';
    final placeImageUrl = (placeDetails?['photos'] is List && placeDetails!['photos'].isNotEmpty)
        ? placeDetails!['photos'][0]
        : placeDetails?['image'] ?? placeDetails?['photo_url'];
        
    final String placeType = placeDetails?['type'] ?? choiceData['targetType'] ?? 'unknown';
    final typeInfo = _getPlaceTypeInfo(placeType);
    final String? placeId = placeDetails?['_id']?.toString();

    final ratings = (choiceData['ratings'] ?? choiceData['aspects']) as Map<String, dynamic>? ?? {};
    final comment = choiceData['comment'] as String? ?? '';
    final createdAt = choiceData['createdAt'] as String?;
    final emotions = choiceData['emotions'] as List<dynamic>?;
    final menuItems = choiceData['menuItems'] as List<dynamic>?;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 250.0,
            floating: false,
            pinned: true,
            stretch: true,
            backgroundColor: typeInfo.color, // Couleur basée sur le type de lieu
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.symmetric(horizontal: 50, vertical: 12),
              title: Text(
                 placeName,
                 style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16.0,
                    fontWeight: FontWeight.bold,
                    shadows: [Shadow(blurRadius: 2, color: Colors.black54)]
                 ),
                 maxLines: 1,
                 overflow: TextOverflow.ellipsis,
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Image de fond
                  if (placeImageUrl != null && placeImageUrl.isNotEmpty)
                    Image(
                      image: utils.getImageProvider(placeImageUrl)!,
                      fit: BoxFit.cover,
                      errorBuilder: (ctx, err, st) => Container(color: typeInfo.color.withOpacity(0.5), child: Icon(typeInfo.icon, size: 80, color: Colors.white38)),
                    )
                  else
                     Container(color: typeInfo.color.withOpacity(0.7), child: Icon(typeInfo.icon, size: 100, color: Colors.white54)),
                  // Dégradé pour la lisibilité du titre
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [ Colors.transparent, Colors.black.withOpacity(0.7) ],
                        stops: const [0.5, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
             actions: [
                 // Chip pour indiquer le type de lieu
                 Padding(
                     padding: const EdgeInsets.only(right: 12.0),
                     child: Chip(
                         avatar: Icon(typeInfo.icon, size: 16, color: typeInfo.color),
                         label: Text(typeInfo.typeLabel),
                         labelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: typeInfo.color),
                         backgroundColor: Colors.white.withOpacity(0.9),
                         padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                         visualDensity: VisualDensity.compact,
                         side: BorderSide.none,
                     ),
                 )
             ],
          ),
          
          // Contenu principal
          SliverPadding(
             padding: const EdgeInsets.all(20),
             sliver: SliverList(delegate: SliverChildListDelegate([
                // Adresse et Date
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (placeAddress.isNotEmpty)
                       Expanded(
                         child: Row(
                           crossAxisAlignment: CrossAxisAlignment.start,
                           children: [
                             Icon(Icons.location_on_outlined, size: 16, color: Colors.grey[600]),
                             const SizedBox(width: 6),
                             Expanded(child: Text(placeAddress, style: TextStyle(fontSize: 13, color: Colors.grey[700]))),
                           ],
                         ),
                       ),
                    if (createdAt != null) ... [
                         if (placeAddress.isNotEmpty) const SizedBox(width: 16), // Espace si les deux sont présents
                         Row(
                           children: [
                              Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey[600]),
                              const SizedBox(width: 6),
                              Text(_formatDate(createdAt), style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                           ],
                         ),
                    ]
                  ],
                ),
                const SizedBox(height: 24),

                // Bouton "Voir la page du lieu"
                if (placeId != null)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.storefront_outlined),
                      label: Text('Voir la page de "$placeName"'),
                      style: OutlinedButton.styleFrom(
                          foregroundColor: typeInfo.color,
                          side: BorderSide(color: typeInfo.color.withOpacity(0.5)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                      ),
                      onPressed: () {
                         // TODO: Adapter la navigation selon le type si nécessaire
                         Navigator.push(
                           context,
                           MaterialPageRoute(builder: (context) => ProducerScreen(producerId: placeId)),
                         );
                      },
                    ),
                  ),
                 const SizedBox(height: 10),
                 const Divider(height: 30),

                // Section des notes données
                const Text(
                  'Votre évaluation',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                if (ratings.isEmpty)
                   const Text('Aucune note spécifique donnée pour ce choice.', style: TextStyle(color: Colors.grey))
                else
                   ...ratings.entries.map((entry) => _buildRatingDisplay(entry.key, entry.value)),
                   
                // Émotions (Wellness/Event)
                _buildChipList('Émotions ressenties', Icons.sentiment_satisfied_alt_outlined, emotions),

                // Plats (Restaurant)
                _buildChipList('Plats consommés', Icons.restaurant_menu_outlined, menuItems),

                // Commentaire
                 if (comment.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const Text(
                      'Votre commentaire',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Container(
                       padding: const EdgeInsets.all(12),
                       width: double.infinity,
                       decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                       ),
                       child: Text(
                           comment,
                           style: TextStyle(fontSize: 14, color: Colors.grey[800], height: 1.4),
                       ),
                    )
                 ],

                const SizedBox(height: 40), // Espace en bas

             ]),),
          ),
        ],
      ),
    );
  }
} 
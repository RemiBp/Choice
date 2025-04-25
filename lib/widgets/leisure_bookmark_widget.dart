import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/map_colors.dart' as mapcolors;
import '../services/map_service.dart';
import '../utils.dart' show getImageProvider;
import 'choiceInterestUsers_popup.dart'; // Import du widget popup

class LeisureBookmarkWidget extends StatefulWidget {
  final Map<String, dynamic> venue;
  final Function(String) onTap;
  final Function(String, bool)? onBookmarkChanged;
  final bool isBookmarked;

  const LeisureBookmarkWidget({
    Key? key,
    required this.venue,
    required this.onTap,
    this.onBookmarkChanged,
    this.isBookmarked = false,
  }) : super(key: key);

  @override
  State<LeisureBookmarkWidget> createState() => _LeisureBookmarkWidgetState();
}

class _LeisureBookmarkWidgetState extends State<LeisureBookmarkWidget> {
  final MapService _mapService = MapService();
  bool _isBookmarked = false;

  @override
  void initState() {
    super.initState();
    _isBookmarked = widget.isBookmarked;
  }

  @override
  void didUpdateWidget(LeisureBookmarkWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isBookmarked != widget.isBookmarked) {
      setState(() {
        _isBookmarked = widget.isBookmarked;
      });
    }
  }

  void _toggleBookmark() async {
    final venueId = widget.venue['id'] ?? widget.venue['_id'];
    if (venueId == null) return;

    final newValue = !_isBookmarked;
    setState(() {
      _isBookmarked = newValue;
    });

    bool success = false;
    try {
      if (newValue) {
        success = await _mapService.addLeisureBookmark(venueId.toString());
      } else {
        success = await _mapService.removeLeisureBookmark(venueId.toString());
      }
    } catch (e) {
      print("Erreur bookmark: $e");
      success = false;
    }

    if (!success) {
      // Revenir à l'état précédent si l'opération a échoué
      setState(() {
        _isBookmarked = !newValue;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la mise à jour du signet.'), backgroundColor: Colors.red),
      );
    }

    // Informer le parent du changement
    widget.onBookmarkChanged?.call(venueId.toString(), _isBookmarked);
  }

  @override
  Widget build(BuildContext context) {
    // Extraire les données du lieu
    final String name = widget.venue['name'] ?? widget.venue['title'] ?? 'Lieu de loisir';
    final String category = widget.venue['category'] ?? widget.venue['type'] ?? '';
    final String imageUrl = widget.venue['imageUrl'] ?? widget.venue['image'] ?? '';
    final double rating = (widget.venue['rating'] is num) 
        ? (widget.venue['rating'] as num).toDouble() 
        : 0.0;
    final String venueId = widget.venue['id'] ?? widget.venue['_id'] ?? '';
    final String venueType = widget.venue['venueType'] ?? widget.venue['targetType'] ?? 'leisure-venue'; // Déterminer le type pour le popup

    // Récupérer les compteurs DIRECTEMENT depuis widget.venue (suppose que l'API les fournit)
    final int choiceCount = widget.venue['choice_count'] ?? widget.venue['choiceCount'] ?? 0;
    final int interestCount = widget.venue['interest_count'] ?? widget.venue['interestCount'] ?? 0;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => widget.onTap(venueId), // Utiliser venueId extrait
        child: Container(
          height: 220,
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image et badge catégorie
              Stack(
                children: [
                  Container(
                    height: 120,
                    width: double.infinity,
                    child: imageUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                mapcolors.MapColors.leisurePrimary
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => Icon(
                            Icons.image_not_supported,
                            size: 40,
                            color: Colors.grey[400],
                          ),
                        )
                      : Container(
                          color: _getCategoryColor(category).withOpacity(0.2),
                          child: Center(
                            child: Icon(
                              _getCategoryIcon(category),
                              size: 40,
                              color: _getCategoryColor(category),
                            ),
                          ),
                        ),
                  ),
                  
                  // Badge catégorie
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getCategoryColor(category),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        category,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  
                  // Bouton de signet
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: Icon(
                          _isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                          color: _isBookmarked 
                            ? mapcolors.MapColors.leisurePrimary 
                            : Colors.grey,
                        ),
                        onPressed: _toggleBookmark,
                        iconSize: 20,
                        padding: EdgeInsets.all(4),
                        constraints: BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        tooltip: _isBookmarked ? 'Retirer des signets' : 'Ajouter aux signets',
                      ),
                    ),
                  ),
                ],
              ),
              
              // Informations sur le lieu
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),
                    if (rating > 0)
                      Row(
                        children: [
                          Icon(Icons.star, color: Colors.amber, size: 16),
                          SizedBox(width: 4),
                          Text(
                            rating.toStringAsFixed(1),
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    SizedBox(height: 8),
                    
                    // Affichage des compteurs globaux et trigger du popup
                    if (choiceCount > 0 || interestCount > 0)
                      GestureDetector(
                        onTap: () {
                          // Ouvre le popup avec les infos du lieu/event
                          _showChoiceInterestUsersPopup(context, venueId, venueType);
                        },
                        child: Row(
                          children: [
                            Icon(Icons.check_circle_outline, size: 16, color: Colors.grey[600]),
                            SizedBox(width: 4),
                            Text('$choiceCount Choices', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                            SizedBox(width: 12),
                            Icon(Icons.favorite_border, size: 16, color: Colors.grey[600]),
                            SizedBox(width: 4),
                            Text('$interestCount Intérêts', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                            Spacer(), // Pousse l'icône vers la droite
                            Icon(Icons.chevron_right, color: Colors.grey, size: 18),
                          ],
                        ),
                      )
                    else
                      Text(
                        'Soyez le premier à interagir !',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showChoiceInterestUsersPopup(BuildContext context, String targetId, String targetType) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.8,
        builder: (_, controller) {
          // Import nécessaire pour ChoiceInterestUsersPopup
          // import 'choiceInterestUsers_popup.dart'; 
          return ChoiceInterestUsersPopup(
            targetId: targetId,
            targetType: targetType,
            scrollController: controller,
          );
          // --- Placeholder en attendant l'import/widget --- 
          /*
          return Container(
            color: Colors.white,
            child: Center(child: Text("Popup pour $targetType $targetId")),
          );
          */
        },
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    final categoryLower = category.toLowerCase();
    
    if (categoryLower.contains('concert') || categoryLower.contains('music') || categoryLower.contains('musique')) {
      return Icons.music_note;
    } else if (categoryLower.contains('théâtre') || categoryLower.contains('theatre')) {
      return Icons.theater_comedy;
    } else if (categoryLower.contains('expo') || categoryLower.contains('art') || 
              categoryLower.contains('musée') || categoryLower.contains('musee')) {
      return Icons.museum;
    } else if (categoryLower.contains('cinéma') || categoryLower.contains('cinema')) {
      return Icons.movie;
    } else if (categoryLower.contains('danse') || categoryLower.contains('ballet')) {
      return Icons.directions_run;
    } else if (categoryLower.contains('festival')) {
      return Icons.celebration;
    } else if (categoryLower.contains('comédie') || categoryLower.contains('comedie') || 
              categoryLower.contains('humour')) {
      return Icons.sentiment_very_satisfied;
    } else {
      return Icons.event;
    }
  }

  Color _getCategoryColor(String category) {
    final categoryLower = category.toLowerCase();
    
    if (categoryLower.contains('concert') || categoryLower.contains('music') || categoryLower.contains('musique')) {
      return Colors.deepPurple;
    } else if (categoryLower.contains('théâtre') || categoryLower.contains('theatre')) {
      return Colors.deepOrange;
    } else if (categoryLower.contains('expo') || categoryLower.contains('art') || 
              categoryLower.contains('musée') || categoryLower.contains('musee')) {
      return Colors.indigo;
    } else if (categoryLower.contains('cinéma') || categoryLower.contains('cinema')) {
      return Colors.red;
    } else if (categoryLower.contains('danse') || categoryLower.contains('ballet')) {
      return Colors.pink;
    } else if (categoryLower.contains('festival')) {
      return Colors.amber;
    } else if (categoryLower.contains('comédie') || categoryLower.contains('comedie') || 
              categoryLower.contains('humour')) {
      return Colors.teal;
    } else {
      return mapcolors.MapColors.leisurePrimary;
    }
  }
} 
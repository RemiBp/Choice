import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/map_colors.dart' as mapcolors;
import '../services/map_service.dart';
import '../utils.dart' show getImageProvider;

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
  bool _isLoading = true;
  bool _isBookmarked = false;
  Map<String, dynamic> _followingsData = {
    'interests': [],
    'choices': [],
    'followings': [],
  };

  @override
  void initState() {
    super.initState();
    _isBookmarked = widget.isBookmarked;
    _loadFollowingsData();
  }

  @override
  void didUpdateWidget(LeisureBookmarkWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isBookmarked != widget.isBookmarked) {
      setState(() {
        _isBookmarked = widget.isBookmarked;
      });
    }
    
    if (oldWidget.venue['id'] != widget.venue['id']) {
      _loadFollowingsData();
    }
  }

  Future<void> _loadFollowingsData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final venueId = widget.venue['id'] ?? widget.venue['_id'];
      if (venueId != null) {
        final dynamic data = await _mapService.getFollowingsInterestsForVenue(venueId.toString());
        
        // Initialiser une structure vide par défaut
        Map<String, dynamic> followingsData = {
          'interests': [],
          'choices': [],
          'followings': [],
        };
        
        // Traiter les données selon leur type
        if (data is Map<String, dynamic>) {
          // Si c'est déjà une Map, l'utiliser directement
          followingsData = data;
        } else if (data is List) {
          // Si c'est une liste, l'assigner comme followings
          followingsData['followings'] = data;
        }
        
        setState(() {
          _followingsData = followingsData;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Erreur lors du chargement des données des followings: $e');
      setState(() {
        _isLoading = false;
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
    if (newValue) {
      success = await _mapService.addLeisureBookmark(venueId.toString());
    } else {
      success = await _mapService.removeLeisureBookmark(venueId.toString());
    }

    if (!success) {
      // Revenir à l'état précédent si l'opération a échoué
      setState(() {
        _isBookmarked = !newValue;
      });
    }

    // Informer le parent du changement
    if (widget.onBookmarkChanged != null) {
      widget.onBookmarkChanged!(venueId.toString(), _isBookmarked);
    }
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

    // Compter le nombre de followings intéressés
    final int interestsCount = (_followingsData['interests'] as List).length;
    final int choicesCount = (_followingsData['choices'] as List).length;
    final List<dynamic> followings = _followingsData['followings'] as List;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => widget.onTap(widget.venue['id'] ?? widget.venue['_id']),
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
                    // Followings intéressés
                    if (_isLoading)
                      Center(
                        child: SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              mapcolors.MapColors.leisurePrimary,
                            ),
                          ),
                        ),
                      )
                    else if (interestsCount > 0 || choicesCount > 0)
                      GestureDetector(
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (context) => DraggableScrollableSheet(
                              initialChildSize: 0.6,
                              minChildSize: 0.4,
                              maxChildSize: 0.8,
                              builder: (context, scrollController) {
                                return Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.vertical(
                                      top: Radius.circular(20),
                                    ),
                                  ),
                                  padding: EdgeInsets.all(16),
                                  child: FollowingsInterestsList(
                                    followingsData: _followingsData,
                                    onClose: () => Navigator.pop(context),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                        child: Row(
                          children: [
                            Icon(
                              Icons.people,
                              size: 16,
                              color: mapcolors.MapColors.leisurePrimary,
                            ),
                            SizedBox(width: 4),
                            Text(
                              interestsCount > 0 && choicesCount > 0
                                ? '$interestsCount intéressés • $choicesCount ont visité'
                                : interestsCount > 0
                                  ? '$interestsCount intéressés'
                                  : '$choicesCount ont visité',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Text(
                        'Aucun ami intéressé pour le moment',
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

/// Widget pour afficher la liste des followings intéressés par un lieu
class FollowingsInterestsList extends StatelessWidget {
  final Map<String, dynamic> followingsData;
  final VoidCallback? onClose;

  const FollowingsInterestsList({
    Key? key,
    required this.followingsData,
    this.onClose,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final List<dynamic> followings = followingsData['followings'] as List;
    final List<dynamic> interests = followingsData['interests'] as List;
    final List<dynamic> choices = followingsData['choices'] as List;

    if (followings.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Aucun de vos amis ne s\'est intéressé à ce lieu pour l\'instant.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontStyle: FontStyle.italic,
              color: Colors.grey[600],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête avec bouton de fermeture
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Amis intéressés',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: mapcolors.MapColors.leisurePrimary,
                ),
              ),
              if (onClose != null)
                IconButton(
                  icon: Icon(Icons.close),
                  onPressed: onClose,
                ),
            ],
          ),
          Divider(),
          
          // Liste des amis
          Expanded(
            child: ListView.builder(
              itemCount: followings.length,
              itemBuilder: (context, index) {
                final following = followings[index];
                final String followingId = following['id'] ?? following['_id'] ?? '';
                final String name = following['name'] ?? 'Ami';
                final String photoUrl = following['photo_url'] ?? following['avatar'] ?? '';
                
                // Vérifier si cet ami a exprimé un intérêt
                final bool hasInterest = interests.any((i) => 
                  (i['userId'] == followingId || i['user_id'] == followingId));
                
                // Vérifier si cet ami a fait un choix
                final bool hasChoice = choices.any((c) => 
                  (c['userId'] == followingId || c['user_id'] == followingId));
                
                return Card(
                  elevation: 2,
                  margin: EdgeInsets.symmetric(vertical: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      radius: 20,
                      backgroundImage: getImageProvider(photoUrl) ?? const AssetImage('assets/images/default_avatar.png'),
                      backgroundColor: Colors.grey[200],
                      child: getImageProvider(photoUrl) == null ? Icon(Icons.person, color: Colors.grey[400]) : null,
                    ),
                    title: Text(
                      name,
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Row(
                      children: [
                        if (hasInterest)
                          Container(
                            margin: EdgeInsets.only(right: 8),
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.star_border, size: 14, color: Colors.amber),
                                SizedBox(width: 4),
                                Text(
                                  'Intéressé',
                                  style: TextStyle(
                                    color: Colors.amber[800],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (hasChoice)
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle_outline, size: 14, color: Colors.green),
                                SizedBox(width: 4),
                                Text(
                                  'A visité',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    trailing: IconButton(
                      icon: Icon(Icons.message_outlined),
                      onPressed: () {
                        // TODO: Implémenter la fonction pour envoyer un message à l'ami
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Envoyer un message à $name'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      tooltip: 'Envoyer un message',
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
} 
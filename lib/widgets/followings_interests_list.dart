import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../constants/colors.dart';
import '../utils/map_colors.dart' as mapcolors;

class FollowingsInterestsList extends StatefulWidget {
  final Map<String, dynamic> followingsData;
  final VoidCallback onClose;

  const FollowingsInterestsList({
    Key? key,
    required this.followingsData,
    required this.onClose,
  }) : super(key: key);

  @override
  _FollowingsInterestsListState createState() => _FollowingsInterestsListState();
}

class _FollowingsInterestsListState extends State<FollowingsInterestsList> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<dynamic> interests = widget.followingsData['interests'] ?? [];
    final List<dynamic> choices = widget.followingsData['choices'] ?? [];
    final List<dynamic> followings = widget.followingsData['followings'] ?? [];
    
    // Créer un map pour retrouver les détails des followings par ID
    final Map<String, dynamic> followingsMap = {};
    for (var following in followings) {
      final id = following['_id'] ?? following['id'] ?? '';
      if (id.isNotEmpty) {
        followingsMap[id] = following;
      }
    }
    
    return Column(
      children: [
        // En-tête
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Amis intéressés',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            IconButton(
              icon: Icon(Icons.close),
              onPressed: widget.onClose,
            ),
          ],
        ),
        
        // Compteurs
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            children: [
              Icon(
                Icons.people,
                size: 16,
                color: mapcolors.MapColors.leisurePrimary,
              ),
              SizedBox(width: 8),
              Text(
                '${interests.length} intéressés • ${choices.length} ont visité',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
        ),
        
        // Tabs
        TabBar(
          controller: _tabController,
          labelColor: mapcolors.MapColors.leisurePrimary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: mapcolors.MapColors.leisurePrimary,
          tabs: [
            Tab(text: 'Intéressés (${interests.length})'),
            Tab(text: 'Ont visité (${choices.length})'),
          ],
        ),
        
        SizedBox(height: 8),
        
        // Contenu des tabs
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // Tab Intéressés
              interests.isEmpty
                ? _buildEmptyState('Aucun ami n\'est intéressé pour le moment')
                : _buildFollowingsList(interests, followingsMap, true),
              
              // Tab Choix/Visites
              choices.isEmpty
                ? _buildEmptyState('Aucun ami n\'a encore visité ce lieu')
                : _buildFollowingsList(choices, followingsMap, false),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 64,
            color: Colors.grey[400],
          ),
          SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  Widget _buildFollowingsList(List<dynamic> items, Map<String, dynamic> followingsMap, bool isInterest) {
    return ListView.builder(
      itemCount: items.length,
      padding: EdgeInsets.only(bottom: 16),
      itemBuilder: (context, index) {
        final item = items[index];
        final followingId = item['userId'] ?? '';
        final followingData = followingsMap[followingId];
        
        if (followingData == null) {
          return SizedBox.shrink();
        }
        
        final String name = followingData['firstName'] ?? followingData['username'] ?? 'Utilisateur';
        final String imageUrl = followingData['profilePicture'] ?? '';
        final String comment = item['comment'] ?? '';
        final DateTime? date = item['createdAt'] != null 
            ? DateTime.tryParse(item['createdAt']) 
            : null;
        
        return Card(
          margin: EdgeInsets.symmetric(vertical: 6),
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar
                CircleAvatar(
                  radius: 24,
                  backgroundImage: imageUrl.isNotEmpty ? getImageProvider(imageUrl) ?? const AssetImage('assets/images/default_avatar.png') : null,
                  backgroundColor: Colors.grey[200],
                  child: imageUrl.isEmpty ? Icon(Icons.person, color: Colors.grey[400]) : null,
                ),
                
                SizedBox(width: 16),
                
                // Contenu
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Nom et badge
                      Row(
                        children: [
                          Text(
                            name,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(width: 8),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isInterest 
                                  ? Colors.amber.withOpacity(0.2) 
                                  : Colors.green.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              isInterest ? 'Intéressé' : 'A visité',
                              style: TextStyle(
                                fontSize: 12,
                                color: isInterest ? Colors.amber[800] : Colors.green[700],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      // Date
                      if (date != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            _formatDate(date),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      
                      // Commentaire
                      if (comment.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            comment,
                            style: TextStyle(
                              fontSize: 14,
                            ),
                          ),
                        ),
                      
                      // Bouton message
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () {
                            // Naviguer vers la conversation avec ce following
                            Navigator.of(context).pop(); // Fermer le bottom sheet
                            _navigateToConversation(followingId);
                          },
                          icon: Icon(
                            Icons.message_outlined, 
                            size: 16,
                            color: mapcolors.MapColors.leisurePrimary,
                          ),
                          label: Text(
                            'Message',
                            style: TextStyle(
                              color: mapcolors.MapColors.leisurePrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            minimumSize: Size(0, 0),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays < 1) {
      if (difference.inHours < 1) {
        return 'Il y a ${difference.inMinutes} min';
      } else {
        return 'Il y a ${difference.inHours} h';
      }
    } else if (difference.inDays < 7) {
      return 'Il y a ${difference.inDays} jour${difference.inDays > 1 ? 's' : ''}';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
  
  void _navigateToConversation(String followingId) {
    // Implémenter la navigation vers la page de conversation avec ce following
    print('Naviguer vers la conversation avec le following: $followingId');
    // Navigator.of(context).pushNamed('/conversations/$followingId');
  }
} 
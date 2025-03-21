import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'producer_screen.dart'; // Pour les détails des restaurants
import 'producerLeisure_screen.dart'; // Pour les producteurs de loisirs
import 'eventLeisure_screen.dart'; // Pour les événements
import 'messaging_screen.dart';
import 'utils.dart';

/// Classe delegate pour TabBar persistant
class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;

  _SliverAppBarDelegate(this._tabBar);

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      child: _tabBar,
    );
  }

  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  double get minExtent => _tabBar.preferredSize.height;

  @override
  bool shouldRebuild(covariant _SliverAppBarDelegate oldDelegate) {
    return false;
  }
}

class ProfileScreen extends StatefulWidget {
  final String userId;
  final String viewMode;

  const ProfileScreen({Key? key, required this.userId, this.viewMode = 'private'}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<Map<String, dynamic>> _userFuture;
  late Future<List<dynamic>> _postsFuture;
  bool _isFollowing = false;

  @override
  void initState() {
    super.initState();
    _userFuture = _fetchUserProfile(widget.userId);
    _userFuture.then((user) {
      _postsFuture = _fetchUserPosts(user['posts'] ?? []);
      _checkFollowStatus();
    });
  }

  /// Récupère le profil de l'utilisateur à afficher
  Future<Map<String, dynamic>> _fetchUserProfile(String userId) async {
    final url = Uri.parse('${getBaseUrl()}/api/users/$userId');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Erreur lors du chargement du profil utilisateur.');
    }
  }

  /// Récupère les posts de l'utilisateur
  Future<List<dynamic>> _fetchUserPosts(List<dynamic> postIds) async {
    if (postIds.isEmpty) return [];

    final List<dynamic> posts = [];
    for (final postId in postIds) {
      final url = Uri.parse('${getBaseUrl()}/api/posts/$postId');
      try {
        final response = await http.get(url);
        if (response.statusCode == 200) {
          posts.add(json.decode(response.body));
        } else {
          print('❌ Erreur HTTP pour le post $postId : ${response.statusCode}');
        }
      } catch (e) {
        print('❌ Erreur réseau pour le post $postId : $e');
      }
    }
    return posts;
  }

  /// Vérifie si l'utilisateur connecté suit cet utilisateur
  void _checkFollowStatus() async {
    // Implémenter la vérification de statut de suivi
    setState(() {
      _isFollowing = false; // Valeur par défaut, à remplacer par une vérification réelle
    });
  }

  /// Suivre l'utilisateur
  Future<void> _followUser(String userId) async {
    try {
      final url = Uri.parse('${getBaseUrl()}/api/users/follow');
      final body = {
        'follower_id': 'current_user_id', // Remplacer par l'ID de l'utilisateur connecté
        'following_id': userId,
      };

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        setState(() {
          _isFollowing = true;
        });
      } else {
        print('❌ Erreur HTTP : ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Erreur réseau : $e');
    }
  }

  /// Arrêter de suivre l'utilisateur
  Future<void> _unfollowUser(String userId) async {
    try {
      final url = Uri.parse('${getBaseUrl()}/api/users/unfollow');
      final body = {
        'follower_id': 'current_user_id', // Remplacer par l'ID de l'utilisateur connecté
        'following_id': userId,
      };

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        setState(() {
          _isFollowing = false;
        });
      } else {
        print('❌ Erreur HTTP : ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Erreur réseau : $e');
    }
  }

  /// Navigation vers les détails d'un producteur ou événement
  Future<void> _navigateToDetails(String id, String type) async {
    print('🔍 Navigation vers l\'ID : $id (Type : $type)');

    try {
      final String endpoint;
      switch (type) {
        case 'restaurant':
          endpoint = 'producers';
          break;
        case 'leisureProducer':
          endpoint = 'leisureProducers';
          break;
        case 'event':
          endpoint = 'events';
          break;
        default:
          throw Exception("Type non reconnu pour l'ID : $id");
      }

      final url = Uri.parse('${getBaseUrl()}/api/$endpoint/$id');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (type == 'restaurant') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProducerScreen(producerId: id),
            ),
          );
        } else if (type == 'leisureProducer') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProducerLeisureScreen(producerData: data),
            ),
          );
        } else if (type == 'event') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EventLeisureScreen(eventData: data),
            ),
          );
        }
      } else {
        print("Erreur lors de la récupération des détails : ${response.body}");
      }
    } catch (e) {
      print("Erreur réseau : $e");
    }
  }

  /// Démarrer une conversation avec cet utilisateur
  Future<void> _startConversation(String recipientId) async {
    // Implémenter la fonctionnalité de messagerie
    try {
      final url = Uri.parse('${getBaseUrl()}/api/conversations/check-or-create');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'senderId': 'current_user_id',  // Remplacer par l'ID de l'utilisateur connecté
          'recipientId': recipientId,
        }),
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        final conversationId = data['conversationId'];
        print('✅ Conversation commencée avec succès, ID : $conversationId');

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              userId: 'current_user_id', // Remplacer par l'ID de l'utilisateur connecté
              conversationId: conversationId,
              name: 'Nom du destinataire', // Remplacer par le nom de l'utilisateur de ce profil
              image: 'URL de l\'image', // Remplacer par l'URL de l'image de l'utilisateur de ce profil
            ),
          ),
        );
      } else {
        print('❌ Erreur lors de la création de la conversation : ${response.body}');
      }
    } catch (e) {
      print('❌ Erreur réseau : $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3, // Trois onglets : Posts, Interests, Choices
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        body: FutureBuilder<Map<String, dynamic>>(
          future: _userFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text('Erreur : ${snapshot.error}'));
            }

            final user = snapshot.data!;

            return NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  // AppBar avec profil et actions
                  SliverAppBar(
                    expandedHeight: 220.0,
                    floating: false,
                    pinned: true,
                    backgroundColor: Colors.indigo,
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    flexibleSpace: FlexibleSpaceBar(
                      background: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.indigo.shade800,
                              Colors.indigo.shade500,
                            ],
                          ),
                        ),
                        child: Stack(
                          children: [
                            // Background effet
                            Positioned.fill(
                              child: Opacity(
                                opacity: 0.1,
                                child: Image.network(
                                  user['photo_url'] ?? 'https://via.placeholder.com/500',
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            // Contenu du header
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    // Photo de profil
                                    Container(
                                      width: 100,
                                      height: 100,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 3),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.2),
                                            blurRadius: 8,
                                            offset: const Offset(0, 3),
                                          ),
                                        ],
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(50),
                                        child: CachedNetworkImage(
                                          imageUrl: user['photo_url'] ?? 'https://via.placeholder.com/150',
                                          fit: BoxFit.cover,
                                          placeholder: (context, url) => Container(
                                            color: Colors.grey[300],
                                            child: const Center(child: CircularProgressIndicator()),
                                          ),
                                          errorWidget: (context, url, error) => Container(
                                            color: Colors.grey[300],
                                            child: const Icon(Icons.person, size: 50, color: Colors.white),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    // Nom de l'utilisateur
                                    Text(
                                      user['name'] ?? 'Nom non spécifié',
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        shadows: [
                                          Shadow(
                                            offset: Offset(0, 1),
                                            blurRadius: 3,
                                            color: Colors.black26,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    // Bio
                                    Text(
                                      user['bio'] ?? 'Bio non spécifiée',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w300,
                                      ),
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  // Stats et boutons d'interaction
                  SliverToBoxAdapter(
                    child: Container(
                      color: Colors.white,
                      child: Column(
                        children: [
                          _buildStatsSection(user),
                          const Divider(height: 1),
                          _buildFollowButton(user),
                          const Divider(height: 1),
                          _buildLikedTags(user),
                        ],
                      ),
                    ),
                  ),
                  
                  // TabBar
                  SliverPersistentHeader(
                    delegate: _SliverAppBarDelegate(
                      TabBar(
                        tabs: const [
                          Tab(text: 'POSTS', icon: Icon(Icons.article_outlined, size: 20)),
                          Tab(text: 'INTÉRÊTS', icon: Icon(Icons.favorite_border, size: 20)),
                          Tab(text: 'CHOICES', icon: Icon(Icons.check_circle_outline, size: 20)),
                        ],
                        labelColor: Colors.indigo,
                        unselectedLabelColor: Colors.grey,
                        indicatorColor: Colors.indigo,
                        indicatorWeight: 3,
                      ),
                    ),
                    pinned: true,
                  ),
                ];
              },
              body: TabBarView(
                children: [
                  // Section Posts
                  _buildPostsSection(),
                  
                  // Section Interests
                  _buildInterestsSection(user),
                  
                  // Section Choices
                  _buildChoicesSection(user),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // Removed duplicate _SliverAppBarDelegate class

  Widget _buildStatsSection(Map<String, dynamic> user) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatItem('Abonnés', user['followers_count'].toString()),
          Container(
            height: 40,
            width: 1,
            color: Colors.grey[300],
          ),
          _buildStatItem('Abonnements', user['following_count'].toString()),
          Container(
            height: 40,
            width: 1,
            color: Colors.grey[300],
          ),
          _buildStatItem('Interactions', user['interaction_metrics']['total_interactions'].toString()),
        ],
      ),
    );
  }

  Widget _buildStatItem(String title, String count) {
    return Column(
      children: [
        Text(
          count,
          style: TextStyle(
            fontSize: 22, 
            fontWeight: FontWeight.bold,
            color: Colors.indigo,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            fontSize: 13, 
            color: Colors.grey[700],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildFollowButton(Map<String, dynamic> user) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: _isFollowing
                ? ElevatedButton.icon(
                    onPressed: () => _unfollowUser(user['_id']),
                    icon: const Icon(Icons.person_remove),
                    label: const Text('Ne plus suivre'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  )
                : ElevatedButton.icon(
                    onPressed: () => _followUser(user['_id']),
                    icon: const Icon(Icons.person_add),
                    label: const Text('Suivre'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          CircleAvatar(
            radius: 25,
            backgroundColor: Colors.indigo.withOpacity(0.1),
            child: IconButton(
              icon: Icon(Icons.message, color: Colors.indigo),
              onPressed: () => _startConversation(user['_id']),
              tooltip: 'Envoyer un message',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLikedTags(Map<String, dynamic> user) {
    final tags = user['liked_tags'] ?? [];
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.label, size: 18, color: Colors.indigo.shade700),
              const SizedBox(width: 8),
              Text(
                'Centres d\'intérêt',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: tags.map<Widget>((tag) {
              return Chip(
                label: Text(tag),
                backgroundColor: Colors.indigo.withOpacity(0.1),
                labelStyle: TextStyle(color: Colors.indigo.shade700, fontSize: 13),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.indigo.withOpacity(0.2)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 2),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPostsSection() {
    return FutureBuilder<List<dynamic>>(
      future: _postsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Erreur : ${snapshot.error}'));
        }

        final posts = snapshot.data ?? [];
        if (posts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.post_add, size: 60, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'Aucune publication',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final post = posts[index];
            return _buildPostCard(post);
          },
        );
      },
    );
  }

  Widget _buildPostCard(Map<String, dynamic> post) {
    final mediaUrls = post['media'] as List<dynamic>? ?? [];
    final hasLocation = post['location'] != null && post['location']['name'] != null;
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête du post
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.indigo.withOpacity(0.3), width: 2),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: CachedNetworkImage(
                      imageUrl: post['photo_url'] ?? 'https://via.placeholder.com/100',
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: Colors.grey[200],
                        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[200],
                        child: const Icon(Icons.person, color: Colors.grey),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post['author_name'] ?? 'Nom non spécifié',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      if (hasLocation)
                        Row(
                          children: [
                            Icon(Icons.place, size: 12, color: Colors.indigo.shade300),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                post['location']['name'],
                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.more_vert, color: Colors.grey),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    // Options supplémentaires
                  },
                ),
              ],
            ),
          ),
          
          // Titre et contenu
          if (post['title'] != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Text(
                post['title'],
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            
          if (post['content'] != null) 
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Text(
                post['content'],
                style: const TextStyle(fontSize: 14),
              ),
            ),
          
          // Média
          if (mediaUrls.isNotEmpty)
            SizedBox(
              height: 250,
              child: PageView.builder(
                itemCount: mediaUrls.length,
                itemBuilder: (context, index) {
                  return CachedNetworkImage(
                    imageUrl: mediaUrls[index],
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: Colors.grey[200],
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey[200],
                      child: const Center(child: Icon(Icons.broken_image, size: 50)),
                    ),
                  );
                },
              ),
            ),
          
          // Boutons d'action
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionButton(
                  icon: Icons.thumb_up_outlined,
                  label: post['likes']?.length.toString() ?? '0',
                  onPressed: () {
                    // Like functionality
                  },
                ),
                _buildActionButton(
                  icon: Icons.mode_comment_outlined,
                  label: post['comments']?.length.toString() ?? '0',
                  onPressed: () {
                    // Comment functionality
                  },
                ),
                _buildActionButton(
                  icon: Icons.check_circle_outline,
                  label: 'Choice',
                  onPressed: () {
                    _showChoiceDialog(context, post);
                  },
                  color: Colors.indigo,
                ),
                _buildActionButton(
                  icon: Icons.share_outlined,
                  label: 'Partager',
                  onPressed: () {
                    // Share functionality
                  },
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    Color? color,
  }) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18, color: color ?? Colors.grey[700]),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: color ?? Colors.grey[700],
        ),
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  void _showChoiceDialog(BuildContext context, Map<String, dynamic> post) {
    if (post['location'] == null || post['location']['_id'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ce post n\'est pas associé à un lieu')),
      );
      return;
    }

    final String locationId = post['location']['_id'];
    final String locationType = post['location']['type'] ?? 'unknown';
    final String locationName = post['location']['name'] ?? 'Lieu inconnu';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.85,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              builder: (_, scrollController) {
                return Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: _buildChoiceForm(context, locationId, locationType, locationName),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildChoiceForm(BuildContext context, String locationId, String locationType, String locationName) {
    double qualiteGenerale = 5.0;
    double interet = 5.0;
    double originalite = 5.0;
    String appreciationGlobale = '';
    
    return StatefulBuilder(
      builder: (context, setState) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // En-tête
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.indigo,
                    child: Icon(
                      locationType == 'restaurant' ? Icons.restaurant : Icons.event,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Ajouter un Choice',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          locationName,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[700],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              
              const Divider(height: 30),
              
              // Qualité générale
              const Text(
                'Qualité générale',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: qualiteGenerale,
                      min: 0.0,
                      max: 10.0,
                      divisions: 10,
                      activeColor: Colors.indigo,
                      label: qualiteGenerale.round().toString(),
                      onChanged: (value) {
                        setState(() {
                          qualiteGenerale = value;
                        });
                      },
                    ),
                  ),
                  Container(
                    width: 40,
                    alignment: Alignment.center,
                    child: Text(
                      qualiteGenerale.round().toString(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Intérêt
              const Text(
                'Intérêt',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: interet,
                      min: 0.0,
                      max: 10.0,
                      divisions: 10,
                      activeColor: Colors.indigo,
                      label: interet.round().toString(),
                      onChanged: (value) {
                        setState(() {
                          interet = value;
                        });
                      },
                    ),
                  ),
                  Container(
                    width: 40,
                    alignment: Alignment.center,
                    child: Text(
                      interet.round().toString(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Originalité
              const Text(
                'Originalité',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: originalite,
                      min: 0.0,
                      max: 10.0,
                      divisions: 10,
                      activeColor: Colors.indigo,
                      label: originalite.round().toString(),
                      onChanged: (value) {
                        setState(() {
                          originalite = value;
                        });
                      },
                    ),
                  ),
                  Container(
                    width: 40,
                    alignment: Alignment.center,
                    child: Text(
                      originalite.round().toString(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
              
              // Appréciation globale
              const Text(
                'Appréciation globale',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Partagez votre expérience...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.indigo, width: 2),
                  ),
                ),
                onChanged: (value) {
                  appreciationGlobale = value;
                },
              ),
              
              const SizedBox(height: 30),
              
              // Bouton de soumission
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    // Soumettre le Choice
                    _submitChoice(
                      context,
                      locationId,
                      locationType,
                      qualiteGenerale.round(),
                      interet.round(),
                      originalite.round(),
                      appreciationGlobale,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text(
                    'SOUMETTRE MON CHOICE',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _submitChoice(
    BuildContext context,
    String locationId,
    String locationType,
    int qualiteGenerale,
    int interet,
    int originalite,
    String appreciationGlobale,
  ) async {
    try {
      final url = Uri.parse('${getBaseUrl()}/api/choices');
      
      final payload = {
        'userId': 'current_user_id', // Remplacer par l'ID de l'utilisateur connecté
        'targetId': locationId,
        'targetType': locationType,
        'aspects': {
          'qualité générale': qualiteGenerale,
          'intérêt': interet,
          'originalité': originalite,
        },
        'appréciation_globale': appreciationGlobale,
      };
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      );
      
      if (response.statusCode == 201) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Votre Choice a été ajouté avec succès!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception('Failed to submit choice: ${response.body}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildInterestsSection(Map<String, dynamic> user) {
    final interests = user['interests'] ?? [];

    if (interests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite_border, size: 60, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Aucun intérêt enregistré',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.8,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: interests.length,
      itemBuilder: (context, index) {
        final interestId = interests[index];
        final interestName = 'Lieu favori';
        final imageUrl = 'https://via.placeholder.com/300';
        
        return GestureDetector(
          onTap: () {
            _navigateToDetails(interestId, 'interest');
          },
          child: Card(
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 2,
            child: Stack(
              children: [
                // Image
                Positioned.fill(
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: Colors.grey[200],
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey[200],
                      child: const Center(child: Icon(Icons.broken_image, size: 40)),
                    ),
                  ),
                ),
                // Overlay pour lisibilité
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.7),
                        ],
                      ),
                    ),
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          interestName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.place, size: 12, color: Colors.white70),
                            const SizedBox(width: 4),
                            const Text(
                              'Voir détails',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                // Badge Intérêt
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.pink.shade400,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.favorite, color: Colors.white, size: 12),
                        SizedBox(width: 4),
                        Text(
                          'FAVORI',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildChoicesSection(Map<String, dynamic> user) {
    final choices = user['choices'] ?? [];

    if (choices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 60, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Aucun Choice ajouté',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.8,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: choices.length,
      itemBuilder: (context, index) {
        final choice = choices[index];
        final targetId = choice['targetId'];
        final comment = choice['comment'] ?? '';
        final targetName = choice['targetName'] ?? 'Lieu non spécifié';
        final imageUrl = choice['imageUrl'] ?? 'https://via.placeholder.com/300';
        
        return GestureDetector(
          onTap: () {
            _navigateToDetails(targetId, 'choice');
          },
          child: Card(
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image en haut
                Expanded(
                  child: Stack(
                    children: [
                      // Image
                      Positioned.fill(
                        child: CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: Colors.grey[200],
                            child: const Center(child: CircularProgressIndicator()),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: Colors.grey[200],
                            child: const Center(child: Icon(Icons.broken_image, size: 40)),
                          ),
                        ),
                      ),
                      // Overlay pour lisibilité
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.7),
                              ],
                            ),
                          ),
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                targetName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (choice['aspects'] != null) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.star, size: 14, color: Colors.amber),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${(choice['aspects']['qualité générale'] as int? ?? 0)}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      // Badge Choice
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.indigo,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle, color: Colors.white, size: 12),
                              SizedBox(width: 4),
                              Text(
                                'CHOICE',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Commentaire en bas si présent
                if (comment.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      comment,
                      style: const TextStyle(fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'producer_screen.dart'; // Pour les détails des restaurants
import 'producerLeisure_screen.dart'; // Pour les producteurs de loisirs
import 'eventLeisure_screen.dart'; // Pour les événements
import 'messaging_screen.dart';
import 'utils.dart';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;

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

class MyProfileScreen extends StatefulWidget {
  final String userId;

  const MyProfileScreen({Key? key, required this.userId}) : super(key: key);

  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen> {
  late Future<Map<String, dynamic>> _userFuture;
  late Future<List<dynamic>> _postsFuture;

  @override
  void initState() {
    super.initState();
    _userFuture = _fetchUserProfile(widget.userId);
    _userFuture.then((user) {
      _postsFuture = _fetchUserPosts(user['posts'] ?? []);
    });
  }

  /// Récupère le profil utilisateur
  Future<Map<String, dynamic>> _fetchUserProfile(String userId) async {
    final url = Uri.parse('${getBaseUrl()}/api/users/$userId');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Erreur lors du chargement du profil utilisateur.');
    }
  }

  /// Récupère les posts associés à l'utilisateur
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

  Future<void> _startConversation(String recipientId) async {
    // Vérifier si l'ID de l'utilisateur est le même que celui du destinataire
    if (widget.userId == recipientId) {
      print('Les IDs sont identiques ! Impossible de commencer une conversation.');
      return; // Retourner si l'ID de l'utilisateur et du destinataire sont identiques
    }

    try {
      final url = Uri.parse('${getBaseUrl()}/api/conversations/check-or-create');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'senderId': widget.userId,  // ID de l'utilisateur connecté
          'recipientId': recipientId, // ID du destinataire (l'ID du profil)
        }),
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        final conversationId = data['conversationId'];
        print('Conversation commencée avec succès, ID : $conversationId');

        // Navigation vers l'écran de messagerie avec la conversation
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              userId: widget.userId,
              conversationId: data['conversationId'], // Passe l'ID de la conversation ici
              name: 'Nom du destinataire', // Vous pouvez aussi obtenir le nom du destinataire
              image: 'URL de l\'image', // Passez l'image du destinataire ici
            ),
          ),
        );
      } else {
        print('Erreur lors de la création de la conversation : ${response.body}');
      }
    } catch (e) {
      print('Erreur réseau : $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3, // Trois onglets : Posts, Choices, Interests
      child: Scaffold(
        backgroundColor: Colors.grey[100], // Fond légèrement plus clair
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
                    expandedHeight: 200.0,
                    floating: false,
                    pinned: true,
                    backgroundColor: Colors.teal,
                    flexibleSpace: FlexibleSpaceBar(
                      background: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.teal.shade800,
                              Colors.teal.shade500,
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
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 70, 20, 20),
                              child: Row(
                                children: [
                                  // Photo de profil
                                  Container(
                                    width: 80,
                                    height: 80,
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
                                      borderRadius: BorderRadius.circular(40),
                                      child: CachedNetworkImage(
                                        imageUrl: user['photo_url'] ?? 'https://via.placeholder.com/150',
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) => Container(
                                          color: Colors.grey[300],
                                          child: const Center(child: CircularProgressIndicator()),
                                        ),
                                        errorWidget: (context, url, error) => Container(
                                          color: Colors.grey[300],
                                          child: const Icon(Icons.person, size: 40, color: Colors.white),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 20),
                                  // Info utilisateur
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          user['name'] ?? 'Nom non spécifié',
                                          style: const TextStyle(
                                            fontSize: 22,
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
                                        Text(
                                          user['bio'] ?? 'Bio non spécifiée',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: Colors.white,
                                            fontWeight: FontWeight.w300,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.white),
                        onPressed: () {
                          // Modifier le profil (à implémenter)
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Édition de profil à venir')),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_a_photo, color: Colors.white),
                        onPressed: () {
                          // Naviguer vers la page de création de post
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CreatePostScreen(userId: widget.userId),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  
                  // Stats et tags
                  SliverToBoxAdapter(
                    child: Container(
                      color: Colors.white,
                      child: Column(
                        children: [
                          _buildStatsSection(user),
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
                          Tab(text: 'CHOICES', icon: Icon(Icons.check_circle_outline, size: 20)),
                          Tab(text: 'INTÉRÊTS', icon: Icon(Icons.favorite_border, size: 20)),
                        ],
                        labelColor: Colors.teal,
                        unselectedLabelColor: Colors.grey,
                        indicatorColor: Colors.teal,
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
                  
                  // Section Choices
                  _buildChoicesSection(user),
                  
                  // Section Interests
                  _buildInterestsSection(user),
                ],
              ),
            );
          },
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            // Naviguer vers la page de création de post
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CreatePostScreen(userId: widget.userId),
              ),
            );
          },
          backgroundColor: Colors.teal,
          child: const Icon(Icons.add),
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
          _buildStatItem('Publications', user['posts']?.length.toString() ?? '0'),
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
          style: const TextStyle(
            fontSize: 22, 
            fontWeight: FontWeight.bold,
            color: Colors.teal,
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
              Icon(Icons.label, size: 18, color: Colors.teal.shade700),
              const SizedBox(width: 8),
              Text(
                'Centres d\'intérêt',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal.shade700,
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
                backgroundColor: Colors.teal.withOpacity(0.1),
                labelStyle: TextStyle(color: Colors.teal.shade700, fontSize: 13),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.teal.withOpacity(0.2)),
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
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CreatePostScreen(userId: widget.userId),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Créer un post'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
    
    return GestureDetector(
      onTap: () => _navigateToPostDetail(post),
      child: Card(
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
                      border: Border.all(color: Colors.teal.withOpacity(0.3), width: 2),
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
                              Icon(Icons.place, size: 12, color: Colors.teal.shade300),
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
                    onPressed: () => _navigateToPostDetail(post),
                  ),
                  _buildActionButton(
                    icon: Icons.check_circle_outline,
                    label: 'Choice',
                    onPressed: () {
                      _showChoiceDialog(context, post);
                    },
                    color: Colors.teal,
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
                    backgroundColor: Colors.teal,
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
                      activeColor: Colors.teal,
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
                      activeColor: Colors.teal,
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
                      activeColor: Colors.teal,
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
                    borderSide: const BorderSide(color: Colors.teal, width: 2),
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
                    backgroundColor: Colors.teal,
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
        'userId': widget.userId,
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
            const SizedBox(height: 8),
            Text(
              'Partagez votre avis sur les lieux que vous avez visités',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
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
                            color: Colors.teal,
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
            const SizedBox(height: 8),
            Text(
              'Ajoutez des lieux à vos favoris pour les retrouver ici',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
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

  void _navigateToPostDetail(Map<String, dynamic> post) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PostDetailScreen(post: post, userId: widget.userId),
      ),
    );
  }

}
class PostDetailScreen extends StatefulWidget {
  final Map<String, dynamic> post;
  final String userId;

  const PostDetailScreen({Key? key, required this.post, required this.userId}) : super(key: key);

  @override
  _PostDetailScreenState createState() => _PostDetailScreenState();
}


class _PostDetailScreenState extends State<PostDetailScreen> {
  final TextEditingController _commentController = TextEditingController();
  late Map<String, dynamic> post; // Variable pour stocker le post
  bool _commentsVisible = false;

  @override
  void initState() {
    super.initState();
    post = widget.post; // Initialise le post à partir du widget parent
  }

  /// Navigation vers les détails du producteur ou événement
  void _navigateToProducer(String targetId, String type) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProducerScreen(producerId: targetId),
      ),
    );
  }

  /// Fonction pour liker un post
  Future<void> _likePost(String postId) async {
    final url = Uri.parse('${getBaseUrl()}/api/posts/$postId/like');
    final body = {'user_id': widget.userId};

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final updatedLikes = json.decode(response.body)['likes'];
        setState(() {
          post['likes'] = updatedLikes;
        });
        print('✅ Post liké avec succès');
      } else {
        print('❌ Erreur lors du like : ${response.body}');
      }
    } catch (e) {
      print('❌ Erreur réseau lors du like : $e');
    }
  }

  /// Fonction pour ajouter un choix (choice)
  Future<void> _addChoice(String postId) async {
    final url = Uri.parse('${getBaseUrl()}/api/posts/$postId/choice');
    final body = {'user_id': widget.userId};

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final updatedChoices = json.decode(response.body)['choices'];
        setState(() {
          post['choices'] = updatedChoices;
        });
        print('✅ Choice ajouté avec succès');
      } else {
        print('❌ Erreur lors de l\'ajout aux choices : ${response.body}');
      }
    } catch (e) {
      print('❌ Erreur réseau lors de l\'ajout aux choices : $e');
    }
  }

  /// Fonction pour ajouter un commentaire
  Future<void> _addComment(String postId, String content) async {
    final url = Uri.parse('${getBaseUrl()}/api/posts/$postId/comments');
    final body = {
      'user_id': widget.userId,
      'content': content,
    };

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (response.statusCode == 201) {
        final newComment = json.decode(response.body);
        setState(() {
          post['comments'].add(newComment);
        });
        print('✅ Commentaire ajouté avec succès');
      } else {
        print('❌ Erreur lors de l\'ajout du commentaire : ${response.body}');
      }
    } catch (e) {
      print('❌ Erreur réseau pour l\'ajout du commentaire : $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaUrls = post['media'] as List<dynamic>? ?? [];
    final producerName = post['location']?['name'] ?? 'Producteur inconnu';

    return Scaffold(
      appBar: AppBar(
        title: Text(post['title'] ?? 'Détails du post'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header du post
            Row(
              children: [
                CircleAvatar(
                  backgroundImage: NetworkImage(
                    post['user_photo'] ?? 'https://via.placeholder.com/150',
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  post['author_name'] ?? 'Utilisateur inconnu',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Titre et contenu
            Text(
              post['title'] ?? 'Titre non spécifié',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              post['content'] ?? 'Contenu non disponible',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),

            // Médias associés
            if (mediaUrls.isNotEmpty)
              SizedBox(
                height: 300,
                child: PageView(
                  children: mediaUrls.map((url) {
                    return Image.network(
                      url,
                      fit: BoxFit.cover,
                      width: double.infinity,
                    );
                  }).toList(),
                ),
              ),
            const SizedBox(height: 20),

            // Lien vers le producteur
            InkWell(
              onTap: () => print('Naviguer vers le producteur $producerName'),
              child: Text(
                producerName,
                style: const TextStyle(
                  color: Colors.blue,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Actions sur le post (like, choice, partage)
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.thumb_up_alt_outlined),
                  onPressed: () => _likePost(post['_id']),
                ),
                IconButton(
                  icon: const Icon(Icons.favorite_border),
                  onPressed: () => _addChoice(post['_id']),
                ),
                IconButton(
                  icon: const Icon(Icons.share),
                  onPressed: () {
                    // Fonctionnalité Partage (à implémenter)
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Section des commentaires
            const Text(
              'Commentaires',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            if (post['comments'] != null && post['comments'].isNotEmpty)
              ...post['comments'].map<Widget>((comment) {
                return ListTile(
                  title: Text(comment['user_id']['name'] ?? 'Utilisateur inconnu'),
                  subtitle: Text(comment['content'] ?? ''),
                );
              }).toList(),
            const Divider(),

            // Ajouter un commentaire
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: const InputDecoration(
                      labelText: 'Ajouter un commentaire...',
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () {
                    if (_commentController.text.isNotEmpty) {
                      _addComment(post['_id'], _commentController.text);
                      _commentController.clear();
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class CreatePostScreen extends StatefulWidget {
  final String userId;

  const CreatePostScreen({Key? key, required this.userId}) : super(key: key);

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _locationNameController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  String? _mediaUrl; // Chemin local du fichier média sélectionné
  String? _mediaType; // "image" ou "video"
  bool _isLoading = false;

  List<dynamic> _searchResults = []; // Liste pour stocker les résultats de recherche
  String? _selectedLocationId; // ID de l'élément sélectionné
  String? _selectedLocationType; // Type de l'élément sélectionné (restaurant ou event)
  String? _selectedLocationName; // Nom de l'élément sélectionnéaurant ou event)
  
  /// Fonction pour créer un post
  Future<void> _createPost() async {
    final content = _contentController.text;

    if (content.isEmpty || _selectedLocationId == null || _selectedLocationType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez remplir le contenu et sélectionner un lieu ou un événement.'),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final postData = {
      'user_id': widget.userId,
      'content': content,
      'tags': ['example'], // Exemple de tags, à personnaliser
      'media': _mediaUrl != null ? [_mediaUrl] : [],
      'target_id': _selectedLocationId, // ID du lieu ou événement sélectionné
      'target_type': _selectedLocationType == 'restaurant' ? 'producer' : _selectedLocationType, // Convertir 'restaurant' en 'producer'
      'choice': true, // Ajouter un choix par défaut
    };

    try {
      final url = Uri.parse('${getBaseUrl()}/api/posts');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(postData),
      );

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post créé avec succès !')),
        );
        Navigator.pop(context); // Revenir au profil après la création
      } else {
        print('Erreur : ${response.body}');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors de la création du post.')),
        );
      }
    } catch (e) {
      print('Erreur réseau : $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur réseau.')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }


  /// Fonction pour sélectionner une photo ou une vidéo
  Future<void> _uploadMedia(bool isImage) async {
    final XFile? mediaFile = await (isImage
        ? _picker.pickImage(source: ImageSource.gallery, imageQuality: 50)
        : _picker.pickVideo(source: ImageSource.gallery));

    if (mediaFile != null) {
      final mediaPath = kIsWeb ? mediaFile.path : mediaFile.path;
      final mediaType = isImage ? "image" : "video";

      if (mounted) {
        setState(() {
          _mediaUrl = mediaPath;
          _mediaType = mediaType;
        });
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aucun fichier sélectionné.')),
        );
      }
    }
  }


  /// Fonction pour effectuer une recherche
  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    try {
      final url = Uri.parse('${getBaseUrl()}/api/unified/search?query=$query');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final results = json.decode(response.body) as List<dynamic>;
        setState(() {
          _searchResults = results;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aucun résultat trouvé.')),
        );
        setState(() {
          _searchResults = [];
        });
      }
    } catch (e) {
      print('Erreur réseau : $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur réseau.')),
      );
    }
  }


  void _resetSelection() {
    setState(() {
      _selectedLocationId = null;
      _selectedLocationType = null;
      _selectedLocationName = null;
      _locationNameController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Créer un post'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Contenu',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            TextField(
              controller: _contentController,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: 'Partagez votre expérience...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Rechercher un lieu associé',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            TextField(
              controller: _locationNameController,
              onChanged: _performSearch,
              enabled: _selectedLocationId == null, // Désactiver si un lieu est sélectionné
              decoration: const InputDecoration(
                hintText: 'Recherchez un restaurant ou un événement...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            if (_searchResults.isNotEmpty)
              Container(
                height: 150,
                child: ListView(
                  children: _searchResults.map((item) {
                    final String type = item['type'] ?? 'unknown';
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: NetworkImage(
                          item['image'] ?? item['photo'] ?? '',
                        ),
                      ),
                      title: Text(item['name'] ?? item['intitulé'] ?? 'Nom non spécifié'),
                      subtitle: Text(item['type'] ?? 'Type inconnu'),
                      onTap: () {
                        setState(() {
                          _selectedLocationId = item['_id'];
                          _selectedLocationType = item['type'];
                          _selectedLocationName = item['name'] ?? item['intitulé'];
                          _searchResults = [];
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
            if (_selectedLocationId != null && _selectedLocationType != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Lieu sélectionné : $_selectedLocationName (Type : $_selectedLocationType)',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: _resetSelection,
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),
            const Text(
              'Ajouter un média',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Row(
              children: [
                ElevatedButton(
                  onPressed: () => _uploadMedia(true),
                  child: const Text('Sélectionner une image'),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () => _uploadMedia(false),
                  child: const Text('Sélectionner une vidéo'),
                ),
              ],
            ),
            if (_mediaUrl != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: _mediaType == "image"
                    ? Image.network(_mediaUrl!, height: 200, width: double.infinity, fit: BoxFit.cover)
                    : const Text('Vidéo sélectionnée'),
              ),
            const SizedBox(height: 20),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: _createPost,
                    child: const Text('Poster'),
                  ),
          ],
        ),
      ),
    );
  }
}
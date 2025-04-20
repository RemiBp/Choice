import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'producer_screen.dart'; // Pour les détails des restaurants
import 'producerLeisure_screen.dart'; // Pour les producteurs de loisirs
import 'eventLeisure_screen.dart'; // Pour les événements
import 'messaging_screen.dart';
import 'utils.dart';
import '../models/post.dart'; // Import PostLocation class
import 'conversation_detail_screen.dart'; // Import for conversation detail screen
import '../utils/constants.dart' as constants;
import '../services/app_data_sender_service.dart'; // Import the sender service
import '../utils/location_utils.dart'; // Import location utils
import 'package:google_maps_flutter/google_maps_flutter.dart'; // For LatLng
import '../utils.dart' show getImageProvider;
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
  // Helper method to build placeholder image
  Widget _buildPlaceholderImage(Color bgColor, IconData icon, String text) {
    return Container(
      color: bgColor,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 40, color: Colors.grey),
          const SizedBox(height: 8),
          Text(
            text, 
            style: TextStyle(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  late Future<Map<String, dynamic>> _userFuture;
  late Future<List<dynamic>> _postsFuture;
  bool _isFollowing = false;
  String _currentUserId = '';
  bool _isCurrentUser = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _userFuture = _fetchUserProfile(widget.userId);
    _postsFuture = _fetchUserPosts(widget.userId); // Utiliser widget.userId
    
    _userFuture.then((user) {
      // L'appel à _checkFollowStatus peut rester ici car il dépend de _currentUserId et widget.userId
      if (_currentUserId.isNotEmpty) {
        _checkFollowStatus();
      }
      // Log profile view after fetching user data
      _logProfileViewActivity(widget.userId, 'user'); 
    }).catchError((error) {
      // Gérer les erreurs de _fetchUserProfile si nécessaire
      print("❌ Erreur lors de la récupération du profil pour l'init: $error");
      // On pourrait afficher un message d'erreur persistant ici
    });
  }

  /// Charge l'ID de l'utilisateur courant à partir du stockage local
  Future<void> _loadCurrentUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id') ?? '';
      
      setState(() {
        _currentUserId = userId;
        _isCurrentUser = (userId == widget.userId);
      });

      if (userId.isNotEmpty) {
        print('✅ Utilisateur connecté, ID: $userId');
      } else {
        print('ℹ️ Aucun utilisateur connecté - visualisation de profil en mode public uniquement');
      }
    } catch (e) {
      // En cas d'erreur, simplement définir les valeurs par défaut
      setState(() {
        _currentUserId = '';
        _isCurrentUser = false;
      });
      print('ℹ️ Impossible d\'accéder aux préférences - visualisation de profil en mode public uniquement');
    }
  }

  /// Récupère le profil de l'utilisateur à afficher
  Future<Map<String, dynamic>> _fetchUserProfile(String userId) async {
    // Utiliser la route simple /api/users/:id au lieu de /api/users/:id/profile
    final url = Uri.parse('${constants.getBaseUrl()}/api/users/${userId}');
    
    try {
      // Aucun besoin de vérifier ou d'envoyer le token
      final Map<String, String> headers = {
        'Content-Type': 'application/json',
      };
      
      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
          print('❌ Erreur HTTP: ${response.statusCode} - ${response.body}');
        throw Exception('Erreur lors du chargement du profil utilisateur.');
        }
      } catch (e) {
        print('❌ Erreur réseau: $e');
        throw Exception('Erreur réseau lors du chargement du profil.');
      }
    }

  /// Récupère les posts de l'utilisateur
  Future<List<dynamic>> _fetchUserPosts(String userId) async { // L'argument est maintenant userId (String)
    // Retirer l'ancien argument postIds qui n'est plus utilisé
    // if (postIds.isEmpty) return []; 

    print('🔍 Fetching posts for user ID: $userId'); // Log l'ID utilisé
    try {
      // Utiliser la route API qui récupère tous les posts en une seule requête
      final url = Uri.parse('${constants.getBaseUrl()}/api/users/$userId/posts');
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          // Pas besoin de token ici si les posts sont publics
        }
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ Posts data received: ${data['posts']?.length ?? 0} posts');
        return data['posts'] ?? [];
      } else {
        print('❌ Erreur HTTP lors de la récupération des posts: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ Erreur réseau pour les posts: $e');
      return [];
    }
  }

  /// Vérifie si l'utilisateur courant suit cet utilisateur
  Future<void> _checkFollowStatus() async {
    if (_isCurrentUser || _currentUserId.isEmpty) {
      setState(() {
        _isFollowing = false;
      });
      return;
    }

    try {
      // Utiliser une route plus simple
      final url = Uri.parse('${constants.getBaseUrl()}/api/users/check-following-status?currentUserId=${_currentUserId}&targetUserId=${widget.userId}');
      
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _isFollowing = data['isFollowing'] ?? false;
        });
      } else {
        // En cas d'erreur, simplement considérer que l'utilisateur ne suit pas
        setState(() {
          _isFollowing = false;
        });
      }
    } catch (e) {
      print('⚠️ Impossible de vérifier le statut de suivi: $e');
      setState(() {
        _isFollowing = false;
      });
    }
  }

  /// Suivre l'utilisateur
  Future<void> _followUser(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';
      
      if (token.isEmpty) {
        print('⚠️ Token manquant pour suivre l\'utilisateur');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vous devez être connecté pour suivre cet utilisateur')),
        );
        return;
      }
      
      final url = Uri.parse('${constants.getBaseUrl()}/api/users/follow/$userId');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _isFollowing = true;
        });
        
        // Mettre à jour le nombre d'abonnés dans les données du profil
        _userFuture.then((userMap) {
          setState(() {
            userMap['followers_count'] = data['followers_count'] ?? userMap['followers_count'];
          });
        });
        
        print('✅ Utilisateur suivi avec succès');
      } else {
        print('❌ Erreur HTTP: ${response.statusCode} - ${response.body}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: ${response.statusCode}')),
        );
      }
    } catch (e) {
      print('❌ Erreur réseau: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur réseau: $e')),
      );
    }

    // --- ADDED: Log follow action --- 
    _logGenericUserAction('follow_user', targetUserId: userId);
    // --- End Log --- 
  }

  /// Arrêter de suivre l'utilisateur
  Future<void> _unfollowUser(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';
      
      if (token.isEmpty) {
        print('⚠️ Token manquant pour ne plus suivre l\'utilisateur');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vous devez être connecté pour ne plus suivre cet utilisateur')),
        );
        return;
      }
      
      final url = Uri.parse('${constants.getBaseUrl()}/api/users/unfollow/$userId');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _isFollowing = false;
        });
        
        // Mettre à jour le nombre d'abonnés dans les données du profil
        _userFuture.then((userMap) {
          setState(() {
            userMap['followers_count'] = data['followers_count'] ?? userMap['followers_count'];
          });
        });
        
        print('✅ Utilisateur non suivi avec succès');
      } else {
        print('❌ Erreur HTTP: ${response.statusCode} - ${response.body}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: ${response.statusCode}')),
        );
      }
    } catch (e) {
      print('❌ Erreur réseau: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur réseau: $e')),
      );
    }

    // --- ADDED: Log unfollow action --- 
    _logGenericUserAction('unfollow_user', targetUserId: userId);
    // --- End Log --- 
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

      final url = Uri.parse('${constants.getBaseUrl()}/api/$endpoint/$id');
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
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';
      final currentUserId = prefs.getString('user_id') ?? '';
      
      if (token.isEmpty || currentUserId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vous devez être connecté pour envoyer un message')),
        );
        return;
      }
      
      // Récupérer le nom et la photo de profil du destinataire
      final recipientInfo = await _fetchUserInfo(recipientId);
      final recipientName = recipientInfo['name'] ?? 'Utilisateur';
      final recipientAvatar = recipientInfo['profilePicture'] ?? '';
      
      // Créer ou récupérer une conversation existante
      final url = Uri.parse('${constants.getBaseUrl()}/api/users/conversations/new-message');
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'senderId': currentUserId,
          'recipientIds': [recipientId],
          'content': 'Bonjour! 👋', // Message initial
        }),
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        final conversationId = data['conversationId'];
        print('✅ Conversation commencée avec succès, ID: $conversationId');

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ConversationDetailScreen(
              userId: currentUserId,
              conversationId: conversationId,
              recipientName: recipientName,
              recipientAvatar: recipientAvatar,
            ),
          ),
        );
      } else {
        print('❌ Erreur lors de la création de la conversation: ${response.body}');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors de la création de la conversation')),
        );
      }
    } catch (e) {
      print('❌ Erreur réseau: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }

    // --- ADDED: Log start conversation action --- 
    _logGenericUserAction('start_conversation', targetUserId: recipientId);
    // --- End Log --- 
  }

  Future<Map<String, dynamic>> _fetchUserInfo(String userId) async {
    try {
      final url = Uri.parse('${constants.getBaseUrl()}/api/users/$userId/info');
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {'name': 'Utilisateur', 'profilePicture': ''};
      }
    } catch (e) {
      return {'name': 'Utilisateur', 'profilePicture': ''};
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3, // Trois onglets : Posts, Choices, Intérêts
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        body: FutureBuilder<Map<String, dynamic>>(
          future: _userFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.indigo),
                    SizedBox(height: 16),
                    Text('Chargement du profil...')
                  ],
                ),
              );
            } else if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 60, color: Colors.red),
                    SizedBox(height: 16),
                    Text(
                      'Erreur de chargement',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text('${snapshot.error}'),
                    SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _userFuture = _fetchUserProfile(widget.userId);
                        });
                      },
                      child: Text('Réessayer'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              );
            }

            // Utiliser des données par défaut si snapshot.data est null (ne devrait pas arriver avec le error handling)
            final user = snapshot.data ?? _getDefaultUserData(widget.userId); 

            return NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  // AppBar avec profil et actions
                  SliverAppBar(
                    expandedHeight: 240.0,
                    floating: false,
                    pinned: true,
                    backgroundColor: Colors.indigo,
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    actions: [
                      if (_isCurrentUser)
                        IconButton(
                          icon: const Icon(Icons.settings, color: Colors.white),
                          onPressed: () {
                            // Naviguer vers les paramètres
                          },
                        ),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, color: Colors.white),
                        onSelected: (choice) {
                          switch (choice) {
                            case 'report':
                              // Signaler profil
                              break;
                            case 'share':
                              // Partager profil
                              break;
                            case 'block':
                              // Bloquer utilisateur
                              break;
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'share',
                            child: Row(
                              children: [
                                Icon(Icons.share, size: 20),
                                SizedBox(width: 8),
                                Text('Partager le profil'),
                              ],
                            ),
                          ),
                          if (!_isCurrentUser)
                            const PopupMenuItem(
                              value: 'report',
                              child: Row(
                                children: [
                                  Icon(Icons.flag, size: 20),
                                  SizedBox(width: 8),
                                  Text('Signaler'),
                                ],
                              ),
                            ),
                          if (!_isCurrentUser)
                            const PopupMenuItem(
                              value: 'block',
                              child: Row(
                                children: [
                                  Icon(Icons.block, size: 20, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('Bloquer', style: TextStyle(color: Colors.red)),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                    flexibleSpace: FlexibleSpaceBar(
                      background: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.indigo,
                              Colors.indigo.withOpacity(0.8),
                            ],
                          ),
                        ),
                        child: Stack(
                          children: [
                            // Background effet with local fallback
                            Positioned.fill(
                              child: Opacity(
                                opacity: 0.08,
                                child: user['photo_url'] != null && user['photo_url'].toString().isNotEmpty
                                  ? Image.network(
                                      user['photo_url'],
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => Container(
                                        color: Colors.indigo.withOpacity(0.2),
                                      ),
                                    )
                                  : Container(
                                      color: Colors.indigo.withOpacity(0.2),
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
                                    Hero(
                                      tag: 'profile_${user['_id'] ?? widget.userId}', // Utiliser widget.userId si _id est null
                                      child: GestureDetector(
                                        onTap: () {
                                          if (user['photo_url'] != null && user['photo_url'].toString().isNotEmpty) {
                                            _showFullScreenImage(user['photo_url']);
                                          }
                                        },
                                        child: Container(
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
                                        child: user['photo_url'] != null && user['photo_url'].toString().isNotEmpty
                                          ? CachedNetworkImage(
                                              imageUrl: user['photo_url'],
                                              fit: BoxFit.cover,
                                              placeholder: (context, url) => Container(
                                                color: Colors.grey[300],
                                                child: const Center(child: CircularProgressIndicator()),
                                              ),
                                              errorWidget: (context, url, error) => Container(
                                                color: Colors.grey[300],
                                                child: const Icon(Icons.person, size: 50, color: Colors.white),
                                              ),
                                            )
                                          : Container(
                                              color: Colors.grey[300],
                                              child: const Icon(Icons.person, size: 50, color: Colors.white),
                                                ),
                                          ),
                                            ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    
                                    // Nom + badge vérifié si applicable
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
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
                                        if (user['is_star'] == true) ... [
                                          const SizedBox(width: 6),
                                          const Icon(Icons.verified, color: Colors.lightBlueAccent, size: 20),
                                        ],
                                      ],
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
                      padding: const EdgeInsets.only(bottom: 8), // Ajouter un padding en bas
                      child: Column(
                        children: [
                          _buildStatsSection(user),
                          const Divider(height: 1, indent: 20, endIndent: 20),
                          _buildFollowButton(user),
                          // Retrait de la deuxième Divider ici pour un meilleur espacement
                          _buildLikedTags(user), // S'assurer que ce widget gère le cas où il n'y a pas de tags
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
                  
                  // Section Choices
                  _buildChoicesSection(user),
                  
                  // Section Interests
                  _buildInterestsSection(user),
                ],
              ),
            );
          },
        ),
        floatingActionButton: _isCurrentUser ? FloatingActionButton(
          backgroundColor: Colors.indigo,
          child: const Icon(Icons.add, color: Colors.white),
          onPressed: () {
            // Afficher un menu pour créer un nouveau post ou un choice
            _showCreateOptions(context);
          },
        ) : null,
      ),
    );
  }

  void _showCreateOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Créer',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.indigo,
                child: Icon(Icons.post_add, color: Colors.white),
              ),
              title: const Text('Nouveau post'),
              subtitle: const Text('Partagez votre expérience'),
              onTap: () {
                Navigator.pop(context);
                // Naviguer vers la création de post
              },
            ),
            const Divider(),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.amber,
                child: Icon(Icons.check_circle, color: Colors.white),
              ),
              title: const Text('Nouveau Choice'),
              subtitle: const Text('Donnez votre avis sur un lieu'),
              onTap: () {
                Navigator.pop(context);
                // Naviguer vers la création de choice
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSection(Map<String, dynamic> user) {
    // Utiliser les compteurs si disponibles, sinon calculer depuis les listes
    final followersCount = user['followers_count'] ?? (user['followers'] as List? ?? []).length;
    final followingCount = user['following_count'] ?? (user['following'] as List? ?? []).length;
    
    // Compteurs Posts et Choices (utiliser la longueur des listes si disponibles)
    final postsCount = (user['posts'] as List? ?? []).length; 
    final choicesCount = (user['choices'] as List? ?? []).length;
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatItemWithTap(
            'Abonnés', 
            followersCount.toString(), 
            followersCount > 0 ? () => _showFollowersList(user) : null, // Rendre cliquable seulement si > 0
          ),
          Container(
            height: 40,
            width: 1,
            color: Colors.grey[300],
          ),
          _buildStatItemWithTap(
            'Abonnements', 
            followingCount.toString(), 
            followingCount > 0 ? () => _showFollowingList(user) : null, // Rendre cliquable seulement si > 0
          ),
          Container(
            height: 40,
            width: 1,
            color: Colors.grey[300],
          ),
          _buildStatItemWithTap(
            'Posts', 
            postsCount.toString(), 
            null, // Onglet dédié
          ),
          Container(
            height: 40,
            width: 1,
            color: Colors.grey[300],
          ),
          _buildStatItemWithTap(
            'Choices', 
            choicesCount.toString(),
            null, // Déjà visible dans les onglets
          ),
        ],
      ),
    );
  }

  Widget _buildStatItemWithTap(String title, String count, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
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
        ),
      ),
    );
  }

  void _showFollowersList(Map<String, dynamic> user) {
    if (user['followers'] == null || (user['followers'] as List).isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cet utilisateur n\'a pas d\'abonnés')),
      );
      return;
    }
    
    _showUsersList(user['followers'], 'Abonnés');
  }

  void _showFollowingList(Map<String, dynamic> user) {
    if (user['following'] == null || (user['following'] as List).isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cet utilisateur ne suit personne')),
      );
      return;
    }
    
    _showUsersList(user['following'], 'Abonnements');
  }

  void _showUsersList(List<dynamic> userIds, String title) {
    // Create a modal to display the list of users
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          builder: (_, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: FutureBuilder<List<Map<String, dynamic>>>(
                      future: _fetchUsersList(userIds),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        } else if (snapshot.hasError) {
                          return Center(child: Text('Erreur: ${snapshot.error}'));
                        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          return const Center(child: Text('Aucun utilisateur à afficher'));
                        }
                        
                        final users = snapshot.data!;
                        return ListView.builder(
                          controller: scrollController,
                          itemCount: users.length,
                          itemBuilder: (context, index) {
                            final user = users[index];
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundImage: user['profilePicture'] != null && user['profilePicture'].toString().isNotEmpty
                                  ? NetworkImage(user['profilePicture'])
                                  : null,
                                child: user['profilePicture'] == null || user['profilePicture'].toString().isEmpty
                                  ? const Icon(Icons.person, color: Colors.white)
                                  : null,
                              ),
                              title: Text(user['name'] ?? 'Utilisateur'),
                              subtitle: user['bio'] != null && user['bio'].toString().isNotEmpty
                                ? Text(
                                    user['bio'],
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  )
                                : null,
                              onTap: () {
                                // Navigate to user profile
                                Navigator.pop(context); // Close the modal
                                if (user['_id'] != widget.userId) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ProfileScreen(
                                        userId: user['_id'],
                                        viewMode: 'public',
                                      ),
                                    ),
                                  );
                                }
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _fetchUsersList(List<dynamic> userIds) async {
    if (userIds.isEmpty) return [];
    
    final List<Map<String, dynamic>> users = [];
    
    for (final userId in userIds) {
      try {
        final url = Uri.parse('${constants.getBaseUrl()}/api/users/${userId.toString()}/info');
        final response = await http.get(url);
        
        if (response.statusCode == 200) {
          users.add(json.decode(response.body));
        } else {
          print('❌ Erreur lors de la récupération de l\'utilisateur $userId: ${response.statusCode}');
        }
      } catch (e) {
        print('❌ Erreur réseau pour l\'utilisateur $userId: $e');
      }
    }
    
    return users;
  }

  Widget _buildFollowButton(Map<String, dynamic> user) {
    // Si c'est le profil de l'utilisateur courant, afficher un bouton d'édition
    if (_isCurrentUser) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  // Naviguer vers l'écran d'édition de profil
                  // Navigator.push(...
                },
                icon: const Icon(Icons.edit),
                label: const Text('Modifier le profil'),
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
          ],
        ),
      );
    }

    // Pour les autres profils, afficher le bouton de suivi
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
              icon: const Icon(Icons.message, color: Colors.indigo),
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
    
    if (tags.isEmpty) {
      return Container();
    }
    
    // Maps de couleurs par catégorie pour une apparence cohérente
    final Map<String, Color> tagColors = {
      'restaurant': Colors.orange.shade400,
      'culture': Colors.purple.shade400,
      'sport': Colors.blue.shade400,
      'événement': Colors.green.shade400,
      'voyage': Colors.indigo.shade400,
      'music': Colors.pink.shade400,
      'art': Colors.deepPurple.shade400,
      'food': Colors.amber.shade600,
      'vegan': Colors.lightGreen.shade600,
      'cinema': Colors.red.shade400,
    };
    
    // Fonction pour déterminer la couleur d'un tag
    Color getTagColor(String tag) {
      final lowercaseTag = tag.toLowerCase();
      
      // Vérifier si le tag correspond à une catégorie connue
      for (final category in tagColors.keys) {
        if (lowercaseTag.contains(category) || category.contains(lowercaseTag)) {
          return tagColors[category]!;
        }
      }
      
      // Couleur par défaut pour les tags non classés
      return Colors.indigo.shade400;
    }
    
    // Icône à associer à chaque tag (si possible)
    IconData getTagIcon(String tag) {
      final lowercaseTag = tag.toLowerCase();
      
      if (lowercaseTag.contains('restaurant') || lowercaseTag.contains('food') || lowercaseTag.contains('cuisine')) {
        return Icons.restaurant;
      } else if (lowercaseTag.contains('sport') || lowercaseTag.contains('fitness')) {
        return Icons.sports;
      } else if (lowercaseTag.contains('event') || lowercaseTag.contains('événement')) {
        return Icons.event;
      } else if (lowercaseTag.contains('music') || lowercaseTag.contains('musique')) {
        return Icons.music_note;
      } else if (lowercaseTag.contains('art') || lowercaseTag.contains('museum') || lowercaseTag.contains('culture')) {
        return Icons.museum;
      } else if (lowercaseTag.contains('travel') || lowercaseTag.contains('voyage')) {
        return Icons.flight;
      } else if (lowercaseTag.contains('cinema') || lowercaseTag.contains('movie')) {
        return Icons.movie;
      } else if (lowercaseTag.contains('book') || lowercaseTag.contains('livre')) {
        return Icons.book;
      } else if (lowercaseTag.contains('tech') || lowercaseTag.contains('technology')) {
        return Icons.computer;
      } else if (lowercaseTag.contains('photo') || lowercaseTag.contains('photography')) {
        return Icons.photo_camera;
      }
      
      // Icône par défaut
      return Icons.label;
    }
    
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.interests, size: 18, color: Colors.indigo.shade700),
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
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
            children: tags.map<Widget>((tag) {
                final Color tagColor = getTagColor(tag);
                final IconData tagIcon = getTagIcon(tag);
                
                return Container(
                  margin: const EdgeInsets.only(right: 10),
                  child: Chip(
                    avatar: CircleAvatar(
                      backgroundColor: tagColor.withOpacity(0.2),
                      child: Icon(tagIcon, color: tagColor, size: 16),
                    ),
                label: Text(tag),
                    backgroundColor: tagColor.withOpacity(0.1),
                    labelStyle: TextStyle(color: tagColor, fontSize: 13),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: tagColor.withOpacity(0.3)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 2),
                  ),
              );
            }).toList(),
            ),
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
                if (_isCurrentUser) ... [
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      // Navigate to post creation screen
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Créer un post'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            setState(() {
              _userFuture = _fetchUserProfile(widget.userId);
              _userFuture.then((user) {
                _postsFuture = _fetchUserPosts(user['posts'] ?? []);
              });
            });
          },
          color: Colors.indigo,
          child: ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final post = posts[index];
            return _buildPostCard(post);
          },
          ),
        );
      },
    );
  }

  Widget _buildPostCard(Map<String, dynamic> post) {
    final mediaUrls = post['media'] as List<dynamic>? ?? [];
    final hasLocation = post['location'] != null && post['location']['name'] != null;
    final hasContent = post['content'] != null && post['content'].toString().isNotEmpty;
    final likesCount = post['likes']?.length ?? 0;
    final commentsCount = post['comments']?.length ?? 0;
    
    // Format date
    String formattedDate = 'Date inconnue';
    if (post['createdAt'] != null) {
      try {
        final DateTime postDate = DateTime.parse(post['createdAt']);
        final DateTime now = DateTime.now();
        final Duration difference = now.difference(postDate);
        
        if (difference.inDays > 7) {
          formattedDate = '${postDate.day}/${postDate.month}/${postDate.year}';
        } else if (difference.inDays > 0) {
          formattedDate = '${difference.inDays} jour${difference.inDays > 1 ? 's' : ''} ago';
        } else if (difference.inHours > 0) {
          formattedDate = '${difference.inHours} heure${difference.inHours > 1 ? 's' : ''} ago';
        } else if (difference.inMinutes > 0) {
          formattedDate = '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
        } else {
          formattedDate = 'À l\'instant';
        }
      } catch (e) {
        print('Erreur de formatage de date: $e');
      }
    }
    
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
                    child: post['photo_url'] != null && post['photo_url'].toString().isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: post['photo_url'],
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: Colors.grey[200],
                            child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: Colors.grey[200],
                            child: const Icon(Icons.person, color: Colors.grey),
                          ),
                        )
                      : Container(
                          color: Colors.grey[200],
                          child: const Icon(Icons.person, color: Colors.grey),
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
                        Row(
                          children: [
                          Text(
                            formattedDate,
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                          if (hasLocation) ... [
                            const SizedBox(width: 8),
                            Icon(Icons.place, size: 12, color: Colors.indigo.withOpacity(0.7)),
                            const SizedBox(width: 2),
                            Expanded(
                              child: Text(
                                post['location']['name'],
                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                          ],
                        ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.grey),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onSelected: (String choice) {
                    switch (choice) {
                      case 'share':
                        // Fonctionnalité de partage
                        break;
                      case 'report':
                        // Fonctionnalité de signalement
                        break;
                      case 'delete':
                        // Fonctionnalité de suppression (uniquement pour l'auteur)
                        if (_isCurrentUser) {
                          _showDeletePostDialog(post['_id']);
                        }
                        break;
                    }
                  },
                  itemBuilder: (BuildContext context) {
                    return [
                      const PopupMenuItem<String>(
                        value: 'share',
                        child: Row(
                          children: [
                            Icon(Icons.share, size: 18),
                            SizedBox(width: 8),
                            Text('Partager'),
                          ],
                        ),
                      ),
                      const PopupMenuItem<String>(
                        value: 'report',
                        child: Row(
                          children: [
                            Icon(Icons.flag, size: 18),
                            SizedBox(width: 8),
                            Text('Signaler'),
                          ],
                        ),
                      ),
                      if (_isCurrentUser)
                        const PopupMenuItem<String>(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, size: 18, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Supprimer', style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                    ];
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
            
          if (hasContent) 
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
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  PageView.builder(
                itemCount: mediaUrls.length,
                itemBuilder: (context, index) {
                  String url = mediaUrls[index].toString();
                      return GestureDetector(
                        onTap: () {
                          // Open full screen image view
                          _showFullScreenImage(url);
                        },
                        child: Hero(
                          tag: 'post_image_${post['_id']}_$index',
                          child: CachedNetworkImage(
                    imageUrl: url,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: Colors.grey[200],
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                    errorWidget: (context, url, error) => _buildPlaceholderImage(
                      Colors.grey[200]!,
                      Icons.broken_image,
                      'Image non disponible'
                            ),
                          ),
                    ),
                  );
                },
                  ),
                  
                  // Indicator dots for multiple images
                  if (mediaUrls.length > 1)
                    Positioned(
                      bottom: 10,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(mediaUrls.length, (index) {
                          return Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.7),
                            ),
                          );
                        }),
                      ),
                    ),
                ],
              ),
            ),
          
          // Boutons d'action
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionButton(
                  icon: Icons.thumb_up_outlined,
                  label: likesCount > 0 ? '$likesCount Like${likesCount > 1 ? 's' : ''}' : 'Like',
                  onTap: () {
                    _likePost(post['_id']);
                  },
                  color: Colors.indigo,
                ),
                _buildActionButton(
                  icon: Icons.mode_comment_outlined,
                  label: commentsCount > 0 ? '$commentsCount Commentaire${commentsCount > 1 ? 's' : ''}' : 'Commenter',
                  onTap: () {
                    _showComments(post);
                  },
                  color: Colors.indigo,
                ),
                if (hasLocation)
                _buildActionButton(
                  icon: Icons.check_circle_outline,
                  label: 'Choice',
                    onTap: () {
                    _showChoiceDialog(context, post);
                  },
                  color: Colors.indigo,
                ),
                _buildActionButton(
                  icon: Icons.share_outlined,
                  label: 'Partager',
                  onTap: () {
                    // Share functionality
                  },
                  color: Colors.indigo,
                ),
              ],
            ),
          ),
          
          // Afficher les premiers commentaires
          if (post['comments'] != null && (post['comments'] as List).isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(thickness: 1),
                  // Afficher jusqu'à 2 commentaires
                  ...(post['comments'] as List)
                      .take(2)
                      .map((comment) => _buildCommentPreview(comment))
                      .toList(),
                  
                  // Afficher un lien "Voir tous les commentaires" s'il y en a plus
                  if ((post['comments'] as List).length > 2)
                    TextButton(
                      onPressed: () => _showComments(post),
                      child: Text(
                        'Voir tous les ${(post['comments'] as List).length} commentaires',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCommentPreview(Map<String, dynamic> comment) {
    return Padding(
      padding: const EdgeInsets.only(top: 4.0, bottom: 4.0),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: comment['author_name'] ?? 'Utilisateur',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
            ),
            TextSpan(
              text: ' ${comment['content']}',
              style: const TextStyle(color: Colors.black),
            ),
          ],
        ),
        overflow: TextOverflow.ellipsis,
        maxLines: 2,
      ),
    );
  }

  void _showFullScreenImage(String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
            elevation: 0,
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 3.0,
              child: Image(
                image: getImageProvider(imageUrl)!,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Icon(Icons.error, color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showComments(Map<String, dynamic> post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
            return DraggableScrollableSheet(
          initialChildSize: 0.8,
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
          child: Column(
            children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Commentaires',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: (post['comments'] as List?)?.length ?? 0,
                      itemBuilder: (context, index) {
                        final comment = (post['comments'] as List)[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage: comment['author_photo'] != null
                                ? getImageProvider(comment['author_photo'])
                                : const AssetImage('assets/default_avatar.png'),
                          ),
                          title: Text(comment['author_name'] ?? 'Utilisateur'),
                          subtitle: Text(comment['content'] ?? ''),
                          trailing: Text(
                            _formatCommentDate(comment['created_at']),
                            style: TextStyle(color: Colors.grey[600], fontSize: 12),
                          ),
                        );
                      },
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).viewInsets.bottom,
                      left: 8.0,
                      right: 8.0,
                      top: 8.0,
                    ),
                    child: Row(
                children: [
                  Expanded(
                          child: TextField(
                decoration: InputDecoration(
                              hintText: 'Ajouter un commentaire...',
                  border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: Colors.grey[200],
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.send, color: Colors.indigo),
                  onPressed: () {
                            // Envoi du commentaire
                          },
                        ),
                      ],
                ),
              ),
            ],
          ),
            );
          },
        );
      },
    );
  }

  String _formatCommentDate(String? dateStr) {
    if (dateStr == null) return 'Date inconnue';
    
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(date);
      
      if (diff.inDays == 0) {
        if (diff.inHours == 0) {
          if (diff.inMinutes == 0) {
            return 'À l\'instant';
          }
          return 'Il y a ${diff.inMinutes} min';
        }
        return 'Il y a ${diff.inHours} h';
      } else if (diff.inDays < 7) {
        return 'Il y a ${diff.inDays} j';
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    } catch (e) {
      return 'Date inconnue';
    }
  }

  Future<void> _likePost(String postId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';
      
      if (token.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vous devez être connecté pour aimer un post')),
        );
        return;
      }
      
      final url = Uri.parse('${constants.getBaseUrl()}/api/posts/$postId/like');
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
        
        if (response.statusCode == 200) {
        // Mettre à jour l'affichage des likes
        setState(() {
          _postsFuture = _postsFuture.then((posts) {
            return posts.map((post) {
              if (post['_id'] == postId) {
                // Mise à jour du nombre de likes
                final data = json.decode(response.body);
                post['likes'] = data['likes'] ?? post['likes'];
              }
              return post;
            }).toList();
          });
        });
      } else {
        print('❌ Erreur lors de l\'ajout du like: ${response.statusCode} - ${response.body}');
        }
      } catch (e) {
      print('❌ Erreur réseau: $e');
    }
  }

  void _showDeletePostDialog(String postId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer le post'),
        content: const Text('Êtes-vous sûr de vouloir supprimer ce post ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deletePost(postId);
            },
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _deletePost(String postId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';
      
      if (token.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vous devez être connecté pour supprimer un post')),
        );
        return;
      }
      
      final url = Uri.parse('${constants.getBaseUrl()}/api/posts/$postId');
      
      final response = await http.delete(
        url,
        headers: {
          'Authorization': 'Bearer $token',
        },
      );
          
          if (response.statusCode == 200) {
        // Mettre à jour la liste des posts
        setState(() {
          _postsFuture = _postsFuture.then((posts) {
            return posts.where((post) => post['_id'] != postId).toList();
          });
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post supprimé avec succès')),
        );
      } else {
        print('❌ Erreur lors de la suppression du post: ${response.statusCode} - ${response.body}');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors de la suppression du post')),
        );
          }
        } catch (e) {
      print('❌ Erreur réseau: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur réseau: $e')),
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

    // Convert all interests to string IDs
    List<String> interestIds = interests.map<String>((interest) {
      if (interest is Map && interest.containsKey('targetId')) {
        return interest['targetId'].toString();
      }
      return interest.toString();
    }).toList();
    
    return FutureBuilder<Map<String, dynamic>>(
      future: _fetchPlaceDetails(interestIds),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final placeDetails = snapshot.data ?? {};
        
        return RefreshIndicator(
          onRefresh: () async {
            setState(() {
              _userFuture = _fetchUserProfile(widget.userId);
            });
          },
          color: Colors.indigo,
          child: GridView.builder(
            padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.8,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
          ),
          itemCount: interests.length,
          itemBuilder: (context, index) {
              final interestId = interestIds[index];
            
            // Get place details if available
            final placeDetail = placeDetails[interestId] ?? {};
            final String placeName = placeDetail['name'] ?? 
                                     placeDetail['intitulé'] ?? 
                                     placeDetail['titre'] ?? 
                                     'Lieu favori';
            
            // Use specific fields based on the place type
            final String? imageUrl;
            if (placeDetail['photos']?.isNotEmpty == true) {
              imageUrl = placeDetail['photos']?[0];
            } else if (placeDetail['image'] != null) {
              imageUrl = placeDetail['image'];
            } else if (placeDetail['photo_url'] != null) {
              imageUrl = placeDetail['photo_url'];
            } else {
              imageUrl = '';
            }
                  
            // Determine place type icon
            IconData placeIcon = Icons.place;
              if (placeDetail['category']?.toString().contains('restaurant') == true) {
              placeIcon = Icons.restaurant;
              } else if (placeDetail['category']?.toString().contains('event') == true) {
              placeIcon = Icons.event;
              } else if (placeDetail['category']?.toString().contains('culture') == true) {
              placeIcon = Icons.museum;
            }
            
            return GestureDetector(
              onTap: () {
                // Determine type for navigation
                String placeType = 'restaurant'; // Default
                if (placeDetail.containsKey('intitulé') || placeDetail.containsKey('titre')) {
                  placeType = 'event';
                } else if (placeDetail.containsKey('lieu')) {
                  placeType = 'leisureProducer';
                }
                _navigateToDetails(interestId, placeType);
              },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      color: Colors.white,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                          // Image
                    Positioned.fill(
                            child: Hero(
                              tag: 'interest_$interestId',
                      child: imageUrl != null && imageUrl.isNotEmpty
                        ? Image(
                            image: getImageProvider(imageUrl)!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => _buildPlaceholderImage(Colors.grey[200]!, placeIcon, placeName),
                          )
                        : _buildPlaceholderImage(Colors.grey[200]!, placeIcon, placeName),
                    ),
                          ),
                          
                          // Gradient overlay at bottom for text
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
                                    Colors.black.withOpacity(0.8),
                            ],
                          ),
                        ),
                              padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              placeName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                      fontSize: 16,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.place, size: 12, color: Colors.white70),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    placeDetail['address'] ?? 
                                    placeDetail['lieu'] ?? 
                                    placeDetail['adresse'] ?? 
                                    'Voir détails',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                          
                          // Type badge
                    Positioned(
                            top: 12,
                            left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                        ),
                              child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                                  Icon(placeIcon, color: Colors.indigo, size: 14),
                                  const SizedBox(width: 4),
                            Text(
                                    _getPlaceTypeName(placeDetail),
                                    style: const TextStyle(
                                      color: Colors.indigo,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                          
                          // Favorite icon
                          Positioned(
                            top: 12,
                            right: 12,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.pink.shade400,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.favorite,
                                color: Colors.white,
                                size: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ),
              ),
            );
          },
          ),
        );
      },
    );
  }

  String _getPlaceTypeName(Map<String, dynamic> placeDetail) {
    // Determine type name from place details
    if (placeDetail.containsKey('intitulé') || placeDetail.containsKey('titre')) {
      return 'Événement';
    } else if (placeDetail.containsKey('lieu')) {
      return 'Lieu';
    } else if (placeDetail['category']?.toString().contains('restaurant') == true) {
      return 'Restaurant';
    } else if (placeDetail['category']?.toString().contains('culture') == true) {
      return 'Culture';
    }
    return 'Lieu';
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

    // Gather all place IDs to fetch
    List<String> placeIds = [];
    Map<String, dynamic> choiceDetails = {};
    
    for (var choice in choices) {
      String targetId = '';
      Map<String, dynamic> choiceData = {};
      
      // Handle both formats:
      // 1. When choice is already a map with targetId
      if (choice is Map && choice.containsKey('targetId')) {
        targetId = choice['targetId'].toString();
        choiceData = Map<String, dynamic>.from(choice);
      } else {
        targetId = choice.toString();
        choiceData = {'targetId': targetId};
      }
      
      if (targetId.isNotEmpty) {
        placeIds.add(targetId);
        choiceDetails[targetId] = choiceData;
      }
    }

    return FutureBuilder<Map<String, dynamic>>(
      future: _fetchPlaceDetails(placeIds),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final placeDetails = snapshot.data ?? {};
        
        return RefreshIndicator(
          onRefresh: () async {
            setState(() {
              _userFuture = _fetchUserProfile(widget.userId);
            });
          },
          color: Colors.indigo,
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: placeIds.length,
          itemBuilder: (context, index) {
              final targetId = placeIds[index];
              final choiceData = choiceDetails[targetId] ?? {};
            
            // Get place details if available
            final placeDetail = placeDetails[targetId] ?? {};
            final String placeName = placeDetail['name'] ?? 
                                     placeDetail['intitulé'] ?? 
                                     placeDetail['titre'] ?? 
                                     'Lieu non spécifié';
            
            // Use specific fields based on the place type
            final String? imageUrl;
            if (placeDetail['photos']?.isNotEmpty == true) {
              imageUrl = placeDetail['photos']?[0];
            } else if (placeDetail['image'] != null) {
              imageUrl = placeDetail['image'];
            } else if (placeDetail['photo_url'] != null) {
              imageUrl = placeDetail['photo_url'];
            } else {
              imageUrl = '';
            }
            
              // Extract rating information
              final aspects = choiceData['aspects'] ?? {};
              final int qualityRating = aspects['qualité générale'] ?? 0;
              final int interestRating = aspects['intérêt'] ?? 0;
              final int originalityRating = aspects['originalité'] ?? 0;
              
              // Calculate average rating
              double averageRating = 0;
              if (aspects.isNotEmpty) {
                final sum = (qualityRating + interestRating + originalityRating);
                final count = 3;
                averageRating = sum / count;
              }
              
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with image
                    Stack(
                        children: [
                        ClipRRect(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                          child: SizedBox(
                            height: 150,
                            width: double.infinity,
                            child: imageUrl != null && imageUrl.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: imageUrl,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(
                                    color: Colors.grey[200],
                                    child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                  ),
                                  errorWidget: (context, url, error) => Container(
                                    color: Colors.grey[200],
                                    child: const Icon(Icons.image_not_supported, size: 40, color: Colors.grey),
                                  ),
                                )
                              : Container(
                                  color: Colors.grey[200],
                                  child: const Icon(Icons.image_not_supported, size: 40, color: Colors.grey),
                          ),
                          ),
                        ),
                        // Type badge
                          Positioned(
                          top: 12,
                          left: 12,
                            child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                      color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                                    children: [
                                Icon(
                                  _getTypeIcon(placeDetail),
                                  color: Colors.indigo,
                                  size: 16,
                                ),
                                      const SizedBox(width: 4),
                                      Text(
                                  _getPlaceTypeName(placeDetail),
                                        style: const TextStyle(
                                    color: Colors.indigo,
                                          fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                              ),
                            ),
                        // Choice badge
                          Positioned(
                          top: 12,
                          right: 12,
                            child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.indigo,
                                borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                              ),
                              ],
                            ),
                            child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                const Icon(
                                  Icons.check_circle,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                const Text(
                                    'CHOICE',
                                    style: TextStyle(
                                      color: Colors.white,
                                    fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ),
                        // Rating
                        if (averageRating > 0)
                          Positioned(
                            bottom: 12,
                            right: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.star,
                                    color: Colors.amber,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${averageRating.toStringAsFixed(1)}/10',
                                    style: const TextStyle(
                                      color: Colors.black87,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                    
                    // Content
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            placeName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.location_on, size: 14, color: Colors.grey),
                              const SizedBox(width: 4),
                              Expanded(
                      child: Text(
                        placeDetail['address'] ?? 
                        placeDetail['lieu'] ?? 
                                  placeDetail['adresse'] ?? 
                                  'Adresse non disponible',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                  maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                          
                          const SizedBox(height: 16),
                          
                          // Ratings visualization
                          if (aspects.isNotEmpty) ...[
                            const Text(
                              'Évaluation',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            
                            // Qualité générale
                            _buildRatingBar('Qualité générale', qualityRating / 10),
                            const SizedBox(height: 8),
                            
                            // Intérêt
                            _buildRatingBar('Intérêt', interestRating / 10),
                            const SizedBox(height: 8),
                            
                            // Originalité
                            _buildRatingBar('Originalité', originalityRating / 10),
                          ],
                          
                          const SizedBox(height: 16),
                          
                          // Appréciation globale
                          if (choiceData['appréciation_globale'] != null && 
                              choiceData['appréciation_globale'].toString().isNotEmpty) ...[
                            const Text(
                              'Appréciation globale',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              choiceData['appréciation_globale'],
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    
                    // Action buttons
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton.icon(
                            onPressed: () {
                              if (targetId.isNotEmpty) {
                                // Determine type for navigation
                                String placeType = 'restaurant'; // Default
                                if (placeDetail.containsKey('intitulé') || placeDetail.containsKey('titre')) {
                                  placeType = 'event';
                                } else if (placeDetail.containsKey('lieu')) {
                                  placeType = 'leisureProducer';
                                }
                                _navigateToDetails(targetId, placeType);
                              }
                            },
                            icon: const Icon(Icons.visibility),
                            label: const Text('Voir détails'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.indigo,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () {
                              // Share functionality
                            },
                            icon: const Icon(Icons.share),
                            label: const Text('Partager'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
              ),
            );
          },
          ),
        );
      },
    );
  }

  IconData _getTypeIcon(Map<String, dynamic> placeDetail) {
    if (placeDetail.containsKey('intitulé') || placeDetail.containsKey('titre')) {
      return Icons.event;
    } else if (placeDetail.containsKey('lieu')) {
      return Icons.location_city;
    } else if (placeDetail['category']?.toString().contains('restaurant') == true) {
      return Icons.restaurant;
    } else if (placeDetail['category']?.toString().contains('culture') == true) {
      return Icons.museum;
    }
    return Icons.place;
  }

  Widget _buildRatingBar(String label, double value) {
    return Row(
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value,
              backgroundColor: Colors.grey[200],
              color: _getRatingColor(value),
              minHeight: 8,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${(value * 10).round()}',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: _getRatingColor(value),
          ),
        ),
      ],
    );
  }

  Color _getRatingColor(double value) {
    if (value >= 0.8) return Colors.green;
    if (value >= 0.6) return Colors.lightGreen;
    if (value >= 0.4) return Colors.amber;
    if (value >= 0.2) return Colors.orange;
    return Colors.red;
  }

  Future<Map<String, dynamic>> _fetchPlaceDetails(List<String> placeIds) async {
    Map<String, dynamic> results = {};
    
    if (placeIds.isEmpty) return results;

    try {
      // Utiliser l'API unifiée pour récupérer plusieurs lieux en une seule requête
      final url = Uri.parse('${constants.getBaseUrl()}/api/unified/batch');
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'ids': placeIds}),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['results'] ?? {};
      }
    } catch (e) {
      print('❌ Erreur lors de la récupération des lieux en lot: $e');
    }
    
    // Si la méthode par lot échoue, essayer de récupérer chaque lieu individuellement
    for (String placeId in placeIds) {
      bool fetched = false;
      
      // Essayer plusieurs endpoints possibles
      final endpoints = [
        'producers',
        'leisureProducers',
        'events',
        'unified',
      ];
      
      for (String endpoint in endpoints) {
        if (fetched) continue;
        
        try {
          final url = Uri.parse('${constants.getBaseUrl()}/api/$endpoint/$placeId');
          final response = await http.get(url);
          
          if (response.statusCode == 200) {
            results[placeId] = json.decode(response.body);
            fetched = true;
            break;
          }
        } catch (e) {
          print('❌ Erreur endpoint $endpoint pour $placeId: $e');
        }
      }
    }
    
    return results;
  }

  // Méthode pour créer un bouton d'action standard
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Méthode pour afficher la boîte de dialogue de choice
  void _showChoiceDialog(BuildContext context, Map<String, dynamic> post) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Marquer comme Choice'),
        content: const Text('Voulez-vous marquer ce lieu comme un "Choice" ? Cela indique que vous avez visité ce lieu et le recommandez.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Ici, ajoutez la logique pour marquer le post comme Choice
              // Exemple: _markAsChoice(post['_id']);
            },
            child: const Text('Confirmer', style: TextStyle(color: Colors.indigo)),
          ),
        ],
      ),
    );
  }

  /// Logs the profile view activity.
  Future<void> _logProfileViewActivity(String profileId, String profileType) async {
    final String? currentUserId = _currentUserId; // Get the logged-in user ID
    if (currentUserId == null || currentUserId.isEmpty) {
      print('📊 Cannot log profile view: Current user ID not available.');
      return; // Don't log if no user is logged in
    }

    // Avoid logging viewing your own profile
    if (currentUserId == profileId) {
       print('📊 Not logging view of own profile.');
       return;
    }

    // Get current location (handle null)
    final LatLng? currentLocation = await LocationUtils.getCurrentLocation();
    final LatLng locationToSend = currentLocation ?? LocationUtils.defaultLocation();

    print('📊 Logging profile view: User: $currentUserId, Viewed Profile ID: $profileId, Type: $profileType, Location: $locationToSend');

    AppDataSenderService.sendActivityLog(
      userId: currentUserId,
      action: 'view_profile', // Specific action type
      location: locationToSend,
      producerId: profileId, // Use producerId field for the viewed profile ID
      producerType: profileType, // 'user', 'restaurant', 'leisure', etc.
    );
  }

  /// Generic helper to log user actions on this profile screen.
  Future<void> _logGenericUserAction(String action, {String? targetUserId}) async {
    final String? currentUserId = _currentUserId;
    if (currentUserId == null || currentUserId.isEmpty) {
      print('📊 Cannot log action \'$action\': Current user ID not available.');
      return;
    }

    // Get current location
    final LatLng? currentLocation = await LocationUtils.getCurrentLocation();
    final LatLng locationToSend = currentLocation ?? LocationUtils.defaultLocation();

    print('📊 Logging Action: User: $currentUserId, Action: $action, Target: $targetUserId, Location: $locationToSend');

    AppDataSenderService.sendActivityLog(
      userId: currentUserId,
      action: action,
      location: locationToSend,
      // Send the target user ID as producerId for context
      producerId: targetUserId ?? widget.userId, 
      producerType: 'user', 
      // Add more metadata if needed
    );
  }

  // Helper function to provide default user data
  Map<String, dynamic> _getDefaultUserData(String userId) {
    return {
      '_id': userId,
      'name': 'Utilisateur',
      'bio': 'Informations non disponibles',
      'photo_url': '', // Utiliser photo_url comme champ principal
      'followers_count': 0,
      'following_count': 0,
      'followers': [],
      'following': [],
      'posts': [],
      'interests': [],
      'liked_tags': [],
      'conversations': [],
      'choices': [],
    };
  }
}
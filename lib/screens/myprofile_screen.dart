import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart' as provider_pkg;
import 'producer_screen.dart'; // Pour les détails des restaurants
import 'producerLeisure_screen.dart'; // Pour les producteurs de loisirs
import 'eventLeisure_screen.dart'; // Pour les événements
import 'messaging_screen.dart';
import 'language_settings_screen.dart'; // Import pour les paramètres de langue
import 'email_notifications_screen.dart'; // Import pour les notifications
import '../utils/constants.dart' as constants; // Import constants directement
import '../services/auth_service.dart'; // Import AuthService for logout
import '../services/translation_service.dart'; // Import pour la traduction
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/post.dart'; // Import PostLocation class
import '../models/post_location.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/utils.dart'; // Import utils pour getBaseUrl()
import 'CreatePostScreen.dart';
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

class MyProfileScreen extends StatefulWidget {
  final String userId;
  final bool isCurrentUser;
  
  const MyProfileScreen({Key? key, required this.userId, this.isCurrentUser = true}) : super(key: key);

  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen> with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  late Future<Map<String, dynamic>> _userFuture;
  late Future<List<dynamic>> _postsFuture;
  bool _isLoading = true;
  String? _errorMessage;
  late TabController _tabController; // Contrôleur pour les onglets

  // Ajouter une variable pour la langue utilisateur
  String userLanguage = 'fr';
  
  // Fonction d'utilité pour obtenir l'URL de base via utils.dart
  String getBaseUrlFromUtils() {
    // Utiliser la fonction importée depuis utils.dart
    return getBaseUrl();
  }

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _userFuture = _fetchUserProfile(widget.userId);
    _userFuture.then((user) {
      _postsFuture = _fetchUserPosts(widget.userId);
    });
  }

  /// Récupère le profil utilisateur
  Future<Map<String, dynamic>> _fetchUserProfile(String userId) async {
    final authService = provider_pkg.Provider.of<AuthService>(context, listen: false);
    
    try {
      // Essayer d'obtenir un token, mais continuer même s'il n'y en a pas
      final token = await authService.getTokenInstance(forceRefresh: false);
      final baseUrl = getBaseUrlFromUtils();
      
      // Construire les en-têtes en fonction de la disponibilité du token
      final headers = {
        'Content-Type': 'application/json',
      };
      
      // Ajouter le token seulement s'il existe
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
      
      // Faire la requête avec ou sans token
      final url = Uri.parse('${constants.getBaseUrl()}/api/users/$userId');
      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        try {
          Map<String, dynamic> userData = json.decode(response.body);
          print('✅ Données utilisateur récupérées avec succès');
          
          // Ensure critical fields exist to prevent null errors
          if (!userData.containsKey('followers')) {
            userData['followers'] = [];
          }
          if (!userData.containsKey('following')) {
            userData['following'] = [];
          }
          if (!userData.containsKey('posts')) {
            userData['posts'] = [];
          }
          
          // Convertir les listes dynamiques en listes de type spécifique pour Flutter
          // Utiliser la méthode _ensureStringList pour garantir la conversion correcte
          userData['followers'] = _ensureStringList(userData['followers']);
          userData['following'] = _ensureStringList(userData['following']);
          userData['posts'] = _ensureStringList(userData['posts']);
          userData['liked_tags'] = _ensureStringList(userData['liked_tags']);
          userData['interests'] = _ensureStringList(userData['interests']);
          userData['conversations'] = _ensureStringList(userData['conversations']);
          
          return userData;
        } catch (e) {
          print('❌ Erreur de parsing JSON: ${response.body}');
          return _getDefaultUserData(userId);
        }
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        // En cas d'erreur d'authentification, retourner des données par défaut
        print('⚠️ Erreur d\'authentification pour le profil - Utilisation des données par défaut');
        return _getDefaultUserData(userId);
      } else {
        print('❌ Erreur de récupération utilisateur (${response.statusCode}): ${response.body}');
        return _getDefaultUserData(userId);
      }
    } catch (e) {
      print('❌ Exception lors de la récupération du profil: $e');
      // Retourner des données par défaut pour éviter les erreurs d'UI
      return _getDefaultUserData(userId);
    }
  }

  /// Convertit les listes dynamiques en listes typées pour éviter les erreurs de casting
  List<String> _ensureStringList(dynamic list) {
    if (list == null) return <String>[];
    if (list is List<String>) return list;
    
    // Convertir une liste dynamique en liste de strings
    if (list is List) {
      return list.map((item) => item.toString()).toList();
    }
    
    return <String>[];
  }

  /// Récupère les posts associés à l'utilisateur
  Future<List<dynamic>> _fetchUserPosts(String userId) async {
    final authService = provider_pkg.Provider.of<AuthService>(context, listen: false);
    
    try {
      // Valider le token avant de faire l'appel API
      final token = await authService.getTokenInstance();
      if (token == null || token.isEmpty) {
        print('❌ Token manquant pour _fetchUserPosts');
        return [];
      }
      
      final baseUrl = getBaseUrlFromUtils();
      final headers = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json'
      };
      
      print('🔍 Récupération des posts pour userId: $userId');
      
      // Utiliser la route API correcte /api/users/:id/posts
      final response = await http.get(
        Uri.parse('$baseUrl/api/users/$userId/posts'),
        headers: headers,
      ).timeout(const Duration(seconds: 10));  // Timeout augmenté à 10 secondes
  
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<dynamic> postsList = [];
        
        // Vérifier le format de la réponse (basé sur le code backend)
        if (data is Map<String, dynamic> && data.containsKey('posts')) {
          final posts = data['posts'];
          if (posts is List) {
            postsList = posts;
          }
        } else if (data is List) {
          // Si les données sont déjà une liste, les utiliser directement
          postsList = data;
        }
        
        if (postsList.isEmpty) {
          print('⚠️ Aucun post trouvé ou format non reconnu');
          return [];
        }
        
        print('✅ Posts utilisateur récupérés avec succès: ${postsList.length} posts');
        
        // Convertir les données pour assurer la cohérence des types
        final processedPosts = postsList.map((post) {
          if (post is Map<String, dynamic>) {
            // S'assurer que _id et id sont en String
            if (post.containsKey('_id')) post['_id'] = post['_id'].toString();
            if (post.containsKey('id')) post['id'] = post['id'].toString();
            
            // Traiter les champs qui peuvent être différents formats selon le backend
            _ensurePostFields(post);
            
            // Convertir les listes dynamiques en listes typées
            if (post.containsKey('likes') && post['likes'] is List) {
              post['likes'] = (post['likes'] as List).map((item) => item.toString()).toList();
            } else if (!post.containsKey('likes')) {
              post['likes'] = <String>[];
            }
            
            if (post.containsKey('comments') && post['comments'] is List) {
              post['comments'] = (post['comments'] as List).map((item) {
                if (item is Map<String, dynamic>) return item;
                return {'text': item.toString()};
              }).toList();
            } else if (!post.containsKey('comments')) {
              post['comments'] = [];
            }
            
            // Vérifier et traiter d'autres champs potentiellement problématiques
            if (post.containsKey('location') && post['location'] != null) {
              // Uniformiser le format de location
              if (post['location'] is String) {
                // Convertir en objet si c'est une chaîne
                post['location'] = {'name': post['location']};
              }
            }
          }
          return post;
        }).toList();
        
        return processedPosts;
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        // En cas d'erreur d'authentification, déconnecter l'utilisateur
        print('⚠️ Erreur d\'authentification (${response.statusCode}) lors de la récupération des posts');
        authService.logout();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Session expirée. Veuillez vous reconnecter.'))
          );
        }
        return [];
      } else {
        print('❌ Erreur (${response.statusCode}) lors de la récupération des posts: ${response.body}');
        return [];
      }
    } catch (e) {
      print('❌ Exception lors de la récupération des posts: $e');
      return [];
    }
  }
  
  /// S'assure que tous les champs nécessaires sont présents dans un post
  void _ensurePostFields(Map<String, dynamic> post) {
    // Liste des champs à vérifier et leurs valeurs par défaut
    final defaults = {
      'content': '',
      'image': '',
      'createdAt': DateTime.now().toIso8601String(),
      'likes': <String>[],
      'comments': <Map<String, dynamic>>[],
      'author': {'name': 'Utilisateur', 'photo': ''},
      'location': null,
    };
    
    // Ajouter les champs manquants avec leurs valeurs par défaut
    defaults.forEach((key, defaultValue) {
      if (!post.containsKey(key)) {
        post[key] = defaultValue;
      }
    });
    
    // Si l'auteur est juste un ID, le convertir en objet
    if (post['author'] is String) {
      post['author'] = {'_id': post['author'], 'name': 'Utilisateur'};
    }
  }

  /// Navigation vers les détails d'un producteur ou événement
  Future<void> _navigateToDetails(String id, String type) async {
    print('🔍 Navigation vers l\'ID : $id (Type : $type)');

    try {
      // Déterminer le bon endpoint et l'écran cible en fonction du type
      String endpoint;
      Widget? targetScreen;
      Map<String, dynamic>? data;
      
      switch (type) {
        case 'restaurant':
          endpoint = 'producers';
          // Pour les restaurants, on peut naviguer directement
          targetScreen = ProducerScreen(producerId: id);
          break;
        case 'leisureProducer':
          endpoint = 'leisureProducers';
          break;
        case 'event':
          endpoint = 'events';
          break;
        case 'wellness':
          endpoint = 'wellnessProducers';
          break;
        default:
          // Essayer avec l'API unifiée pour identifier le type
          endpoint = 'unified';
          break;
      }

      // Si on n'a pas déjà construit l'écran cible (comme pour les restaurants)
      if (targetScreen == null) {
        // Construire l'URL et effectuer la requête
        final url = Uri.parse('${constants.getBaseUrl()}/api/$endpoint/$id');
        // Récupérer le token pour l'autorisation si disponible
        final authService = provider_pkg.Provider.of<AuthService>(context, listen: false);
        final token = await authService.getTokenInstance();
        
        // Préparer les en-têtes avec ou sans token
        final headers = <String, String>{
          'Content-Type': 'application/json',
        };
        
        if (token != null && token.isNotEmpty) {
          headers['Authorization'] = 'Bearer $token';
        }
        
        final response = await http.get(url, headers: headers);
      
      if (response.statusCode == 200) {
          // Analyser les données de réponse
          data = json.decode(response.body);
          
          // Construire l'écran approprié selon le type
          switch (type) {
            case 'leisureProducer':
              targetScreen = ProducerLeisureScreen(producerData: data);
              break;
            case 'event':
              targetScreen = EventLeisureScreen(eventData: data);
              break;
            case 'wellness':
              // Ajouter l'écran de bien-être si disponible
              // targetScreen = WellnessScreen(wellnessData: data);
              break;
            default:
              // Si le type n'est pas spécifié, essayer de déterminer par les données
              if (data?.containsKey('category') == true && (data?['category'] == 'leisure' || data?.containsKey('events') == true)) {
                targetScreen = ProducerLeisureScreen(producerData: data!);
              } else if (data?.containsKey('date_debut') == true || data?.containsKey('start_date') == true) {
                targetScreen = EventLeisureScreen(eventData: data!);
              } else {
                // Par défaut, considérer comme un restaurant
                targetScreen = ProducerScreen(producerId: id);
              }
              break;
          }
        } else {
          print("❌ Erreur lors de la récupération des détails : ${response.statusCode} - ${response.body}");
          // Afficher un message d'erreur à l'utilisateur
          if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Impossible de charger les détails. Erreur ${response.statusCode}"))
            );
          }
          return;
        }
      }
      
      // Naviguer vers l'écran cible si disponible
      if (mounted && targetScreen != null) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => targetScreen!),
        );
      }
    } catch (e) {
      print("❌ Erreur réseau : $e");
      if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur de connexion : $e"))
        );
      }
    }
  }

  Future<void> _startConversation(String recipientId) async {
    // Vérifier si l'ID de l'utilisateur est le même que celui du destinataire
    if (widget.userId == recipientId) {
      print('Les IDs sont identiques ! Impossible de commencer une conversation.');
      return; // Retourner si l'ID de l'utilisateur et du destinataire sont identiques
    }

    try {
      // Obtenir l'ID de l'utilisateur et du destinataire
      final senderId = widget.userId;
      // Nous utilisons directement recipientId qui est déjà un paramètre
      // final recipientId = user['_id'].toString();

      // Créer une nouvelle conversation
      try {
        final url = Uri.parse('${constants.getBaseUrl()}/api/conversations/check-or-create');
        final response = await http.post(
          url,
          headers: {
            'Content-Type': 'application/json',
          },
          body: json.encode({
            'participants': [senderId, recipientId],
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
              builder: (context) => MessagingScreen(
                userId: widget.userId,
              ),
            ),
          );
        } else {
          print('Erreur lors de la création de la conversation : ${response.body}');
        }
      } catch (e) {
        print('Erreur réseau : $e');
      }
    } catch (e) {
      print('Erreur réseau : $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3, // Trois onglets : Posts, Interests, Choices
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
                            // Background effet with local fallback
                            Positioned.fill(
                              child: Opacity(
                                opacity: 0.1,
                                child: user['photo_url'] != null && user['photo_url'].toString().isNotEmpty
                                  ? Image.network(
                                      user['photo_url'],
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => Container(
                                        color: Colors.teal.shade200,
                                      ),
                                    )
                                  : Container(
                                      color: Colors.teal.shade200,
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
                                              child: const Icon(Icons.person, size: 40, color: Colors.white),
                                            ),
                                          )
                                        : Container(
                                            color: Colors.grey[300],
                                            child: const Icon(Icons.person, size: 40, color: Colors.white),
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
    IconButton(
      icon: const Icon(Icons.menu, color: Colors.white),
      onPressed: () {
        // Afficher le menu hamburger
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const Text(
                    'Menu',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildMenuOption(
                    icon: Icons.bookmark,
                    text: 'Publications sauvegardées',
                    onTap: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Publications sauvegardées à venir')),
                      );
                    },
                  ),
                  _buildMenuOption(
                    icon: Icons.dark_mode,
                    text: 'Mode sombre',
                    isToggle: true,
                    onTap: () {
                      Navigator.pop(context);
                      // Toggle theme logic
                      // Cela devrait être connecté à votre système de thème
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Basculement du thème')),
                      );
                    },
                  ),
                  _buildMenuOption(
                    icon: Icons.block,
                    text: 'Profils bloqués',
                    onTap: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Profils bloqués à venir')),
                      );
                    },
                  ),
                  _buildMenuOption(
                    icon: Icons.logout,
                    text: 'Déconnexion',
                    color: Colors.red,
                    onTap: () async {
                      Navigator.pop(context);
                      // Déconnecter l'utilisateur via AuthService
                      await AuthService().logout();
                      // Forcer la navigation vers la page d'accueil en effaçant la pile de navigation
                      if (context.mounted) {
                        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
                      }
                    },
                  ),
                ],
              ),
            );
          },
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
            // Ouvrir la page de création de Choice avec le logo amélioré
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              useSafeArea: true,
              isDismissible: true,
              enableDrag: true,
              builder: (BuildContext dialogContext) {
                return FractionallySizedBox(
                  heightFactor: 0.95,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                ),
                child: SafeArea(
                      child: CreatePostScreen(userId: widget.userId),
                ),
              ),
                );
              },
            );
          },
          backgroundColor: Colors.teal,
          child: const Icon(Icons.check, size: 30), // Logo Choice (check mark)
          tooltip: "Déposez votre choice",
        ),
      ),
    );
  }

  // Removed duplicate _SliverAppBarDelegate class

  Widget _buildStatsSection(Map<String, dynamic> user) {
    final followers = user['followers'] ?? [];
    final following = user['following'] ?? [];
    final postsCount = user['posts']?.length ?? 0;
    final choices = user['choices'] ?? [];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
          _buildStatButton(
            context,
            icon: Icons.people,
            label: 'Abonnés',
            count: followers.length,
            onTap: () => _showUserListModal(context, followers, 'Abonnés'),
          ),
          _verticalDivider(),
          _buildStatButton(
            context,
            icon: Icons.person_add_alt_1,
            label: 'Abonnements',
            count: following.length,
            onTap: () => _showUserListModal(context, following, 'Abonnements'),
          ),
          _verticalDivider(),
          _buildStatButton(
            context,
            icon: Icons.article_outlined,
            label: 'Posts',
            count: postsCount,
            onTap: null,
          ),
          _verticalDivider(),
          _buildStatButton(
            context,
            icon: Icons.check_circle_outline,
            label: 'Choices',
            count: choices.length,
            onTap: () => _showChoicesModal(context, choices),
          ),
        ],
      ),
    );
  }

  Widget _verticalDivider() {
    return Container(
      height: 40,
      width: 1,
      color: Colors.grey[300],
    );
  }

  Widget _buildStatButton(BuildContext context, {required IconData icon, required String label, required int count, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Column(
                children: [
            Icon(icon, color: Colors.teal, size: 22),
            const SizedBox(height: 2),
            Text(
              count.toString(),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.teal,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showUserListModal(BuildContext context, List<dynamic> users, String title) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
                          backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                title,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final user = users[index];
                  return ListTile(
                    leading: CircleAvatar(
                          backgroundImage: user['photo_url'] != null && user['photo_url'].toString().isNotEmpty
                              ? NetworkImage(user['photo_url'])
                              : null,
                          child: user['photo_url'] == null || user['photo_url'].toString().isEmpty
                          ? const Icon(Icons.person, color: Colors.grey)
                              : null,
                        ),
                    title: Text(user['name'] ?? 'Utilisateur'),
                    onTap: () {
                      Navigator.pop(context);
                      // Navigation vers le profil utilisateur
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MyProfileScreen(userId: user['_id'], isCurrentUser: false),
                        ),
                      );
                    },
                  );
                },
              ),
                          ),
                      ],
                    ),
                  ),
    );
  }

  void _showChoicesModal(BuildContext context, List<dynamic> choices) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) => Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Vos Choices',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: choices.length,
                itemBuilder: (context, index) {
                  final choice = choices[index];
                  return ListTile(
                    leading: const Icon(Icons.check_circle, color: Colors.teal),
                    title: Text(choice['targetName'] ?? 'Lieu'),
                    subtitle: Text(choice['type'] ?? ''),
                    onTap: () {
                      Navigator.pop(context);
                      // Navigation vers le détail du lieu/choice
                      _navigateToDetails(choice['targetId'].toString(), choice['type'] ?? 'restaurant');
                    },
                  );
                },
              ),
            ),
          ],
        ),
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
    return GestureDetector(
      onTap: () => _navigateToPostDetail(post),
      child: Card(
        margin: const EdgeInsets.only(bottom: 16),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Contenu du post
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
                    post['title'] ?? 'Sans titre',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
                      fontSize: 18,
            ),
          ),
                  const SizedBox(height: 8),
          Text(
                    post['content'] ?? 'Aucun contenu',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Actions
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  IconButton(
                    icon: const Icon(Icons.thumb_up_outlined),
                    onPressed: () {
                      // Ajouter la logique de like ici
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.comment_outlined),
                    onPressed: () {
                      // Ajouter la logique de commentaire ici
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.star_outline),
                    onPressed: () {
                      // Ajouter la logique d'intérêt ici
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Affiche les utilisateurs qui ont aimé un post
  void _showLikesBottomSheet(BuildContext context, String postId) async {
    try {
      final url = Uri.parse('${constants.getBaseUrl()}/api/posts/$postId/likes');
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final List<dynamic> likesData = json.decode(response.body);
        
        if (!mounted) return;
        
        showModalBottomSheet(
          context: context,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (context) {
            return Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Aimé par ${likesData.length} personne${likesData.length > 1 ? 's' : ''}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(),
                  Expanded(
                    child: likesData.isEmpty
                      ? const Center(child: Text('Personne n\'a encore aimé ce post'))
                      : ListView.builder(
                          itemCount: likesData.length,
                          itemBuilder: (context, index) {
                            final user = likesData[index];
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundImage: user['photo_url'] != null
                                  ? NetworkImage(user['photo_url'])
                                  : null,
                                child: user['photo_url'] == null
                                  ? const Icon(Icons.person)
                                  : null,
                              ),
                              title: Text(user['name'] ?? 'Utilisateur'),
                              subtitle: user['bio'] != null ? Text(
                                user['bio'],
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ) : null,
                              onTap: () {
                                Navigator.pop(context);
                                // Navigation vers le profil de l'utilisateur si nécessaire
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
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible de charger les likes')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }

  // Affiche les commentaires d'un post
  void _showCommentsBottomSheet(BuildContext context, String postId) async {
    try {
      final url = Uri.parse('${constants.getBaseUrl()}/api/posts/$postId/comments');
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final List<dynamic> commentsData = json.decode(response.body);
        
        if (!mounted) return;
        
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
          builder: (context) {
            return DraggableScrollableSheet(
              initialChildSize: 0.6,
              minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
              builder: (context, scrollController) {
                return Container(
              padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${commentsData.length} commentaire${commentsData.length > 1 ? 's' : ''}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const Divider(),
            Expanded(
                        child: commentsData.isEmpty
                          ? const Center(child: Text('Aucun commentaire'))
                          : ListView.builder(
                controller: scrollController,
                              itemCount: commentsData.length,
                itemBuilder: (context, index) {
                                final comment = commentsData[index];
                                final user = comment['user_id'] ?? {};
                                final content = comment['content'] ?? '';
                                final timestamp = comment['timestamp'] != null
                                  ? DateTime.parse(comment['timestamp'])
                                  : null;
                                
                  return ListTile(
                    leading: CircleAvatar(
                                    backgroundImage: user['photo_url'] != null
                                      ? NetworkImage(user['photo_url'])
                          : null,
                                    child: user['photo_url'] == null
                                      ? const Icon(Icons.person)
                          : null,
                    ),
                                  title: Row(
                                    children: [
                                      Text(
                                        user['name'] ?? 'Utilisateur',
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      if (timestamp != null) ...[
                                        const SizedBox(width: 8),
                                        Text(
                                          _formatTimestamp(timestamp),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  subtitle: Text(content),
                                  isThreeLine: content.length > 40,
                                );
                              },
                            ),
                      ),
                      const Divider(),
                      // Add comment input field
                      Row(
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
                            icon: const Icon(Icons.send, color: Colors.teal),
                            onPressed: () {
                              // Ajouter un commentaire
                      Navigator.pop(context);
                              // Rediriger vers la page de détail du post pour commenter
                              _navigateToPostDetail({"_id": postId});
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible de charger les commentaires')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()} an${(difference.inDays / 365).floor() > 1 ? 's' : ''}';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()} mois';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} jour${difference.inDays > 1 ? 's' : ''}';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} heure${difference.inHours > 1 ? 's' : ''}';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} min';
    } else {
      return 'à l\'instant';
    }
  }

  // Like un post
  Future<void> _likePost(String postId) async {
    try {
      final url = Uri.parse('${constants.getBaseUrl()}/api/posts/$postId/like');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'user_id': widget.userId}),
      );
      
      if (response.statusCode == 200) {
        // Rafraîchir les posts en utilisant _userFuture
        _userFuture.then((userData) {
          setState(() {
            _postsFuture = _fetchUserPosts(userData['posts'] ?? []);
          });
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post liké !'),
            duration: Duration(seconds: 1),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible de liker ce post')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
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
      final url = Uri.parse('${constants.getBaseUrl()}/api/choices');
      
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

    // Gather all place IDs to fetch
    List<String> placeIds = [];
    for (var choice in choices) {
      String? targetId;
      
      // Handle both formats:
      // 1. When choice is already a map with targetId
      // 2. When choice is an ObjectId that needs to be converted to string
      if (choice is Map && choice.containsKey('targetId')) {
        targetId = choice['targetId'].toString();
      } else {
        targetId = choice.toString();
      }
      
      if (targetId.isNotEmpty) {
        placeIds.add(targetId);
      }
    }

    return FutureBuilder<Map<String, dynamic>>(
      future: _fetchPlaceDetails(placeIds),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final placeDetails = snapshot.data ?? {};

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
            
            // Extract the targetId from the choice
            String targetId = '';
            if (choice is Map && choice.containsKey('targetId')) {
              targetId = choice['targetId'].toString();
            } else {
              targetId = choice.toString();
            }
            
            // Get place details if available
            final placeDetail = placeDetails[targetId] ?? {};
            final String placeName = placeDetail['name'] ?? 
                                     placeDetail['intitulé'] ?? 
                                     placeDetail['titre'] ?? 
                                     'Lieu non spécifié';
            
            // Use specific fields based on the place type
            String? imageUrl;
            if (placeDetail['photos']?.isNotEmpty == true) {
              imageUrl = placeDetail['photos']?[0];
            } else {
              imageUrl = placeDetail['image'] != null 
                  ? placeDetail['image'] 
                  : (placeDetail['photo_url'] != null 
                      ? placeDetail['photo_url'] 
                      : '');
            }
            
            // Determine place type icon
            IconData placeIcon = Icons.place;
            if (placeDetail['category']?.contains('restaurant') == true) {
              placeIcon = Icons.restaurant;
            } else if (placeDetail['category']?.contains('event') == true) {
              placeIcon = Icons.event;
            } else if (placeDetail['category']?.contains('culture') == true) {
              placeIcon = Icons.museum;
            }
            
            return GestureDetector(
              onTap: () {
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
              child: Card(
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                          Positioned.fill(
                            child: imageUrl != null && imageUrl.isNotEmpty
                              ? Image(
                                  image: getImageProvider(imageUrl)!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => _buildPlaceholderImage(Colors.grey[200]!, placeIcon, placeName),
                                )
                              : _buildPlaceholderImage(Colors.grey[200]!, placeIcon, placeName),
                          ),
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
                                    placeName,
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
                                      const Icon(Icons.star, size: 14, color: Colors.amber),
                                const SizedBox(width: 4),
                                Text(
                                        placeDetail['rating']?.toString() ?? "N/A",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                                ],
                              ),
                            ),
                          ),
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
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        placeDetail['address'] ?? 
                        placeDetail['lieu'] ?? 
                        placeDetail['adresse'] ?? '',
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
      },
    );
  }

  Future<Map<String, dynamic>> _fetchPlaceDetails(List<String> placeIds) async {
    Map<String, dynamic> results = {};
    
    if (placeIds.isEmpty) return results;
    
    // Try to fetch each place from different API endpoints
    for (String placeId in placeIds) {
      bool fetched = false;
      
      // Try restaurant API first
      try {
        final url = Uri.parse('${constants.getBaseUrl()}/api/producers/$placeId');
        final response = await http.get(url);
        
        if (response.statusCode == 200) {
          results[placeId] = json.decode(response.body);
          fetched = true;
      }
    } catch (e) {
        print('❌ Error fetching restaurant: $e');
      }
      
      // Try leisure producer API if not fetched yet
      if (!fetched) {
        try {
          final url = Uri.parse('${constants.getBaseUrl()}/api/leisureProducers/$placeId');
          final response = await http.get(url);
          
          if (response.statusCode == 200) {
            results[placeId] = json.decode(response.body);
            fetched = true;
          }
        } catch (e) {
          print('❌ Error fetching leisure producer: $e');
        }
      }
      
      // Try unified API as last resort
      if (!fetched) {
        try {
          final url = Uri.parse('${constants.getBaseUrl()}/api/unified/$placeId');
          final response = await http.get(url);
          
          if (response.statusCode == 200) {
            results[placeId] = json.decode(response.body);
          }
        } catch (e) {
          print('❌ Error fetching unified: $e');
        }
      }
    }
    
    return results;
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

    // Properly convert List<dynamic> to List<String>
    List<String> interestIds = interests.map<String>((interest) => interest.toString()).toList();
    
    return FutureBuilder<Map<String, dynamic>>(
      future: _fetchPlaceDetails(interestIds),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final placeDetails = snapshot.data ?? {};
        
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
            final interestId = interests[index].toString();
            
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
            if (placeDetail['category']?.contains('restaurant') == true) {
              placeIcon = Icons.restaurant;
            } else if (placeDetail['category']?.contains('event') == true) {
              placeIcon = Icons.event;
            } else if (placeDetail['category']?.contains('culture') == true) {
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
              child: Card(
                clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
                elevation: 2,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Positioned.fill(
                      child: imageUrl != null && imageUrl.isNotEmpty
                        ? Image(
                            image: getImageProvider(imageUrl)!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => _buildPlaceholderImage(Colors.grey[200]!, placeIcon, placeName),
                          )
                        : _buildPlaceholderImage(Colors.grey[200]!, placeIcon, placeName),
                    ),
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
                              placeName,
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
      },
    );
  }
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
  
  Widget _buildMenuOption({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
    Color? color,
    bool isToggle = false,
  }) {
    return ListTile(
      leading: Icon(icon, color: color ?? Colors.grey[800]),
      title: Text(
        text,
        style: TextStyle(
          color: color ?? Colors.grey[800],
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: isToggle
          ? Switch(
              value: Theme.of(context).brightness == Brightness.dark,
              onChanged: (_) => onTap(),
              activeColor: Colors.teal,
            )
          : null,
      onTap: isToggle ? null : onTap,
    );
  }

  void _navigateToPostDetail(Map<String, dynamic> post) {
    // Éviter d'utiliser PostLocation et passer simplement les données brutes
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PostDetailScreen(
          post: post, 
          userId: widget.userId
        ),
      ),
    );
  }

  // Helper function to provide default user data
  Map<String, dynamic> _getDefaultUserData(String userId) {
    return {
      '_id': userId,
      'name': 'Utilisateur',
      'bio': 'Informations non disponibles',
      'profilePicture': '',
      'followers': <String>[],
      'following': <String>[],
      'posts': <String>[],
      'interests': <String>[],
      'liked_tags': <String>[],
      'conversations': <String>[]
    };
  }

  // Stub implementations to resolve missing references
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
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
    final url = Uri.parse('${constants.getBaseUrl()}/api/posts/$postId/like');
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
    final url = Uri.parse('${constants.getBaseUrl()}/api/posts/$postId/choice');
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
    final url = Uri.parse('${constants.getBaseUrl()}/api/posts/$postId/comments');
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
                backgroundColor: Colors.grey[300],
                child: post['user_photo'] != null && post['user_photo'].toString().isNotEmpty
                  ? CircleAvatar(
                      backgroundImage: getImageProvider(post['user_photo']),
                      onBackgroundImageError: (exception, stackTrace) {
                        // Error handling for background image
                      },
                    )
                  : Icon(Icons.person, color: Colors.grey[600]),
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
                    return CachedNetworkImage(
                      imageUrl: url,
                      fit: BoxFit.cover,
              width: double.infinity, 
                      placeholder: (context, url) => Container(
                        color: Colors.grey[200],
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[200],
                        child: const Icon(Icons.broken_image, size: 50),
                      ),
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
  bool _isVerifying = false;
  bool _isVerified = false;
  Map<String, dynamic>? _verificationResult;

  List<dynamic> _searchResults = []; // Liste pour stocker les résultats de recherche
  String? _selectedLocationId; // ID de l'élément sélectionné
  String? _selectedLocationType; // Type de l'élément sélectionné (restaurant, event, ou leisureProducer)
  String? _selectedLocationName; // Nom de l'élément sélectionné
  Map<String, dynamic>? _selectedLocationDetails; // Détails complets du lieu sélectionné
  
  // Notes par aspect - spécifiques au type de lieu
  Map<String, double> _aspectRatings = {};
  double _overallRating = 3.0; // Note globale par défaut
  
  // Pour les restaurants - plats consommés
  List<String> _selectedMenuItems = [];
  final TextEditingController _menuItemController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _initializeAspectRatings();
  }
  
  void _initializeAspectRatings() {
    // Initialisation avec des valeurs par défaut
    _aspectRatings = {
      'qualite_generale': 3.0,
      'interet': 3.0,
      'originalite': 3.0,
    };
  }
  
  /// Met à jour les aspects de notation en fonction du type de lieu
  void _updateAspectRatings(String locationType, Map<String, dynamic> locationDetails) {
          setState(() {
      if (locationType == 'restaurant') {
        _aspectRatings = {
          'nourriture': 3.0,
          'service': 3.0,
          'ambiance': 3.0,
          'rapport_qualite_prix': 3.0,
        };
      } 
      else if (locationType == 'event') {
        // Déterminer la catégorie de l'événement
        String? category = locationDetails['categorie'] ?? locationDetails['type'] ?? 'Default';
        
        if (category?.contains('Théâtre') ?? false) {
          _aspectRatings = {
            'mise_en_scene': 3.0,
            'jeu_des_acteurs': 3.0,
            'texte': 3.0,
            'scenographie': 3.0,
          };
        } 
        else if ((category?.contains('Concert') ?? false) || (category?.contains('Musique') ?? false)) {
          _aspectRatings = {
            'performance': 3.0,
            'repertoire': 3.0,
            'son': 3.0,
            'ambiance': 3.0,
          };
        } 
        else if (category?.contains('Danse') ?? false) {
          _aspectRatings = {
            'choregraphie': 3.0,
            'technique': 3.0,
            'expressivite': 3.0,
            'musique': 3.0,
          };
        } 
        else {
          _aspectRatings = {
            'qualite_generale': 3.0,
            'interet': 3.0,
            'originalite': 3.0,
          };
        }
      } 
      else if (locationType == 'leisureProducer') {
        // Déterminer le type de lieu culturel
        String? category = locationDetails['categorie'] ?? locationDetails['type'] ?? 'Default';
        
        if (category?.contains('Théâtre') ?? false) {
          _aspectRatings = {
            'programmation': 3.0,
            'lieu': 3.0,
            'accueil': 3.0,
            'accessibilite': 3.0,
          };
        } 
        else if ((category?.contains('Musée') ?? false) || (category?.contains('Exposition') ?? false)) {
          _aspectRatings = {
            'collections': 3.0,
            'scenographie': 3.0,
            'mediation_culturelle': 3.0,
            'accessibilite': 3.0,
          };
        } 
        else {
          _aspectRatings = {
            'qualite_generale': 3.0,
            'interet': 3.0,
            'originalite': 3.0,
            'accessibilite': 3.0,
          };
        }
      }
    });
  }
  
  /// Fonction pour vérifier si l'utilisateur a visité le lieu
  Future<void> _verifyLocationVisit() async {
    if (_selectedLocationId == null || _selectedLocationType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez d\'abord sélectionner un lieu')),
      );
      return;
    }
    
    setState(() {
      _isVerifying = true;
      _isVerified = false;
      _verificationResult = null;
    });
    
    try {
      // Convertir le type pour l'API de vérification
      String apiLocationType;
      if (_selectedLocationType == 'restaurant') {
        apiLocationType = 'restaurant';
      } else if (_selectedLocationType == 'event') {
        apiLocationType = 'event';
      } else {
        apiLocationType = 'leisure';
      }
      
      // Appeler l'API de vérification de localisation
      final url = Uri.parse('${constants.getBaseUrl()}/api/location-history/verify?userId=${widget.userId}&locationId=$_selectedLocationId&locationType=$apiLocationType');
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        setState(() {
          _isVerifying = false;
          _isVerified = result['verified'] ?? false;
          _verificationResult = result;
        });
        
        if (!_isVerified) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Vous n\'avez pas passé assez de temps à cet endroit récemment.'),
              duration: const Duration(seconds: 5),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Visite vérifiée !'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        throw Exception('Erreur lors de la vérification: ${response.body}');
      }
    } catch (e) {
      setState(() {
        _isVerifying = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }
  
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
    
    // Vérifier si la visite a été validée
    if (!_isVerified) {
      // Demander une vérification si ce n'est pas déjà fait
      if (_verificationResult == null) {
        await _verifyLocationVisit();
      }
      
      if (!_isVerified) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vous devez avoir passé au moins 30 minutes sur place dans les 7 derniers jours pour publier ce post.'),
            duration: Duration(seconds: 5),
          ),
        );
        return;
      }
    }

    // Calculer la note moyenne des aspects
    double ratingSum = 0;
    _aspectRatings.forEach((key, value) {
      ratingSum += value;
    });
    _overallRating = ratingSum / _aspectRatings.length;

                setState(() {
      _isLoading = true;
    });

    // Préparer les données du post en fonction du type de lieu
    Map<String, dynamic> postData = {
      'userId': widget.userId,
      'content': content,
      'rating': _overallRating,
      'aspectRatings': _aspectRatings,
      'media': _mediaUrl != null ? [_mediaUrl] : [],
      'isChoice': true,
    };
    
    // Ajouter des champs spécifiques selon le type
    if (_selectedLocationType == 'restaurant') {
      postData['linkedId'] = _selectedLocationId;
      postData['linkedType'] = 'producer';
      postData['producerId'] = _selectedLocationId;
      postData['menuItems'] = _selectedMenuItems;
      postData['tags'] = [_selectedLocationName ?? 'Restaurant'];
    } 
    else if (_selectedLocationType == 'event') {
      postData['linkedId'] = _selectedLocationId;
      postData['linkedType'] = 'event';
      postData['eventId'] = _selectedLocationId;
      postData['tags'] = [_selectedLocationName ?? 'Événement'];
      
      // Ajouter la date de l'événement si disponible
      if (_selectedLocationDetails != null && _selectedLocationDetails!['date'] != null) {
        postData['eventDate'] = _selectedLocationDetails!['date'];
      }
    } 
    else if (_selectedLocationType == 'leisureProducer') {
      postData['linkedId'] = _selectedLocationId;
      postData['linkedType'] = 'leisure';
      postData['leisureVenueId'] = _selectedLocationId;
      postData['tags'] = [_selectedLocationName ?? 'Lieu culturel'];
    }

    try {
      final url = Uri.parse('${constants.getBaseUrl()}/api/posts');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(postData),
      );

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post créé avec succès !'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context); // Revenir au profil après la création
      } else {
        print('Erreur : ${response.body}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la création du post: ${response.body}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Erreur réseau : $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur réseau: $e'),
          backgroundColor: Colors.red,
        ),
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
      final url = Uri.parse('${constants.getBaseUrl()}/api/unified/search?query=$query');
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
      _selectedLocationDetails = null;
      _locationNameController.clear();
      _selectedMenuItems = [];
      _isVerified = false;
      _verificationResult = null;
      _initializeAspectRatings(); // Réinitialiser les notes
    });
  }
  
  // Ajouter un plat au menu (pour les restaurants)
  void _addMenuItem() {
    if (_menuItemController.text.isEmpty) return;
    
    setState(() {
      _selectedMenuItems.add(_menuItemController.text);
      _menuItemController.clear();
    });
  }
  
  // Supprimer un plat du menu
  void _removeMenuItem(int index) {
    setState(() {
      _selectedMenuItems.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Partagez votre expérience'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          if (_isVerified && !_isLoading)
            TextButton(
              onPressed: _createPost,
              child: const Text('PUBLIER', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section de recherche de lieu
            if (_selectedLocationId == null) ...[
              const Text(
                'Où êtes-vous allé(e) ?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
        TextField(
                controller: _locationNameController,
                onChanged: _performSearch,
          decoration: InputDecoration(
                  hintText: 'Recherchez un restaurant ou un événement...',
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              if (_searchResults.isNotEmpty)
                Container(
                  height: 250,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ListView.separated(
                    itemCount: _searchResults.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = _searchResults[index];
                      
                      // Déterminer le type et les propriétés de l'élément
                      final bool isRestaurant = item['type'] == 'restaurant' || (item['name'] != null && item['address'] != null);
                      final bool isEvent = item['type'] == 'event' || item['intitulé'] != null || item['titre'] != null;
                      final bool isLeisureVenue = item['type'] == 'leisureProducer' || (item['nom'] != null || item['lieu'] != null);
                      
                      String title = item['name'] ?? item['intitulé'] ?? item['titre'] ?? item['nom'] ?? item['lieu'] ?? 'Sans nom';
                      String subtitle = item['address'] ?? item['adresse'] ?? item['lieu'] ?? '';
                      String type = isRestaurant ? 'restaurant' : (isEvent ? 'event' : 'leisureProducer');
                      
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isRestaurant ? Colors.amber.shade200 : 
                                           isEvent ? Colors.teal.shade200 : 
                                           Colors.purple.shade200,
                          child: Icon(
                            isRestaurant ? Icons.restaurant : 
                            isEvent ? Icons.event : 
                            Icons.museum,
                            color: isRestaurant ? Colors.amber.shade800 : 
                                   isEvent ? Colors.teal.shade800 : 
                                   Colors.purple.shade800,
                          ),
                        ),
                        title: Text(title),
                        subtitle: Text(subtitle),
          onTap: () {
            setState(() {
                            _selectedLocationId = item['_id'];
                            _selectedLocationType = type;
                            _selectedLocationName = title;
                            _selectedLocationDetails = item;
                            _searchResults = [];
                            
                            // Mettre à jour les aspects de notation en fonction du type de lieu
                            _updateAspectRatings(type, item);
                          });
                          
                          // Vérifier si l'utilisateur a visité ce lieu
                          _verifyLocationVisit();
                        },
                      );
                    },
                  ),
                ),
            ],
            
            // Lieu sélectionné et statut de vérification
            if (_selectedLocationId != null) ...[
              // Affichage du lieu sélectionné
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
          children: [
                          CircleAvatar(
                            backgroundColor: _selectedLocationType == 'restaurant' ? Colors.amber.shade200 :
                                             _selectedLocationType == 'event' ? Colors.teal.shade200 :
                                             Colors.purple.shade200,
                            radius: 24,
                            child: Icon(
                              _selectedLocationType == 'restaurant' ? Icons.restaurant :
                              _selectedLocationType == 'event' ? Icons.event :
                              Icons.museum,
                              size: 24,
                              color: _selectedLocationType == 'restaurant' ? Colors.amber.shade800 :
                                     _selectedLocationType == 'event' ? Colors.teal.shade800 :
                                     Colors.purple.shade800,
                            ),
                          ),
                          const SizedBox(width: 16),
            Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selectedLocationName ?? 'Lieu sélectionné',
                style: const TextStyle(
                                    fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _selectedLocationType == 'restaurant' ? 'Restaurant' :
                                  _selectedLocationType == 'event' ? 'Événement' :
                                  'Lieu culturel',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: _resetSelection,
            ),
          ],
        ),
        const SizedBox(height: 16),
        
                      // Statut de vérification
                      if (_isVerifying)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 12.0),
                            child: Column(
                              children: [
                                CircularProgressIndicator(),
                                SizedBox(height: 8),
                                Text('Vérification de votre visite...'),
                              ],
                            ),
                          ),
                        )
                      else if (_isVerified)
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green.shade300),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.green.shade700),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Visite vérifiée !',
          style: TextStyle(
            fontWeight: FontWeight.bold,
                                        color: Colors.green.shade800,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Vous pouvez partager votre expérience.',
                                      style: TextStyle(
                                        color: Colors.green.shade800,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange.shade300),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.info, color: Colors.orange.shade700),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Vérification de visite requise',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.orange.shade800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Pour partager votre expérience, vous devez avoir passé au moins 30 minutes sur place dans les 7 derniers jours.',
                                style: TextStyle(
                                  color: Colors.orange.shade800,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _verifyLocationVisit,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: const Text('VÉRIFIER MA VISITE'),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              // Section d'évaluation (uniquement si visite vérifiée)
              if (_isVerified) ...[
                const Text(
                  'Évaluez votre expérience',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        
                // Notes par aspect
                ...List.generate(_aspectRatings.entries.length, (index) {
                  final entry = _aspectRatings.entries.elementAt(index);
                  final aspect = entry.key;
                  final rating = entry.value;
                  
                  // Formater l'affichage de l'aspect
                  String displayAspect = aspect
                      .replaceAll('_', ' ')
                      .split(' ')
                      .map((word) => word.isNotEmpty 
                          ? word[0].toUpperCase() + word.substring(1) 
                          : '')
                      .join(' ');
                  
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 1,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                                displayAspect,
                  style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                    fontSize: 16,
                                ),
                              ),
                              Text(
                                '${rating.toStringAsFixed(1)}/5',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: Colors.teal,
                              inactiveTrackColor: Colors.teal.shade100,
                              thumbColor: Colors.teal,
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
                            ),
                      child: Slider(
                              value: rating,
                        min: 0.0,
                              max: 5.0,
                        divisions: 10,
                        onChanged: (value) {
                          setState(() {
                                  _aspectRatings[aspect] = value;
                          });
                        },
                      ),
                    ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Insuffisant', style: TextStyle(fontSize: 12)),
                              const Text('Excellent', style: TextStyle(fontSize: 12)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                
                // Pour les restaurants - plats consommés
                if (_selectedLocationType == 'restaurant') ...[
                  const SizedBox(height: 20),
                  const Text(
                    'Plats consommés',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _menuItemController,
                          decoration: InputDecoration(
                            hintText: 'Ex: Salade César, Burger...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _addMenuItem,
                        icon: const Icon(Icons.add),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                        ),
                ),
              ],
            ),
                  if (_selectedMenuItems.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List.generate(_selectedMenuItems.length, (index) {
                        return Chip(
                          label: Text(_selectedMenuItems[index]),
                          deleteIcon: const Icon(Icons.close, size: 16),
                          onDeleted: () => _removeMenuItem(index),
                          backgroundColor: Colors.grey.shade200,
                        );
                      }),
                    ),
                  ],
                ],
              ],
              
              const SizedBox(height: 20),
              
              // Section de contenu
              const Text(
                'Partagez votre expérience',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
        TextField(
                controller: _contentController,
                maxLines: 5,
          decoration: InputDecoration(
                  hintText: 'Qu\'avez-vous pensé de cet endroit ?',
            border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
                maxLength: 500,
              ),
              const SizedBox(height: 20),
              
              // Section média
              const Text(
                'Ajouter des photos ou vidéos',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _uploadMedia(true),
                      icon: const Icon(Icons.photo),
                      label: const Text('Photo'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _uploadMedia(false),
                      icon: const Icon(Icons.videocam),
                      label: const Text('Vidéo'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
              if (_mediaUrl != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Stack(
                    children: [
                      _mediaType == "image"
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network(
                                _mediaUrl!,
                                height: 200,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            )
                          : Container(
                              height: 200,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Center(
                                child: Icon(Icons.videocam, size: 50, color: Colors.grey),
                              ),
                            ),
                      Positioned(
                        right: 8,
                        top: 8,
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _mediaUrl = null;
                              _mediaType = null;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),
              
              // Bouton de publication (pour les petits écrans)
              if (MediaQuery.of(context).size.width < 600)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isVerified && !_isLoading ? _createPost : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      disabledBackgroundColor: Colors.grey.shade300,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'PUBLIER',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
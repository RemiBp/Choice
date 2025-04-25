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
import '../utils/utils.dart'; // Import utils pour getBaseUrl() et getImageProvider
import 'CreatePostScreen.dart';
import 'edit_profile_screen.dart'; // Import EditProfileScreen
import 'post_detail_screen.dart'; // Import PostDetailScreen
import 'dart:io'; // Pour File (utilisé dans _ChoiceForm)
import 'package:choice_app/screens/choice_detail_screen.dart'; // Importer le nouvel écran
import 'choice_creation_screen.dart'; // Importer l'écran de création de choice
import 'profile_screen.dart'; // Import ProfileScreen
import 'package:choice_app/utils/validation_utils.dart';

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

class _MyProfileScreenState extends State<MyProfileScreen> with AutomaticKeepAliveClientMixin {
  // State pour les données du profil et des posts
  late Future<Map<String, dynamic>> _userFuture;
  late Future<List<dynamic>> _postsFuture;

  // Garder l'état de la page
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _fetchData(); // Lancer la récupération des données
    
    // Vérifier périodiquement si nous devons demander le coup de cœur du mois
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkIfShouldAskForFavoriteChoice();
    });
  }

  // Fonction principale pour récupérer les données utilisateur et posts
  void _fetchData() {
    // Créer le Future pour l'utilisateur
    _userFuture = _fetchUserProfile(widget.userId);

    // Créer le Future pour les posts, qui dépend du résultat de _userFuture
    _postsFuture = _userFuture.then((user) {
      // Vérifier si l'utilisateur a été chargé correctement
      if (user['_id'] != null && user['_id'] == widget.userId) {
        // Lancer la récupération des posts seulement si l'utilisateur est valide
        return _fetchUserPosts(user['_id']);
      } else {
        // Si l'utilisateur n'a pas pu être chargé ou ID incorrect, retourner une liste vide
        print("⚠️ Utilisateur non chargé ou ID incorrect, impossible de récupérer les posts.");
        return Future.value(<dynamic>[]); // Retourner un Future<List> vide
      }
    }).catchError((error) {
      // Gérer les erreurs lors de la récupération de l'utilisateur
      print("❌ Erreur lors de la récupération initiale de l'utilisateur: $error");
      return Future.value(<dynamic>[]); // Retourner un Future<List> vide en cas d'erreur
    });

    // Mettre à jour l'état pour reconstruire avec les Futures initialisés
    if (mounted) {
      setState(() {});
    }
  }

  // ---------------------------------------------------------------------------
  // Fonctions de récupération de données (API Calls)
  // ---------------------------------------------------------------------------

  /// Récupère le profil utilisateur complet
  Future<Map<String, dynamic>> _fetchUserProfile(String userId) async {
    // Ne pas appeler si le widget n'est plus monté
    if (!mounted) return _getDefaultUserData(userId);
    
    final authService = provider_pkg.Provider.of<AuthService>(context, listen: false);
      final token = await authService.getTokenInstance(forceRefresh: false);
    final baseUrl = getBaseUrlFromUtils(); // Utiliser l'utilitaire local
      
      final headers = {
        'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };

    try {
      print("🔄 Fetching user profile for $userId...");
      final url = Uri.parse('$baseUrl/api/users/$userId');
      final response = await http.get(url, headers: headers).timeout(const Duration(seconds: 10));

      if (!mounted) return _getDefaultUserData(userId);

      if (response.statusCode == 200) {
        print("✅ User profile fetched successfully for $userId.");
          Map<String, dynamic> userData = json.decode(response.body);
        // Normalisation des données (s'assurer que les listes existent etc.)
        return _normalizeUserData(userData, userId);
      } else {
        print('❌ Erreur récupération profil utilisateur $userId (${response.statusCode}): ${response.body}');
        return _getDefaultUserData(userId); // Retourner données par défaut en cas d'erreur
      }
    } catch (e) {
      print('❌ Exception lors de la récupération du profil $userId: $e');
      return _getDefaultUserData(userId); // Retourner données par défaut en cas d'exception
    }
  }

   /// Normalise les données utilisateur reçues de l'API
   Map<String, dynamic> _normalizeUserData(Map<String, dynamic> userData, String originalUserId) {
     // Assurer l'existence des champs clés
     userData['_id'] ??= originalUserId;
     userData['name'] ??= 'Utilisateur inconnu';
          userData['followers'] = _ensureStringList(userData['followers']);
          userData['following'] = _ensureStringList(userData['following']);
          userData['posts'] = _ensureStringList(userData['posts']);
          userData['interests'] = _ensureStringList(userData['interests']);
     userData['liked_tags'] = _ensureStringList(userData['liked_tags']);
          userData['conversations'] = _ensureStringList(userData['conversations']);
     // Assurer que choices est une liste (peut contenir des objets ou des IDs)
     userData['choices'] = (userData['choices'] is List) ? userData['choices'] : [];
     userData['bio'] ??= ''; // Assurer que bio existe
     userData['profilePicture'] ??= userData['photo_url']; // Fallback photo_url
          return userData;
   }


  /// Récupère les posts associés à l'utilisateur
  Future<List<dynamic>> _fetchUserPosts(String userId) async {
    if (!mounted) return [];
    
    final authService = provider_pkg.Provider.of<AuthService>(context, listen: false);
      final token = await authService.getTokenInstance();
    final baseUrl = getBaseUrlFromUtils();

    // Pour les profils publics, on pourrait éventuellement essayer sans token,
    // mais la route actuelle semble protégée.
      if (token == null || token.isEmpty) {
      print('ℹ️ Pas de token pour récupérer les posts du profil $userId. Affiche une liste vide.');
        return [];
      }
      
      final headers = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json'
      };
      
    try {
      print("🔄 Fetching posts for user $userId...");
      final url = Uri.parse('$baseUrl/api/users/$userId/posts');
      final response = await http.get(url, headers: headers).timeout(const Duration(seconds: 15));

      if (!mounted) return [];
  
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<dynamic> postsList = [];
        
        if (data is Map<String, dynamic> && data.containsKey('posts')) {
          postsList = data['posts'] is List ? data['posts'] : [];
        } else if (data is List) {
          postsList = data;
        }
        
        if (postsList.isEmpty) {
          print('✅ Aucun post trouvé pour $userId.');
          return [];
        }
        
        print('✅ ${postsList.length} posts récupérés pour $userId.');
        // Normaliser chaque post
        return postsList.map((post) => _normalizePostData(post)).toList();
      } else if (response.statusCode == 401 || response.statusCode == 403) {
         // Correction: Utiliser des guillemets doubles pour la chaîne contenant une apostrophe
         // Correction: Utiliser un caractère ASCII pour l'icône d'avertissement
         print("⚠️ Erreur d'authentification (${response.statusCode}) lors de la recuperation des posts de $userId");
         if (widget.isCurrentUser) {
           authService.logout();
           if (mounted) {
             ScaffoldMessenger.of(context).showSnackBar(
               // Correction: Utiliser des guillemets doubles
               const SnackBar(content: Text("Session expiree. Veuillez vous reconnecter."))
             );
             Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
           }
         }
        return [];
      } else {
        print('❌ Erreur recuperation posts $userId (${response.statusCode}): ${response.body}');
        return [];
      }
    } catch (e) {
      print('❌ Exception lors de la recuperation des posts de $userId: $e');
      return [];
    }
  }
  
   /// Normalise les données d'un post reçu de l'API
   Map<String, dynamic> _normalizePostData(dynamic postData) {
     if (postData is! Map<String, dynamic>) {
       // Si ce n'est pas un map, retourner un objet vide ou une structure par défaut
       return {'_id': UniqueKey().toString(), 'title': 'Post invalide', 'content': '', 'media': [], 'likes': [], 'comments': [], 'author': {}, 'createdAt': DateTime.now().toIso8601String()};
     }

     // Copie pour éviter de modifier l'original directement
     final post = Map<String, dynamic>.from(postData);

     // Assurer les champs de base
     post['_id'] = post['_id']?.toString() ?? UniqueKey().toString();
     post['title'] ??= '';
     post['content'] ??= '';
     post['createdAt'] = post['createdAt'] ?? DateTime.now().toIso8601String();
     post['likes'] = _ensureStringList(post['likes']);
     post['media'] = (post['media'] is List) ? post['media'] : [];

     // Normaliser les commentaires (assurer format Map)
     if (post['comments'] is List) {
       post['comments'] = (post['comments'] as List).map((c) {
         if (c is Map<String, dynamic>) return c;
         return {'content': c.toString()}; // Format minimal si ce n'est pas un Map
       }).toList();
     } else {
       post['comments'] = <Map<String, dynamic>>[];
     }

     // Normaliser l'auteur
    if (post['author'] is String) {
       post['author'] = {'_id': post['author'], 'name': 'Auteur inconnu'};
     } else if (post['author'] is Map<String, dynamic>) {
       post['author']['_id'] ??= '';
       post['author']['name'] ??= 'Auteur inconnu';
     } else {
       post['author'] = {'_id': '', 'name': 'Auteur inconnu'};
     }

     // Normaliser la localisation
     if (post['location'] is Map<String, dynamic>) {
       post['location']['_id'] = post['location']['_id']?.toString(); // Assurer string ou null
       post['location']['name'] ??= 'Lieu associé';
       post['location']['type'] ??= 'unknown';
     } else {
       post['location'] = null; // Mettre à null si pas un Map valide
     }

     return post;
   }


  /// Récupère les informations minimales d'un utilisateur ou producteur par son ID
  Future<Map<String, dynamic>> _fetchMinimalUserInfo(String userId) async {
    if (!mounted) return {'_id': userId, 'name': '...', 'profilePicture': null, 'type': 'unknown'};
    final authService = provider_pkg.Provider.of<AuthService>(context, listen: false);
    final token = await authService.getTokenInstance(forceRefresh: false);
    final baseUrl = getBaseUrlFromUtils();
    final headers = {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };

    // Helper interne pour fetch info sur un endpoint
    Future<Map<String, dynamic>?> tryFetch(String url, String type) async {
      try {
        final response = await http.get(Uri.parse(url), headers: headers).timeout(const Duration(seconds: 5));
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          return {
            '_id': data['_id']?.toString() ?? userId,
            'name': data['name'] ?? data['username'] ?? 'Utilisateur',
            'profilePicture': data['profilePicture'] ?? data['avatar'] ?? data['logo'] ?? data['photo_url'],
            'type': type,
          };
        }
      } catch (_) {}
      return null;
    }

    // 1. Essayer user
    final userInfo = await tryFetch('$baseUrl/api/users/$userId/info', 'user');
    if (userInfo != null) return userInfo;
    // 2. Essayer producer (restaurant)
    final producerInfo = await tryFetch('$baseUrl/api/producers/$userId/info', 'producer');
    if (producerInfo != null) return producerInfo;
    // 3. Essayer leisureProducer
    final leisureInfo = await tryFetch('$baseUrl/api/leisureProducers/$userId/info', 'leisureProducer');
    if (leisureInfo != null) return leisureInfo;
    // 4. Essayer wellnessProducer
    final wellnessInfo = await tryFetch('$baseUrl/api/wellnessProducers/$userId/info', 'wellness');
    if (wellnessInfo != null) return wellnessInfo;

    // Si rien trouvé
    return {'_id': userId, 'name': 'Inconnu', 'profilePicture': null, 'type': 'unknown'};
  }

    /// Récupère les détails d'un ensemble de lieux (restaurants, events, etc.)
    Future<Map<String, dynamic>> _fetchPlaceDetails(List<String> placeIds) async {
       if (!mounted) return {};
       if (placeIds.isEmpty) return {};

       // Filtrer les IDs invalides
       List<String> validPlaceIds = placeIds
           .where((id) => id.isNotEmpty && ValidationUtils.isValidObjectId(id))
           .toSet() // Ensure unique IDs
           .toList();
       if (validPlaceIds.isEmpty) return {};

       print("🔄 Fetching details for ${validPlaceIds.length} places using BATCH endpoint...");

       Map<String, dynamic> results = {};
       final authService = provider_pkg.Provider.of<AuthService>(context, listen: false);
       final token = await authService.getTokenInstance();
       final headers = <String, String>{'Content-Type': 'application/json'};
       if (token != null && token.isNotEmpty) {
          headers['Authorization'] = 'Bearer $token';
       }
       final baseUrl = getBaseUrlFromUtils();

       try {
         // Utiliser le nouvel endpoint batch
         final idsParam = validPlaceIds.join(',');
         final url = Uri.parse('$baseUrl/api/unified/batch?ids=$idsParam');
         final response = await http.get(url, headers: headers).timeout(const Duration(seconds: 15)); // Augmenter timeout pour les lots importants

         if (!mounted) return {};

         if (response.statusCode == 200) {
           final decodedBody = json.decode(response.body);
           if (decodedBody is Map<String, dynamic>) {
             // La réponse est déjà un Map<String, dynamic> avec les IDs comme clés
             results = decodedBody;
             print("✅ Batch fetch successful. Received ${results.length} details.");
           } else {
             print("❌ Batch fetch response format error: Expected Map, got ${decodedBody.runtimeType}");
             // Mettre des erreurs pour tous les IDs demandés
             for (String id in validPlaceIds) {
                results[id] = {'_id': id, 'name': 'Erreur format réponse', 'error': true};
             }
           }
         } else {
           print("❌ Erreur batch fetch (${response.statusCode}): ${response.body}");
           
           // Si le batch endpoint échoue, on fait fallback sur les appels individuels
           print("⚠️ Fallback to individual requests...");
           for (String placeId in validPlaceIds) {
             try {
               final url = Uri.parse('$baseUrl/api/unified/$placeId');
               final response = await http.get(url, headers: headers).timeout(const Duration(seconds: 5));
               if (response.statusCode == 200) {
                 results[placeId] = json.decode(response.body);
               } else {
                 print("❓ Détails non trouvés ou erreur pour $placeId (${response.statusCode})");
                 results[placeId] = {'_id': placeId, 'name': 'Détails indisponibles', 'error': true};
               }
               // Petite pause pour éviter de surcharger le serveur
               await Future.delayed(const Duration(milliseconds: 50));
               if (!mounted) break;
             } catch (e) {
               print("⚠️ Erreur fetch détails pour $placeId: $e");
               results[placeId] = {'_id': placeId, 'name': 'Erreur réseau', 'error': true};
             }
           }
         }
       } catch (e) {
         print("⚠️ Exception batch fetch: $e");
         // Mettre des erreurs pour tous les IDs demandés
         for (String id in validPlaceIds) {
           results[id] = {'_id': id, 'name': 'Erreur réseau', 'error': true};
         }
       }

       // Assurer que tous les IDs demandés ont une entrée (même si c'est une erreur)
       for (String id in validPlaceIds) {
         if (!results.containsKey(id)) {
           results[id] = {'_id': id, 'name': 'Non trouvé', 'error': true};
         }
       }

       print("✅ Fin fetchPlaceDetails (batch).");
       return results;
    }


  // ---------------------------------------------------------------------------
  // Fonctions de Navigation
  // ---------------------------------------------------------------------------

  /// Navigation vers les détails d'un producteur, événement, etc.
  Future<void> _navigateToDetails(String targetId, String targetType) async {
     if (!mounted) return;
     print('➡️ Navigating to details: ID=$targetId, Type=$targetType');

     // Valider l'ID
     if (!ValidationUtils.isValidObjectId(targetId)) {
        print("❌ ID cible invalide: $targetId");
        ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text("Impossible d'ouvrir les détails (ID invalide)."))
        );
        return;
     }

     Widget? targetScreen;

     // Déterminer l'écran cible en fonction du type
     // Note: On pourrait aussi récupérer les détails ici et ensuite choisir l'écran,
     // mais pour l'instant on se base sur le type fourni.
     switch (targetType.toLowerCase()) {
       case 'restaurant':
       case 'producer': // Accepter les deux termes
         targetScreen = ProducerScreen(producerId: targetId);
         break;
       case 'leisureproducer':
       case 'leisure': // Accepter les deux termes
         // ProducerLeisureScreen attend les données, il faudrait les fetcher ici
         // ou modifier ProducerLeisureScreen pour accepter seulement l'ID.
         // Pour l'instant, on navigue vers le ProducerScreen générique.
          print("ℹ️ Navigation vers ProducerScreen (ID seulement) pour leisureProducer $targetId");
          targetScreen = ProducerScreen(producerId: targetId);
         // TODO: Remplacer par: targetScreen = ProducerLeisureScreen(producerId: targetId);
         break;
       case 'event':
         // EventLeisureScreen attend les données.
         // Pour l'instant, on navigue vers ProducerScreen.
          print("ℹ️ Navigation vers ProducerScreen (ID seulement) pour event $targetId");
         targetScreen = ProducerScreen(producerId: targetId);
         // TODO: Remplacer par: targetScreen = EventLeisureScreen(eventId: targetId);
         break;
       case 'wellness':
          print("ℹ️ Navigation vers ProducerScreen (ID seulement) pour wellness $targetId");
          targetScreen = ProducerScreen(producerId: targetId);
          // TODO: Créer et utiliser WellnessScreen(wellnessId: targetId);
         break;
       default:
         print("❓ Type de cible inconnu '$targetType' pour $targetId. Tentative ProducerScreen.");
         targetScreen = ProducerScreen(producerId: targetId);
     }

     // Naviguer si un écran a été déterminé
     if (targetScreen != null && mounted) {
          Navigator.push(
            context,
         MaterialPageRoute(builder: (context) => targetScreen!),
       );
     }
  }

  /// Navigation vers l'écran de détail d'un post
  void _navigateToPostDetail(Map<String, dynamic> post) {
     if (!mounted) return;
     final postId = post['_id']?.toString();
     if (postId == null) {
        print("❌ ID de post manquant, impossible de naviguer.");
        return;
     }

     Navigator.push(
       context,
       MaterialPageRoute(
         builder: (context) => PostDetailScreen(
           // Correction: Passer postId au lieu de l'objet post complet (Hypothèse)
           postId: postId,
           userId: widget.userId // ID de l'utilisateur dont on voit le profil
         ),
       ),
     ).then((_) {
        // Optionnel: Rafraîchir les posts après retour de PostDetailScreen?
        // _fetchData();
     });
  }

  /// Navigation vers l'écran de détail d'un Choice
  void _navigateToChoiceDetail(Map<String, dynamic> choiceData, Map<String, dynamic>? placeDetails) {
     if (!mounted) return;
     // Vérifier si choiceData est valide (au cas où)
     if (choiceData['_id'] == null) {
        print("❌ Données de choice invalides pour la navigation détail.");
        ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text("Impossible d'ouvrir les détails du choice."))
        );
        return;
     }
     
     Navigator.push(
            context,
        MaterialPageRoute(
          builder: (context) => ChoiceDetailScreen(
             choiceData: choiceData,     // Passer les données complètes du choice
             placeDetails: placeDetails, // Passer les détails du lieu déjà récupérés
          ),
      ),
    );
  }

  // --- AJOUT: Fonction manquante ---
  void _startConversation(String targetUserId) {
    if (!mounted) return;
    print("TODO: Implement start conversation with user $targetUserId");
    // Exemple de navigation (à adapter)
    // Navigator.push(context, MaterialPageRoute(builder: (context) => MessagingScreen(targetUserId: targetUserId)));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Fonctionnalite de messagerie a implementer')),
    );
  }

  // ---------------------------------------------------------------------------
  // Fonctions d'affichage des Modals (BottomSheet)
  // ---------------------------------------------------------------------------

   /// Affiche la liste des utilisateurs (abonnés/abonnements)
   void _showUserListModal(BuildContext context, List<String> userIds, String title) {
       if (!mounted) return;
       if (userIds.isEmpty) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Liste "$title" vide.')),
         );
         return;
       }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (modalContext) => DraggableScrollableSheet(
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
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: userIds.length,
                itemBuilder: (context, index) {
                  final userId = userIds[index];
                  return FutureBuilder<Map<String, dynamic>>(
                    future: _fetchMinimalUserInfo(userId),
                    builder: (context, snapshot) {
                      Widget leadingWidget = CircleAvatar(backgroundColor: Colors.grey[300]);
                      Widget titleWidget = Container(height: 10, width: 100, color: Colors.grey[300]);
                      Widget? subtitleWidget = Container(height: 8, width: 60, color: Colors.grey[200]);
                      VoidCallback? onTapAction;

                      if (snapshot.connectionState == ConnectionState.done) {
                        if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
                          leadingWidget = const CircleAvatar(child: Icon(Icons.error_outline, color: Colors.red));
                          titleWidget = Text('Erreur chargement');
                          subtitleWidget = Text('ID: $userId', style: TextStyle(fontSize: 10, color: Colors.red));
                        } else {
                          final userInfo = snapshot.data!;
                          final profilePic = userInfo['profilePicture'];
                          final userName = userInfo['name'] ?? 'Utilisateur inconnu';
                          final userType = userInfo['type'] ?? 'unknown';
                          leadingWidget = CircleAvatar(
                            backgroundColor: Colors.grey[200],
                            backgroundImage: (profilePic != null && profilePic is String && profilePic.isNotEmpty)
                                ? CachedNetworkImageProvider(profilePic)
                                : null,
                            child: (profilePic == null || !(profilePic is String) || profilePic.isEmpty)
                                ? const Icon(Icons.person, color: Colors.grey)
                                : null,
                          );
                          titleWidget = Text(userName);
                          subtitleWidget = Text(_getTypeLabel(userType), style: const TextStyle(fontSize: 12, color: Colors.teal));
                          onTapAction = () {
                            Navigator.pop(modalContext); // Fermer la modale
                            // Naviguer selon le type
                            if (userType == 'user') {
                              if (userId != widget.userId) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ProfileScreen(userId: userId, viewMode: 'public'),
                                  ),
                                );
                              }
                            } else if (userType == 'producer' || userType == 'restaurant') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ProducerScreen(producerId: userId),
                                ),
                              );
                            } else if (userType == 'leisureProducer' || userType == 'leisure') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ProducerLeisureScreen(producerId: userId),
                                ),
                              );
                            } else if (userType == 'wellness') {
                              // TODO: Créer WellnessProducerScreen si besoin
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ProducerScreen(producerId: userId),
                                ),
                              );
                            } else {
                              // Fallback
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Type de profil inconnu ou non supporté.')),
                              );
                            }
                          };
                        }
                      }

                      return ListTile(
                        leading: leadingWidget,
                        title: titleWidget,
                        subtitle: subtitleWidget,
                        onTap: onTapAction,
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

    /// Affiche la liste stylisée des intérêts (lieux favoris)
    void _showInterestsListModal(BuildContext context, List<String> interestIds, String title) {
      if (!mounted) return;
      if (interestIds.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Liste "$title" vide.')),
        );
        return;
      }
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (modalContext) => DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, scrollController) => FutureBuilder<Map<String, dynamic>>(
            future: _fetchPlaceDetails(interestIds),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final placeDetailsMap = snapshot.data ?? {};
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      title,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: interestIds.length,
                      itemBuilder: (context, index) {
                        final placeId = interestIds[index];
                        final place = placeDetailsMap[placeId] ?? {'name': 'Données indisponibles', 'error': true};
                        final hasError = place['error'] == true;
                        final String placeName = place['name'] ?? 'Lieu favori';
                        final String? imageUrl = (place['photos'] is List && place['photos'].isNotEmpty)
                          ? place['photos'][0]
                          : place['image'] ?? place['photo_url'];
                        final String address = place['address'] ?? place['adresse'] ?? place['lieu'] ?? '';
                        final String type = (place['_fetched_as'] ?? place['type'] ?? 'unknown').toString().toLowerCase();
                        IconData icon = Icons.place;
                        if (hasError) icon = Icons.error_outline;
                        else if (type.contains('restaurant')) icon = Icons.restaurant;
                        else if (type.contains('leisure')) icon = Icons.museum;
                        else if (type.contains('wellness')) icon = Icons.spa;
                        else if (type.contains('event')) icon = Icons.event;
                        return ListTile(
                          leading: (imageUrl != null && imageUrl.isNotEmpty && !hasError)
                            ? CircleAvatar(backgroundImage: getImageProvider(imageUrl)!)
                            : CircleAvatar(child: Icon(icon, color: hasError ? Colors.red : Colors.teal)),
                          title: Text(placeName),
                          subtitle: Text(address.isNotEmpty ? address : type),
                          onTap: hasError ? null : () {
                            Navigator.pop(modalContext);
                            _navigateToDetails(placeId, type);
                          },
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      );
    }

    /// Retourne un label lisible pour le type d'entité
    String _getTypeLabel(String type) {
      switch (type) {
        case 'user':
          return 'Utilisateur';
        case 'producer':
        case 'restaurant':
          return 'Restaurant';
        case 'leisureProducer':
        case 'leisure':
          return 'Producteur de loisirs';
        case 'wellness':
          return 'Bien-être';
        default:
          return 'Inconnu';
      }
    }

    /// Affiche la liste des choices de l'utilisateur
  void _showChoicesModal(BuildContext context, List<dynamic> choices) {
        if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
          builder: (modalContext) => DraggableScrollableSheet(
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
                 const Divider(height: 1),
            Expanded(
                  child: choices.isEmpty
                   ? const Center(child: Text("Aucun choice pour l'instant."))
                   : ListView.builder(
                controller: scrollController,
                itemCount: choices.length,
                itemBuilder: (context, index) {
                  final choice = choices[index];
                        // Valider et extraire les données du choice
                        if (choice is Map<String, dynamic> &&
                            choice.containsKey('targetId') &&
                            choice.containsKey('targetName') &&
                            ValidationUtils.isValidObjectId(choice['targetId']?.toString()))
                        {
                           final String targetId = choice['targetId'].toString();
                           final String targetName = choice['targetName'].toString();
                           final String targetType = choice['targetType']?.toString() ?? 'unknown';

                           // Déterminer l'icône en fonction du type
                           IconData icon = Icons.place;
                           switch (targetType.toLowerCase()) {
                              case 'restaurant': case 'producer': icon = Icons.restaurant; break;
                              case 'event': icon = Icons.event; break;
                              case 'leisureproducer': case 'leisure': icon = Icons.museum; break;
                              case 'wellness': icon = Icons.spa; break;
                           }

                           return ListTile(
                             leading: Icon(icon, color: Colors.teal),
                             title: Text(targetName),
                             subtitle: Text(targetType != 'unknown' ? 'Type: $targetType' : 'Type inconnu'),
                             trailing: const Icon(Icons.chevron_right),
                             onTap: () {
                               Navigator.pop(modalContext); // Fermer la modale
                               _navigateToDetails(targetId, targetType);
                             },
                           );
                        } else {
                          // Afficher une tuile d'erreur si les données sont invalides
                          return ListTile(
                            leading: Icon(Icons.error, color: Colors.red),
                            title: Text('Donnée Choice invalide #$index'),
                            subtitle: Text(choice.toString()),
                          );
                        }
                      },
              ),
            ),
          ],
        ),
      ),
    );
  }

   /// Affiche la modal pour ajouter un commentaire
   void _showCommentsBottomSheet(BuildContext context, String postId) async {
     if (!mounted) return;

     // Afficher un indicateur de chargement pendant la récupération des commentaires
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chargement des commentaires...'), duration: Duration(seconds: 1)));

     try {
       final url = Uri.parse('${constants.getBaseUrl()}/api/posts/$postId/comments');
       final authService = provider_pkg.Provider.of<AuthService>(context, listen: false);
       final token = await authService.getTokenInstance();
       final headers = <String, String>{'Content-Type': 'application/json'};
       if (token != null && token.isNotEmpty) {
          headers['Authorization'] = 'Bearer $token';
       }
       final response = await http.get(url, headers: headers).timeout(const Duration(seconds: 8));
        
        if (!mounted) return;

       if (response.statusCode == 200) {
         List<dynamic> commentsData = [];
         try {
            final decodedBody = json.decode(response.body);
            if (decodedBody is List) {
               commentsData = decodedBody;
            } else {
                print("⚠️ Format de réponse des commentaires inattendu: pas une liste.");
            }
         } catch(e) {
            print("❌ Erreur parsing commentaires: $e");
         }
        
        showModalBottomSheet(
          context: context,
           isScrollControlled: true,
           backgroundColor: Colors.transparent, // Pour coins arrondis du DraggableScrollableSheet
           builder: (modalContext) {
             return _CommentsBottomSheet(
               postId: postId,
               initialComments: commentsData.whereType<Map<String, dynamic>>().toList(),
               currentUserId: widget.userId, // ID de l'utilisateur affiché
               onCommentAdded: (newComment) {
                  // Rafraîchir les données pour voir le nouveau commentaire
                  _fetchData();
               },
               navigateToProfile: (userId) {
                   Navigator.pop(modalContext); // Fermer la modale avant de naviguer
                   if (userId != widget.userId) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => MyProfileScreen(userId: userId, isCurrentUser: false)),
                    );
                  }
               }
            );
          },
        );
      } else {
          print("Erreur chargement commentaires: ${response.statusCode}");
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Impossible de charger les commentaires (${response.statusCode})')),
        );
      }
    } catch (e) {
       print("Exception chargement commentaires: $e");
       if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Erreur réseau commentaires: $e')),
         );
       }
     }
   }

    /// Affiche la modal pour ajouter un Choice à un post
    void _showChoiceDialog(BuildContext context, Map<String, dynamic> post) {
      if (!mounted) return;

      final location = post['location'];
      if (location == null || location is! Map || !ValidationUtils.isValidObjectId(location['_id']?.toString())) {
        ScaffoldMessenger.of(context).showSnackBar(
          // Correction: Utiliser des guillemets doubles
          const SnackBar(content: Text("Ce post n'est pas associe a un lieu valide pour ajouter un Choice.")),
        );
        return;
      }

      final String locationId = location['_id'].toString();
      final String locationType = location['type']?.toString() ?? 'unknown';
      final String locationName = location['name']?.toString() ?? 'Lieu inconnu';
        
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (dialogContext) {
            return DraggableScrollableSheet(
            initialChildSize: 0.9,
            minChildSize: 0.5,
            maxChildSize: 0.95,
        expand: false,
            builder: (_, scrollController) {
                return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: _ChoiceForm( // Utiliser le widget _ChoiceForm
                  locationId: locationId,
                  locationType: locationType,
                  locationName: locationName,
                  currentUserId: widget.userId, // L'ID de l'utilisateur du profil affiché
                  scrollController: scrollController,
                  onSubmitSuccess: () {
                      // Rafraîchir les données après succès
                      _fetchData();
                  },
                  ),
                );
              },
            );
          },
        );
    }


  // ---------------------------------------------------------------------------
  // Fonctions d'Action (Like, etc.)
  // ---------------------------------------------------------------------------

  /// Gère le like/unlike d'un post
  Future<void> _likePost(String postId) async {
     if (!mounted) return;

     final authService = provider_pkg.Provider.of<AuthService>(context, listen: false);
     final token = await authService.getTokenInstance();
     // Correction: Utiliser getCurrentUserId() (Hypothèse)
     final currentUserId = authService.userId; // ID de l'utilisateur connecté

     if (token == null || currentUserId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          // Correction: Utiliser des guillemets doubles
          const SnackBar(content: Text("Veuillez vous reconnecter pour liker.")),
        );
        return;
     }

     print("🔄 Liking/Unliking post $postId by user $currentUserId...");

    try {
      final url = Uri.parse('${constants.getBaseUrl()}/api/posts/$postId/like');
      final response = await http.post(
        url,
         headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token'
         },
         // Le backend devrait utiliser l'ID du token, mais on peut l'envoyer si nécessaire
         body: json.encode({'user_id': currentUserId}),
       ).timeout(const Duration(seconds: 8));

       if (!mounted) return;

      if (response.statusCode == 200) {
         print("✅ Like/Unlike success for post $postId");
         // Rafraîchir les données pour mettre à jour l'UI (compteur, icône)
         // C'est simple mais pas optimal. Idéalement, on mettrait à jour l'état local du post.
         _fetchData();
      } else {
         print("❌ Erreur like post $postId (${response.statusCode}): ${response.body}");
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Impossible de liker (${response.statusCode})')),
        );
      }
    } catch (e) {
       print("❌ Exception like post $postId: $e");
       if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Erreur réseau like: $e')),
         );
       }
     }
   }


  // ---------------------------------------------------------------------------
  // Fonctions Utilitaires
  // ---------------------------------------------------------------------------

  /// Retourne l'URL de base de l'API
  String getBaseUrlFromUtils() {
    return constants.getBaseUrlSync(); // Utiliser la version synchrone
  }

  /// Convertit une liste dynamique en liste de strings (IDs), filtrant les nulls et gérant les objets ConnectionSchema
  List<String> _ensureStringList(dynamic list) {
    if (list == null) return <String>[];
    if (list is List<String>) return list; // Already a list of strings (IDs)
    if (list is List) {
      List<String> ids = [];
      for (var item in list) {
        if (item == null) continue;
        if (item is String && ValidationUtils.isValidObjectId(item)) { // If it's already a valid ID string
          ids.add(item);
        } else if (item is Map<String, dynamic>) { // If it's an object (likely ConnectionSchema)
          // Try to extract the ID from common fields ('userId', '_id')
          final idFromUserId = item['userId']?.toString();
          final idFromId = item['_id']?.toString(); // Fallback in case the object itself is the user ID (less likely based on schema)

          String? finalId = null;
          if (idFromUserId != null && ValidationUtils.isValidObjectId(idFromUserId)) {
            finalId = idFromUserId;
          } else if (idFromId != null && ValidationUtils.isValidObjectId(idFromId)) {
            finalId = idFromId;
          }

          if (finalId != null) {
            ids.add(finalId);
          } else {
             print("⚠️ _ensureStringList: Could not extract valid ObjectId from Map item: $item");
          }
        } else {
          // Try converting other types, but check validity
          final potentialId = item.toString();
          if (ValidationUtils.isValidObjectId(potentialId)) {
            ids.add(potentialId);
          } else {
            print("⚠️ _ensureStringList: Item is neither a String ID nor a recognized Map, and toString() is not a valid ID: $item");
          }
        }
      }
      return ids;
    }
    return <String>[];
  }

  /// Retourne des données utilisateur par défaut en cas d'erreur de fetch
  Map<String, dynamic> _getDefaultUserData(String userId) {
    return {
      '_id': userId,
      'name': 'Utilisateur indisponible',
      'bio': 'Erreur lors du chargement.',
      'profilePicture': null,
      'photo_url': null,
      'followers': <String>[],
      'following': <String>[],
      'posts': <String>[],
      'interests': <String>[],
      'choices': [],
      'liked_tags': <String>[],
      'conversations': <String>[]
    };
  }

  /// Formate un timestamp pour affichage (ex: '2h', '3j')
  String _formatTimestamp(DateTime timestamp) {
      final now = DateTime.now();
      final difference = now.difference(timestamp);

      if (difference.inSeconds < 60) return 'maintenant';
      if (difference.inMinutes < 60) return '${difference.inMinutes}min';
      if (difference.inHours < 24) return '${difference.inHours}h';
      if (difference.inDays < 7) return '${difference.inDays}j';
      // Afficher date complète si plus vieux
      return '${timestamp.day}/${timestamp.month}/${timestamp.year % 100}';
    }

   /// Construit une option de menu pour les BottomSheets
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
            : (color == Colors.red ? null : const Icon(Icons.chevron_right)),
        onTap: isToggle ? null : onTap,
      );
   }


  // ---------------------------------------------------------------------------
  // Build Method
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // Nécessaire pour AutomaticKeepAliveClientMixin
    super.build(context);

    return DefaultTabController(
      length: 3, // Intérêts, Choices, Posts
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        body: FutureBuilder<Map<String, dynamic>>(
          future: _userFuture,
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting && !userSnapshot.hasData) {
              // Afficher un loader simple pendant le tout premier chargement
              return const Center(child: CircularProgressIndicator());
            }
            if (userSnapshot.hasError || !userSnapshot.hasData || userSnapshot.data == null) {
              // Afficher une erreur si le chargement initial échoue
              print("❌ Erreur FutureBuilder _userFuture: ${userSnapshot.error}");
              return Scaffold(
                  appBar: AppBar(title: const Text("Erreur Profil")),
                  body: Center(child: Text('Erreur de chargement du profil: ${userSnapshot.error ?? "Données indisponibles"}'))
              );
            }

            // Données utilisateur disponibles
            final user = userSnapshot.data!;

            return NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  // === Header ===
                  _ProfileHeader(
                    user: user,
                    isCurrentUser: widget.isCurrentUser,
                    onStartConversation: () => _startConversation(widget.userId),
                    onShowMainMenu: () => _showMainMenu(context),
                    onShowExternalProfileOptions: () => _showExternalProfileOptions(context, user),
                  ),

                  // === Stats & Tags ===
                  SliverToBoxAdapter(
                    child: _ProfileStats(
                       user: user,
                       onNavigateToDetails: _navigateToDetails,
                       onShowUserList: _showUserListModal,
                       onShowChoicesList: () => _showChoicesModal(context, user['choices'] ?? []),
                       onShowInterestsList: (ctx, ids, title) => _showInterestsListModal(ctx, ids, title),
                       onEditProfileFromMenu: () {
                         if (widget.isCurrentUser && mounted) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => EditProfileScreen(userId: widget.userId)),
                            ).then((result) {
                               if (result == true) {
                                  print("🔄 Refreshing profile data after edit...");
                                  _fetchData();
                               }
                            });
                         }
                       }
                    ),
                  ),

                  // === TabBar ===
                  SliverPersistentHeader(
                    delegate: _SliverAppBarDelegate(
                      TabBar(
                        tabs: const [
                           Tab(text: 'INTÉRÊTS', icon: Icon(Icons.star_border, size: 20)),
                           Tab(text: 'CHOICES', icon: Icon(Icons.check_circle_outline, size: 20)),
                           Tab(text: 'POSTS', icon: Icon(Icons.article_outlined, size: 20)),
                        ],
                        labelColor: Colors.teal,
                        unselectedLabelColor: Colors.grey[600],
                        indicatorColor: Colors.teal,
                        indicatorWeight: 3,
                      ),
                    ),
                    pinned: true,
                  ),
                ];
              },
              // === Contenu des Onglets ===
              body: FutureBuilder<List<dynamic>>(
                  future: _postsFuture, // Utiliser le Future des posts ici
                  builder: (context, postsSnapshot) {
                      // Gérer l'état de chargement des posts séparément
                      // (on peut afficher les onglets même si les posts chargent encore)
                     return _ProfileTabs(
                       user: user,
                       postsFuture: _postsFuture, // Passer le future
                       postsSnapshot: postsSnapshot, // Passer aussi le snapshot pour état chargement/erreur
                       onNavigateToDetails: _navigateToDetails,
                       onNavigateToPostDetail: _navigateToPostDetail,
                       onNavigateToChoiceDetail: _navigateToChoiceDetail,
                       userId: widget.userId,
                       fetchPlaceDetails: _fetchPlaceDetails,
                       likePost: _likePost, // Passer la fonction like
                       showComments: _showCommentsBottomSheet, // Passer la fonction comments
                       showChoiceDialog: _showChoiceDialog, // Passer la fonction choice
                       formatTimestamp: _formatTimestamp, // Passer la fonction de formatage
                     );
                  },
              ),
            );
          },
        ),
        // === Floating Action Button ===
        floatingActionButton: widget.isCurrentUser ? FloatingActionButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChoiceCreationScreen(userId: widget.userId),
                ),
              );
            },
            backgroundColor: Colors.teal,
            child: const Icon(Icons.add_task_outlined, size: 30), // Changed icon
            tooltip: "Créer un Choice", 
          ) : null,
      ),
    );
  }

    // --- Modals spécifiques à ce Screen State ---

    /// Affiche le menu principal pour l'utilisateur courant
    void _showMainMenu(BuildContext context) {
        if (!mounted) return;
        final authService = provider_pkg.Provider.of<AuthService>(context, listen: false);
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (modalContext) {
            return Container(
              decoration: const BoxDecoration(
                      color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                    ),
                  ),
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewPadding.bottom),
                    child: Column(
                mainAxisSize: MainAxisSize.min,
                      children: [
                  Container(width: 40, height: 4, margin: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
                  _buildMenuOption(icon: Icons.edit_outlined, text: 'Modifier le profil', onTap: () { 
                     Navigator.pop(modalContext);
                     // Find the _ProfileStats widget and call its callback
                     // This is a bit indirect, ideally state management would handle this better
                     // For now, assume the _ProfileStats is accessible via context or state
                     Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => EditProfileScreen(userId: widget.userId)),
                     ).then((result) {
                       if (result == true) {
                          print("🔄 Refreshing profile data after edit...");
                          _fetchData(); // Refresh data on return
                       }
                     });
                  }),
                  _buildMenuOption(icon: Icons.bookmark_border, text: 'Publications sauvegardees', onTap: () { Navigator.pop(modalContext); /* TODO */ }),
                  _buildMenuOption(icon: Icons.language, text: 'Langue', onTap: () { Navigator.pop(modalContext); Navigator.push(context, MaterialPageRoute(builder: (context) => LanguageSettingsScreen())); }),
                  _buildMenuOption(icon: Icons.notifications_none, text: 'Notifications par email', onTap: () { Navigator.pop(modalContext); Navigator.push(context, MaterialPageRoute(builder: (context) => EmailNotificationsScreen(userId: widget.userId))); }),
                  const Divider(height: 1),
                  _buildMenuOption(icon: Icons.block, text: 'Profils bloqués', onTap: () { Navigator.pop(modalContext); /* TODO */ }),
                  _buildMenuOption(icon: Icons.logout, text: 'Déconnexion', color: Colors.red, onTap: () async {
                     Navigator.pop(modalContext); // Fermer modal
                     await authService.logout();
                     if (mounted) {
                       Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
                     }
                   }),
                  const SizedBox(height: 10),
                ],
              ),
            );
          },
        );
      }

      /// Affiche les options pour un profil externe
      void _showExternalProfileOptions(BuildContext context, Map<String, dynamic> targetUser) {
         if (!mounted) return;
         final targetUserId = targetUser['_id']?.toString() ?? '';
         if (targetUserId.isEmpty) return;

          showModalBottomSheet(
             context: context,
             backgroundColor: Colors.transparent,
             builder: (modalContext) {
                 return Container(
                    decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
                    ),
                    padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewPadding.bottom),
                     child: Column(
                         mainAxisSize: MainAxisSize.min,
                children: [
                             Container(width: 40, height: 4, margin: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
                              _buildMenuOption(
                                 icon: Icons.block,
                                 text: 'Bloquer ${targetUser['name'] ?? 'cet utilisateur'}',
                                 color: Colors.red,
                                 onTap: () {
                                     Navigator.pop(modalContext);
                                     print("TODO: Bloquer utilisateur $targetUserId");
                                     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Blocage (à implémenter)')));
                                 },
                             ),
                              _buildMenuOption(
                                 icon: Icons.report_problem_outlined,
                                 text: 'Signaler ${targetUser['name'] ?? 'cet utilisateur'}',
                                 color: Colors.orange,
                                 onTap: () {
                                     Navigator.pop(modalContext);
                                     print("TODO: Signaler utilisateur $targetUserId");
                                     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Signalement (à implémenter)')));
                                 },
                             ),
                             const SizedBox(height: 10),
                         ],
                     ),
                 );
             },
         );
      }

  // Fonction qui vérifie si on doit demander à l'utilisateur son choice favori
  void _checkIfShouldAskForFavoriteChoice() async {
    // Ne demander que pour l'utilisateur courant
    if (!widget.isCurrentUser || !mounted) return;
    
    final userData = await _userFuture;
    if (userData == null) return;
    
    // Vérifier s'il y a des choices
    final choices = (userData['choices'] is List) 
      ? List<Map<String, dynamic>>.from(userData['choices'].whereType<Map<String, dynamic>>()) 
      : <Map<String, dynamic>>[];
    
    if (choices.isEmpty) return; // Ne rien faire s'il n'y a pas de choices
    
    // Vérifier la date du dernier coup de cœur
    final lastFavoriteChoiceTimestamp = userData['lastFavoriteChoiceTimestamp'];
    
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month);
    DateTime? lastFavoriteDate;
    
    if (lastFavoriteChoiceTimestamp != null) {
      // Convertir en DateTime selon le format
      if (lastFavoriteChoiceTimestamp is String) {
        lastFavoriteDate = DateTime.tryParse(lastFavoriteChoiceTimestamp);
      } else if (lastFavoriteChoiceTimestamp is int) {
        lastFavoriteDate = DateTime.fromMillisecondsSinceEpoch(lastFavoriteChoiceTimestamp);
      }
    }
    
    // Si pas de date ou date du mois précédent (ou avant), demander le coup de cœur
    final shouldAsk = lastFavoriteDate == null || 
                      DateTime(lastFavoriteDate.year, lastFavoriteDate.month).isBefore(currentMonth);
                      
    if (shouldAsk && mounted) {
      // Attendre un peu pour ne pas montrer immédiatement à l'ouverture
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        _showFavoriteChoiceDialog(choices);
      }
    }
  }

  // Fonction qui affiche le dialogue de sélection du coup de cœur
  void _showFavoriteChoiceDialog(List<Map<String, dynamic>> choices) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Votre coup de cœur du mois'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sélectionnez votre Choice préféré du mois pour le mettre en avant sur votre profil.',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 300,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: choices.length,
                    itemBuilder: (context, index) {
                      final choice = choices[index];
                      return ListTile(
                        leading: choice['locationImage'] != null && choice['locationImage'].isNotEmpty
                            ? CircleAvatar(backgroundImage: NetworkImage(choice['locationImage']))
                            : const CircleAvatar(child: Icon(Icons.place)),
                        title: Text(choice['locationName'] ?? 'Choice sans nom'),
                        subtitle: Text(choice['comment'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
                        onTap: () {
                          // Sélectionner ce choice comme favori
                          _setFavoriteChoice(choice);
                          Navigator.of(dialogContext).pop();
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Plus tard'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
          ],
        );
      },
    );
  }

  // Fonction qui enregistre le choice favori de l'utilisateur
  Future<void> _setFavoriteChoice(Map<String, dynamic> choice) async {
    if (!mounted) return;
    
    try {
      final authService = provider_pkg.Provider.of<AuthService>(context, listen: false);
      final token = await authService.getTokenInstance();
      if (token == null || token.isEmpty) return;
      
      final baseUrl = getBaseUrlFromUtils();
      final url = Uri.parse('$baseUrl/api/users/${widget.userId}/favorite-choice');
      
      final headers = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json'
      };
      
      final response = await http.post(
        url,
        headers: headers,
        body: json.encode({
          'choiceId': choice['_id'],
          'timestamp': DateTime.now().toIso8601String()
        }),
      );
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        // Actualiser les données du profil
        _fetchData();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Votre coup de cœur a été mis à jour!'))
          ); // <-- Added missing parenthesis here
        }
      } else {
        throw Exception('Échec de la mise à jour: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: ${e.toString()}'))
        );
      }
      print('❌ Erreur lors de la mise à jour du coup de cœur: $e');
    }
  }
}

//==============================================================================
// WIDGET: _ProfileHeader (Stateless)
//==============================================================================
class _ProfileHeader extends StatelessWidget {
  final Map<String, dynamic> user;
  final bool isCurrentUser;
  final VoidCallback onStartConversation;
  final VoidCallback onShowMainMenu;
  final VoidCallback onShowExternalProfileOptions;


  const _ProfileHeader({
     Key? key,
     required this.user,
     required this.isCurrentUser,
     required this.onStartConversation,
     required this.onShowMainMenu,
     required this.onShowExternalProfileOptions,

  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final profileImageUrl = user['profilePicture'] ?? user['photo_url'];

    return SliverAppBar(
      expandedHeight: 200.0,
      floating: false,
      pinned: true,
      backgroundColor: Colors.teal,
      elevation: 1, // Légère ombre quand pinné
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [ Colors.teal.shade700, Colors.teal.shade500 ],
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
                children: [
              // Image de fond floue
              if (profileImageUrl != null && profileImageUrl.isNotEmpty)
                 Positioned.fill(
                   child: Opacity(
                     opacity: 0.15,
                     child: CachedNetworkImage(
                         imageUrl: profileImageUrl,
                         fit: BoxFit.cover,
                         errorWidget: (ctx, url, err) => Container(color: Colors.teal.shade300),
                      ),
                   ),
                 ),
              // Contenu principal du header
              Padding(
                 // Ajuster padding pour la status bar
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 15,
                  left: 20,
                  right: 20,
                  bottom: 15
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Photo de profil
                    CircleAvatar(
                       radius: 40,
                       backgroundColor: Colors.white.withOpacity(0.8),
                       child: CircleAvatar(
                         radius: 37,
                         backgroundColor: Colors.grey[300],
                         backgroundImage: (profileImageUrl != null && profileImageUrl.isNotEmpty)
                              ? CachedNetworkImageProvider(profileImageUrl)
                              : null,
                         child: (profileImageUrl == null || profileImageUrl.isEmpty)
                              ? const Icon(Icons.person, size: 40, color: Colors.white)
                              : null,
                       ),
                     ),
                    const SizedBox(width: 16),
                    // Nom et bio
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center, // Centrer verticalement
                        children: [
                          Text(
                            user['name'] ?? 'Nom inconnu',
                            style: const TextStyle(
                              fontSize: 20, // Légèrement plus petit
                  fontWeight: FontWeight.bold,
                              color: Colors.white,
                              shadows: [ Shadow(offset: Offset(0, 1), blurRadius: 2, color: Colors.black38) ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (user['bio'] != null && user['bio'].isNotEmpty)
                             Padding(
                               padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                                user['bio'],
                      style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w300,
                      ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                    ),
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
      actions: isCurrentUser
       ? [ // Actions pour profil courant
            IconButton(icon: const Icon(Icons.menu, color: Colors.white), tooltip: "Menu", onPressed: onShowMainMenu),
         ]
       : [ // Actions pour profil externe
            IconButton(icon: const Icon(Icons.message_outlined, color: Colors.white), tooltip: "Message", onPressed: onStartConversation),
            IconButton(icon: const Icon(Icons.more_vert, color: Colors.white), tooltip: "Options", onPressed: onShowExternalProfileOptions),
         ],
    );
  }
}


//==============================================================================
// WIDGET: _ProfileStats (Stateless)
//==============================================================================
class _ProfileStats extends StatelessWidget {
   final Map<String, dynamic> user;
   final Function(String, String) onNavigateToDetails;
   final Function(BuildContext, List<String>, String) onShowUserList;
   final VoidCallback onShowChoicesList;
   final Function(BuildContext, List<String>, String) onShowInterestsList;
   final VoidCallback onEditProfileFromMenu;

   const _ProfileStats({
     Key? key,
     required this.user,
     required this.onNavigateToDetails,
     required this.onShowUserList,
     required this.onShowChoicesList,
     required this.onShowInterestsList,
     required this.onEditProfileFromMenu,
   }) : super(key: key);

    // Copié ici pour être autonome
    List<String> _ensureStringList(dynamic list) {
      if (list == null) return <String>[];
      if (list is List<String>) return list;
      if (list is List) {
        return list.where((item) => item != null).map((item) => item.toString()).toList();
      }
      return <String>[];
    }

   @override
   Widget build(BuildContext context) {
     final followersIds = _ensureStringList(user['followers']);
     final followingIds = _ensureStringList(user['following']);
     final interestsIds = _ensureStringList(user['interests']); // Calculate interests count
     final choices = (user['choices'] is List) ? user['choices'] : [];
     final likedTags = _ensureStringList(user['liked_tags']);
     
     // Stats d'activité: nombre de posts par mois, nombre de choices ce mois, etc.
     final DateTime now = DateTime.now();
     final DateTime firstDayOfMonth = DateTime(now.year, now.month, 1);
     
     // Calculer le nombre de choices créés ce mois
     int choicesThisMonth = 0;
     if (choices.isNotEmpty) {
       choicesThisMonth = choices.where((choice) {
         if (choice is Map && choice['createdAt'] != null) {
           DateTime createdAt;
           if (choice['createdAt'] is String) {
             createdAt = DateTime.tryParse(choice['createdAt']) ?? DateTime(2000);
           } else {
             createdAt = DateTime.fromMillisecondsSinceEpoch(choice['createdAt'] ?? 0);
           }
           return createdAt.isAfter(firstDayOfMonth);
         }
         return false;
       }).length;
     }
     
     // Coup de cœur du mois
     Map<String, dynamic>? favoriteChoice;
     if (user['favoriteChoice'] is Map) {
       favoriteChoice = Map<String, dynamic>.from(user['favoriteChoice']);
     }

     return Container(
       color: Colors.white,
       padding: const EdgeInsets.symmetric(vertical: 16), // Pas de padding H ici
       child: Column(
          children: [
             // Première ligne: statistiques classiques (followers, following, etc.)
             Row(
               mainAxisAlignment: MainAxisAlignment.spaceEvenly,
               children: [
                 _buildStatButton(context, icon: Icons.people_outline, label: 'Abonnés', count: followersIds.length, onTap: () => onShowUserList(context, followersIds, 'Abonnés')),
                 _verticalDivider(),
                 _buildStatButton(context, icon: Icons.person_outline, label: 'Abonnements', count: followingIds.length, onTap: () => onShowUserList(context, followingIds, 'Abonnements')),
                 _verticalDivider(),
                 _buildStatButton(context, icon: Icons.star_border, label: 'Intérêts', count: interestsIds.length, onTap: () => onShowInterestsList(context, interestsIds, 'Intérêts')),
                 _verticalDivider(),
                 _buildStatButton(context, icon: Icons.check_circle_outline, label: 'Choices', count: choices.length, onTap: onShowChoicesList),
               ],
             ),
             const Divider(height: 32, thickness: 0.5),
             
             // Troisième ligne: Badges et récompenses
             if (user['badges'] != null && user['badges'] is List && user['badges'].isNotEmpty)
             Padding(
               padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
               child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   const Row(
                     children: [
                       Icon(Icons.emoji_events_outlined, size: 16, color: Colors.amber),
                       SizedBox(width: 8),
                       Text('Badges et récompenses', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                     ],
                   ),
                   const SizedBox(height: 8),
                   SingleChildScrollView(
                     scrollDirection: Axis.horizontal,
                     child: Row(
                       children: List.generate(
                         (user['badges'] as List).length,
                         (index) => _buildBadge(user['badges'][index]),
                       ),
                     ),
                   ),
                 ],
               ),
             ),
             
             // S'il existe un coup de cœur du mois
             if (favoriteChoice != null)
             Padding(
               padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
               child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   Row(
                     children: [
                       Icon(Icons.favorite, size: 16, color: Colors.red.shade400),
                       const SizedBox(width: 8),
                       const Text('Coup de cœur du mois', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                     ],
                   ),
                   const SizedBox(height: 8),
                   InkWell(
                     onTap: () {
                       // Ajouter l'action pour ouvrir le choice favori
                     },
                     child: Container(
                       padding: const EdgeInsets.all(8),
                       decoration: BoxDecoration(
                         color: Colors.red.shade50,
                         borderRadius: BorderRadius.circular(8),
                         border: Border.all(color: Colors.red.shade200),
                       ),
                       child: Row(
                         children: [
                           ClipRRect(
                             borderRadius: BorderRadius.circular(8),
                             child: SizedBox(
                               width: 50,
                               height: 50,
                               child: Image.network(
                                 favoriteChoice['image'] ?? 'https://via.placeholder.com/50',
                                 fit: BoxFit.cover,
                                 errorBuilder: (ctx, error, stackTrace) => Container(
                                   color: Colors.grey.shade200,
                                   child: const Icon(Icons.image_not_supported, color: Colors.grey),
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
                                   favoriteChoice['name'] ?? 'Coup de cœur',
                                   style: const TextStyle(fontWeight: FontWeight.bold),
                                   maxLines: 1,
                                   overflow: TextOverflow.ellipsis,
                                 ),
                                 Text(
                                   favoriteChoice['comment'] ?? '',
                                   style: const TextStyle(fontSize: 12, color: Colors.grey),
                                   maxLines: 2,
                                   overflow: TextOverflow.ellipsis,
                                 ),
                               ],
                             ),
                           ),
                         ],
                       ),
                     ),
                   ),
                 ],
               ),
             ),
             
             // Quatrième ligne: Accès rapide aux catégories
             Padding(
               padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
               child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   const Row(
                     children: [
                       Icon(Icons.category_outlined, size: 16, color: Colors.blue),
                       SizedBox(width: 8),
                       Text('Accès rapide', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                     ],
                   ),
                   const SizedBox(height: 8),
                   SingleChildScrollView(
                     scrollDirection: Axis.horizontal,
                     child: Row(
                       children: [
                         _buildQuickAccessButton(context, 'Restaurants', Icons.restaurant, Colors.orange, () {
                           // Navigation vers recherche filtrée par restaurants
                         }),
                         _buildQuickAccessButton(context, 'Événements', Icons.event, Colors.blue, () {
                           // Navigation vers recherche filtrée par événements
                         }),
                         _buildQuickAccessButton(context, 'Loisirs', Icons.museum, Colors.purple, () {
                           // Navigation vers recherche filtrée par loisirs
                         }),
                         _buildQuickAccessButton(context, 'Wellness', Icons.spa, Colors.green, () {
                           // Navigation vers recherche filtrée par wellness
                         }),
                       ],
                     ),
                   ),
                 ],
               ),
             ),
             
             // Cinquième ligne: Boutons d'action supplémentaires (partage only now)
             Padding(
               padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
               child: Row(
                 mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                 children: [
                   // Bouton de partage (Kept, now takes full width if edit is gone)
                   Expanded(
                     child: OutlinedButton.icon(
                       onPressed: () {
                         _shareProfile(context);
                       },
                       icon: const Icon(Icons.share),
                       label: const Text('Partager profil'),
                       style: OutlinedButton.styleFrom(
                         foregroundColor: Colors.teal,
                         side: const BorderSide(color: Colors.teal),
                         padding: const EdgeInsets.symmetric(vertical: 10),
                       ),
                     ),
                   ),
                 ],
               ),
             ),
             
             const Divider(height: 16, thickness: 0.5),
          ],
       ),
     );
   }

   // Méthode pour partager le profil
   void _shareProfile(BuildContext context) {
     // Implémenter le partage du profil via les mécanismes natifs
     // Exemple: utiliser le package share_plus
     ScaffoldMessenger.of(context).showSnackBar(
       const SnackBar(content: Text('Partage du profil en cours de développement')),
     );
   }

   // Widget pour un badge
   Widget _buildBadge(dynamic badge) {
     String title = 'Badge';
     IconData icon = Icons.star;
     Color color = Colors.amber;
     
     if (badge is Map) {
       title = badge['title'] ?? 'Badge';
       
       // Choisir l'icône en fonction du type de badge
       switch (badge['type']) {
         case 'verified':
           icon = Icons.verified;
           color = Colors.blue;
           break;
         case 'premium':
           icon = Icons.workspace_premium;
           color = Colors.amber;
           break;
         case 'new':
           icon = Icons.new_releases;
           color = Colors.green;
           break;
         case 'contributor':
           icon = Icons.emoji_events;
           color = Colors.orange;
           break;
         default:
           icon = Icons.star;
           color = Colors.amber;
       }
     }
     
     return Padding(
       padding: const EdgeInsets.only(right: 12.0),
       child: Tooltip(
         message: title,
         child: Container(
           padding: const EdgeInsets.all(8),
           decoration: BoxDecoration(
             color: color.withOpacity(0.1),
             borderRadius: BorderRadius.circular(8),
             border: Border.all(color: color.withOpacity(0.3)),
           ),
           child: Icon(icon, color: color, size: 24),
         ),
       ),
     );
   }
   
   // Widget pour une carte de statistique d'activité
   Widget _buildActivityCard({required String title, required String value, required IconData icon, required Color color}) {
     return Container(
       padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
       decoration: BoxDecoration(
         color: color.withOpacity(0.05),
         borderRadius: BorderRadius.circular(8),
         border: Border.all(color: color.withOpacity(0.2)),
       ),
       child: Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
           Row(
             children: [
               Icon(icon, size: 14, color: color),
               const SizedBox(width: 4),
               Text(title, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
             ],
           ),
           const SizedBox(height: 4),
           Text(
             value,
             style: TextStyle(
               fontSize: 20,
               fontWeight: FontWeight.bold,
               color: color,
             ),
           ),
         ],
       ),
     );
   }
   
   // Widget pour un bouton d'accès rapide
   Widget _buildQuickAccessButton(BuildContext context, String label, IconData icon, Color color, VoidCallback onTap) {
     return Padding(
       padding: const EdgeInsets.only(right: 8.0),
       child: InkWell(
         onTap: onTap,
         borderRadius: BorderRadius.circular(8),
         child: Container(
           padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
           decoration: BoxDecoration(
             color: color.withOpacity(0.1),
             borderRadius: BorderRadius.circular(8),
             border: Border.all(color: color.withOpacity(0.3)),
           ),
           child: Row(
             children: [
               Icon(icon, size: 16, color: color),
               const SizedBox(width: 6),
               Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w500)),
             ],
           ),
         ),
       ),
     );
   }
   
   // ... Widgets existants ...
   Widget _buildStatButton(BuildContext context, {required IconData icon, required String label, required int count, required VoidCallback onTap}) {
     return InkWell(
       onTap: onTap,
       child: Padding(
         padding: const EdgeInsets.all(8.0),
         child: Column(
           children: [
             Icon(icon, color: Colors.grey[700]),
             const SizedBox(height: 4),
             Text(
               count.toString(), // Nombre
               style: const TextStyle(
                 fontSize: 18,
                 fontWeight: FontWeight.bold,
               ),
             ),
             const SizedBox(height: 2),
             Text(
               label, // Libellé
               style: TextStyle(
                 fontSize: 12,
                 color: Colors.grey[600],
               ),
             ),
           ],
         ),
       ),
     );
   }

   Widget _verticalDivider() {
     return Container(
       height: 30,
       width: 1,
       color: Colors.grey[300],
     );
   }
}

//==============================================================================
// WIDGET: _ProfileTabs (Stateless)
//==============================================================================
class _ProfileTabs extends StatelessWidget {
   final Map<String, dynamic> user;
   final Future<List<dynamic>> postsFuture;
   final AsyncSnapshot<List<dynamic>> postsSnapshot; // Snapshot des posts
   final Function(String, String) onNavigateToDetails;
   final Function(Map<String, dynamic>) onNavigateToPostDetail;
   final String userId;
   final Future<Map<String, dynamic>> Function(List<String>) fetchPlaceDetails;
   final Future<void> Function(String) likePost;
   final Function(BuildContext, String) showComments;
   final Function(BuildContext, Map<String, dynamic>) showChoiceDialog;
   final String Function(DateTime) formatTimestamp;
   final Function(Map<String, dynamic>, Map<String, dynamic>?) onNavigateToChoiceDetail; // Nouveau callback

   const _ProfileTabs({
     Key? key,
     required this.user,
     required this.postsFuture,
     required this.postsSnapshot,
     required this.onNavigateToDetails, // Toujours nécessaire pour l'onglet Intérêts
     required this.onNavigateToPostDetail,
     required this.onNavigateToChoiceDetail, // Ajouter le nouveau callback
     required this.userId,
     required this.fetchPlaceDetails,
     required this.likePost,
     required this.showComments,
     required this.showChoiceDialog,
     required this.formatTimestamp,
   }) : super(key: key);

   // --- Utilitaires locaux --- (copiés pour autonomie)
    List<String> _ensureStringList(dynamic list) {
      if (list == null) return <String>[];
      if (list is List<String>) return list;
      if (list is List) {
        return list.where((item) => item != null).map((item) => item.toString()).toList();
      }
      return <String>[];
    }

    Widget _buildPlaceholderImage(Color bgColor, IconData icon, String text) {
       return Container(
         color: bgColor,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
             Icon(icon, size: 40, color: Colors.grey),
            const SizedBox(height: 8),
             Padding(
               padding: const EdgeInsets.symmetric(horizontal: 8.0),
               child: Text(text, style: TextStyle(color: Colors.grey[600], fontSize: 12), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      );
    }

   @override
   Widget build(BuildContext context) {
     return TabBarView(
       children: [
         _buildInterestsSection(context),
         _buildChoicesSection(context),
         _buildPostsSection(context),
       ],
     );
   }

   // --- Widgets pour chaque onglet ---

    Widget _buildInterestsSection(BuildContext context) {
     final interestsIds = _ensureStringList(user['interests']);

     if (interestsIds.isEmpty) {
       return _buildEmptyState(icon: Icons.star_border, title: 'Aucun intérêt', subtitle: 'Ajoutez des lieux favoris');
    }

    return FutureBuilder<Map<String, dynamic>>(
       future: fetchPlaceDetails(interestsIds),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
         } else if (snapshot.hasError || !snapshot.hasData) {
            return Center(child: Text("Erreur chargement favoris: ${snapshot.error ?? 'Données nulles'}"));
        }
        
         final placeDetailsMap = snapshot.data ?? {};

        // --- CHANGE: Use GridView instead of ListView ---
        return GridView.builder(
          padding: const EdgeInsets.all(12.0), // Add padding around grid
          itemCount: interestsIds.length,
           gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
             crossAxisCount: 2, // Number of columns
             crossAxisSpacing: 12.0, // Spacing between columns
             mainAxisSpacing: 12.0, // Spacing between rows
             childAspectRatio: 0.8, // Adjust aspect ratio (width/height)
          ),
          itemBuilder: (context, index) {
            final interestId = interestsIds[index];
            final placeDetail = placeDetailsMap[interestId] ?? {'error': true, 'name': 'Données indisponibles'};
            bool hasError = placeDetail['error'] == true;

            final String placeName = placeDetail['name'] ?? 'Lieu favori';
            final String? imageUrl = (placeDetail['photos'] is List && placeDetail['photos'].isNotEmpty)
                                ? placeDetail['photos'][0]
                                : placeDetail['image'] ?? placeDetail['photo_url'];
            final String address = placeDetail['address'] ?? placeDetail['adresse'] ?? placeDetail['lieu'] ?? '';
            final String type = (placeDetail['_fetched_as'] ?? placeDetail['type'] ?? 'unknown').toString().toLowerCase();

            IconData icon = Icons.place;
            Color iconColor = Colors.teal;
            if (hasError) {
              icon = Icons.error_outline;
              iconColor = Colors.red;
            } else {
               switch (type) {
                 case 'restaurant': icon = Icons.restaurant; iconColor = Colors.orange; break;
                 case 'event': icon = Icons.event; iconColor = Colors.blue; break;
                 case 'leisureproducer': icon = Icons.museum; iconColor = Colors.purple; break;
                 case 'wellness': case 'beautyplace': icon = Icons.spa; iconColor = Colors.green; break;
               }
            }

            // Build the grid item card
            return Card(
               clipBehavior: Clip.antiAlias, // Clip image to card shape
               elevation: 2.0,
               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
               child: InkWell(
                 onTap: hasError ? null : () => onNavigateToDetails(interestId, type),
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.stretch, // Make children fill width
                   children: [
                     Expanded(
                       child: (imageUrl != null && imageUrl.isNotEmpty && !hasError)
                          ? CachedNetworkImage(
                              imageUrl: imageUrl,
                              fit: BoxFit.cover,
                              errorWidget: (ctx, url, err) => _buildPlaceholderImage(Colors.grey[200]!, icon, 'Erreur image'),
                              placeholder: (ctx, url) => Container(color: Colors.grey[100]),
                            )
                          : Container(
                              color: iconColor.withOpacity(0.1),
                              child: Icon(icon, size: 40, color: iconColor.withOpacity(0.8)),
                            ),
                     ),
                     Padding(
                       padding: const EdgeInsets.all(8.0),
                       child: Text(
                         placeName,
                         style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                         maxLines: 2, 
                         overflow: TextOverflow.ellipsis,
                         textAlign: TextAlign.center,
                       ),
                     ),
                   ],
                 ),
               ),
             );
          },
        );
        // --- END CHANGE ---
      },
    );
  }

   Widget _buildChoicesSection(BuildContext context) {
       // Récupérer les choices depuis l'objet user (qui devrait être peuplé)
       final choices = (user['choices'] is List) ? List<Map<String, dynamic>>.from(user['choices'].whereType<Map<String, dynamic>>()) : <Map<String, dynamic>>[];

       if (choices.isEmpty) {
          return _buildEmptyState(icon: Icons.check_circle_outline, title: 'Aucun Choice', subtitle: 'Vos recommandations apparaîtront ici');
       }

       // Extraire les IDs des lieux associés aux choices pour les pré-charger
       List<String> targetIds = choices
           .map((choice) => choice['locationId']?['_id']?.toString() ?? // ID depuis locationId peuplé
                           choice['targetId']?.toString())              // Fallback si locationId n'est pas peuplé
           .whereType<String>()
           .where((id) => ValidationUtils.isValidObjectId(id))
           .toSet() // Utiliser un Set pour éviter les doublons
           .toList();
    
    return FutureBuilder<Map<String, dynamic>>(
          future: fetchPlaceDetails(targetIds), // Pré-charger les détails des lieux
      builder: (context, snapshot) {
             // Afficher un loader pendant le chargement des détails des lieux
             if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
             } 
             // Afficher une erreur si le chargement des détails échoue (mais on affiche quand même les choices)
             if (snapshot.hasError) {
                print("⚠️ Erreur fetchPlaceDetails dans _buildChoicesSection: ${snapshot.error}");
        }
        
             final placeDetailsMap = snapshot.data ?? {};
        
        // --- CHANGE: Use GridView instead of ListView ---
        return GridView.builder(
          padding: const EdgeInsets.all(12.0),
          itemCount: choices.length,
           gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
             crossAxisCount: 2, // Number of columns
             crossAxisSpacing: 12.0, // Spacing between columns
             mainAxisSpacing: 12.0, // Spacing between rows
             childAspectRatio: 0.8, // Adjust aspect ratio (width/height)
          ),
          itemBuilder: (context, index) {
            final choice = choices[index];
            final String? targetId = choice['locationId']?['_id']?.toString() ?? choice['targetId']?.toString();

            if (targetId == null || !ValidationUtils.isValidObjectId(targetId)) {
              return const Card(child: Center(child: Text('Donnée invalide')));
            }
            if (choice['_id'] == null) {
               return const Card(child: Center(child: Text('Donnée invalide')));
            }

            final placeDetail = placeDetailsMap[targetId] ?? choice['locationId'] ?? {'error': true, 'name': 'Détails lieu indisponibles'};
            bool hasError = placeDetail['error'] == true;

            final String placeName = placeDetail['name'] ?? 'Lieu inconnu';
            final String? imageUrl = (placeDetail['photos'] is List && placeDetail['photos'].isNotEmpty)
                                      ? placeDetail['photos'][0]
                                      : placeDetail['image'] ?? placeDetail['photo_url'];
            final String address = placeDetail['address'] ?? placeDetail['adresse'] ?? '';
            final String placeType = (placeDetail['_fetched_as'] ?? placeDetail['type'] ?? choice['targetType'] ?? 'unknown').toString().toLowerCase();
            final String review = choice['review'] ?? choice['comment'] ?? ''; // récupérer le texte du choice

            IconData icon = Icons.place; 
            Color iconColor = Colors.teal;
            if (hasError) {
               icon = Icons.error_outline; 
               iconColor = Colors.red;
            } else {
               switch (placeType) {
                  case 'restaurant': case 'producer': 
                    icon = Icons.restaurant; 
                    iconColor = Colors.orange; 
                    break;
                  case 'event': 
                    icon = Icons.event; 
                    iconColor = Colors.blue; 
                    break;
                  case 'leisureproducer': case 'leisure': 
                    icon = Icons.museum; 
                    iconColor = Colors.purple; 
                    break;
                  case 'wellness': case 'beautyplace': 
                    icon = Icons.spa; 
                    iconColor = Colors.green; 
                    break;
               }
            }

            return Card(
              clipBehavior: Clip.antiAlias,
              elevation: 2.0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
              child: InkWell(
                onTap: () {
                  if (hasError) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Détails du lieu associés indisponibles."))
                    );
                  } else {
                    onNavigateToChoiceDetail(choice, placeDetail);
                  }
                },
                child: Column(
                   crossAxisAlignment: CrossAxisAlignment.stretch,
                   children: [
                     Expanded(
                       child: (imageUrl != null && imageUrl.isNotEmpty && !hasError)
                          ? CachedNetworkImage(
                              imageUrl: imageUrl,
                              fit: BoxFit.cover,
                              errorWidget: (ctx, url, err) => _buildPlaceholderImage(Colors.grey[200]!, icon, 'Erreur image'),
                              placeholder: (ctx, url) => Container(color: Colors.grey[100]),
                            )
                          : Container(
                              color: iconColor.withOpacity(0.1),
                              child: Icon(icon, size: 40, color: iconColor.withOpacity(0.8)),
                            ),
                     ),
                     Padding(
                       padding: const EdgeInsets.all(8.0),
                       child: Column(
                         mainAxisSize: MainAxisSize.min, // Take minimum space
                         children: [
                            Text(
                              placeName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                            if (review.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text(
                                    '"${review}"' , // Add quotes
                                    style: TextStyle(fontSize: 11, color: Colors.grey[600], fontStyle: FontStyle.italic),
                                    maxLines: 2, 
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
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
        // --- END CHANGE ---
       },
   );
}

   Widget _buildPostsSection(BuildContext context) {
       // Utiliser le snapshot des posts passé en paramètre
       if (postsSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
       } else if (postsSnapshot.hasError) {
          return Center(child: Text('Erreur chargement posts: ${postsSnapshot.error}'));
       }

       final posts = postsSnapshot.data ?? [];
       if (posts.isEmpty) {
          return _buildEmptyState(
             icon: Icons.article_outlined,
             title: 'Aucune publication',
             subtitle: 'Les posts et choices partagés apparaîtront ici',
          );
       }

       return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: posts.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
             final post = posts[index];
             if (post is Map<String, dynamic>) {
                return _buildPostCard(context, post); // Passer context
             } else {
                return Card(child: ListTile(title: Text('Donnée post invalide #$index')));
             }
          },
       );
   }

   // --- Widgets internes pour les cartes et états vides --- //

   Widget _buildCardOverlay(String title, String subtitle, IconData badgeIcon, Color badgeColor, String badgeLabel) {
      return Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                  colors: [ Colors.transparent, Colors.black.withOpacity(0.7) ],
                  stops: [0.0, 0.8], // Contrôler le dégradé
               ),
            ),
            padding: const EdgeInsets.all(10),
            child: Row(
               crossAxisAlignment: CrossAxisAlignment.end, // Aligner en bas
               children: [
                  Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
                       mainAxisSize: MainAxisSize.min, // Prendre hauteur minimale
              children: [
                Text(
                           title,
                           style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14, shadows: [Shadow(blurRadius: 1)]),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                ),
                         if (subtitle.isNotEmpty) ...[
                            const SizedBox(height: 4),
                Row(
                  children: [
                               Icon(Icons.location_on_outlined, size: 12, color: Colors.white70),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                   subtitle,
                                   style: const TextStyle(color: Colors.white70, fontSize: 10, shadows: [Shadow(blurRadius: 1)]),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                         ]
                          ],
                        ),
                      ),
                  const SizedBox(width: 8),
                  // Badge (Favori ou Choice)
                   Chip(
                      avatar: Icon(badgeIcon, color: Colors.white, size: 14),
                      label: Text(badgeLabel),
                      labelStyle: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      backgroundColor: badgeColor.withOpacity(0.9),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      side: BorderSide.none,
                   ),
               ],
            ),
         ),
      );
   }

    Widget _buildPostCard(BuildContext context, Map<String, dynamic> post) {
      // Assurer que les données du post sont normalisées (fait dans _fetchUserPosts)
      final String title = post['title'] ?? '';
      final String content = post['content'] ?? '';
      final List<dynamic> media = post['media'] ?? [];
      final String? imageUrl = (media.isNotEmpty && media[0] is String) ? media[0] : post['image'];
      final author = post['author'] ?? {};
      final authorName = author['name'] ?? 'Auteur inconnu';
      final authorPhoto = author['photo'] ?? author['profilePicture'];
      final DateTime createdAt = DateTime.tryParse(post['createdAt'] ?? '') ?? DateTime.now();
      final List<String> likes = (post['likes'] is List) ? List<String>.from(post['likes']) : [];
      final List<dynamic> comments = (post['comments'] is List) ? post['comments'] : [];
      final String postId = post['_id']?.toString() ?? '';
      final location = post['location']; // Peut être null ou un Map
      final String locationName = (location is Map) ? location['name'] ?? '' : '';
      final String locationId = (location is Map) ? location['_id']?.toString() ?? '' : '';
      final String locationType = (location is Map) ? location['type']?.toString() ?? 'unknown' : 'unknown';

      // Déterminer si l'utilisateur courant a liké ce post (nécessite l'ID de l'utilisateur connecté)
      // TODO: Passer l'ID de l'utilisateur connecté à _ProfileTabs
      // bool isLikedByCurrentUser = likes.contains(currentUserConnectedId);

     return Card(
       margin: EdgeInsets.zero,
       elevation: 1.5,
       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
       clipBehavior: Clip.antiAlias,
       child: Column(
         crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
           // Header
           ListTile(
             leading: CircleAvatar(
                radius: 20,
                backgroundColor: Colors.grey[200],
                backgroundImage: (authorPhoto != null && authorPhoto.isNotEmpty) ? CachedNetworkImageProvider(authorPhoto) : null,
                child: (authorPhoto == null || authorPhoto.isEmpty) ? const Icon(Icons.person, size: 20, color: Colors.grey) : null,
             ),
             title: Text(authorName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
             subtitle: Text(formatTimestamp(createdAt), style: TextStyle(fontSize: 12, color: Colors.grey[600])),
             trailing: IconButton(icon: const Icon(Icons.more_vert, size: 20), onPressed: () {/* TODO: Options post */}),
             dense: true,
             contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
           ),
           // Image
           if (imageUrl != null && imageUrl.isNotEmpty)
             CachedNetworkImage(
               imageUrl: imageUrl,
               fit: BoxFit.cover,
               height: 250,
               width: double.infinity,
               placeholder: (ctx, url) => Container(height: 250, color: Colors.grey[200], child: const Center(child: CircularProgressIndicator(strokeWidth: 2))),
               errorWidget: (ctx, url, err) => Container(height: 250, color: Colors.grey[100], child: const Icon(Icons.image_not_supported_outlined, color: Colors.grey, size: 40)),
             ),
           // Contenu texte
           Padding(
             padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 if (title.isNotEmpty) Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                 if (title.isNotEmpty && content.isNotEmpty) const SizedBox(height: 6),
                 if (content.isNotEmpty) Text(content, style: TextStyle(fontSize: 14, color: Colors.grey[850], height: 1.4)),
                 if (locationName.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    InkWell(
                       onTap: () {
                          if (locationId.isNotEmpty && ValidationUtils.isValidObjectId(locationId)) {
                             onNavigateToDetails(locationId, locationType);
                          }
                       },
                       child: Row(
                         mainAxisSize: MainAxisSize.min,
                         children: [
                           Icon(Icons.location_on_outlined, size: 14, color: Colors.teal),
                           const SizedBox(width: 4),
                           Flexible(child: Text(locationName, style: const TextStyle(fontSize: 13, color: Colors.teal, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis)),
                         ],
                       ),
                    )
                 ]
              ],
            ),
          ),
           // Actions
           const Divider(height: 1),
           Padding(
             padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
             child: Row(
               mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
                  _buildPostActionButton(context, icon: Icons.thumb_up_outlined, /* TODO: use filled icon if liked */ count: likes.length, onPressed: () => likePost(postId)),
                  _buildPostActionButton(context, icon: Icons.chat_bubble_outline, count: comments.length, onPressed: () => showComments(context, postId)),
                  if (locationId.isNotEmpty && ValidationUtils.isValidObjectId(locationId))
                     _buildPostActionButton(context, icon: Icons.check_circle_outline, label: "Choice", onPressed: () => showChoiceDialog(context, post))
                  else
                     const Spacer(), // Pour équilibrer si pas de bouton Choice
                  // Optionnel: Bouton Partager
                  // _buildPostActionButton(context, icon: Icons.share_outlined, onPressed: () {/* Share logic */}),
               ],
             ),
          ),
        ],
      ),
    );
  }
  
   // Helper pour les boutons d'action de post
   Widget _buildPostActionButton(BuildContext context, {required IconData icon, int? count, String? label, required VoidCallback onPressed}) {
      return TextButton.icon(
         icon: Icon(icon, size: 18, color: Colors.grey[700]),
         label: Text(
            (label != null) ? label : (count != null && count > 0 ? count.toString() : ''),
            style: TextStyle(fontSize: 12, color: Colors.grey[700])
         ),
         style: TextButton.styleFrom(
            foregroundColor: Colors.grey[700],
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            minimumSize: const Size(40, 36), // Taille minimale
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
         ),
         onPressed: onPressed,
      );
   }

   // Widget pour état vide des onglets
   Widget _buildEmptyState({required IconData icon, required String title, required String subtitle, Widget? action}) {
     return Center(
       child: Padding(
         padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 50),
         child: Column(
           mainAxisAlignment: MainAxisAlignment.center,
           children: [
             Icon(icon, size: 50, color: Colors.grey[350]),
             const SizedBox(height: 20),
             Text(title, style: TextStyle(fontSize: 17, color: Colors.grey[600], fontWeight: FontWeight.w500), textAlign: TextAlign.center),
             const SizedBox(height: 10),
             Text(subtitle, style: TextStyle(fontSize: 14, color: Colors.grey[450]), textAlign: TextAlign.center),
             if (action != null) ...[ const SizedBox(height: 25), action ]
           ],
        ),
      ),
    );
  }
}


//==============================================================================
// WIDGET: _CommentsBottomSheet (Stateful)
//==============================================================================
class _CommentsBottomSheet extends StatefulWidget {
  final String postId;
  final List<Map<String, dynamic>> initialComments;
  final String currentUserId; // ID de l'utilisateur qui regarde
  final Function(Map<String, dynamic>) onCommentAdded;
  final Function(String) navigateToProfile;

  const _CommentsBottomSheet({
    Key? key,
    required this.postId,
    required this.initialComments,
    required this.currentUserId,
    required this.onCommentAdded,
    required this.navigateToProfile,
  }) : super(key: key);

  @override
  State<_CommentsBottomSheet> createState() => _CommentsBottomSheetState();
}

class _CommentsBottomSheetState extends State<_CommentsBottomSheet> {
  late List<Map<String, dynamic>> _comments;
  final TextEditingController _commentController = TextEditingController();
  bool _isPosting = false;
  String? _postingError;

  @override
  void initState() {
    super.initState();
    _comments = List.from(widget.initialComments); // Copie modifiable
    _sortComments(); // Trier initialement
  }

  void _sortComments() {
    _comments.sort((a, b) {
      final dateA = DateTime.tryParse(a['timestamp'] ?? a['createdAt'] ?? '');
      final dateB = DateTime.tryParse(b['timestamp'] ?? b['createdAt'] ?? '');
      if (dateA == null && dateB == null) return 0;
      if (dateA == null) return 1; // Dates nulles à la fin
      if (dateB == null) return -1;
      return dateB.compareTo(dateA); // Plus récent en premier
    });
  }

  Future<void> _addComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty || _isPosting) return;
    if (!mounted) return;

        setState(() {
      _isPosting = true;
      _postingError = null;
    });

     final authService = provider_pkg.Provider.of<AuthService>(context, listen: false);
     final token = await authService.getTokenInstance();
     final userId = authService.userId; // Utilisateur connecté qui commente

     if (token == null || userId == null) {
        if (!mounted) return;
        setState(() { _isPosting = false; _postingError = "Non connecté."; });
        return;
     }

    try {
      final url = Uri.parse('${constants.getBaseUrl()}/api/posts/${widget.postId}/comments');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: json.encode({'user_id': userId, 'content': content}),
      ).timeout(const Duration(seconds: 10));

       if (!mounted) return;

      if (response.statusCode == 201) {
         final newCommentData = json.decode(response.body);
         // Normaliser le commentaire reçu
          final Map<String, dynamic> normalizedComment = {
             ...newCommentData,
             '_id': newCommentData['_id']?.toString() ?? UniqueKey().toString(),
             'user_id': (newCommentData['user_id'] is Map) ? newCommentData['user_id'] : {'_id': newCommentData['user_id']?.toString() ?? userId, 'name': 'Vous'}, // Créer un objet user si juste ID
             'content': newCommentData['content'] ?? '',
             'timestamp': newCommentData['timestamp'] ?? DateTime.now().toIso8601String(),
          };

         // Essayer de récupérer les infos complètes de l'utilisateur si nécessaire
         if (normalizedComment['user_id']['name'] == 'Vous') {
             try {
                final userInfo = await _MyProfileScreenState()._fetchMinimalUserInfo(userId);
                 normalizedComment['user_id'] = {
                     '_id': userId,
                     'name': userInfo['name'] ?? 'Vous',
                     'profilePicture': userInfo['profilePicture'],
                 };
             } catch (e) { print("Erreur fetch user info pour nouveau commentaire: $e"); }
         }

      setState(() {
           _comments.insert(0, normalizedComment);
           _sortComments();
           _commentController.clear();
           _isPosting = false;
           _postingError = null;
        });
        widget.onCommentAdded(normalizedComment); // Informer le parent
      } else {
         String errorMessage = 'Erreur serveur';
         try { errorMessage = json.decode(response.body)['message'] ?? errorMessage; } catch (_) {}
         setState(() { _postingError = errorMessage; _isPosting = false; });
         print('❌ Erreur ajout commentaire (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
       if (mounted) {
         setState(() { _postingError = 'Erreur réseau/Timeout.'; _isPosting = false; });
       }
      print('❌ Exception ajout commentaire: $e');
    }
  }

   String _formatTimestamp(DateTime timestamp) {
      final now = DateTime.now();
      final difference = now.difference(timestamp);
      if (difference.inSeconds < 60) return 'maintenant';
      if (difference.inMinutes < 60) return '${difference.inMinutes}min';
      if (difference.inHours < 24) return '${difference.inHours}h';
      if (difference.inDays < 7) return '${difference.inDays}j';
      return '${timestamp.day}/${timestamp.month}/${timestamp.year % 100}';
  }
  
  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6, // Hauteur initiale
      minChildSize: 0.4,
      maxChildSize: 0.9, // Max 90% de l'écran
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
             color: Colors.white,
             borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
             boxShadow: [BoxShadow(blurRadius: 10, color: Colors.black12)] // Légère ombre
          ),
          // Clip pour que le contenu respecte les coins arrondis
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              // Header de la modal
              Container(
                 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                 child: Row(
                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                   children: [
                     Text('Commentaires (${_comments.length})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                     IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                   ],
                 ),
              ),
              const Divider(height: 1),
              // Liste des commentaires
              Expanded(
                child: _comments.isEmpty
                    ? const Center(child: Text('Soyez le premier à commenter !', style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _comments.length,
                        itemBuilder: (context, index) {
                          final comment = _comments[index];
                           final user = comment['user_id'] ?? {};
                           final content = comment['content']?.toString() ?? '';
                           final timestampStr = comment['timestamp'] ?? comment['createdAt'];
                           final timestamp = DateTime.tryParse(timestampStr ?? '');
                           final userName = user is Map ? (user['name'] ?? 'Utilisateur') : 'Utilisateur';
                           final userPhoto = user is Map ? (user['profilePicture'] ?? user['photo_url']) : null;
                           final userId = user is Map ? user['_id']?.toString() : null;

                           return Padding(
                             padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                             child: Row(
                               crossAxisAlignment: CrossAxisAlignment.start,
                               children: [
                                 GestureDetector(
                                    onTap: () { if (userId != null) widget.navigateToProfile(userId); },
                                    child: CircleAvatar(
                                       radius: 18,
                                       backgroundColor: Colors.grey[200],
                                       backgroundImage: (userPhoto != null && userPhoto.isNotEmpty) ? CachedNetworkImageProvider(userPhoto) : null,
                                       child: (userPhoto == null || userPhoto.isEmpty) ? const Icon(Icons.person, size: 18, color: Colors.grey) : null,
                                    ),
                                 ),
                                 const SizedBox(width: 12),
                                 Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
                                           Expanded(child: Text(userName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                                           if (timestamp != null) Text(_formatTimestamp(timestamp), style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                                         ],
                                       ),
                                       const SizedBox(height: 4),
                                       Text(content, style: const TextStyle(fontSize: 14, height: 1.3)),
                                     ],
                                   ),
                                 ),
                               ],
                             ),
                           );
                        },
                      ),
              ),
               // Input field
               Container(
                 padding: EdgeInsets.only(
                    left: 16, right: 8, top: 8,
                    // Ajustement pour le clavier
                    bottom: MediaQuery.of(context).viewInsets.bottom + 8,
                 ),
                 decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: Colors.grey[200]!))
                 ),
                 child: Column(
                   mainAxisSize: MainAxisSize.min,
          children: [
                      if (_postingError != null)
                         Padding(
                           padding: const EdgeInsets.only(bottom: 4.0),
                           child: Text(_postingError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                         ),
        Row(
          children: [
            Expanded(
                  child: TextField(
                    controller: _commentController,
                             textCapitalization: TextCapitalization.sentences,
                             minLines: 1,
                             maxLines: 3,
                             decoration: InputDecoration(
                               hintText: 'Votre commentaire...',
                               border: InputBorder.none, // Pas de bordure
                               filled: false,
                               contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                               isDense: true,
                             ),
                             style: const TextStyle(fontSize: 14),
                             onSubmitted: (_) => _addComment(), // Envoyer avec Entrée
                  ),
                ),
                IconButton(
                           icon: _isPosting
                               ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                               : const Icon(Icons.send_outlined),
                           iconSize: 24,
                           color: Colors.teal,
                           disabledColor: Colors.grey,
                           onPressed: _isPosting ? null : _addComment,
                           tooltip: "Envoyer",
                           padding: const EdgeInsets.all(10),
                ),
          ],
        ),
      ],
        ),
               ),
            ],
          ),
        );
      },
    );
  }
}


//==============================================================================
// WIDGET: _ChoiceForm (Stateful)
//==============================================================================
class _ChoiceForm extends StatefulWidget {
  final String locationId;
  final String locationType;
  final String locationName;
  final String currentUserId; // Utilisateur qui crée le choice
  final ScrollController scrollController;
  final VoidCallback onSubmitSuccess;

  const _ChoiceForm({
    Key? key,
    required this.locationId,
    required this.locationType,
    required this.locationName,
    required this.currentUserId,
    required this.scrollController,
    required this.onSubmitSuccess,
  }) : super(key: key);

  @override
  State<_ChoiceForm> createState() => _ChoiceFormState();
}

class _ChoiceFormState extends State<_ChoiceForm> {
  Map<String, double> _aspectRatings = {};
  final TextEditingController _appreciationController = TextEditingController();
  bool _isLoading = false;
  String? _submitError;

  // Aspects par défaut et spécifiques
  final Map<String, List<String>> _aspectsByType = {
    'restaurant': ['Nourriture', 'Service', 'Ambiance', 'Prix'],
    'event': ['Qualité', 'Intérêt', 'Originalité', 'Organisation'],
    'leisureProducer': ['Qualité', 'Accueil', 'Offre', 'Accessibilité'],
    'wellness': ['Prestation', 'Accueil', 'Environnement', 'Prix'],
    'unknown': ['Qualité', 'Intérêt', 'Originalité'],
  };
  
  @override
  void initState() {
    super.initState();
    _initializeAspects();
  }

  @override
  void dispose() {
    _appreciationController.dispose();
    super.dispose();
  }

  void _initializeAspects() {
    final aspects = _aspectsByType[widget.locationType.toLowerCase()] ?? _aspectsByType['unknown']!;
    // Utiliser une clé normalisée (lowercase, underscore)
    _aspectRatings = {for (var aspect in aspects) aspect.toLowerCase().replaceAll(' ', '_'): 5.0};
  }

  Future<void> _submit() async {
    if (_isLoading) return;
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _submitError = null;
    });

    final authService = provider_pkg.Provider.of<AuthService>(context, listen: false);
    final token = await authService.getTokenInstance();

    if (token == null) {
        if (!mounted) return;
        setState(() { _isLoading = false; _submitError = "Non connecté."; });
      return;
    }
    
    try {
      final url = Uri.parse('${constants.getBaseUrl()}/api/choices');
      final Map<String, int> aspectRatingsInt = _aspectRatings.map((key, value) => MapEntry(key, value.round()));

      final payload = {
        'userId': widget.currentUserId,
        'targetId': widget.locationId,
        'targetType': widget.locationType,
        'aspects': aspectRatingsInt,
        'review': _appreciationController.text.trim(),
        // 'overallRating': ... // Le backend devrait calculer ça
      };

      print("📤 Envoi du Choice payload: ${json.encode(payload)}");

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: json.encode(payload),
      ).timeout(const Duration(seconds: 15));

       if (!mounted) return;

      if (response.statusCode == 201) {
         final responseData = json.decode(response.body);
         print("✅ Choice créé avec succès: ${responseData['_id']}");
         Navigator.pop(context); // Fermer le bottom sheet
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Votre Choice a été ajouté !'), backgroundColor: Colors.green),
        );
         widget.onSubmitSuccess(); // Rafraîchir la page profil
      } else {
         print("❌ Erreur soumission Choice (${response.statusCode}): ${response.body}");
         String errorMessage = 'Erreur serveur.';
         try { errorMessage = json.decode(response.body)['message'] ?? errorMessage; } catch (_) {}
         setState(() { _isLoading = false; _submitError = errorMessage; });
      }
    } catch (e) {
       print("❌ Exception soumission Choice: $e");
      if (mounted) {
          setState(() { _isLoading = false; _submitError = 'Erreur réseau/Timeout.'; });
       }
    }
  }

  @override
  Widget build(BuildContext context) {
    IconData headerIcon = Icons.place; Color headerColor = Colors.grey;
    switch (widget.locationType.toLowerCase()) {
      case 'restaurant': headerIcon = Icons.restaurant; headerColor = Colors.orange; break;
      case 'event': headerIcon = Icons.event; headerColor = Colors.blue; break;
      case 'leisureproducer': headerIcon = Icons.museum; headerColor = Colors.purple; break;
      case 'wellness': headerIcon = Icons.spa; headerColor = Colors.green; break;
    }

    return SingleChildScrollView(
      controller: widget.scrollController,
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
                  child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
          // Header
        Row(
          children: [
              CircleAvatar(backgroundColor: headerColor.withOpacity(0.2), foregroundColor: headerColor, child: Icon(headerIcon)),
                          const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                 const Text('Ajouter un Choice', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                 Text(widget.locationName, style: TextStyle(fontSize: 16, color: Colors.grey[700]), maxLines: 1, overflow: TextOverflow.ellipsis),
              ])),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const Divider(height: 30),

           if (_submitError != null)
             Padding(
               padding: const EdgeInsets.only(bottom: 15.0),
               child: Text(_submitError!, style: const TextStyle(color: Colors.red, fontSize: 14)),
             ),

          // Sliders
          ..._aspectRatings.entries.map((entry) {
             final aspectKey = entry.key;
             final ratingValue = entry.value;
             final displayAspect = aspectKey.replaceAll('_', ' ').split(' ').map((w) => w.isNotEmpty ? w[0].toUpperCase() + w.substring(1) : '').join(' ');

             return Padding(
               padding: const EdgeInsets.only(bottom: 16.0),
               child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(displayAspect, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Row(children: [
                     Expanded(child: Slider(
                        value: ratingValue, min: 0.0, max: 10.0, divisions: 10,
                        activeColor: Colors.teal, inactiveColor: Colors.teal.shade100,
                        label: ratingValue.round().toString(),
                        onChanged: (value) => setState(() => _aspectRatings[aspectKey] = value),
                     )),
                     Container(width: 40, alignment: Alignment.center, child: Text(ratingValue.round().toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                  ]),
               ]),
             );
          }).toList(),

          const SizedBox(height: 16),

          // Review Text Field
          const Text('Appréciation globale', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
        TextField(
            controller: _appreciationController,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
              hintText: 'Partagez votre expérience...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.teal, width: 1.5)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
          const SizedBox(height: 30),

          // Submit Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
              onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                disabledBackgroundColor: Colors.teal.withOpacity(0.5),
                    ),
                    child: _isLoading
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                  : const Text('SOUMETTRE MON CHOICE', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
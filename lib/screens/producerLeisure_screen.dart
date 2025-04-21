import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'utils.dart'; // Uses conditional exports to select the right implementation
import 'package:intl/intl.dart';
import 'map_leisure_screen.dart';
import 'dart:math' as math;
import 'eventLeisure_screen.dart'; // Import nécessaire pour afficher les événements
import '../utils/leisureHelpers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../widgets/profile_post_card.dart';  // Import du widget ProfilePostCard
import 'dart:typed_data';
import 'leisure_events_calendar_screen.dart';
import '../utils/constants.dart' as constants;
import '../utils.dart' show getImageProvider;

// Rendre createUriFromBaseUrl disponible globalement dans la classe
Future<Uri> createUriFromBaseUrl(String path, {Map<String, dynamic>? queryParameters}) async {
  final baseUrl = await getBaseUrl();
  if (baseUrl.startsWith('http://')) {
    final domain = baseUrl.replaceFirst('http://', '');
    return Uri.http(domain, path, queryParameters);
  } else if (baseUrl.startsWith('https://')) {
    final domain = baseUrl.replaceFirst('https://', '');
    return Uri.https(domain, path, queryParameters);
  } else {
    String queryString = '';
    if (queryParameters != null && queryParameters.isNotEmpty) {
      queryString = '?' + queryParameters.entries.map((e) => '${e.key}=${e.value}').join('&');
    }
    return Uri.parse('$baseUrl$path$queryString');
  }
}

class ProducerLeisureScreen extends StatefulWidget {
  final String producerId;
  final Map<String, dynamic>? producerData;
  final String? userId; // Add userId to match the structure of ProducerScreen

  // Constructor that accepts either producerId or producerData
  const ProducerLeisureScreen({
    Key? key, 
    this.producerId = '', 
    this.producerData,
    this.userId,
  }) : super(key: key);

  @override
  _ProducerLeisureScreenState createState() => _ProducerLeisureScreenState();
}

class _ProducerLeisureScreenState extends State<ProducerLeisureScreen> with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _producerData;
  bool _isLoading = true;
  String? _error;
  late String _producerId;
  late TabController _tabController;
  bool _isFollowing = false;
  
  // Stocke les posts du producteur
  List<dynamic> _producerPosts = [];
  bool _isLoadingPosts = false;
  bool _hasPostsError = false;

  // Méthode pour récupérer les détails du producteur
  Future<void> _fetchProducerDetails() async {
    try {
      // Utiliser la fonction fetchProducerWithFallback pour récupérer les données du producteur
      final client = http.Client();
      final baseUrl = await getBaseUrl();
      
      // Cette fonction essaie d'abord l'endpoint standard puis l'endpoint leisure en cas d'échec
      final producerData = await fetchProducerWithFallback(_producerId, client, baseUrl);
      
      if (producerData != null) {
        // Récupérer les données de relations pour ce producteur
        Map<String, dynamic>? relationsData;
        try {
          // Essayer de récupérer les relations via l'API
          final relationsUrl = await createUriFromBaseUrl('/api/producers/$_producerId/relations');
          final relationsResponse = await client.get(relationsUrl);
          
          if (relationsResponse.statusCode == 200) {
            relationsData = json.decode(relationsResponse.body);
          } else {
            // Si échec, essayer l'endpoint leisure
            final leisureRelationsUrl = await createUriFromBaseUrl('/api/leisureProducers/$_producerId/relations');
            final leisureRelationsResponse = await client.get(leisureRelationsUrl);
            if (leisureRelationsResponse.statusCode == 200) {
              relationsData = json.decode(leisureRelationsResponse.body);
            }
          }
        } catch (e) {
          print('⚠️ Erreur lors de la récupération des relations: $e');
        }
        
        // Fusionner les données du producteur avec les relations si disponibles
        if (relationsData != null) {
          producerData.addAll(relationsData);
        }
        
        // Mettre à jour l'état
        setState(() {
          _producerData = producerData;
          _isLoading = false;
          
          // Check if user is following this producer
          if (widget.userId != null) {
            final followers = _producerData?['followers'] as List? ?? [];
            _isFollowing = followers.contains(widget.userId);
          }
        });
      } else {
        setState(() {
          _error = 'Erreur lors de la récupération des données du producteur';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Erreur réseau: $e';
        _isLoading = false;
      });
    }
  }

  // Fonction pour suivre/ne plus suivre un producteur
  Future<void> _toggleFollow() async {
    if (widget.userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vous devez être connecté pour suivre un producteur')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final url = await createUriFromBaseUrl('/api/follows/producer');
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'userId': widget.userId,
          'producerId': _producerId,
          'follow': !_isFollowing,
        }),
      );

      if (response.statusCode == 200) {
        setState(() {
          _isFollowing = !_isFollowing;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la mise à jour: ${response.statusCode}')),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur réseau: $e')),
      );
    }
  }

  // Fonction pour marquer intérêt/choix
  Future<void> _markInteraction(String type) async {
    if (widget.userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Vous devez être connecté pour marquer ${type == 'interest' ? 'un intérêt' : 'un choix'}')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final endpoint = type == 'interest' ? 'interested' : 'choice';
      final url = await createUriFromBaseUrl('/api/choicexinterest/$endpoint');
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'userId': widget.userId,
          'producerId': _producerId,
        }),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final isMarked = type == 'interest' ? responseData['interested'] : responseData['choice'];
        
        // Refresh producer data to update UI
        _fetchProducerDetails();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isMarked 
              ? type == 'interest' ? 'Ajouté à vos intérêts' : 'Ajouté à vos choix'
              : type == 'interest' ? 'Retiré de vos intérêts' : 'Retiré de vos choix'
            ),
            backgroundColor: isMarked ? Colors.green : Colors.grey,
          ),
        );
      } else {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la mise à jour: ${response.statusCode}')),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur réseau: $e')),
      );
    }
  }

  // Fonction pour récupérer les posts du producteur
  Future<void> _fetchProducerPosts() async {
    if (_producerId.isEmpty) return;
    
    setState(() {
      _isLoadingPosts = true;
      _hasPostsError = false;
    });
    
    try {
      // Utiliser une URL qui filtre spécifiquement par producerId
      final queryParams = {
        'limit': '30',
        'producerId': _producerId,
        'venueOnly': 'true',
        'prioritizeFollowers': 'true',
        'followersWeight': '2',
        'sort': 'relevance',
      };
      
      // Ajouter le userId si disponible
      if (widget.userId != null) {
        queryParams['userId'] = widget.userId!;
      }
      
      final url = await createUriFromBaseUrl('/api/posts', queryParameters: queryParams);
      
      print('🔍 Récupération des posts du lieu avec URL: $url');
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        
        // Filtrer les posts
        final filteredPosts = data.where((post) => 
          post['producer_id'] == _producerId || 
          post['isProducerPost'] == true && post['producer_id'] == _producerId
        ).toList();
        
        setState(() {
          _producerPosts = filteredPosts;
          _isLoadingPosts = false;
        });
        print('✅ Posts du producteur récupérés : ${_producerPosts.length} posts');
        
        if (_producerPosts.isEmpty) {
          print('⚠️ Aucun post trouvé, essai avec méthode alternative');
          _fetchProducerPostsAlternative();
        }
      } else {
        setState(() {
          _isLoadingPosts = false;
          _hasPostsError = true;
        });
        print('❌ Erreur lors de la récupération des posts: ${response.statusCode}');
        
        // En cas d'erreur, essayer la méthode alternative
        _fetchProducerPostsAlternative();
      }
    } catch (e) {
      setState(() {
        _isLoadingPosts = false;
        _hasPostsError = true;
      });
      print('❌ Erreur réseau: $e');
      
      // En cas d'exception, essayer la méthode alternative
      _fetchProducerPostsAlternative();
    }
  }
  
  // Méthode alternative pour récupérer les posts
  Future<void> _fetchProducerPostsAlternative() async {
    print('🔄 Tentative alternative de récupération des posts');
    
    try {
      final queryParams = {
        'limit': '30',
      };
      
      if (widget.userId != null) {
        queryParams['userId'] = widget.userId!;
      }
      
      final url = await createUriFromBaseUrl('/api/posts', queryParameters: queryParams);
      
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List;
        
        // Filtrer pour ne retenir que les posts pertinents
        final filteredPosts = data.where((post) => 
          post['producer_id'] == _producerId ||
          post['isProducerPost'] == true && post['producer_id'] == _producerId ||
          post['isLeisureProducer'] == true && post['producer_id'] == _producerId ||
          (post['referenced_event_id'] != null && 
           _producerData!['evenements']?.any((event) => 
             event['_id'] == post['referenced_event_id'] ||
             event['lien_evenement']?.contains(post['referenced_event_id'].toString()) == true
           ) == true) ||
          (post['content'] != null && 
           _producerData!['lieu'] != null &&
           post['content'].toString().toLowerCase().contains(_producerData!['lieu'].toString().toLowerCase()))
        ).toList();
        
        if (filteredPosts.isNotEmpty) {
          setState(() {
            _producerPosts = filteredPosts;
            _isLoadingPosts = false;
          });
          print('✅ Posts récupérés (méthode alternative): ${_producerPosts.length}');
        } else {
          // Si aucun post pertinent, afficher quelques posts généraux
          if (data.isNotEmpty) {
            setState(() {
              _producerPosts = data.take(math.min(5, data.length)).toList();
              _isLoadingPosts = false;
            });
          }
          print('ℹ️ Aucun post pertinent trouvé, affichage de posts généraux');
        }
      }
    } catch (e) {
      print('❌ Erreur méthode alternative: $e');
    }
  }

  // Widget pour les compteurs d'interaction
  Widget _buildInteractionCounter(IconData icon, Color color, int count, String label) {
    return Column(
      children: [
        Icon(icon, color: count > 0 ? color : Colors.grey),
        const SizedBox(height: 4),
        Text(
          count.toString(),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: count > 0 ? color : Colors.grey,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  // Navigation vers les détails d'un événement
  void _navigateToEventDetails(dynamic event) {
    if (event == null) return;

    String eventId = '';
    String eventTitle = 'Événement'; // Default title

    // Déterminer l'ID de l'événement en fonction du type d'objet fourni
    if (event is Map<String, dynamic>) {
      eventId = event['_id'] ?? event['id'] ?? '';
      // Use bracket notation for non-ASCII keys
      eventTitle = event['title'] ?? event['intitulé'] ?? eventTitle;
    } else if (event is String) {
      // Assuming the string is the ID
      eventId = event;
    } else {
      // Attempt to access properties if it's some other object type
      try {
        eventId = event.id ?? '';
        // Use bracket notation here too if event might be a Map
        eventTitle = event.title ?? (event as Map<String, dynamic>)['intitulé'] ?? eventTitle;
      } catch (e) {
        print("❌ Erreur lors de l'accès à l'ID/titre de l'événement: $e");
        if (mounted) { // Check if the widget is still mounted
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Impossible d'ouvrir cet événement"), backgroundColor: Colors.red),
          );
        }
        return;
      }
    }

    if (eventId.isEmpty) {
       print('❌ ID d\'événement vide, navigation annulée.');
       if (mounted) { // Check if the widget is still mounted
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('ID d\'événement manquant'), backgroundColor: Colors.orange),
         );
       }
       return;
    }

    print('➡️ Navigation vers EventLeisureScreen pour ID: $eventId, Titre: $eventTitle');

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EventLeisureScreen(
          // Pass both id and potentially pre-fetched data if available
          id: eventId,
          eventData: (event is Map<String, dynamic>) ? event : null,
        ),
      ),
    );
  }

  // Widget pour afficher un message quand il n'y a pas de posts
  Widget _buildEmptyPostsMessage() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40.0),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.article_outlined,
              size: 40,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Aucune publication disponible',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Revenez bientôt pour voir les nouvelles publications',
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
  
  // Widget pour afficher un message d'erreur générique
  Widget _buildErrorMessage(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 30.0, horizontal: 20.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 60,
            color: Colors.red[300],
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey[800],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _isLoadingPosts = true;
                _hasPostsError = false;
              });
              _fetchProducerPosts();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
            ),
            child: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }
  
  // Widget pour afficher un message d'erreur lors du chargement des posts
  Widget _buildPostsErrorWidget() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32.0),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.error_outline,
              size: 40,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Erreur lors du chargement des posts',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _fetchProducerPosts,
            icon: const Icon(Icons.refresh),
            label: const Text('Réessayer'),
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.blue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // Section pour afficher les posts du producteur
  Widget _buildPostsSection() {
    if (_isLoadingPosts) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_hasPostsError) {
      return _buildErrorMessage('Impossible de charger les publications');
    }
    
    if (_producerPosts.isEmpty) {
      return _buildEmptyPostsMessage();
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _producerPosts.length,
      itemBuilder: (context, index) {
        final post = _producerPosts[index];
        return _buildPostItem(post);
      },
    );
  }

  // Widget pour afficher un post
  Widget _buildPostItem(Map<String, dynamic> post) {
    // Extraire les informations du post - gestion des différentes structures
    final String content = post['content'] ?? 'Contenu non disponible';
    final List<dynamic> media = post['media'] ?? [];
    final bool isAutomated = post['is_automated'] == true;
    final bool isProducerPost = post['isProducerPost'] == true;
    final bool isLeisureProducer = post['isLeisureProducer'] == true;
    final String postedAt = post['time_posted'] ?? post['posted_at'] ?? DateTime.now().toIso8601String();
    final int likesCount = post['likes_count'] ?? 0;
    final int commentsCount = post['comments_count'] ?? 0;
    final int interestedCount = post['interested_count'] ?? 0;
    final int choiceCount = post['choice_count'] ?? 0;
    final eventId = post['referenced_event_id'];
    final bool isEvent = post['is_event'] == true || eventId != null;
    final Map<String, dynamic>? location = post['location'] is Map ? post['location'] as Map<String, dynamic> : null;
    final Map<String, dynamic>? author = post['author'] is Map ? post['author'] as Map<String, dynamic> : null;
    
    // Formatage de la date
    String formattedDate = '';
    try {
      final DateTime date = DateTime.parse(postedAt);
      formattedDate = DateFormat('dd MMM yyyy à HH:mm').format(date);
    } catch (e) {
      formattedDate = 'Date inconnue';
    }
    
    // Récupérer les informations de l'auteur (gestion des différentes structures)
    String authorName = '';
    String authorAvatar = '';
    
    if (author != null) {
      authorName = author['name'] ?? '';
      authorAvatar = author['avatar'] ?? '';
    }
    
    // Si pas d'informations d'auteur, utiliser les données du producteur
    if (authorName.isEmpty) {
      authorName = _producerData!['lieu'] ?? 'Nom non spécifié';
    }
    
    if (authorAvatar.isEmpty) {
      authorAvatar = getProducerImageUrl(_producerData!);
    }
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
              // En-tête du post avec avatar et badges
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    // Avatar du producteur
                    CircleAvatar(
                      radius: 20,
                      backgroundImage: getImageProvider(authorAvatar) ?? const AssetImage('assets/images/default_avatar.png'),
                      backgroundColor: Colors.grey[200],
                    ),
                    const SizedBox(width: 12),
                    // Nom et date
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            authorName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            formattedDate,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Système de badges amélioré
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Badge pour post automatisé
                        if (isAutomated)
                          Container(
                            margin: const EdgeInsets.only(right: 8.0),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.blue.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.auto_awesome, size: 14, color: Colors.blue.shade700),
                                const SizedBox(width: 4),
                                Text(
                                  'Auto',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                        // Badge pour post de lieu
                        if (isProducerPost)
                          Container(
                            margin: const EdgeInsets.only(right: 8.0),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.deepPurple.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.deepPurple.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.store, size: 14, color: Colors.deepPurple.shade700),
                                const SizedBox(width: 4),
                                Text(
                                  'Lieu',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.deepPurple.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                        // Badge pour événement
                        if (isEvent)
                          Container(
                            margin: const EdgeInsets.only(right: 8.0),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.amber.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.event, size: 14, color: Colors.amber.shade700),
                                const SizedBox(width: 4),
                                Text(
                                  'Événement',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.amber.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
          
          // Contenu du post
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              content,
              style: const TextStyle(fontSize: 16),
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          
          // Localisation si présente
          if (location != null && location['address'] != null)
            Padding(
              padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 12.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.3), width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.location_on, size: 14, color: Colors.blue.shade700),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        location['address'].toString(),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          
          // Media (images) s'il y en a
          if (media.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: SizedBox(
                height: 200,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: media.length,
                  itemBuilder: (context, index) {
                    final mediaItem = media[index];
                    final String url = mediaItem is Map ? (mediaItem['url'] ?? '') : mediaItem.toString();
                    
                    return Container(
                      margin: const EdgeInsets.only(left: 16.0, right: 8.0),
                      width: 180,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image(
                          image: getImageProvider(url) ?? const AssetImage('assets/images/default_image.png'),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: Colors.grey[200],
                            child: const Icon(Icons.broken_image, color: Colors.grey),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            
            // Section événement référencé si présent
            if (eventId != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0),
                child: InkWell(
                  onTap: () => _navigateToEventDetails(eventId),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.purple.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.event,
                          color: Colors.purple.shade700,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Voir l\'événement associé',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.purple.shade700,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: Colors.purple.shade700,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            
          // Barre d'interactions (compteurs)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Likes
                _buildInteractionCounter(
                  Icons.favorite,
                  Colors.red,
                  likesCount,
                  'J\'aime',
                ),
                
                // Comments
                _buildInteractionCounter(
                  Icons.chat_bubble,
                  Colors.blue,
                  commentsCount,
                  'Commentaires',
                ),
                
                // Interested
                _buildInteractionCounter(
                  Icons.star,
                  Colors.amber,
                  interestedCount,
                  'Intéressés',
                ),
                
                // Choice
                _buildInteractionCounter(
                  Icons.check_circle,
                  Colors.green,
                  choiceCount,
                  'Choix',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    
    // Initialize TabController with 3 tabs (Events, Posts, Location)
    _tabController = TabController(length: 3, vsync: this);
    
    // If producerData is provided, use it directly
    if (widget.producerData != null) {
      setState(() {
        _producerData = widget.producerData;
        _isLoading = false;
        // Extract the producer ID from producerData if needed
        _producerId = widget.producerData!['_id'] ?? '';
        
        // Fetch posts once we have the producer ID
        _fetchProducerPosts();
      });
    } else {
      // Otherwise, use the provided producerId and fetch data
      _producerId = widget.producerId;
      _fetchProducerDetails();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Afficher un indicateur de chargement
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Détails Lieu de Loisir'),
          backgroundColor: Colors.deepPurple,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.deepPurple),
              SizedBox(height: 16),
              Text('Chargement des données...', style: TextStyle(color: Colors.grey))
            ],
          )
        ),
      );
    }

    // Afficher un message d'erreur
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Erreur'),
          backgroundColor: Colors.deepPurple,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.error_outline, size: 60, color: Colors.red),
              ),
              const SizedBox(height: 16),
              Text(_error!, 
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _error = null;
                  });
                  _fetchProducerDetails();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Réessayer'),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.deepPurple,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Si les données sont chargées mais nulles
    if (_producerData == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Données non disponibles'),
          backgroundColor: Colors.deepPurple,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.search_off, size: 60, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              const Text(
                'Aucune donnée disponible pour ce lieu de loisir',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // Afficher les données du producteur
    final events = _producerData!['evenements'] ?? [];
    final coordinates = _producerData!['location']?['coordinates'];
    
    // Split events into upcoming and past events
    final upcomingEvents = <dynamic>[];
    final pastEvents = <dynamic>[];
    
    for (var event in events) {
      try {
        // Use the helper function to determine if the event is passed
        final bool isPast = isEventPassed(event);
        
        if (isPast) {
          pastEvents.add(event);
        } else {
          upcomingEvents.add(event);
        }
      } catch (e) {
        print('❌ Erreur lors du traitement d\'un événement: $e');
        upcomingEvents.add(event); // Default to upcoming
      }
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(_producerData!),
          SliverToBoxAdapter(
            child: _buildProfileActions(_producerData!),
          ),
          SliverPersistentHeader(
            delegate: _SliverAppBarDelegate(
              TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(
                    icon: Icon(Icons.event),
                    text: "Événements",
                  ),
                  Tab(
                    icon: Icon(Icons.article),
                    text: "Publications",
                  ),
                  Tab(
                    icon: Icon(Icons.place),
                    text: "Localisation",
                  ),
                ],
                labelColor: Colors.deepPurple,
                unselectedLabelColor: Colors.grey,
                indicatorColor: Colors.deepPurple,
              ),
            ),
            pinned: true,
          ),
          SliverFillRemaining(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Events Tab
                SingleChildScrollView(
                  child: _buildTabSection(upcomingEvents, pastEvents),
                ),
                
                // Posts Tab
                SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: _isLoadingPosts
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32.0),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      : _hasPostsError
                        ? _buildPostsErrorWidget()
                        : _producerPosts.isEmpty
                          ? _buildEmptyPostsMessage()
                          : _buildPostsSection(),
                  ),
                ),
                
                // Location Tab
                SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 16),
                      if (coordinates != null) _buildMap(coordinates),
                      const SizedBox(height: 16),
                      _buildMapButton(),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTabSection(List<dynamic> upcomingEvents, List<dynamic> pastEvents) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title section
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.event, color: Colors.deepPurple),
              ),
              const SizedBox(width: 12),
              const Text(
                'Événements',
                style: TextStyle(
                  fontSize: 22, 
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Tabs
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16.0),
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TabBar(
            controller: _tabController,
            tabs: [
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.calendar_today, size: 16),
                    const SizedBox(width: 8),
                    Text('À venir (${upcomingEvents.length})'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.history, size: 16),
                    const SizedBox(width: 8),
                    Text('Passés (${pastEvents.length})'),
                  ],
                ),
              ),
            ],
            labelColor: Colors.white,
            unselectedLabelColor: Colors.deepPurple,
            indicator: BoxDecoration(
              color: Colors.deepPurple,
              borderRadius: BorderRadius.circular(12),
            ),
            dividerColor: Colors.transparent,
            indicatorSize: TabBarIndicatorSize.tab,
            labelPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          ),
        ),
        
        // TabBarView
        SizedBox(
          height: upcomingEvents.isEmpty && pastEvents.isEmpty ? 100 : 
                 math.max(upcomingEvents.length, pastEvents.length) * 130,
          child: TabBarView(
            controller: _tabController,
            children: [
              // Upcoming events tab
              upcomingEvents.isEmpty
                  ? _buildEmptyEventsMessage('Aucun événement à venir')
                  : _buildEventsList(
                      events: upcomingEvents,
                      isLoading: _isLoading,
                      onEventTap: _navigateToEventDetails,
                    ),
              
              // Past events tab
              pastEvents.isEmpty
                  ? _buildEmptyEventsMessage('Aucun événement passé')
                  : _buildEventsList(
                      events: pastEvents,
                      isLoading: _isLoading,
                      onEventTap: _navigateToEventDetails,
                    ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildEmptyEventsMessage(String message) {
    return Container(
      margin: const EdgeInsets.only(top: 30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              message.contains('venir') ? Icons.event_busy : Icons.history_toggle_off,
              size: 40,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(Map<String, dynamic> data) {
    // Check if the producer is followed by the current user
    final List<dynamic> followers = data['followers'] as List? ?? [];
    final bool isCurrentUserFollowing = widget.userId != null && followers.contains(widget.userId);
    
    // Calculate interest and choice counts
    final int interestsCount = (data['interestedUsers'] is List) ? (data['interestedUsers'] as List).length : 0;
    final int choicesCount = (data['choiceUsers'] is List) ? (data['choiceUsers'] as List).length : 0;
    
    // Utilisez la fonction helper améliorée pour obtenir l'image du producteur
    final String backgroundImage = getProducerImageUrl(data);
    
    return SliverAppBar(
      expandedHeight: 300,
      floating: false,
      pinned: true,
      backgroundColor: Colors.deepPurple,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Background image with overlay gradient
            ShaderMask(
              shaderCallback: (rect) {
                return LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withOpacity(0.1), Colors.black.withOpacity(0.9)],
                ).createShader(rect);
              },
              blendMode: BlendMode.darken,
              child: backgroundImage.startsWith('data:image') 
                ? Image.memory(
                    _decodeBase64Image(backgroundImage),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.deepPurple.withOpacity(0.7),
                        child: const Center(
                          child: Icon(Icons.broken_image, size: 50, color: Colors.white60),
                        ),
                      );
                    },
                  )
                : Image.network(
                    backgroundImage,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.deepPurple.withOpacity(0.7),
                        child: const Center(
                          child: Icon(Icons.broken_image, size: 50, color: Colors.white60),
                        ),
                      );
                    },
                  ),
            ),
            
            // Category and status info
            Positioned(
              top: 60,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.theater_comedy, color: Colors.white, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'Lieu de Loisir',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Info overlay at the bottom
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.9),
                      Colors.black.withOpacity(0.1),
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Profile Photo with border
                        ClipOval(
                          child: Image(
                            image: getImageProvider(backgroundImage) ?? const AssetImage('assets/images/default_avatar.png'),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              color: Colors.grey[200],
                              child: const Icon(Icons.broken_image, color: Colors.grey),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                data['lieu'] ?? 'Nom non spécifié',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (data['adresse'] != null)
                                Row(
                                  children: [
                                    const Icon(Icons.location_on, size: 16, color: Colors.white70),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        data['adresse'],
                                        style: const TextStyle(color: Colors.white70, fontSize: 14),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (data['description'] != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          data['description'],
                          style: const TextStyle(fontSize: 14, color: Colors.white, height: 1.4),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            
            // Social interaction buttons at top right
            Positioned(
              top: 16,
              right: 16,
              child: Row(
                children: [
                  // Interest button
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: InkWell(
                      onTap: () => _markInteraction('interest'),
                      child: Row(
                        children: [
                          const Icon(Icons.favorite, color: Colors.white, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            '$interestsCount',
                            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Choice button
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: InkWell(
                      onTap: () => _markInteraction('choice'),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.white, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            '$choicesCount',
                            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        titlePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(
          data['lieu'] ?? 'Détails Lieu de Loisir',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      actions: [
        // Follow/Unfollow button
        Container(
          margin: const EdgeInsets.only(right: 8),
          child: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _isFollowing ? Colors.deepPurple.shade100 : Colors.deepPurple.shade700,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isFollowing ? Icons.person_remove : Icons.person_add,
                color: _isFollowing ? Colors.deepPurple : Colors.white,
                size: 18,
              ),
            ),
            onPressed: _toggleFollow,
            tooltip: _isFollowing ? 'Ne plus suivre' : 'Suivre',
          ),
        ),
      ],
    );
  }

  Widget _buildProfileActions(Map<String, dynamic> data) {
    final followersCount = (data['followers'] is List) 
        ? data['followers'].length
        : 0;
    final followingCount = (data['following'] is List)
        ? data['following'].length
        : 0;
    final interestedCount = (data['interestedUsers'] is List)
        ? data['interestedUsers'].length
        : 0;
    final choicesCount = (data['choiceUsers'] is List)
        ? data['choiceUsers'].length
        : 0;
    
    // Check if the user has this producer as interested/choice
    final bool isInterested = widget.userId != null && 
        data['interestedUsers'] is List && 
        (data['interestedUsers'] as List).contains(widget.userId);
        
    final bool isChoice = widget.userId != null && 
        data['choiceUsers'] is List && 
        (data['choiceUsers'] as List).any((item) => 
            item is Map && item['userId'] == widget.userId);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // Main stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // Followers
              _buildSocialStats(
                '${NumberFormat.compact().format(followersCount)}',
                'Followers',
                Icons.people,
                Colors.deepPurple,
              ),
              
              // Following
              _buildSocialStats(
                '${NumberFormat.compact().format(followingCount)}',
                'Following',
                Icons.person_add,
                Colors.indigo,
              ),
              
              // Interested
              _buildSocialStats(
                '${NumberFormat.compact().format(interestedCount)}',
                'Intéressés',
                Icons.favorite_border,
                Colors.red,
                isActive: isInterested,
                onTap: () => _markInteraction('interest'),
              ),
              
              // Choices
              _buildSocialStats(
                '${NumberFormat.compact().format(choicesCount)}',
                'Choix',
                Icons.check_circle_outline,
                Colors.blue,
                isActive: isChoice,
                onTap: () => _markInteraction('choice'),
              ),
            ],
          ),
          
          // Separator
          const SizedBox(height: 20),
          Divider(color: Colors.grey.withOpacity(0.3), height: 1),
          const SizedBox(height: 20),
          
          // Extra stats and info
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // Number of events
              _buildExtraStat(
                '${data['evenements']?.length ?? 0}',
                'Événements',
                Icons.event_note,
              ),
              
              // Last active
              _buildExtraStat(
                'Actif',
                'Statut',
                Icons.access_time,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSocialStats(String count, String label, IconData icon, Color color, {bool isActive = false, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isActive ? color.withOpacity(0.2) : Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: isActive ? Border.all(color: color.withOpacity(0.8), width: 2) : null,
              ),
              child: Icon(
                icon, 
                color: isActive ? color : Colors.grey[700], 
                size: 24
              ),
            ),
            const SizedBox(height: 8),
            Text(
              count,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isActive ? color : Colors.black87,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: isActive ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildExtraStat(String count, String label, IconData icon) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: Colors.deepPurple),
            const SizedBox(width: 6),
            Text(
              count,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildEventsList({
    required List<dynamic> events,
    required bool isLoading,
    required Function(dynamic) onEventTap,
  }) {
    if (isLoading) {
      return Center(child: CircularProgressIndicator());
    }
    
    return ListView.builder(
      itemCount: events.length,
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      itemBuilder: (context, index) {
        final event = events[index];
        return _buildEventCard(
          event: event,
          onEventTap: onEventTap,
        );
      },
    );
  }

  Widget _buildEventCard({
    required Map<String, dynamic> event,
    required Function(dynamic) onEventTap,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: InkWell(
        onTap: () => onEventTap(event),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image de l'événement
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: Image(
                image: getImageProvider(event['photo']) ?? const AssetImage('assets/images/default_event.png'),
                width: double.infinity,
                height: 150,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: double.infinity,
                  height: 150,
                  color: Colors.grey[200],
                  child: const Icon(Icons.event, color: Colors.grey, size: 40),
                ),
              ),
            ),
            
            // Informations sur l'événement
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event['title'] ?? event['intitulé'] ?? 'Événement sans titre',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    
                    // Date
                    Row(
                      children: [
                        Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            event['date'] ?? event['prochaines_dates'] ?? 'Date non spécifiée',
                            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 4),
                    
                    // Catégorie
                    if (event['category'] != null || event['catégorie'] != null)
                      Row(
                        children: [
                          Icon(Icons.category, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              event['category'] ?? event['catégorie'] ?? '',
                              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
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
          ],
        ),
      ),
    );
  }
  
  // Helper pour décoder les images en base64
  Uint8List _decodeBase64Image(String base64String) {
    String normalizedSource = base64String;
    
    // Supprimer le préfixe data:image si présent
    if (base64String.contains(';base64,')) {
      normalizedSource = base64String.split(';base64,')[1];
    }
    
    try {
      return base64Decode(normalizedSource);
    } catch (e) {
      print('⚠️ Erreur de décodage base64: $e');
      // Retourner un tableau vide en cas d'erreur
      return Uint8List(0);
    }
  }

  Widget _buildMapButton() {
    return Center(
      child: ElevatedButton.icon(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const MapLeisureScreen(),
            ),
          );
        },
        icon: const Icon(Icons.map, size: 22),
        label: const Text(
          'Voir sur la carte',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: Colors.deepPurple,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          elevation: 4,
          shadowColor: Colors.deepPurple.withOpacity(0.4),
        ),
      ),
    );
  }

  Widget _buildMap(List<dynamic> coordinates) {
    try {
      // Vérifier que les coordonnées sont valides
      if (coordinates.length < 2) {
        print('❌ Coordonnées invalides: longueur insuffisante');
        return _buildMapErrorWidget('Coordonnées incomplètes');
      }
      
      // Vérifier que les coordonnées sont numériques
      if (coordinates[0] == null || coordinates[1] == null || 
          !(coordinates[0] is num) || !(coordinates[1] is num)) {
        print('❌ Coordonnées invalides: valeurs non numériques');
        return _buildMapErrorWidget('Coordonnées non numériques');
      }
      
      // Convertir en double de manière sécurisée
      final double longitude = coordinates[0].toDouble();
      final double latitude = coordinates[1].toDouble();
      
      // Vérifier que les coordonnées sont dans les limites valides
      if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
        print('❌ Coordonnées invalides: hors limites');
        return _buildMapErrorWidget('Coordonnées hors limites');
      }
      
      final latLng = LatLng(latitude, longitude);
      
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title section with icon
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.place, color: Colors.deepPurple, size: 24),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Emplacement',
                  style: TextStyle(
                    fontSize: 22, 
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Map container with shadow and rounded corners
            Container(
              height: 250,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  // Google Map
                  GoogleMap(
                    initialCameraPosition: CameraPosition(target: latLng, zoom: 15),
                    markers: {
                      Marker(
                        markerId: const MarkerId('producer'),
                        position: latLng,
                        infoWindow: InfoWindow(
                          title: _producerData!['lieu'] ?? 'Lieu de loisir',
                          snippet: _producerData!['adresse'],
                        ),
                      )
                    },
                    mapType: MapType.normal,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                  ),
                  
                  // Address overlay at the bottom
                  if (_producerData!['adresse'] != null)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                        child: Row(
                          children: [
                            const Icon(Icons.location_on, color: Colors.white, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _producerData!['adresse'],
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      print('❌ Erreur lors de l\'affichage de la carte: $e');
      return _buildMapErrorWidget('Impossible d\'afficher la carte');
    }
  }
  
  // Widget de remplacement en cas d'erreur de carte
  Widget _buildMapErrorWidget(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title section
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.place, color: Colors.grey, size: 24),
              ),
              const SizedBox(width: 12),
              const Text(
                'Emplacement',
                style: TextStyle(
                  fontSize: 22, 
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Error container
          Container(
            height: 250,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.withOpacity(0.3)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.map_outlined, size: 48, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                Text(
                  message,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Veuillez vérifier les coordonnées',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Événements du producteur - This method is now correctly calling _buildEventsList
  Widget _buildEventsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          title: 'Événements',
          icon: Icons.event,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        
        // Affichage des événements
        _buildEventsList(
          events: _producerData!['evenements'] ?? [],
          isLoading: _isLoading,
          onEventTap: _navigateToEventDetails,
        ),
        
        // Bouton pour voir tous les événements au format calendrier
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => LeisureEventsCalendarScreen(
                    producerId: _producerId,
                    producerName: _producerData?['nom'] ?? 'Producteur',
                  ),
                ),
              );
            },
            icon: const Icon(Icons.calendar_month),
            label: const Text('Voir le calendrier des événements'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.purple,
              side: const BorderSide(color: Colors.purple),
              padding: const EdgeInsets.symmetric(vertical: 12.0),
            ),
          ),
        ),
      ],
    );
  }

  // Ajouter cette méthode pour créer les en-têtes de section
  Widget _buildSectionHeader({
    required String title,
    required IconData icon,
    EdgeInsetsGeometry padding = const EdgeInsets.all(16),
  }) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Icon(icon, color: Colors.purple[700]),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.purple[700],
            ),
          ),
        ],
      ),
    );
  }
}

// Delegate pour gérer la taille et le comportement de l'en-tête persistant de la barre d'onglets
class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this.tabBar);

  final TabBar tabBar;

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}

// Classe EventCard 
class EventCard extends StatelessWidget {
  final Map<String, dynamic> event;
  final VoidCallback onTap;

  const EventCard({
    Key? key,
    required this.event,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image de l'événement
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: Image(
                image: getImageProvider(event['photo']) ?? const AssetImage('assets/images/default_event.png'),
                width: double.infinity,
                height: 150,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: double.infinity,
                  height: 150,
                  color: Colors.grey[200],
                  child: const Icon(Icons.event, color: Colors.grey, size: 40),
                ),
              ),
            ),
            
            // Informations sur l'événement
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event['title'] ?? event['intitulé'] ?? 'Événement sans titre',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    
                    // Date
                    Row(
                      children: [
                        Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            event['date'] ?? event['prochaines_dates'] ?? 'Date non spécifiée',
                            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 4),
                    
                    // Catégorie
                    if (event['category'] != null || event['catégorie'] != null)
                      Row(
                        children: [
                          Icon(Icons.category, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              event['category'] ?? event['catégorie'] ?? '',
                              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
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
          ],
        ),
      ),
    );
  }
}


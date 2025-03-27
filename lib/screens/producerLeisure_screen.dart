import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'utils.dart'; // Uses conditional exports to select the right implementation
import 'package:intl/intl.dart';
import 'map_leisure_screen.dart';
import 'dart:math' as Math;
import 'eventLeisure_screen.dart'; // Import nécessaire pour afficher les événements
import '../utils/leisureHelpers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../widgets/profile_post_card.dart';  // Import du widget ProfilePostCard

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


  Future<void> _fetchProducerDetails() async {
    try {
      // Utiliser la nouvelle fonction fetchProducerWithFallback pour éviter les erreurs 404
      final baseUrl = getBaseUrl();
      final client = http.Client();
      
      // Cette fonction essaie d'abord l'endpoint standard puis l'endpoint leisure en cas d'échec
      final producerData = await fetchProducerWithFallback(_producerId, client, baseUrl);
      
      if (producerData != null) {
        // Récupérer les données de relations pour ce producteur
        Map<String, dynamic>? relationsData;
        try {
          // Essayer de récupérer les relations via l'API standard
          Uri relationsUrl;
          if (baseUrl.startsWith('http://')) {
            final domain = baseUrl.replaceFirst('http://', '');
            relationsUrl = Uri.http(domain, '/api/producers/$_producerId/relations');
          } else {
            final domain = baseUrl.replaceFirst('https://', '');
            relationsUrl = Uri.https(domain, '/api/producers/$_producerId/relations');
          }
          
          final relationsResponse = await client.get(relationsUrl);
          
          if (relationsResponse.statusCode == 200) {
            relationsData = json.decode(relationsResponse.body);
          } else {
            // Si échec, essayer l'endpoint leisure
            if (baseUrl.startsWith('http://')) {
              final domain = baseUrl.replaceFirst('http://', '');
              relationsUrl = Uri.http(domain, '/api/leisureProducers/$_producerId/relations');
            } else {
              final domain = baseUrl.replaceFirst('https://', '');
              relationsUrl = Uri.https(domain, '/api/leisureProducers/$_producerId/relations');
            }
            
            final leisureRelationsResponse = await client.get(relationsUrl);
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

  // Function to toggle follow status
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
      final baseUrl = getBaseUrl();
      Uri url;
      
      if (baseUrl.startsWith('http://')) {
        final domain = baseUrl.replaceFirst('http://', '');
        url = Uri.http(domain, '/api/follows/producer');
      } else if (baseUrl.startsWith('https://')) {
        final domain = baseUrl.replaceFirst('https://', '');
        url = Uri.https(domain, '/api/follows/producer');
      } else {
        url = Uri.parse('$baseUrl/api/follows/producer');
      }
      
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

  // Function to mark interested/choice
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
      final baseUrl = getBaseUrl();
      final endpoint = type == 'interest' ? 'interested' : 'choice';
      Uri url;
      
      if (baseUrl.startsWith('http://')) {
        final domain = baseUrl.replaceFirst('http://', '');
        url = Uri.http(domain, '/api/choicexinterest/$endpoint');
      } else if (baseUrl.startsWith('https://')) {
        final domain = baseUrl.replaceFirst('https://', '');
        url = Uri.https(domain, '/api/choicexinterest/$endpoint');
      } else {
        url = Uri.parse('$baseUrl/api/choicexinterest/$endpoint');
      }
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'userId': widget.userId,
          'targetId': _producerId,
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

  // Stocke les posts du producteur
  List<dynamic> _producerPosts = [];
  bool _isLoadingPosts = false;
  bool _hasPostsError = false;

  // Fonction pour récupérer les posts du producteur avec filtrage amélioré
  Future<void> _fetchProducerPosts() async {
    if (_producerId.isEmpty) return;
    
    setState(() {
      _isLoadingPosts = true;
      _hasPostsError = false;
    });
    
    try {
      // Extraire le domaine et le protocole de l'URL complète
      final baseUrl = getBaseUrl();
      Uri url;
      
      // Utiliser une URL qui filtre spécifiquement par producerId
      // pour s'assurer que seuls les posts de ce lieu sont affichés
      final queryParams = {
        'limit': '30',
        'producerId': _producerId,         // Filtrer par l'ID du producteur
        'venueOnly': 'true',               // S'assurer que ce sont des posts du lieu spécifique
        'prioritizeFollowers': 'true',     // Prioriser les posts des followers
        'followersWeight': '2',            // Donner plus de poids aux posts des followers
        'sort': 'relevance',               // Trier par pertinence plutôt que juste par date
      };
      
      // Ajouter le userId si disponible pour personnaliser les posts
      if (widget.userId != null) {
        queryParams['userId'] = widget.userId!;
      }
      
      if (baseUrl.startsWith('http://')) {
        final domain = baseUrl.replaceFirst('http://', '');
        url = Uri.http(domain, '/api/posts', queryParams);
      } else if (baseUrl.startsWith('https://')) {
        final domain = baseUrl.replaceFirst('https://', '');
        url = Uri.https(domain, '/api/posts', queryParams);
      } else {
        // Construire l'URL manuellement
        final queryString = queryParams.entries.map((e) => '${e.key}=${e.value}').join('&');
        url = Uri.parse('$baseUrl/api/posts?$queryString');
      }
      
      print('🔍 Récupération des posts du lieu avec URL: $url');
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        
        // Filtrer pour s'assurer que nous n'affichons que les posts de ce lieu spécifique
        final filteredPosts = data.where((post) => 
          post['producer_id'] == _producerId || 
          post['isProducerPost'] == true && post['producer_id'] == _producerId
        ).toList();
        
        setState(() {
          _producerPosts = filteredPosts;
          _isLoadingPosts = false;
        });
        print('✅ Posts du producteur récupérés : ${_producerPosts.length} posts');
        
        // Si aucun post n'est trouvé, essayer une approche différente
        if (_producerPosts.isEmpty) {
          print('⚠️ Aucun post trouvé avec producerId=$_producerId, essai avec méthode alternative');
          _fetchProducerPostsAlternative();
        }
      } else {
        setState(() {
          _isLoadingPosts = false;
          _hasPostsError = true;
        });
        print('❌ Erreur lors de la récupération des posts du producteur : ${response.statusCode}');
        print('❌ Message : ${response.body}');
        
        // En cas d'erreur, essayer la méthode alternative
        _fetchProducerPostsAlternative();
      }
    } catch (e) {
      setState(() {
        _isLoadingPosts = false;
        _hasPostsError = true;
      });
      print('❌ Erreur réseau lors de la récupération des posts : $e');
      
      // En cas d'exception, essayer la méthode alternative
      _fetchProducerPostsAlternative();
    }
  }
  
  // Méthode alternative pour récupérer les posts si la première tentative échoue
  Future<void> _fetchProducerPostsAlternative() async {
    print('🔄 Tentative alternative de récupération des posts du producteur');
    
    try {
      final baseUrl = getBaseUrl();
      Uri url;
      
      // Combiner plusieurs stratégies de recherche pour maximiser les chances de trouver des posts
      final queryParams = {
        'limit': '30',
      };
      
      // Ajouter le userId si disponible
      if (widget.userId != null) {
        queryParams['userId'] = widget.userId!;
      }
      
      if (baseUrl.startsWith('http://')) {
        final domain = baseUrl.replaceFirst('http://', '');
        url = Uri.http(domain, '/api/posts', queryParams);
      } else if (baseUrl.startsWith('https://')) {
        final domain = baseUrl.replaceFirst('https://', '');
        url = Uri.https(domain, '/api/posts', queryParams);
      } else {
        final queryString = queryParams.entries.map((e) => '${e.key}=${e.value}').join('&');
        url = Uri.parse('$baseUrl/api/posts?$queryString');
      }
      
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List;
        
        // Filtrer manuellement pour ne retenir que les posts pertinents à ce lieu
        final filteredPosts = data.where((post) => 
          // Vérifier plusieurs critères pour être sûr de ne retenir que les posts pertinents
          post['producer_id'] == _producerId ||
          post['isProducerPost'] == true && post['producer_id'] == _producerId ||
          post['isLeisureProducer'] == true && post['producer_id'] == _producerId ||
          (post['referenced_event_id'] != null && 
           _producerData!['evenements']?.any((event) => 
             event['_id'] == post['referenced_event_id'] ||
             event['lien_evenement']?.contains(post['referenced_event_id'].toString()) == true
           ) == true) ||
          // Vérifier si le contenu mentionne le nom du lieu
          (post['content'] != null && 
           _producerData!['lieu'] != null &&
           post['content'].toString().toLowerCase().contains(_producerData!['lieu'].toString().toLowerCase()))
        ).toList();
        
        if (filteredPosts.isNotEmpty) {
          setState(() {
            _producerPosts = filteredPosts;
            _isLoadingPosts = false;
          });
          print('✅ Posts du producteur récupérés (méthode alternative) : ${_producerPosts.length} posts');
        } else {
          // Si aucun post pertinent n'est trouvé, prendre quelques posts généraux
          setState(() {
            // Prendre au maximum 5 posts généraux si disponibles
            _producerPosts = data.take(Math.min(5, data.length)).toList();
            _isLoadingPosts = false;
          });
          print('ℹ️ Aucun post pertinent trouvé, affichage de posts généraux');
        }
      }
    } catch (e) {
      print('❌ Erreur lors de la méthode alternative : $e');
      // Ne pas modifier l'état car nous sommes déjà dans un état d'erreur ou vide
    }
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
  
  // Helper to navigate to event details
  Future<void> _navigateToEventDetails(BuildContext context, String eventId) async {
    setState(() {
      _isLoading = true;
    });
    print('🔍 Navigation vers l\'événement avec ID : $eventId');

    try {
      // Utiliser notre fonction améliorée pour extraire l'ID proprement
      final cleanId = extractEventId(eventId);
      print('🔍 ID extrait : $cleanId');
      
      if (cleanId.isEmpty) {
        throw Exception("ID d'événement invalide");
      }
      
      // Extraire le domaine et le protocole de l'URL complète
      final baseUrl = getBaseUrl();
      Uri url;
      
      // Construire l'URL avec le chemin normalisé
      final apiPath = normalizeCollectionRoute('events', cleanId);
      
      if (baseUrl.startsWith('http://')) {
        // Si c'est http://
        final domain = baseUrl.replaceFirst('http://', '');
        url = Uri.http(domain, apiPath);
      } else if (baseUrl.startsWith('https://')) {
        // Si c'est https://
        final domain = baseUrl.replaceFirst('https://', '');
        url = Uri.https(domain, apiPath);
      } else {
        // Utiliser Uri.parse comme solution de secours
        url = Uri.parse('$baseUrl$apiPath');
      }
      
      final response = await http.get(url);

      // Si première tentative échoue, essayer un chemin alternatif
      if (response.statusCode != 200) {
        print('⚠️ Premier appel API a échoué, tentative avec un autre endpoint...');
        final alternativeApiPath = apiPath.contains('events') 
            ? apiPath.replaceAll('events', 'evenements') 
            : apiPath.replaceAll('evenements', 'events');
            
        if (baseUrl.startsWith('http://')) {
          url = Uri.http(baseUrl.replaceFirst('http://', ''), alternativeApiPath);
        } else {
          url = Uri.https(baseUrl.replaceFirst('https://', ''), alternativeApiPath);
        }
        
        final secondResponse = await http.get(url);
        
        if (secondResponse.statusCode == 200) {
          // Utiliser les données de la deuxième tentative
          final data = json.decode(secondResponse.body);
          setState(() {
            _isLoading = false;
          });
          
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EventLeisureScreen(
                eventData: data,
              ),
            ),
          );
          return;
        }
      } else {
        // La première requête a réussi
        final data = json.decode(response.body);
        setState(() {
          _isLoading = false;
        });
        
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EventLeisureScreen(
              eventData: data,
            ),
          ),
        );
        return;
      }
      
      // Si on arrive ici, les deux tentatives ont échoué
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Événement introuvable. ID: $cleanId"),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      // Gestion des erreurs réseau
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur réseau : $e"),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        _isLoading = false;
      });
    }
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
                      backgroundImage: CachedNetworkImageProvider(
                        authorAvatar,
                      ),
                      backgroundColor: Colors.grey.shade200,
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
                        child: CachedNetworkImage(
                          imageUrl: url,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: Colors.grey[300],
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: Colors.grey[300],
                            child: const Icon(Icons.error),
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
                onTap: () => _navigateToEventDetails(context, eventId),
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
        return ProfilePostCard(
          post: post,
          userId: widget.userId ?? '',
          onRefresh: () {
            _fetchProducerPosts();
          },
        );
      },
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
                 Math.max(upcomingEvents.length, pastEvents.length) * 130,
          child: TabBarView(
            controller: _tabController,
            children: [
              // Upcoming events tab
              upcomingEvents.isEmpty
                  ? _buildEmptyEventsMessage('Aucun événement à venir')
                  : _buildEventsList(upcomingEvents, context, true),
              
              // Past events tab
              pastEvents.isEmpty
                  ? _buildEmptyEventsMessage('Aucun événement passé')
                  : _buildEventsList(pastEvents, context, false),
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
    
    // Default background image if none provided
    final String backgroundImage = data['photo'] ?? 
        'https://images.unsplash.com/photo-1519750783826-e2420f4d687f?ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D&auto=format&fit=crop&w=2574&q=80';
    
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
              child: Image.network(
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
                        Container(
                          height: 70,
                          width: 70,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: Image.network(
                              getProducerImageUrl(data),
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.deepPurple.withOpacity(0.5),
                                  child: const Icon(Icons.person, size: 40, color: Colors.white),
                                );
                              },
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

  Widget _buildEventsList(List<dynamic> events, BuildContext context, bool isUpcoming) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: events.length,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        final event = events[index];
        final eventId = event['lien_evenement']?.split('/').last;
        
        // Use helper to get consistent image URL
        String eventImage = getEventImageUrl(event);
        
        // Get category cleaned up
        String category = '';
        if (event['catégorie'] != null) {
          category = event['catégorie'].toString().split('»').last.trim();
        }
        
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 4,
          shadowColor: Colors.black26,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: InkWell(
            onTap: () {
              if (eventId != null) {
                _navigateToEventDetails(context, eventId);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Impossible de charger l'événement."),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            borderRadius: BorderRadius.circular(16),
            child: Row(
              children: [
                // Event status indicator
                Container(
                  width: 6,
                  height: 120,
                  decoration: BoxDecoration(
                    color: isUpcoming ? Colors.green : Colors.grey.shade400,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                    ),
                  ),
                ),
                
                // Event image with gradient overlay
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        bottomLeft: Radius.circular(12),
                      ),
                      child: Image.network(
                        eventImage,
                        width: 100,
                        height: 120,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 100,
                          height: 120,
                          color: Colors.grey[300],
                          child: const Icon(Icons.image_not_supported, size: 40, color: Colors.grey),
                        ),
                      ),
                    ),
                    
                    // Status badge overlay
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isUpcoming 
                            ? Colors.green.withOpacity(0.9)
                            : Colors.grey.shade700.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          isUpcoming ? 'À venir' : 'Passé',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                
                // Event details
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title
                        Text(
                          event['intitulé'] ?? 'Événement sans titre',
                          style: const TextStyle(
                            fontSize: 16, 
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        
                        // Category with colored background
                        if (category.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: Colors.deepPurple.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.deepPurple.withOpacity(0.3)),
                            ),
                            child: Text(
                              category,
                              style: TextStyle(
                                fontSize: 12, 
                                color: Colors.deepPurple[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        
                        // Dates with icon - use formatted date
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Row(
                            children: [
                              Icon(
                                isUpcoming ? Icons.calendar_today : Icons.history, 
                                size: 14, 
                                color: isUpcoming ? Colors.deepPurple : Colors.grey
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  formatEventDate(event['date_debut'] ?? event['prochaines_dates']),
                                  style: TextStyle(
                                    fontSize: 13, 
                                    color: isUpcoming ? Colors.deepPurple : Colors.grey[600],
                                    fontWeight: isUpcoming ? FontWeight.w500 : FontWeight.normal,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                          
                        // Price with discount display
                        if (event['prix_reduit'] != null)
                          Row(
                            children: [
                              const Icon(Icons.euro, size: 14, color: Colors.green),
                              const SizedBox(width: 6),
                              Text(
                                event['prix_reduit'],
                                style: const TextStyle(
                                  fontSize: 14, 
                                  color: Colors.green, 
                                  fontWeight: FontWeight.bold
                                ),
                              ),
                              if (event['ancien_prix'] != null) ...[
                                const SizedBox(width: 6),
                                Text(
                                  event['ancien_prix'],
                                  style: const TextStyle(
                                    fontSize: 12, 
                                    color: Colors.grey, 
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                // Calculate and show discount percentage if possible
                                _buildDiscountBadge(event['prix_reduit'], event['ancien_prix']),
                              ],
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
                
                // Arrow indicator with interactive effect
                Container(
                  padding: const EdgeInsets.all(12),
                  child: Icon(
                    Icons.arrow_forward_ios, 
                    size: 16, 
                    color: Colors.deepPurple.withOpacity(0.7)
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  // Helper to calculate and show discount percentage
  Widget _buildDiscountBadge(String currentPrice, String originalPrice) {
    try {
      // Extract numeric values from price strings
      double current = double.parse(currentPrice.replaceAll('€', '').replaceAll(',', '.').trim());
      double original = double.parse(originalPrice.replaceAll('€', '').replaceAll(',', '.').trim());
      
      if (original > 0 && current < original) {
        int discountPercentage = ((original - current) / original * 100).round();
        
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.red.shade600,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '-$discountPercentage%',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      }
    } catch (e) {
      // Silently handle parsing errors
    }
    
    return const SizedBox.shrink();
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

  Future<void> _navigateToEventDetails(BuildContext context, String eventId) async {
    setState(() {
      _isLoading = true;
    });
    print('🔍 Navigation vers l\'événement avec ID : $eventId');

    try {
      // Utiliser notre fonction améliorée pour extraire l'ID proprement
      final cleanId = extractEventId(eventId);
      print('🔍 ID extrait : $cleanId');
      
      if (cleanId.isEmpty) {
        throw Exception("ID d'événement invalide");
      }
      
      // Extraire le domaine et le protocole de l'URL complète
      final baseUrl = getBaseUrl();
      Uri url;
      
      // Construire l'URL avec le chemin normalisé
      final apiPath = normalizeCollectionRoute('events', cleanId);
      
      if (baseUrl.startsWith('http://')) {
        // Si c'est http://
        final domain = baseUrl.replaceFirst('http://', '');
        url = Uri.http(domain, apiPath);
      } else if (baseUrl.startsWith('https://')) {
        // Si c'est https://
        final domain = baseUrl.replaceFirst('https://', '');
        url = Uri.https(domain, apiPath);
      } else {
        // Utiliser Uri.parse comme solution de secours
        url = Uri.parse('$baseUrl$apiPath');
      }
      
      final response = await http.get(url);

      // Si première tentative échoue, essayer un chemin alternatif
      if (response.statusCode != 200) {
        print('⚠️ Premier appel API a échoué, tentative avec un autre endpoint...');
        final alternativeApiPath = apiPath.contains('events') 
            ? apiPath.replaceAll('events', 'evenements') 
            : apiPath.replaceAll('evenements', 'events');
            
        if (baseUrl.startsWith('http://')) {
          url = Uri.http(baseUrl.replaceFirst('http://', ''), alternativeApiPath);
        } else {
          url = Uri.https(baseUrl.replaceFirst('https://', ''), alternativeApiPath);
        }
        
        final secondResponse = await http.get(url);
        
        if (secondResponse.statusCode == 200) {
          // Utiliser les données de la deuxième tentative
          final data = json.decode(secondResponse.body);
          setState(() {
            _isLoading = false;
          });
          
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EventLeisureScreen(
                eventData: data,
              ),
            ),
          );
          return;
        }
      } else {
        // La première requête a réussi
        final data = json.decode(response.body);
        setState(() {
          _isLoading = false;
        });
        
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EventLeisureScreen(
              eventData: data,
            ),
          ),
        );
        return;
      }
      
      // Si on arrive ici, les deux tentatives ont échoué
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Événement introuvable. ID: $cleanId"),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      // Gestion des erreurs réseau
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur réseau : $e"),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        _isLoading = false;
      });
    }
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

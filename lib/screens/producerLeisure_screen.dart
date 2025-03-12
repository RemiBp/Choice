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

  @override
  void initState() {
    super.initState();
    
    // Initialize TabController
    _tabController = TabController(length: 2, vsync: this);
    
    // If producerData is provided, use it directly
    if (widget.producerData != null) {
      setState(() {
        _producerData = widget.producerData;
        _isLoading = false;
        // Extract the producer ID from producerData if needed
        _producerId = widget.producerData!['_id'] ?? '';
      });
    } else {
      // Otherwise, use the provided producerId and fetch data
      _producerId = widget.producerId;
      _fetchProducerDetails();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

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
              const SizedBox(height: 24),
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
          SliverList(
            delegate: SliverChildListDelegate([
              _buildProfileActions(_producerData!),
              const SizedBox(height: 16),
              _buildTabSection(upcomingEvents, pastEvents),
              const SizedBox(height: 24),
              if (coordinates != null) _buildMap(coordinates),
              const SizedBox(height: 24),
              _buildMapButton(),
              const SizedBox(height: 24),
            ]),
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
}

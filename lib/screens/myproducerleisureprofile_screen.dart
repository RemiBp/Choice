import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'eventLeisure_screen.dart';
import 'utils.dart';
import '../services/payment_service.dart';

class MyProducerLeisureProfileScreen extends StatefulWidget {
  final String userId;

  const MyProducerLeisureProfileScreen({Key? key, required this.userId}) : super(key: key);

  @override
  State<MyProducerLeisureProfileScreen> createState() => _MyProducerLeisureProfileScreenState();
}

class _MyProducerLeisureProfileScreenState extends State<MyProducerLeisureProfileScreen> with SingleTickerProviderStateMixin {
  late Future<Map<String, dynamic>> _producerFuture;
  late TabController _tabController;
  final List<String> _tabs = ['Mon profil', 'Mes événements', 'Statistiques'];
  bool _isLoading = false;
  
  // Pour la création/édition d'événements
  final TextEditingController _eventTitleController = TextEditingController();
  final TextEditingController _eventDescriptionController = TextEditingController();
  final TextEditingController _eventCategoryController = TextEditingController();
  String? _eventImageUrl;
  DateTime? _eventStartDate;
  DateTime? _eventEndDate;

  @override
  void initState() {
    super.initState();
    _producerFuture = _fetchProducerData(widget.userId);
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _eventTitleController.dispose();
    _eventDescriptionController.dispose();
    _eventCategoryController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _fetchProducerData(String userId) async {
    final url = Uri.parse('${getBaseUrl()}/api/producers/$userId');
    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        Map<String, dynamic> data = json.decode(response.body);
        
        // Fetch additional relations data
        final relationsUrl = Uri.parse('${getBaseUrl()}/api/producers/$userId/relations');
        try {
          final relationsResponse = await http.get(relationsUrl);
          if (relationsResponse.statusCode == 200) {
            final relationsData = json.decode(relationsResponse.body);
            data = {...data, ...relationsData};
          }
        } catch (e) {
          print('Error fetching relations: $e');
        }
        
        return data;
      } else {
        throw Exception('Erreur lors de la récupération des données : ${response.body}');
      }
    } catch (e) {
      throw Exception('Erreur réseau : $e');
    }
  }

  Future<List<dynamic>> _fetchProducerEvents(String userId) async {
    final url = Uri.parse('${getBaseUrl()}/api/producers/$userId/events');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Erreur lors de la récupération des événements');
      }
    } catch (e) {
      print('Erreur réseau : $e');
      return [];
    }
  }

  Future<List<dynamic>> _fetchProducerPosts(String userId) async {
    final url = Uri.parse('${getBaseUrl()}/api/producers/$userId');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final producerData = json.decode(response.body);
        final postIds = producerData['posts'] as List<dynamic>? ?? [];

        if (postIds.isEmpty) {
          return [];
        }

        // Récupérer les détails de chaque post à partir des IDs
        final List<dynamic> posts = [];
        for (final postId in postIds) {
          final postUrl = Uri.parse('${getBaseUrl()}/api/posts/$postId');
          try {
            final postResponse = await http.get(postUrl);
            if (postResponse.statusCode == 200) {
              posts.add(json.decode(postResponse.body));
            } else {
              print('❌ Erreur HTTP pour le post $postId : ${postResponse.statusCode}');
            }
          } catch (e) {
            print('❌ Erreur réseau pour le post $postId : $e');
          }
        }
        return posts;
      } else {
        throw Exception('Erreur lors de la récupération des données du producteur.');
      }
    } catch (e) {
      print('Erreur réseau : $e');
      return [];
    }
  }

  Future<void> _createPost(String content, String? eventId) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final postData = {
        'producer_id': widget.userId,
        'content': content,
        'target_id': eventId,
        'target_type': 'event',
        'media': _eventImageUrl != null ? [_eventImageUrl] : [],
      };

      final url = Uri.parse('${getBaseUrl()}/api/posts');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(postData),
      );

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post créé avec succès!')),
        );
        setState(() {
          _producerFuture = _fetchProducerData(widget.userId);
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: ${response.body}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur réseau: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _uploadMedia(bool isImage) async {
    final ImagePicker picker = ImagePicker();
    final XFile? mediaFile = await (isImage
        ? picker.pickImage(source: ImageSource.gallery)
        : picker.pickVideo(source: ImageSource.gallery));

    if (mediaFile != null) {
      String mediaPath;
      if (kIsWeb) {
        Uint8List bytes = await mediaFile.readAsBytes();
        mediaPath = "data:image/jpeg;base64,${base64Encode(bytes)}";
      } else {
        mediaPath = mediaFile.path;
      }

      setState(() {
        _eventImageUrl = mediaPath;
      });
    }
  }

  Future<List<Map<String, dynamic>>> _validateProfiles(List<String> ids) async {
    List<Map<String, dynamic>> validProfiles = [];

    for (final id in ids) {
      final profile = await _fetchProfileById(id);
      if (profile != null) {
        validProfiles.add(profile);
      }
    }

    return validProfiles;
  }

  Future<Map<String, dynamic>?> _fetchProfileById(String id) async {
    final userUrl = Uri.parse('${getBaseUrl()}/api/users/$id');
    final unifiedUrl = Uri.parse('${getBaseUrl()}/api/unified/$id');

    try {
      final userResponse = await http.get(userUrl);
      if (userResponse.statusCode == 200) {
        return json.decode(userResponse.body);
      }
    } catch (e) {
      print('Error fetching user profile: $e');
    }

    try {
      final unifiedResponse = await http.get(unifiedUrl);
      if (unifiedResponse.statusCode == 200) {
        return json.decode(unifiedResponse.body);
      }
    } catch (e) {
      print('Error fetching unified profile: $e');
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<Map<String, dynamic>>(
        future: _producerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.deepPurple));
          } else if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 60, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Erreur : ${snapshot.error}',
                      style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
                    onPressed: () {
                      setState(() {
                        _producerFuture = _fetchProducerData(widget.userId);
                      });
                    },
                    child: const Text('Réessayer'),
                  ),
                ],
              ),
            );
          }

          final data = snapshot.data!;
          
          return NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverAppBar(
                  expandedHeight: 220.0,
                  floating: false,
                  pinned: true,
                  backgroundColor: Colors.deepPurple,
                  flexibleSpace: FlexibleSpaceBar(
                    title: Text(
                      data['lieu'] ?? 'Mon profil producteur',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18.0,
                      ),
                    ),
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Background image with gradient overlay
                        ShaderMask(
                          shaderCallback: (rect) {
                            return LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.7),
                              ],
                            ).createShader(rect);
                          },
                          blendMode: BlendMode.darken,
                          child: Image.network(
                            data['photo'] ?? 'https://via.placeholder.com/500',
                            fit: BoxFit.cover,
                          ),
                        ),
                        
                        // Content positioned at the bottom
                        Positioned(
                          bottom: 60,
                          left: 16,
                          child: Row(
                            children: [
                              Container(
                                width: 70,
                                height: 70,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: ClipOval(
                                  child: Image.network(
                                    data['photo'] ?? 'https://via.placeholder.com/150',
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    data['name'] ?? 'Nom non spécifié',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    data['type'] ?? 'Loisir',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.white),
                      onPressed: () {
                        // TODO: Implémenter l'édition du profil
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Fonctionnalité d\'édition en développement')),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.settings, color: Colors.white),
                      onPressed: () {
                        // TODO: Implémenter les paramètres
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Fonctionnalité de paramètres en développement')),
                        );
                      },
                    ),
                  ],
                ),
                SliverPersistentHeader(
                  delegate: _SliverAppBarDelegate(
                    TabBar(
                      controller: _tabController,
                      labelColor: Colors.deepPurple,
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: Colors.deepPurple,
                      tabs: _tabs.map((String name) => Tab(text: name)).toList(),
                    ),
                  ),
                  pinned: true,
                ),
              ];
            },
            body: TabBarView(
              controller: _tabController,
              children: [
                _buildProfileTab(data),
                _buildEventsTab(data),
                _buildStatsTab(data),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateOptionsDialog(),
        backgroundColor: Colors.deepPurple,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildProfileTab(Map<String, dynamic> data) {
    final followersCount = (data['followers'] is Map && data['followers']?['count'] is int)
        ? data['followers']['count']
        : 0;
    final followingCount = (data['following'] is Map && data['following']?['count'] is int)
        ? data['following']['count']
        : 0;
    final interestedCount = (data['interestedUsers'] is Map && data['interestedUsers']?['count'] is int)
        ? data['interestedUsers']['count']
        : 0;
    final choicesCount = (data['choiceUsers'] is Map && data['choiceUsers']?['count'] is int)
        ? data['choiceUsers']['count']
        : 0;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Followers section
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.people, color: Colors.deepPurple),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Communauté',
                        style: TextStyle(
                          fontSize: 18, 
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildCommunityStats('Followers', followersCount, Icons.people, () {
                        _navigateToFollowersList(data, 'followers');
                      }),
                      _buildCommunityStats('Following', followingCount, Icons.person_add, () {
                        _navigateToFollowersList(data, 'following');
                      }),
                      _buildCommunityStats('Interested', interestedCount, Icons.emoji_objects, () {
                        _navigateToFollowersList(data, 'interested');
                      }),
                      _buildCommunityStats('Choices', choicesCount, Icons.check_circle, () {
                        _navigateToFollowersList(data, 'choices');
                      }),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Description section
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.info, color: Colors.blue),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'À propos',
                        style: TextStyle(
                          fontSize: 18, 
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    data['description'] ?? 'Description non spécifiée',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey[700],
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (data['adresse'] != null)
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.deepPurple, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            data['adresse'],
                            style: TextStyle(fontSize: 15, color: Colors.grey[700]),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 8),
                  if (data['website'] != null)
                    Row(
                      children: [
                        const Icon(Icons.link, color: Colors.deepPurple, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            data['website'],
                            style: TextStyle(fontSize: 15, color: Colors.grey[700]),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Posts section
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.post_add, color: Colors.orange),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Mes Posts',
                            style: TextStyle(
                              fontSize: 18, 
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle, color: Colors.deepPurple),
                        onPressed: () => _showCreatePostDialog(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  FutureBuilder<List<dynamic>>(
                    future: _fetchProducerPosts(widget.userId),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      } else if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}'));
                      }

                      final posts = snapshot.data ?? [];
                      if (posts.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Center(
                            child: Text(
                              'Aucun post pour le moment.\nCréez votre premier post!',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        );
                      }

                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: posts.length,
                        itemBuilder: (context, index) {
                          final post = posts[index];
                          return _buildPostCard(post);
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Map section
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.map, color: Colors.green),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Emplacement',
                        style: TextStyle(
                          fontSize: 18, 
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 200,
                    child: _buildMap(data['location']?['coordinates']),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommunityStats(String label, int count, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.deepPurple),
            const SizedBox(height: 4),
            Text(
              '$count',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToFollowersList(Map<String, dynamic> data, String type) async {
    List<String> userIds = [];
    String title = '';
    
    if (type == 'followers' && data['followers'] != null) {
      userIds = List<String>.from(data['followers']['users'] ?? []);
      title = 'Followers';
    } else if (type == 'following' && data['following'] != null) {
      userIds = List<String>.from(data['following']['users'] ?? []);
      title = 'Following';
    } else if (type == 'interested' && data['interestedUsers'] != null) {
      userIds = List<String>.from(data['interestedUsers']['users'] ?? []);
      title = 'Interested Users';
    } else if (type == 'choices' && data['choiceUsers'] != null) {
      userIds = List<String>.from(data['choiceUsers']['users'] ?? []);
      title = 'Users Who Chose';
    }
    
    if (userIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun utilisateur à afficher')),
      );
      return;
    }

    final profiles = await _validateProfiles(userIds);
    
    if (!mounted) return;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(
                    child: profiles.isNotEmpty
                        ? ListView.builder(
                            controller: scrollController,
                            itemCount: profiles.length,
                            itemBuilder: (context, index) {
                              final profile = profiles[index];
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundImage: NetworkImage(
                                    profile['photo'] ?? 'https://via.placeholder.com/150',
                                  ),
                                ),
                                title: Text(profile['name'] ?? 'Nom inconnu'),
                                subtitle: Text(profile['description'] ?? 'Pas de description'),
                              );
                            },
                          )
                        : const Center(
                            child: Text('Aucun profil disponible.'),
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

  Widget _buildPostCard(Map<String, dynamic> post) {
    final mediaUrls = post['media'] as List<dynamic>? ?? [];
    final interestedCount = post['interested']?.length ?? 0;
    final choicesCount = post['choices']?.length ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundImage: NetworkImage(
                    post['user_photo'] ?? 'https://via.placeholder.com/150',
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post['author_name'] ?? 'Nom non spécifié',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    if (post['created_at'] != null)
                      Text(
                        _formatDate(post['created_at']),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
                const Spacer(),
                // Edit button for my posts
                IconButton(
                  icon: const Icon(Icons.more_vert),
                  onPressed: () {
                    // Show options menu
                    showModalBottomSheet(
                      context: context,
                      builder: (context) {
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ListTile(
                              leading: const Icon(Icons.edit),
                              title: const Text('Modifier'),
                              onTap: () {
                                Navigator.pop(context);
                                // Edit post
                              },
                            ),
                            ListTile(
                              leading: const Icon(Icons.delete, color: Colors.red),
                              title: const Text('Supprimer', style: TextStyle(color: Colors.red)),
                              onTap: () {
                                Navigator.pop(context);
                                // Delete post
                              },
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Content
            Text(
              post['content'] ?? '',
              style: const TextStyle(fontSize: 16),
            ),
            
            if (post['target_id'] != null && post['target_type'] == 'event')
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.deepPurple.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.event, color: Colors.deepPurple),
                    const SizedBox(width: 8),
                    const Text(
                      'Événement associé',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        // Navigate to event details
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EventLeisureScreen(
                              eventId: post['target_id'],
                            ),
                          ),
                        );
                      },
                      child: const Text('Voir'),
                    ),
                  ],
                ),
              ),
            
            // Media
            if (mediaUrls.isNotEmpty)
              Container(
                height: 200,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  image: DecorationImage(
                    image: NetworkImage(mediaUrls[0]),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            
            // Interaction stats
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Row(
                children: [
                  const Icon(Icons.favorite, color: Colors.red, size: 18),
                  const SizedBox(width: 4),
                  Text('0'),
                  const SizedBox(width: 16),
                  Icon(Icons.emoji_objects, 
                    color: interestedCount > 0 ? Colors.orange : Colors.grey, 
                    size: 18
                  ),
                  const SizedBox(width: 4),
                  Text('$interestedCount'),
                  const SizedBox(width: 16),
                  Icon(Icons.check_circle, 
                    color: choicesCount > 0 ? Colors.green : Colors.grey, 
                    size: 18
                  ),
                  const SizedBox(width: 4),
                  Text('$choicesCount'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return '';
    
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('dd/MM/yyyy').format(date);
    } catch (e) {
      return dateString;
    }
  }

  Widget _buildEventsTab(Map<String, dynamic> data) {
    return FutureBuilder<List<dynamic>>(
      future: _fetchProducerEvents(widget.userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final events = snapshot.data ?? [];
        
        if (events.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.event_busy, size: 80, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'Aucun événement pour le moment',
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Créer un événement'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  onPressed: () => _showCreateEventDialog(),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: events.length,
          itemBuilder: (context, index) {
            final event = events[index];
            return _buildEventCard(event);
          },
        );
      },
    );
  }

  Widget _buildEventCard(Map<String, dynamic> event) {
    final String? imageUrl = event['image'];
    final String title = event['intitulé'] ?? 'Sans titre';
    final String date = event['prochaines_dates'] ?? 'Date non spécifiée';
    final String category = event['catégorie'] != null 
        ? event['catégorie'].toString().split('»').last.trim() 
        : 'Catégorie non spécifiée';
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EventLeisureScreen(
                eventId: event['_id'] ?? '',
                eventData: event,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image with gradient overlay
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
              child: Stack(
                children: [
                  // Event image
                  imageUrl != null && imageUrl.isNotEmpty
                      ? Image.network(
                          imageUrl,
                          height: 160,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            height: 160,
                            color: Colors.grey[300],
                            child: const Icon(Icons.broken_image, size: 40),
                          ),
                        )
                      : Container(
                          height: 160,
                          color: Colors.grey[300],
                          child: Icon(
                            Icons.event,
                            size: 50,
                            color: Colors.grey[500],
                          ),
                        ),
                  
                  // Gradient overlay
                  Positioned.fill(
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
                    ),
                  ),
                  
                  // Category badge
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        category,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  
                  // Event title at bottom
                  Positioned(
                    bottom: 12,
                    left: 12,
                    right: 12,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(
                                offset: Offset(0, 1),
                                blurRadius: 3,
                                color: Colors.black45,
                              ),
                            ],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.calendar_today,
                              color: Colors.white70,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              date,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Action buttons
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildActionButton(
                    icon: Icons.edit,
                    label: 'Modifier',
                    onTap: () {
                      // Edit event functionality
                      _showEditEventDialog(event);
                    },
                  ),
                  _buildActionButton(
                    icon: Icons.share,
                    label: 'Partager',
                    onTap: () {
                      // Share event functionality
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Fonctionnalité de partage en développement')),
                      );
                    },
                  ),
                  _buildActionButton(
                    icon: Icons.post_add,
                    label: 'Poster',
                    onTap: () {
                      // Create post about this event
                      _showCreatePostDialog(eventId: event['_id']);
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

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.deepPurple),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.deepPurple,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsTab(Map<String, dynamic> data) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.bar_chart, color: Colors.blue),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Vue d\'ensemble',
                        style: TextStyle(
                          fontSize: 18, 
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStatCard(
                        title: 'Événements',
                        value: data['nombre_evenements']?.toString() ?? '0',
                        icon: Icons.event,
                        color: Colors.purple,
                      ),
                      _buildStatCard(
                        title: 'Vues',
                        value: '0',
                        icon: Icons.visibility,
                        color: Colors.blue,
                      ),
                      _buildStatCard(
                        title: 'Engagement',
                        value: '0%',
                        icon: Icons.people,
                        color: Colors.green,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.trending_up, color: Colors.green),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Croissance des followers',
                        style: TextStyle(
                          fontSize: 18, 
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  SizedBox(
                    height: 200,
                    child: LineChart(
                      LineChartData(
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (value) {
                            return FlLine(
                              color: Colors.grey[200]!,
                              strokeWidth: 1,
                              dashArray: [5, 5],
                            );
                          },
                        ),
                        titlesData: FlTitlesData(
                          show: true,
                          rightTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          topTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'];
                                if (value.toInt() >= 0 && value.toInt() < months.length) {
                                  return Text(months[value.toInt()]);
                                }
                                return const Text('');
                              },
                            ),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: [
                              const FlSpot(0, 3),
                              const FlSpot(1, 4),
                              const FlSpot(2, 3.5),
                              const FlSpot(3, 5),
                              const FlSpot(4, 6),
                              const FlSpot(5, 8),
                            ],
                            isCurved: true,
                            color: Colors.green,
                            barWidth: 3,
                            isStrokeCapRound: true,
                            dotData: FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              color: Colors.green.withOpacity(0.1),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.equalizer, color: Colors.orange),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Performance des événements',
                        style: TextStyle(
                          fontSize: 18, 
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  SizedBox(
                    height: 200,
                    child: BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: 10,
                        barGroups: [
                          _makeBarGroup(0, 5, Colors.blue),
                          _makeBarGroup(1, 8, Colors.blue),
                          _makeBarGroup(2, 6, Colors.blue),
                          _makeBarGroup(3, 9, Colors.blue),
                          _makeBarGroup(4, 7, Colors.blue),
                        ],
                        gridData: FlGridData(
                          show: true,
                          drawHorizontalLine: true,
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (value) {
                            return FlLine(
                              color: Colors.grey[200]!,
                              strokeWidth: 1,
                              dashArray: [5, 5],
                            );
                          },
                        ),
                        titlesData: FlTitlesData(
                          show: true,
                          rightTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          topTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                const events = ['Event 1', 'Event 2', 'Event 3', 'Event 4', 'Event 5'];
                                if (value.toInt() >= 0 && value.toInt() < events.length) {
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Text(
                                      events[value.toInt()],
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black54,
                                      ),
                                    ),
                                  );
                                }
                                return const Text('');
                              },
                            ),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.purple.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.pie_chart, color: Colors.purple),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Abonnement Premium',
                        style: TextStyle(
                          fontSize: 18, 
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.purple.shade100, Colors.purple.shade50],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: const BoxDecoration(
                            color: Colors.purple,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.star,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Passez au premium',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.purple,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Obtenez plus de visibilité et d\'outils analytiques pour développer votre audience.',
                                style: TextStyle(
                                  color: Colors.grey[700],
                                ),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: () {
                                  // Upgrade to premium
                                  _showPremiumOptions();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.purple,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                                child: const Text('Découvrir les offres'),
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
        ],
      ),
    );
  }

  void _showPremiumOptions() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              minChildSize: 0.5,
              maxChildSize: 0.9,
              builder: (context, scrollController) {
                return Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 10),
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            const Text(
                              'Choisir un abonnement Premium',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Débloquez toutes les fonctionnalités et développez votre visibilité',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          children: [
                            _buildPlanCard(
                              title: 'Bronze',
                              price: 5,
                              features: [
                                'Boost de visibilité',
                                'Statistiques de base',
                                'Support prioritaire',
                              ],
                              isRecommended: false,
                              onSubscribe: () => _subscribe(context, 'bronze', 5),
                            ),
                            const SizedBox(height: 16),
                            _buildPlanCard(
                              title: 'Silver',
                              price: 10,
                              features: [
                                'Tout ce qui est dans Bronze',
                                'Analytics avancés',
                                'Événements mis en avant',
                                'Personnalisation accrue',
                              ],
                              isRecommended: true,
                              onSubscribe: () => _subscribe(context, 'silver', 10),
                            ),
                            const SizedBox(height: 16),
                            _buildPlanCard(
                              title: 'Gold',
                              price: 15,
                              features: [
                                'Tout ce qui est dans Silver',
                                'IA Analytics',
                                'Visibilité maximale',
                                'Accès exclusif à de nouvelles fonctionnalités',
                                'Support dédié',
                              ],
                              isRecommended: false,
                              onSubscribe: () => _subscribe(context, 'gold', 15),
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
      },
    );
  }

  Widget _buildPlanCard({
    required String title,
    required int price,
    required List<String> features,
    required bool isRecommended,
    required VoidCallback onSubscribe,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: BoxDecoration(
            color: isRecommended ? Colors.purple.withOpacity(0.05) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isRecommended ? Colors.purple : Colors.grey[300]!,
              width: isRecommended ? 2 : 1,
            ),
            boxShadow: isRecommended
                ? [
                    BoxShadow(
                      color: Colors.purple.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : null,
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isRecommended ? Colors.purple : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$price€',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: isRecommended ? Colors.purple : Colors.black,
                    ),
                  ),
                  const Text(
                    '/mois',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              ...features.map((feature) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: isRecommended ? Colors.purple : Colors.green,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        feature,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              )),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onSubscribe,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isRecommended ? Colors.purple : Colors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text('S\'abonner'),
                ),
              ),
            ],
          ),
        ),
        if (isRecommended)
          Positioned(
            top: -12,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.purple,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Recommandé',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.25,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  BarChartGroupData _makeBarGroup(int x, double y, Color color) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          width: 12,
          color: color,
          gradient: LinearGradient(
            colors: [color.withOpacity(0.7), color],
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
          ),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(4),
          ),
        ),
      ],
    );
  }

  Widget _buildMap(List<dynamic>? coordinates) {
    try {
      if (coordinates == null || coordinates.length < 2) {
        return Container(
          height: 200,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Center(
            child: Text('Coordonnées GPS non disponibles'),
          ),
        );
      }
      
      if (coordinates[0] == null || coordinates[1] == null || 
          !(coordinates[0] is num) || !(coordinates[1] is num)) {
        return Container(
          height: 200,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Center(
            child: Text('Coordonnées invalides'),
          ),
        );
      }
      
      final double lon = coordinates[0].toDouble();
      final double lat = coordinates[1].toDouble();
      
      if (lat < -90 || lat > 90 || lon < -180 || lon > 180) {
        return Container(
          height: 200,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Center(
            child: Text('Coordonnées hors limites'),
          ),
        );
      }

      final latLng = LatLng(lat, lon);

      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: GoogleMap(
          initialCameraPosition: CameraPosition(target: latLng, zoom: 15),
          markers: {
            Marker(
              markerId: const MarkerId('producer_location'),
              position: latLng,
            ),
          },
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          myLocationButtonEnabled: false,
        ),
      );
    } catch (e) {
      print('❌ Erreur lors du rendu de la carte: $e');
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text('Erreur lors du chargement de la carte'),
        ),
      );
    }
  }

  void _showCreateOptionsDialog() {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Que souhaitez-vous créer ?'),
        children: [
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(context);
              _showCreatePostDialog();
            },
            child: const Row(
              children: [
                Icon(Icons.post_add, color: Colors.deepPurple),
                SizedBox(width: 10),
                Text('Nouveau post'),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(context);
              _showCreateEventDialog();
            },
            child: const Row(
              children: [
                Icon(Icons.event, color: Colors.deepPurple),
                SizedBox(width: 10),
                Text('Nouvel événement'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showCreatePostDialog({String? eventId}) {
    final contentController = TextEditingController();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              builder: (context, scrollController) {
                return Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 10),
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Créer un post',
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
                      Expanded(
                        child: ListView(
                          controller: scrollController,
                          padding: const EdgeInsets.all(16),
                          children: [
                            // Content field
                            TextField(
                              controller: contentController,
                              maxLines: 5,
                              decoration: const InputDecoration(
                                hintText: 'Partagez quelque chose avec votre audience...',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            // Event link (if provided)
                            if (eventId != null)
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.deepPurple.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.deepPurple.withOpacity(0.3)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.event, color: Colors.deepPurple),
                                    const SizedBox(width: 8),
                                    const Expanded(
                                      child: Text(
                                        'Ce post sera lié à l\'événement sélectionné',
                                        style: TextStyle(
                                          color: Colors.deepPurple,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.info_outline, color: Colors.deepPurple),
                                      onPressed: () {
                                        // Show info about linking to event
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Vos followers pourront accéder directement à cet événement depuis votre post.'),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            
                            const SizedBox(height: 16),
                            
                            // Media preview
                            if (_eventImageUrl != null)
                              Container(
                                height: 200,
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  image: DecorationImage(
                                    image: NetworkImage(_eventImageUrl!),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            
                            // Media upload buttons
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.image),
                                  label: const Text('Ajouter une image'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.deepPurple.withOpacity(0.8),
                                  ),
                                  onPressed: () async {
                                    await _uploadMedia(true);
                                    if (mounted) setState(() {});
                                  },
                                ),
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.videocam),
                                  label: const Text('Ajouter une vidéo'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.deepPurple.withOpacity(0.8),
                                  ),
                                  onPressed: () async {
                                    await _uploadMedia(false);
                                    if (mounted) setState(() {});
                                  },
                                ),
                              ],
                            ),
                            
                            const SizedBox(height: 24),
                            
                            // Post button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () {
                                  if (contentController.text.trim().isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Veuillez ajouter du contenu à votre post')),
                                    );
                                    return;
                                  }
                                  Navigator.pop(context);
                                  _createPost(contentController.text, eventId);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.deepPurple,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                child: const Text(
                                  'Publier',
                                  style: TextStyle(fontSize: 16),
                                ),
                              ),
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
      },
    );
  }

  void _showCreateEventDialog() {
    _eventTitleController.clear();
    _eventDescriptionController.clear();
    _eventCategoryController.clear();
    _eventImageUrl = null;
    _eventStartDate = null;
    _eventEndDate = null;

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
              builder: (context, scrollController) {
                return Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 10),
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Créer un événement',
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
                      Expanded(
                        child: ListView(
                          controller: scrollController,
                          padding: const EdgeInsets.all(16),
                          children: [
                            // Title field
                            TextField(
                              controller: _eventTitleController,
                              decoration: const InputDecoration(
                                labelText: 'Titre de l\'événement',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            // Description field
                            TextField(
                              controller: _eventDescriptionController,
                              maxLines: 4,
                              decoration: const InputDecoration(
                                labelText: 'Description',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            // Category field
                            TextField(
                              controller: _eventCategoryController,
                              decoration: const InputDecoration(
                                labelText: 'Catégorie',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            // Date pickers
                            Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: () async {
                                      final pickedDate = await showDatePicker(
                                        context: context,
                                        initialDate: DateTime.now(),
                                        firstDate: DateTime.now(),
                                        lastDate: DateTime.now().add(const Duration(days: 365)),
                                      );
                                      if (pickedDate != null) {
                                        setState(() {
                                          _eventStartDate = pickedDate;
                                        });
                                      }
                                    },
                                    child: InputDecorator(
                                      decoration: const InputDecoration(
                                        labelText: 'Date de début',
                                        border: OutlineInputBorder(),
                                      ),
                                      child: Text(
                                        _eventStartDate != null
                                            ? DateFormat('dd/MM/yyyy').format(_eventStartDate!)
                                            : 'Sélectionner',
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: InkWell(
                                    onTap: () async {
                                      final pickedDate = await showDatePicker(
                                        context: context,
                                        initialDate: _eventStartDate ?? DateTime.now(),
                                        firstDate: _eventStartDate ?? DateTime.now(),
                                        lastDate: DateTime.now().add(const Duration(days: 365)),
                                      );
                                      if (pickedDate != null) {
                                        setState(() {
                                          _eventEndDate = pickedDate;
                                        });
                                      }
                                    },
                                    child: InputDecorator(
                                      decoration: const InputDecoration(
                                        labelText: 'Date de fin',
                                        border: OutlineInputBorder(),
                                      ),
                                      child: Text(
                                        _eventEndDate != null
                                            ? DateFormat('dd/MM/yyyy').format(_eventEndDate!)
                                            : 'Sélectionner',
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            
                            // Image preview
                            if (_eventImageUrl != null)
                              Container(
                                height: 200,
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  image: DecorationImage(
                                    image: NetworkImage(_eventImageUrl!),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            
                            // Image upload button
                            ElevatedButton.icon(
                              icon: const Icon(Icons.image),
                              label: const Text('Ajouter une image'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.deepPurple,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(double.infinity, 50),
                              ),
                              onPressed: () async {
                                await _uploadMedia(true);
                                if (mounted) setState(() {});
                              },
                            ),
                            
                            const SizedBox(height: 24),
                            
                            // Create event button
                            ElevatedButton(
                              onPressed: () {
                                if (_eventTitleController.text.isEmpty || 
                                    _eventDescriptionController.text.isEmpty || 
                                    _eventCategoryController.text.isEmpty ||
                                    _eventStartDate == null ||
                                    _eventEndDate == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Veuillez remplir tous les champs')),
                                  );
                                  return;
                                }
                                
                                // Create event logic
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Événement créé avec succès!')),
                                );
                                
                                // Refresh events
                                setState(() {
                                  _producerFuture = _fetchProducerData(widget.userId);
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.deepPurple,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(double.infinity, 50),
                              ),
                              child: const Text(
                                'Créer l\'événement',
                                style: TextStyle(fontSize: 16),
                              ),
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
      },
    );
  }

  void _showEditEventDialog(Map<String, dynamic> event) {
    _eventTitleController.text = event['intitulé'] ?? '';
    _eventDescriptionController.text = event['détail'] ?? '';
    _eventCategoryController.text = event['catégorie'] ?? '';
    _eventImageUrl = event['image'];
    
    try {
      if (event['date_debut'] != null) {
        _eventStartDate = DateTime.parse(event['date_debut']);
      }
      if (event['date_fin'] != null) {
        _eventEndDate = DateTime.parse(event['date_fin']);
      }
    } catch (e) {
      print('Error parsing dates: $e');
    }

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
              builder: (context, scrollController) {
                return Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 10),
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Modifier l\'événement',
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
                      Expanded(
                        child: ListView(
                          controller: scrollController,
                          padding: const EdgeInsets.all(16),
                          children: [
                            // Same fields as create event, but pre-filled
                            TextField(
                              controller: _eventTitleController,
                              decoration: const InputDecoration(
                                labelText: 'Titre de l\'événement',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            TextField(
                              controller: _eventDescriptionController,
                              maxLines: 4,
                              decoration: const InputDecoration(
                                labelText: 'Description',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            TextField(
                              controller: _eventCategoryController,
                              decoration: const InputDecoration(
                                labelText: 'Catégorie',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: () async {
                                      final pickedDate = await showDatePicker(
                                        context: context,
                                        initialDate: _eventStartDate ?? DateTime.now(),
                                        firstDate: DateTime.now(),
                                        lastDate: DateTime.now().add(const Duration(days: 365)),
                                      );
                                      if (pickedDate != null) {
                                        setState(() {
                                          _eventStartDate = pickedDate;
                                        });
                                      }
                                    },
                                    child: InputDecorator(
                                      decoration: const InputDecoration(
                                        labelText: 'Date de début',
                                        border: OutlineInputBorder(),
                                      ),
                                      child: Text(
                                        _eventStartDate != null
                                            ? DateFormat('dd/MM/yyyy').format(_eventStartDate!)
                                            : 'Sélectionner',
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: InkWell(
                                    onTap: () async {
                                      final pickedDate = await showDatePicker(
                                        context: context,
                                        initialDate: _eventEndDate ?? _eventStartDate ?? DateTime.now(),
                                        firstDate: _eventStartDate ?? DateTime.now(),
                                        lastDate: DateTime.now().add(const Duration(days: 365)),
                                      );
                                      if (pickedDate != null) {
                                        setState(() {
                                          _eventEndDate = pickedDate;
                                        });
                                      }
                                    },
                                    child: InputDecorator(
                                      decoration: const InputDecoration(
                                        labelText: 'Date de fin',
                                        border: OutlineInputBorder(),
                                      ),
                                      child: Text(
                                        _eventEndDate != null
                                            ? DateFormat('dd/MM/yyyy').format(_eventEndDate!)
                                            : 'Sélectionner',
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            
                            if (_eventImageUrl != null)
                              Container(
                                height: 200,
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  image: DecorationImage(
                                    image: NetworkImage(_eventImageUrl!),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            
                            ElevatedButton.icon(
                              icon: const Icon(Icons.image),
                              label: const Text('Modifier l\'image'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.deepPurple,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(double.infinity, 50),
                              ),
                              onPressed: () async {
                                await _uploadMedia(true);
                                if (mounted) setState(() {});
                              },
                            ),
                            
                            const SizedBox(height: 24),
                            
                            ElevatedButton(
                              onPressed: () {
                                if (_eventTitleController.text.isEmpty || 
                                    _eventDescriptionController.text.isEmpty || 
                                    _eventCategoryController.text.isEmpty ||
                                    _eventStartDate == null ||
                                    _eventEndDate == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Veuillez remplir tous les champs')),
                                  );
                                  return;
                                }
                                
                                // Update event logic here
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Événement mis à jour avec succès!')),
                                );
                                
                                // Refresh events
                                setState(() {
                                  _producerFuture = _fetchProducerData(widget.userId);
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.deepPurple,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(double.infinity, 50),
                              ),
                              child: const Text(
                                'Mettre à jour l\'événement',
                                style: TextStyle(fontSize: 16),
                              ),
                            ),
                            
                            const SizedBox(height: 16),
                            
                            OutlinedButton(
                              onPressed: () {
                                // Show delete confirmation
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Supprimer l\'événement ?'),
                                    content: const Text('Cette action est irréversible. Souhaitez-vous vraiment supprimer cet événement ?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('Annuler'),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          Navigator.pop(context); // Close dialog
                                          Navigator.pop(context); // Close edit sheet
                                          
                                          // Delete event logic
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Événement supprimé avec succès!')),
                                          );
                                          
                                          // Refresh events
                                          setState(() {
                                            _producerFuture = _fetchProducerData(widget.userId);
                                          });
                                        },
                                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                                        child: const Text('Supprimer'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: const BorderSide(color: Colors.red),
                                minimumSize: const Size(double.infinity, 50),
                              ),
                              child: const Text('Supprimer l\'événement'),
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
      },
    );
  }

  void _subscribe(BuildContext context, String plan, int price) async {
    setState(() {
      _isLoading = true;
    });

    try {
      bool success = await PaymentService.processPayment(context, plan, widget.userId);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Abonnement réussi !")),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Erreur lors du paiement. Réessayez.")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur : $e")),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);

  final TabBar _tabBar;

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
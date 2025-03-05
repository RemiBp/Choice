import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'producer_screen.dart'; // Pour les détails des restaurants
import 'producerLeisure_screen.dart'; // Pour les producteurs de loisirs
import 'eventLeisure_screen.dart'; // Pour les événements
import 'messaging_screen.dart';
import 'utils.dart';

class ProfileScreen extends StatefulWidget {
  final String userId;

  const ProfileScreen({Key? key, required this.userId}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<Map<String, dynamic>> _userFuture;
  late Future<List<dynamic>> _postsFuture;

  @override
  void initState() {
    super.initState();
    _userFuture = _fetchUserProfile(widget.userId);
    _postsFuture = _fetchUserPosts(widget.userId);
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
  Future<List<dynamic>> _fetchUserPosts(String userId) async {
    final user = await _fetchUserProfile(userId);
    final postIds = user['posts'] as List<dynamic>? ?? [];

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


  Future<void> _followUser(String targetId) async {
    // Debugging : affichez le followerId avant d'envoyer la requête
    print('🟢 Follower ID (connecté) : ${widget.userId}');
    print('🔵 Target ID (profil visité) : $targetId');

    final url = Uri.parse('${getBaseUrl()}/api/linked/follow');
    final body = {
      'followerId': widget.userId, // Utilisateur connecté
      'targetId': targetId, // Profil visité
    };

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('✅ Suivi avec succès.');
      } else {
        print('❌ Erreur lors du suivi : ${response.body}');
      }
    } catch (e) {
      print('❌ Erreur réseau : $e');
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        title: const Text('Profil', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _userFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Erreur : ${snapshot.error}'));
          }

          final user = snapshot.data!;
          return DefaultTabController(
            length: 3, // Trois tabs: Posts, Interests, Choices
            child: Column(
              children: [
                _buildProfileHeader(user),
                const Divider(thickness: 1),
                _buildStatsSection(user),
                const Divider(thickness: 1),
                _buildLikedTags(user),
                const Divider(thickness: 1),
                // Barre de navigation avec les tabs
                TabBar(
                  tabs: const [
                    Tab(icon: Icon(Icons.grid_on), text: 'Posts'),
                    Tab(icon: Icon(Icons.star_border), text: 'Intérêts'),
                    Tab(icon: Icon(Icons.check_circle_outline), text: 'Choix'),
                  ],
                  indicatorColor: Colors.blue,
                  labelColor: Colors.blue,
                  unselectedLabelColor: Colors.grey,
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      // Tab 1: Posts
                      _buildPostsTab(),
                      // Tab 2: Interests
                      _buildInterestsTab(user),
                      // Tab 3: Choices
                      _buildChoicesTab(user),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileHeader(Map<String, dynamic> user) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundImage: NetworkImage(
              user['photo_url'] ?? 'https://via.placeholder.com/150',
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user['name'] ?? 'Nom non spécifié',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  user['bio'] ?? 'Bio non spécifiée',
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Text(
                  user['is_star'] ? '🌟 Star Utilisateur' : '',
                  style: const TextStyle(color: Colors.orange),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection(Map<String, dynamic> user) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildFollowButton(user),
          // Remplacer "Influence" par le bouton "Écrire"
          _buildMessageButton(user),
          _buildStatItem('Interactions', user['interaction_metrics']['total_interactions'].toString()),
        ],
      ),
    );
  }

  Widget _buildFollowButton(Map<String, dynamic> user) {
    // Vérifie si l'utilisateur suit déjà le profil
    bool _isFollowing = user['followers'] != null && user['followers'].contains(widget.userId);

    return ElevatedButton(
      onPressed: _isFollowing
          ? null // Désactiver le bouton si déjà suivi
          : () async {
              await _followUser(user['_id']); // Appel API pour suivre
              setState(() {
                _isFollowing = true; // Met à jour l'état local
              });
            },
      style: ElevatedButton.styleFrom(
        backgroundColor: _isFollowing ? Colors.green : Colors.blueAccent, // Différencier les couleurs
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
      ),
      child: Text(
        _isFollowing ? 'Suivi' : 'Suivre', // Texte dynamique
        style: const TextStyle(
          fontSize: 16,
          color: Colors.white, // Couleur du texte pour contraste
        ),
      ),
    );
  }



  // Remplacer "Influence" par un bouton "Écrire"
  Widget _buildMessageButton(Map<String, dynamic> user) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      color: Colors.white,
      child: ElevatedButton(
        onPressed: () {
          // Démarrer une conversation avec cet utilisateur
          _startConversation(user['_id']);
        },
        child: const Text('Écrire', style: TextStyle(fontSize: 16)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blueAccent, // Modifier "primary" par "backgroundColor"
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 40),
        ),
      ),
    );
  }



  Widget _buildStatItem(String title, String count) {
    return Column(
      children: [
        Text(
          count,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: const TextStyle(fontSize: 14, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildLikedTags(Map<String, dynamic> user) {
    final tags = user['liked_tags'] ?? [];
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: tags.map<Widget>((tag) {
          return Chip(
            label: Text(tag),
            backgroundColor: Colors.blueAccent.withOpacity(0.2),
            labelStyle: const TextStyle(color: Colors.blueAccent),
          );
        }).toList(),
      ),
    );
  }

  // Construit la vue des posts de l'utilisateur (TabView 1)
  Widget _buildPostsTab() {
    return FutureBuilder<List<dynamic>>(
      future: _postsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Erreur : ${snapshot.error}'));
        }

        final posts = snapshot.data!;
        if (posts.isEmpty) {
          return const Center(child: Text('Aucun post trouvé.'));
        }

        return ListView.builder(
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final post = posts[index];
            return _buildPostCard(post);
          },
        );
      },
    );
  }
  // Construit la grille d'intérêts Instagram-style (TabView 2)
  Widget _buildInterestsTab(Map<String, dynamic> user) {
    final interests = user['interests'] as List<dynamic>? ?? [];
    
    if (interests.isEmpty) {
      return const Center(child: Text('Aucun intérêt trouvé.'));
    }
    
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchInterestsDetails(interests),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Erreur : ${snapshot.error}'));
        }
        
        final interestsDetails = snapshot.data!;
        
        return GridView.builder(
          padding: const EdgeInsets.all(2),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 1.0,
            mainAxisSpacing: 2,
            crossAxisSpacing: 2,
          ),
          itemCount: interestsDetails.length,
          itemBuilder: (context, index) {
            final interest = interestsDetails[index];
            return _buildInterestItem(interest);
          },
        );
      },
    );
  }
  
  // Construit la grille de choix Instagram-style (TabView 3)
  Widget _buildChoicesTab(Map<String, dynamic> user) {
    final choices = user['choices'] as List<dynamic>? ?? [];
    
    if (choices.isEmpty) {
      return const Center(child: Text('Aucun choix trouvé.'));
    }
    
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchChoicesDetails(choices),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Erreur : ${snapshot.error}'));
        }
        
        final choicesDetails = snapshot.data!;
        
        return GridView.builder(
          padding: const EdgeInsets.all(2),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 1.0,
            mainAxisSpacing: 2,
            crossAxisSpacing: 2,
          ),
          itemCount: choicesDetails.length,
          itemBuilder: (context, index) {
            final choice = choicesDetails[index];
            return _buildChoiceItem(choice);
          },
        );
      },
    );
  }
  
  // Récupère les détails de chaque intérêt
  Future<List<Map<String, dynamic>>> _fetchInterestsDetails(List<dynamic> interestIds) async {
    final List<Map<String, dynamic>> interestsDetails = [];
    
    for (final id in interestIds) {
      try {
        // D'abord essayer comme un producer standard
        var data = await _fetchItemDetails(id, 'producers');
        if (data != null) {
          data['_type'] = 'restaurant';
          interestsDetails.add(data);
          continue;
        }
        
        // Ensuite essayer comme un leisure producer
        data = await _fetchItemDetails(id, 'leisureProducers');
        if (data != null) {
          data['_type'] = 'leisureProducer';
          interestsDetails.add(data);
          continue;
        }
        
        // Enfin essayer comme un événement
        data = await _fetchItemDetails(id, 'events');
        if (data != null) {
          data['_type'] = 'event';
          interestsDetails.add(data);
          continue;
        }
        
        print('⚠️ Impossible de trouver les détails pour l\'intérêt: $id');
      } catch (e) {
        print('❌ Erreur lors de la récupération des détails de l\'intérêt $id: $e');
      }
    }
    
    return interestsDetails;
  }
  
  // Récupère les détails de chaque choix
  Future<List<Map<String, dynamic>>> _fetchChoicesDetails(List<dynamic> choiceIds) async {
    final List<Map<String, dynamic>> choicesDetails = [];
    
    for (final id in choiceIds) {
      try {
        // D'abord essayer comme un producer standard
        var data = await _fetchItemDetails(id, 'producers');
        if (data != null) {
          data['_type'] = 'restaurant';
          choicesDetails.add(data);
          continue;
        }
        
        // Ensuite essayer comme un leisure producer
        data = await _fetchItemDetails(id, 'leisureProducers');
        if (data != null) {
          data['_type'] = 'leisureProducer';
          choicesDetails.add(data);
          continue;
        }
        
        // Enfin essayer comme un événement
        data = await _fetchItemDetails(id, 'events');
        if (data != null) {
          data['_type'] = 'event';
          choicesDetails.add(data);
          continue;
        }
        
        print('⚠️ Impossible de trouver les détails pour le choix: $id');
      } catch (e) {
        print('❌ Erreur lors de la récupération des détails du choix $id: $e');
      }
    }
    
    return choicesDetails;
  }
  
  // Récupère les détails d'un item (utilisé pour les intérêts et les choix)
  Future<Map<String, dynamic>?> _fetchItemDetails(String id, String endpoint) async {
    final url = Uri.parse('${getBaseUrl()}/api/$endpoint/$id');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      print('❌ Erreur réseau pour l\'endpoint $endpoint: $e');
    }
    return null;
  }
  
  // Construit un élément d'intérêt dans la grille
  Widget _buildInterestItem(Map<String, dynamic> interest) {
    // Extraire intelligemment le nom et l'image selon le type d'item
    final String name = _extractItemName(interest);
    final String imageUrl = _extractItemImage(interest);
    final String type = interest['_type'] ?? 'unknown';
    
    return GestureDetector(
      onTap: () => _navigateToDetails(interest['_id'], type),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Image de fond
          Image.network(
            imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: Colors.grey[300],
                child: const Icon(Icons.broken_image, size: 50, color: Colors.grey),
              );
            },
          ),
          // Overlay foncé pour rendre le texte lisible
          Container(
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
          // Indicateur d'intérêt
          const Positioned(
            top: 5,
            right: 5,
            child: Icon(
              Icons.star,
              color: Colors.amber,
              size: 18,
            ),
          ),
          // Nom en bas
          Positioned(
            bottom: 5,
            left: 5,
            right: 5,
            child: Text(
              name,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
  
  // Construit un élément de choix dans la grille
  Widget _buildChoiceItem(Map<String, dynamic> choice) {
    // Extraire intelligemment le nom et l'image selon le type d'item
    final String name = _extractItemName(choice);
    final String imageUrl = _extractItemImage(choice);
    final String type = choice['_type'] ?? 'unknown';
    
    return GestureDetector(
      onTap: () => _navigateToDetails(choice['_id'], type),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Image de fond
          Image.network(
            imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: Colors.grey[300],
                child: const Icon(Icons.broken_image, size: 50, color: Colors.grey),
              );
            },
          ),
          // Overlay foncé pour rendre le texte lisible
          Container(
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
          // Indicateur de choix
          const Positioned(
            top: 5,
            right: 5,
            child: Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 18,
            ),
          ),
          // Nom en bas
          Positioned(
            bottom: 5,
            left: 5,
            right: 5,
            child: Text(
              name,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
  
  // Extrait le nom d'un item selon son type
  String _extractItemName(Map<String, dynamic> item) {
    final type = item['_type'];
    
    if (type == 'leisureProducer') {
      return item['nom'] ?? 
             item['intitulé'] ?? 
             item['title'] ?? 
             item['name'] ?? 
             'Lieu culturel';
    } else if (type == 'restaurant') {
      return item['name'] ?? 
             item['nom'] ?? 
             item['établissement'] ?? 
             'Restaurant';
    } else if (type == 'event') {
      return item['title'] ?? 
             item['nom'] ?? 
             item['name'] ?? 
             'Événement';
    }
    
    return item['name'] ?? 'Nom non disponible';
  }
  
  // Extrait l'image d'un item selon son type
  String _extractItemImage(Map<String, dynamic> item) {
    return item['photo'] ?? 
           item['photo_url'] ?? 
           item['image'] ?? 
           item['banner'] ?? 
           'https://via.placeholder.com/150';
  }
  Widget _buildPostCard(Map<String, dynamic> post) {
    final mediaUrls = post['media'] as List<dynamic>? ?? [];
    return GestureDetector(
      onTap: () => _navigateToPostDetail(post),
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        elevation: 5,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundImage: NetworkImage(
                      post['photo_url'] ?? 'https://via.placeholder.com/150',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    post['author_name'] ?? 'Nom non spécifié',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                post['title'] ?? 'Titre non spécifié',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(post['content'] ?? 'Contenu non disponible'),
              const SizedBox(height: 10),
              if (mediaUrls.isNotEmpty)
                SizedBox(
                  height: 200,
                  child: PageView(
                    children: mediaUrls.map((url) {
                      return Image.network(url, fit: BoxFit.cover, width: double.infinity);
                    }).toList(),
                  ),
                ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.thumb_up_alt_outlined),
                    onPressed: () {
                      // Fonctionnalité Like (à implémenter)
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.comment_outlined),
                    onPressed: () => _navigateToPostDetail(post),
                  ),
                  IconButton(
                    icon: const Icon(Icons.share),
                    onPressed: () {
                      // Fonctionnalité Partage (à implémenter)
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
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

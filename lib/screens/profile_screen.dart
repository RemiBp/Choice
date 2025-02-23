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
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    _buildProfileHeader(user),
                    const Divider(thickness: 1),
                    _buildStatsSection(user),
                    const Divider(thickness: 1),
                    _buildLikedTags(user),
                    const Divider(thickness: 1),
                  ],
                ),
              ),
              _buildPostsSection(),
            ],
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

  Widget _buildPostsSection() {
    return FutureBuilder<List<dynamic>>(
      future: _postsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SliverToBoxAdapter(
            child: Center(child: CircularProgressIndicator()),
          );
        } else if (snapshot.hasError) {
          return SliverToBoxAdapter(
            child: Center(child: Text('Erreur : ${snapshot.error}')),
          );
        }

        final posts = snapshot.data!;
        if (posts.isEmpty) {
          return const SliverToBoxAdapter(
            child: Center(child: Text('Aucun post trouvé.')),
          );
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final post = posts[index];
              return _buildPostCard(post);
            },
            childCount: posts.length,
          ),
        );
      },
    );
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

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'producer_screen.dart'; // Pour les détails des restaurants
import 'producerLeisure_screen.dart'; // Pour les producteurs de loisirs
import 'eventLeisure_screen.dart'; // Pour les événements
import 'messaging_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'utils.dart';
import 'dart:io' if (dart.library.io) 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;

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
        backgroundColor: Colors.grey[200],
        appBar: AppBar(
          title: const Text(
            'Profil',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0.5,
          actions: [
            IconButton(
              icon: const Icon(Icons.add_a_photo),
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
        body: FutureBuilder<Map<String, dynamic>>(
          future: _userFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text('Erreur : ${snapshot.error}'));
            }

            final user = snapshot.data!;

            return Column(
              children: [
                // Profil utilisateur
                _buildProfileHeader(user),
                const Divider(thickness: 1),
                _buildStatsSection(user),
                const Divider(thickness: 1),
                _buildLikedTags(user),
                const Divider(thickness: 1),

                // Bandeau des onglets sous le profil
                Container(
                  color: Colors.white,
                  child: const TabBar(
                    indicatorColor: Colors.blue,
                    labelColor: Colors.black,
                    unselectedLabelColor: Colors.grey,
                    tabs: [
                      Tab(text: 'Posts', icon: Icon(Icons.article_outlined)),
                      Tab(text: 'Choices', icon: Icon(Icons.check_circle_outline)),
                      Tab(text: 'Interests', icon: Icon(Icons.favorite_border)),
                    ],
                  ),
                ),

                // Contenu des onglets
                Expanded(
                  child: TabBarView(
                    children: [
                      // Section Posts
                      _buildPostsSection(),

                      // Section Choices
                      _buildChoicesSection(user),

                      // Section Interests
                      _buildInterestsSection(user),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }


  Widget _buildProfileHeader(Map<String, dynamic> user) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12), // Réduction du padding
      color: Colors.white,
      child: Row(
        children: [
          CircleAvatar(
            radius: 40, // Réduction de la taille de l'avatar
            backgroundImage: NetworkImage(
              user['photo_url'] ?? 'https://via.placeholder.com/150',
            ),
          ),
          const SizedBox(width: 8), // Réduction de l'espacement horizontal
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user['name'] ?? 'Nom non spécifié',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), // Réduction de la taille du texte
                ),
                const SizedBox(height: 2), // Réduction de l'espacement
                Text(
                  user['bio'] ?? 'Bio non spécifiée',
                  style: const TextStyle(fontSize: 12, color: Colors.grey), // Taille réduite
                ),
                const SizedBox(height: 4), // Réduction de l'espacement
                if (user['is_star'])
                  const Text(
                    '🌟 Star Utilisateur',
                    style: TextStyle(fontSize: 12, color: Colors.orange), // Taille ajustée
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
      padding: const EdgeInsets.symmetric(vertical: 8), // Réduit le padding vertical
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatItem('Abonnés', user['followers_count'].toString()),
          _buildMessageButton(user),
          _buildStatItem('Interactions', user['interaction_metrics']['total_interactions'].toString()),
        ],
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
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), // Taille réduite
        ),
        const SizedBox(height: 2), // Réduit l'espacement
        Text(
          title,
          style: const TextStyle(fontSize: 12, color: Colors.grey), // Taille réduite
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
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Erreur : ${snapshot.error}'));
        }

        final posts = snapshot.data ?? [];
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

  Widget _buildChoicesSection(Map<String, dynamic> user) {
    final choices = user['choices'] ?? [];

    if (choices.isEmpty) {
      return const Center(
        child: Text(
          'Aucun choix enregistré.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: choices.length,
      itemBuilder: (context, index) {
        final choice = choices[index];
        final targetId = choice['targetId'];
        final comment = choice['comment'] ?? '';

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: ListTile(
            leading: const Icon(Icons.check_circle_outline, color: Colors.blue),
            title: Text('ID cible : $targetId'),
            subtitle: Text(comment.isNotEmpty ? comment : 'Pas de commentaire.'),
            onTap: () {
              // Naviguer vers les détails de la cible si applicable
              _navigateToDetails(targetId, 'choice');
            },
          ),
        );
      },
    );
  }

  Widget _buildInterestsSection(Map<String, dynamic> user) {
    final interests = user['interests'] ?? [];

    if (interests.isEmpty) {
      return const Center(
        child: Text(
          'Aucun intérêt enregistré.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: interests.length,
      itemBuilder: (context, index) {
        final interestId = interests[index];

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: ListTile(
            leading: const Icon(Icons.favorite_border, color: Colors.red),
            title: Text('ID intérêt : $interestId'),
            onTap: () {
              // Naviguer vers les détails de l'intérêt si applicable
              _navigateToDetails(interestId, 'interest');
            },
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
                    ? kIsWeb
                        ? Image.network(_mediaUrl!, height: 200, width: double.infinity, fit: BoxFit.cover)
                        : Image.file(File(_mediaUrl!), height: 200, width: double.infinity, fit: BoxFit.cover)
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
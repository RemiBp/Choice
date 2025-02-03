import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:choice_app/screens/producer_screen.dart';
import 'package:choice_app/screens/eventLeisure_screen.dart';
import 'package:intl/intl.dart';
import 'package:choice_app/screens/profile_screen.dart';
import 'package:video_player/video_player.dart'; 
import 'package:choice_app/screens/producerLeisure_screen.dart';

class FeedScreen extends StatefulWidget {
  final String userId;

  const FeedScreen({Key? key, required this.userId}) : super(key: key);

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  late Future<List<dynamic>> _feedFuture;

  @override
  void initState() {
    super.initState();
    _fetchFeed();
  }

  /// Récupère les données du feed depuis le backend
  void _fetchFeed() {
    setState(() {
      _feedFuture = _getFeedData(widget.userId);
    });
  }

  /// Effectue la requête HTTP pour récupérer les posts
  Future<List<dynamic>> _getFeedData(String userId) async {
    final url = Uri.parse('http://10.0.2.2:5000/api/posts?userId=$userId&limit=10');
    try {
      print('🔍 Requête vers : $url');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('📩 Réponse reçue : ${data.length} posts');
        return data;
      } else {
        print('❌ Erreur lors de la récupération du feed : ${response.body}');
        return [];
      }
    } catch (e) {
      print('❌ Erreur réseau : $e');
      return [];
    }
  }

  /// Récupère les informations d'un auteur (producteur ou utilisateur)
  Future<Map<String, dynamic>?> _fetchUserProfile(String userId) async {
    final url = Uri.parse('http://10.0.2.2:5000/api/users/$userId');
    try {
      print('🔍 Requête utilisateur vers : $url');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        print('📩 Profil utilisateur récupéré avec succès');
        return json.decode(response.body);
      } else {
        print('❌ Erreur lors de la récupération du profil utilisateur : ${response.body}');
        return null;
      }
    } catch (e) {
      print('❌ Erreur réseau pour le profil utilisateur : $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> _fetchAuthorDetails(String authorId, bool isProducer,
      {bool isLeisureProducer = false}) async {
    String endpoint = isLeisureProducer ? 'leisureProducers' : (isProducer ? 'producers' : 'users');
    Uri url = Uri.parse('http://10.0.2.2:5000/api/$endpoint/$authorId');

    try {
      print('🔍 Requête auteur vers : $url');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        print('📩 Auteur récupéré avec succès depuis $endpoint');
        return json.decode(response.body);
      } else {
        print('❌ Erreur lors de la récupération des détails de l\'auteur depuis $endpoint : ${response.body}');

        // Fallback : si la requête sur "producers" échoue, essaye "leisureProducers"
        if (!isLeisureProducer && isProducer) {
          print('🔄 Tentative de fallback vers leisureProducers...');
          endpoint = 'leisureProducers';
          url = Uri.parse('http://10.0.2.2:5000/api/$endpoint/$authorId');
          final fallbackResponse = await http.get(url);

          if (fallbackResponse.statusCode == 200) {
            print('📩 Auteur récupéré avec succès depuis $endpoint');
            return json.decode(fallbackResponse.body);
          } else {
            print('❌ Erreur également sur $endpoint : ${fallbackResponse.body}');
          }
        }
      }
    } catch (e) {
      print('❌ Erreur réseau pour l\'auteur : $e');
    }

    // Retourne null si toutes les tentatives échouent
    return null;
  }

  Future<void> _markInterested(String targetId, Map<String, dynamic> post, {bool isLeisureProducer = false}) async {
    final url = Uri.parse('http://10.0.2.2:5000/api/choicexinterest/interested');
    final body = {
      'userId': widget.userId,
      'targetId': targetId, // Peut être producerId ou eventId selon le contexte
      'isLeisureProducer': isLeisureProducer
    };

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final updatedInterested = json.decode(response.body)['interested'];
        setState(() {
          post['interested'] = updatedInterested; // Mise à jour locale du post
        });
        print('✅ Interested ajouté avec succès');
      } else {
        print('❌ Erreur lors de l\'ajout à Interested : ${response.body}');
      }
    } catch (e) {
      print('❌ Erreur réseau lors de l\'ajout à Interested : $e');
    }
  }

  Future<void> _markChoice(String targetId, Map<String, dynamic> post, {bool isLeisureProducer = false}) async {
    final url = Uri.parse('http://10.0.2.2:5000/api/choicexinterest/choice');
    final body = {
      'userId': widget.userId,
      'targetId': targetId,
      'isLeisureProducer': isLeisureProducer
    };

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final updatedChoice = json.decode(response.body)['choice'];
        setState(() {
          post['choice'] = updatedChoice; // Mise à jour locale du post
        });
        print('✅ Choice ajouté avec succès');
      } else {
        print('❌ Erreur lors de l\'ajout à Choice : ${response.body}');
      }
    } catch (e) {
      print('❌ Erreur réseau lors de l\'ajout à Choice : $e');
    }
  }

  /// Récupère les informations d'un événement
  Future<Map<String, dynamic>?> _fetchEventDetails(String eventId) async {
    final url = Uri.parse('http://10.0.2.2:5000/api/events/$eventId');
    try {
      print('🔍 Requête événement vers : $url');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        print('❌ Erreur lors de la récupération des détails de l\'événement : ${response.body}');
        return null;
      }
    } catch (e) {
      print('❌ Erreur réseau pour l\'événement : $e');
      return null;
    }
  }

  /// Ajoute un commentaire
  Future<void> _addComment(String postId, String comment) async {
    final url = Uri.parse('http://10.0.2.2:5000/api/posts/$postId/comments');
    try {
      final response = await http.post(
        url,
        body: json.encode({'comment': comment}),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) {
        print('✅ Commentaire ajouté avec succès');
        setState(() {
          _fetchFeed();
        });
      } else {
        print('❌ Erreur lors de l\'ajout du commentaire : ${response.body}');
      }
    } catch (e) {
      print('❌ Erreur réseau pour l\'ajout du commentaire : $e');
    }
  }

  /// Like un commentaire
  Future<void> _likeComment(String postId, String commentId) async {
    final url = Uri.parse('http://10.0.2.2:5000/api/posts/$postId/comments/$commentId/like');
    try {
      final response = await http.post(url);
      if (response.statusCode == 200) {
        print('✅ Commentaire liké avec succès');
        setState(() {
          _fetchFeed();
        });
      } else {
        print('❌ Erreur lors du like du commentaire : ${response.body}');
      }
    } catch (e) {
      print('❌ Erreur réseau pour le like du commentaire : $e');
    }
  }

  Future<VideoPlayerController> _initializeVideoController(String videoUrl) async {
    final controller = VideoPlayerController.network(videoUrl);

    try {
      await controller.initialize();
      controller.setLooping(true); // Permet à la vidéo de boucler automatiquement.
      controller.setVolume(0); // Désactive le son si vous le souhaitez.
      controller.play(); // Lance automatiquement la lecture de la vidéo.
      return controller;
    } catch (e) {
      debugPrint('Erreur lors de l\'initialisation de la vidéo : $e');
      throw Exception('Impossible de charger la vidéo');
    }
  }



void _navigateToDetails(String id, bool isProducer, {bool isLeisureProducer = false}) async {
  final producerData = await _fetchAuthorDetails(id, isProducer, isLeisureProducer: isLeisureProducer);

  if (producerData != null) {
    if (isLeisureProducer || producerData['type'] == 'leisureProducer') {
      // Redirection vers ProducerLeisureScreen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProducerLeisureScreen(producerData: producerData),
        ),
      );
    } else if (isProducer) {
      // Redirection vers ProducerScreen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProducerScreen(producerId: id),
        ),
      );
    } else {
      // Redirection vers EventLeisureScreen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EventLeisureScreen(eventData: {'_id': id}),
        ),
      );
    }
  } else {
    print('❌ Impossible de récupérer les données pour l\'auteur avec ID : $id');
  }
}




  /// Formate la date et l'heure du post
  String _formatPostedTime(String postedAt) {
    final DateTime postedDate = DateTime.parse(postedAt);
    final Duration difference = DateTime.now().difference(postedDate);

    if (difference.inMinutes < 60) {
      return "${difference.inMinutes} min";
    } else if (difference.inHours < 24) {
      return "${difference.inHours} h";
    } else {
      return DateFormat('dd MMM, yyyy').format(postedDate);
    }
  }

    /// Construit la carte d'un post
  Widget _buildPostCard(Map<String, dynamic> post) {
    final String content = post['content']?.toString() ?? 'Contenu non disponible';
    final String postedAt = post['posted_at']?.toString() ?? DateTime.now().toIso8601String();
    final String? mediaUrl = (post['media'] as List?)?.isNotEmpty == true
        ? ((post['media'][0]?.toString()?.endsWith('.jpg') ?? false) ||
                (post['media'][0]?.toString()?.endsWith('.png') ?? false) ||
                (post['media'][0]?.toString()?.endsWith('.jpeg') ?? false))
            ? post['media'][0].toString()
            : null
        : null;
    final String? videoUrl = (post['media'] as List?)?.isNotEmpty == true
        ? ((post['media'][0]?.toString()?.endsWith('.mp4') ?? false) ||
                (post['media'][0]?.toString()?.endsWith('.mov') ?? false) ||
                (post['media'][0]?.toString()?.endsWith('.avi') ?? false))
            ? post['media'][0].toString()
            : null
        : null;
    final String? producerId = post['producer_id']?.toString();
    final String? userId = post['user_id']?.toString();
    final String? eventId = post['event_id']?.toString();
    final bool isProducer = producerId != null;
    final bool isLeisureProducer = post['is_leisure_producer'] == true;
    final String targetId = isLeisureProducer ? (eventId ?? '') : (producerId ?? '');
    final List<dynamic> comments = post['comments'] ?? [];

    // Ajout de la gestion de l'état pour le bouton "More"
    bool isExpanded = false;

    return StatefulBuilder(
      builder: (context, setState) {
        return Card(
          color: isProducer ? Colors.blue[50] : Colors.white,
          margin: const EdgeInsets.symmetric(vertical: 15, horizontal: 20), // Plus de marge
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          elevation: 5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Informations sur l'auteur (nom + avatar) avec redirection
              if (producerId != null || userId != null)
                FutureBuilder<Map<String, dynamic>?>(
                  future: isProducer
                      ? _fetchAuthorDetails(producerId!, true, isLeisureProducer: isLeisureProducer)
                      : _fetchUserProfile(userId!),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    } else if (snapshot.hasError || snapshot.data == null) {
                      return const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text(
                          'Auteur non disponible',
                          style: TextStyle(color: Colors.red),
                        ),
                      );
                    }

                    final authorData = snapshot.data!;
                    final String name = authorData['name'] ?? 'Nom non disponible';
                    final String avatarUrl = isProducer
                        ? authorData['photo'] ?? 'https://via.placeholder.com/150'
                        : authorData['photo_url'] ?? 'https://via.placeholder.com/150';

                    return GestureDetector(
                      onTap: () => isProducer
                          ? _navigateToDetails(producerId!, true, isLeisureProducer: isLeisureProducer)
                          : Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ProfileScreen(userId: userId!),
                              ),
                            ),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundImage: NetworkImage(avatarUrl),
                              radius: 25,
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  _formatPostedTime(postedAt),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

              // Texte du post avec bouton "More"
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      isExpanded = !isExpanded;
                    });
                  },
                  child: Text(
                    isExpanded ? content : '${content.substring(0, 100)}...',
                    style: const TextStyle(fontSize: 16, color: Colors.black87), // Taille augmentée
                  ),
                ),
              ),
              if (!isExpanded && content.length > 100)
                TextButton(
                  onPressed: () {
                    setState(() {
                      isExpanded = true;
                    });
                  },
                  child: const Text(
                    'More',
                    style: TextStyle(color: Colors.blue),
                  ),
                ),

              // Affichage vidéo ou image
              if (videoUrl != null)
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(15),
                    topRight: Radius.circular(15),
                  ),
                  child: FutureBuilder<VideoPlayerController>(
                    future: _initializeVideoController(videoUrl),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.done &&
                          snapshot.hasData) {
                        final controller = snapshot.data!;
                        return AspectRatio(
                          aspectRatio: controller.value.aspectRatio,
                          child: Stack(
                            alignment: Alignment.bottomCenter,
                            children: [
                              VideoPlayer(controller),
                              VideoProgressIndicator(controller, allowScrubbing: true),
                            ],
                          ),
                        );
                      } else if (snapshot.hasError) {
                        return const Center(
                          child: Text(
                            'Erreur de chargement de la vidéo',
                            style: TextStyle(color: Colors.red),
                          ),
                        );
                      } else {
                        return const Center(child: CircularProgressIndicator());
                      }
                    },
                  ),
                )
              else if (mediaUrl != null)
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(15),
                    topRight: Radius.circular(15),
                  ),
                  child: Image.network(
                    mediaUrl,
                    height: 300,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Colors.grey[200],
                      height: 300,
                      width: double.infinity,
                      child: const Center(
                        child: Text('Image invalide', style: TextStyle(color: Colors.red)),
                      ),
                    ),
                  ),
                ),

              const Divider(),

              // Boutons interactifs
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      _markInterested(targetId, post, isLeisureProducer: isLeisureProducer);
                    },
                    icon: Icon(
                      Icons.star,
                      color: post['interested'] == true ? Colors.yellow : Colors.grey,
                    ),
                    label: Text(
                      'Interest',
                      style: TextStyle(
                        color: post['interested'] == true ? Colors.yellow : Colors.grey,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      _markChoice(targetId, post, isLeisureProducer: isLeisureProducer);
                    },
                    icon: Icon(
                      Icons.check_circle,
                      color: post['choice'] == true ? Colors.green : Colors.grey,
                    ),
                    label: Text(
                      'Choice',
                      style: TextStyle(
                        color: post['choice'] == true ? Colors.green : Colors.grey,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      _showAddCommentDialog(context, post['_id']);
                    },
                    icon: const Icon(Icons.comment_outlined),
                    label: const Text('Comment'),
                  ),
                ],
              ),

              // Section des commentaires
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: comments
                      .map((comment) => _buildCommentSection(post['_id'], comment))
                      .toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }


// Fonction pour afficher une boîte de dialogue d'ajout de commentaire
void _showAddCommentDialog(BuildContext context, String postId) {
  final TextEditingController commentController = TextEditingController();
  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Ajouter un commentaire'),
        content: TextField(
          controller: commentController,
          decoration: const InputDecoration(
            labelText: 'Votre commentaire',
            hintText: 'Tapez votre commentaire ici...',
          ),
          maxLines: 3, // Permet plusieurs lignes pour le commentaire
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (commentController.text.isNotEmpty) {
                await _addComment(postId, commentController.text); // Utilisation de votre fonction
                Navigator.of(context).pop(); // Ferme le dialogue après l'ajout
              } else {
                print('❌ Le commentaire est vide');
              }
            },
            child: const Text('Publier'),
          ),
        ],
      );
    },
  );
}





  Widget _buildCommentSection(String postId, Map<String, dynamic> comment) {
    return Row(
      children: [
        Expanded(
          child: ListTile(
            title: Text(comment['author'] ?? 'Anonyme', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(comment['content'] ?? ''),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.favorite, color: Colors.red),
          onPressed: () => _likeComment(postId, comment['_id'] ?? ''),
        ),
        Text('${comment['likes'] ?? 0}'),
      ],
    );
  }

  Widget _buildAddCommentSection(String postId) {
    final TextEditingController commentController = TextEditingController();
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: commentController,
            decoration: const InputDecoration(labelText: 'Ajouter un commentaire'),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.send),
          onPressed: () {
            if (commentController.text.isNotEmpty) {
              _addComment(postId, commentController.text);
              commentController.clear();
            }
          },
        ),
      ],
    );
  }

  void _showPostDetail(Map<String, dynamic> post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                post['title'] ?? 'Titre non spécifié',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                post['content'] ?? 'Contenu non disponible',
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Feed'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {},
          ),
        ],
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _feedFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Erreur : ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Aucun post trouvé.'));
          }

          final posts = snapshot.data!;
          return ListView.builder(
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final post = posts[index];
              return _buildPostCard(post);
            },
          );
        },
      ),
    );
  }
}
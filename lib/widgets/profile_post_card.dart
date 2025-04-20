import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../screens/producer_screen.dart';
import '../screens/producerLeisure_screen.dart';
import '../screens/eventLeisure_screen.dart';
import '../utils/constants.dart' as constants;
import 'feed/post_interaction_bar.dart';
import '../../utils.dart' show getImageProvider;

class ProfilePostCard extends StatefulWidget {
  final Map<String, dynamic> post;
  final String userId;
  final VoidCallback onRefresh;
  final Color? themeColor;
  final String? currentUserId;
  final bool showDetailsLink;
  final bool isDetailed;

  const ProfilePostCard({
    Key? key,
    required this.post,
    required this.userId,
    required this.onRefresh,
    this.themeColor,
    this.currentUserId,
    this.showDetailsLink = true,
    this.isDetailed = false,
  }) : super(key: key);

  @override
  State<ProfilePostCard> createState() => _ProfilePostCardState();
}

class _ProfilePostCardState extends State<ProfilePostCard> {
  bool _isLiked = false;
  int _likesCount = 0;
  int _commentsCount = 0;
  bool _isInterested = false;
  bool _isChoice = false;
  int _interestedCount = 0;
  int _choiceCount = 0;
  bool _isExpanded = false;
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmittingComment = false;
  
  @override
  void initState() {
    super.initState();
    _loadInteractionData();
  }
  
  void _loadInteractionData() {
    // Extract initial data from post
    _isLiked = widget.post['isLiked'] == true;
    _likesCount = widget.post['likes_count'] ?? 
                 (widget.post['likes'] is List ? (widget.post['likes'] as List).length : 0);
    _commentsCount = widget.post['comments_count'] ?? 
                    (widget.post['comments'] is List ? (widget.post['comments'] as List).length : 0);
    _isInterested = widget.post['isInterested'] == true || widget.post['interested'] == true;
    _isChoice = widget.post['isChoice'] == true || widget.post['choice'] == true;
    _interestedCount = widget.post['interested_count'] ?? widget.post['interestedCount'] ?? 0;
    _choiceCount = widget.post['choice_count'] ?? widget.post['choiceCount'] ?? 0;
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  // Gestion du like
  Future<void> _handleLike() async {
    final String postId = widget.post['_id'] ?? widget.post['id'] ?? '';
    if (postId.isEmpty) return;

    setState(() {
      _isLiked = !_isLiked;
      _likesCount = _isLiked ? _likesCount + 1 : _likesCount - 1;
      if (_likesCount < 0) _likesCount = 0;
    });

    try {
      final url = Uri.parse('${constants.getBaseUrl()}/api/posts/$postId/like');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'userId': widget.userId,
          'action': _isLiked ? 'like' : 'unlike',
        }),
      );

      if (response.statusCode != 200) {
        // Rollback on failure
        setState(() {
          _isLiked = !_isLiked;
          _likesCount = _isLiked ? _likesCount + 1 : _likesCount - 1;
          if (_likesCount < 0) _likesCount = 0;
        });
      } else if (widget.onRefresh != null) {
        widget.onRefresh();
      }
    } catch (e) {
      print('❌ Error liking post: $e');
      // Rollback on exception
      setState(() {
        _isLiked = !_isLiked;
        _likesCount = _isLiked ? _likesCount + 1 : _likesCount - 1;
        if (_likesCount < 0) _likesCount = 0;
      });
    }
  }

  // Gestion de l'intérêt
  Future<void> _handleInterested() async {
    final String postId = widget.post['_id'] ?? widget.post['id'] ?? '';
    if (postId.isEmpty) return;

    setState(() {
      _isInterested = !_isInterested;
      _interestedCount = _isInterested ? _interestedCount + 1 : _interestedCount - 1;
      if (_interestedCount < 0) _interestedCount = 0;
    });

    try {
      final url = Uri.parse('${constants.getBaseUrl()}/api/posts/$postId/interest');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'userId': widget.userId,
          'action': _isInterested ? 'interest' : 'uninterest',
        }),
      );

      if (response.statusCode != 200) {
        // Rollback on failure
        setState(() {
          _isInterested = !_isInterested;
          _interestedCount = _isInterested ? _interestedCount + 1 : _interestedCount - 1;
          if (_interestedCount < 0) _interestedCount = 0;
        });
      } else if (widget.onRefresh != null) {
        widget.onRefresh();
      }
    } catch (e) {
      print('❌ Error marking interest: $e');
      // Rollback on exception
      setState(() {
        _isInterested = !_isInterested;
        _interestedCount = _isInterested ? _interestedCount + 1 : _interestedCount - 1;
        if (_interestedCount < 0) _interestedCount = 0;
      });
    }
  }

  // Gestion du choix
  Future<void> _handleChoice() async {
    final String postId = widget.post['_id'] ?? widget.post['id'] ?? '';
    if (postId.isEmpty) return;

    setState(() {
      _isChoice = !_isChoice;
      _choiceCount = _isChoice ? _choiceCount + 1 : _choiceCount - 1;
      if (_choiceCount < 0) _choiceCount = 0;
    });

    try {
      final url = Uri.parse('${constants.getBaseUrl()}/api/posts/$postId/choice');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'userId': widget.userId,
          'action': _isChoice ? 'choice' : 'unchoice',
        }),
      );

      if (response.statusCode != 200) {
        // Rollback on failure
        setState(() {
          _isChoice = !_isChoice;
          _choiceCount = _isChoice ? _choiceCount + 1 : _choiceCount - 1;
          if (_choiceCount < 0) _choiceCount = 0;
        });
      } else if (widget.onRefresh != null) {
        widget.onRefresh();
      }
    } catch (e) {
      print('❌ Error marking choice: $e');
      // Rollback on exception
      setState(() {
        _isChoice = !_isChoice;
        _choiceCount = _isChoice ? _choiceCount + 1 : _choiceCount - 1;
        if (_choiceCount < 0) _choiceCount = 0;
      });
    }
  }

  // Afficher les commentaires
  void _showCommentsSheet() {
    setState(() {
      _isExpanded = true;
    });
    
    final List<dynamic> comments = widget.post['comments'] ?? [];
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, controller) => Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Commentaires',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Divider(),
              Expanded(
                child: comments.isEmpty
                    ? const Center(
                        child: Text('Aucun commentaire pour le moment'),
                      )
                    : ListView.builder(
                        controller: controller,
                        itemCount: comments.length,
                        itemBuilder: (context, index) {
                          final comment = comments[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundImage: getImageProvider(
                                comment['author_avatar'] ?? '',
                              ),
                            ),
                            title: Text(comment['author_name'] ?? 'Utilisateur'),
                            subtitle: Text(comment['content'] ?? ''),
                            trailing: Text(_formatCommentTime(comment['posted_at'] ?? '')),
                          );
                        },
                      ),
              ),
              const Divider(),
              Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 8,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 8,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        decoration: const InputDecoration(
                          hintText: 'Ajouter un commentaire...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(25.0)),
                          ),
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                        maxLines: 3,
                        minLines: 1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: _isSubmittingComment
                          ? const CircularProgressIndicator()
                          : const Icon(Icons.send, color: Colors.blue),
                      onPressed: _isSubmittingComment ? null : _submitComment,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ).then((_) {
      setState(() {
        _isExpanded = false;
      });
    });
  }

  // Soumettre un commentaire
  Future<void> _submitComment() async {
    if (_commentController.text.trim().isEmpty) return;

    setState(() {
      _isSubmittingComment = true;
    });

    try {
      final String postId = widget.post['_id'] ?? widget.post['id'] ?? '';
      
      final url = Uri.parse('${constants.getBaseUrl()}/api/posts/$postId/comment');
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'userId': widget.userId,
          'content': _commentController.text.trim(),
        }),
      );

      if (response.statusCode == 200) {
        _commentController.clear();
        
        // Refresh comments count
        setState(() {
          _commentsCount++;
        });
        
        // Close and reopen to refresh
        Navigator.of(context).pop();
        _showCommentsSheet();
        
        if (widget.onRefresh != null) {
          widget.onRefresh();
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors de l\'envoi du commentaire')),
        );
      }
    } catch (e) {
      print('❌ Error submitting comment: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    } finally {
      setState(() {
        _isSubmittingComment = false;
      });
    }
  }

  String _formatCommentTime(String timeStr) {
    try {
      final DateTime time = DateTime.parse(timeStr);
      final DateTime now = DateTime.now();
      final Duration difference = now.difference(time);
      
      if (difference.inMinutes < 1) {
        return 'À l\'instant';
      } else if (difference.inHours < 1) {
        return 'Il y a ${difference.inMinutes} min';
      } else if (difference.inDays < 1) {
        return 'Il y a ${difference.inHours} h';
      } else if (difference.inDays < 7) {
        return 'Il y a ${difference.inDays} j';
      } else {
        return '${time.day}/${time.month}/${time.year}';
      }
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final String title = widget.post['title']?.toString() ?? 'Sans titre';
    final String content = widget.post['content']?.toString() ?? 'Aucun contenu';
    final String? authorId = widget.post['producer_id']?.toString() ?? widget.post['user_id']?.toString();
    final bool isProducer = widget.post['producer_id'] != null;
    final List<dynamic> mediaList = widget.post['media'] ?? [];
    final String? mediaUrl = mediaList.isNotEmpty ? mediaList[0]?.toString() : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête du post avec les informations de l'auteur
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundImage: getImageProvider(
                    widget.post['authorProfileImage'] ?? '',
                  ),
                  backgroundColor: Colors.grey[200],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.post['authorName'] ?? 'Utilisateur',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        _formatDate(widget.post['created_at']),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.more_vert, size: 20),
                  onPressed: () => _showPostOptions(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          // Contenu du post
          if (content.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                content,
                style: const TextStyle(fontSize: 14),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ),

          // Image du post si disponible
          if (mediaUrl != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
                child: () {
                  final imageProvider = getImageProvider(mediaUrl);
                  if (imageProvider != null) {
                    return Image(
                      image: imageProvider,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: 200,
                        color: Colors.grey[300],
                        child: const Icon(Icons.broken_image, size: 50, color: Colors.white),
                      ),
                    );
                  } else {
                    return Container(
                      height: 200,
                      color: Colors.grey[300],
                      child: const Icon(Icons.broken_image, size: 50, color: Colors.white),
                    );
                  }
                }(),
              ),
            ),

          // Barre d'interaction (likes, interests, choices)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: PostInteractionBar(
              post: widget.post,
              userId: widget.userId,
              onRefresh: widget.onRefresh,
              themeColor: widget.themeColor,
            ),
          ),
        ],
      ),
    );
  }

  // Formater la date de création du post
  String _formatDate(dynamic dateString) {
    if (dateString == null) return 'Date inconnue';
    try {
      final DateTime date = DateTime.parse(dateString.toString());
      final DateTime now = DateTime.now();
      final Duration difference = now.difference(date);

      if (difference.inDays > 365) {
        return 'Il y a ${(difference.inDays / 365).floor()} an(s)';
      } else if (difference.inDays > 30) {
        return 'Il y a ${(difference.inDays / 30).floor()} mois';
      } else if (difference.inDays > 0) {
        return 'Il y a ${difference.inDays} jour(s)';
      } else if (difference.inHours > 0) {
        return 'Il y a ${difference.inHours} heure(s)';
      } else if (difference.inMinutes > 0) {
        return 'Il y a ${difference.inMinutes} minute(s)';
      } else {
        return 'À l\'instant';
      }
    } catch (e) {
      return 'Date invalide';
    }
  }

  // Afficher les options du post
  void _showPostOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.share),
            title: const Text('Partager'),
            onTap: () {
              Navigator.pop(context);
              // Logique de partage
            },
          ),
          ListTile(
            leading: const Icon(Icons.bookmark_border),
            title: const Text('Sauvegarder'),
            onTap: () {
              Navigator.pop(context);
              // Logique de sauvegarde
            },
          ),
          if (widget.post['user_id'] == widget.userId || widget.post['producer_id'] == widget.userId)
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Supprimer', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _confirmDelete(context);
              },
            ),
        ],
      ),
    );
  }

  // Confirmer la suppression d'un post
  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer ce post ?'),
        content: const Text('Cette action est irréversible. Voulez-vous vraiment supprimer ce post ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Logique de suppression
              // Après la suppression, appeler onRefresh pour mettre à jour l'UI
              widget.onRefresh();
            },
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
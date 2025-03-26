import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../screens/producer_screen.dart';
import '../screens/producerLeisure_screen.dart';
import '../screens/eventLeisure_screen.dart';
import '../utils.dart';
import 'feed/post_interaction_bar.dart';

class ProfilePostCard extends StatefulWidget {
  final Map<String, dynamic> post;
  final String userId;
  final VoidCallback? onRefresh;

  const ProfilePostCard({
    Key? key,
    required this.post,
    required this.userId,
    this.onRefresh,
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
      final url = Uri.parse('${getBaseUrl()}/api/posts/$postId/like');
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
        widget.onRefresh!();
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
      final url = Uri.parse('${getBaseUrl()}/api/posts/$postId/interest');
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
        widget.onRefresh!();
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
      final url = Uri.parse('${getBaseUrl()}/api/posts/$postId/choice');
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
        widget.onRefresh!();
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
                              backgroundImage: CachedNetworkImageProvider(
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
      
      final url = Uri.parse('${getBaseUrl()}/api/posts/$postId/comment');
      
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
          widget.onRefresh!();
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
    final bool isProducerPost = widget.post['isProducerPost'] == true || 
                             widget.post['producer_id'] != null;
    final bool isLeisureProducer = widget.post['isLeisureProducer'] == true;
    
    // Get media items
    final List<dynamic> mediaItems = widget.post['media'] ?? [];
    
    // Get author info
    String authorName = '';
    String authorAvatar = '';
    String authorId = '';
    
    if (widget.post['author'] is Map) {
      final author = widget.post['author'] as Map;
      authorName = author['name'] ?? '';
      authorAvatar = author['avatar'] ?? '';
      authorId = author['id'] ?? '';
    } else {
      authorName = widget.post['author_name'] ?? '';
      authorAvatar = widget.post['author_avatar'] ?? widget.post['author_photo'] ?? '';
      authorId = widget.post['author_id'] ?? widget.post['user_id'] ?? '';
    }
    
    return Card(
      margin: const EdgeInsets.all(8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Post header
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => _navigateToProfile(context, authorId, isProducerPost, isLeisureProducer),
                  child: CircleAvatar(
                    backgroundImage: CachedNetworkImageProvider(
                      authorAvatar.isNotEmpty
                          ? authorAvatar
                          : 'https://via.placeholder.com/150',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
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
                        _formatTimestamp(widget.post['posted_at'] ?? widget.post['time_posted'] ?? ''),
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.more_vert),
                  onPressed: () {
                    _showPostOptions(context);
                  },
                ),
              ],
            ),
          ),

          // Post content
          if (widget.post['content'] != null && widget.post['content'].toString().isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                widget.post['content'],
                style: const TextStyle(fontSize: 16),
              ),
            ),

          // Post media
          if (mediaItems.isNotEmpty)
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                ),
                child: GestureDetector(
                  onTap: () {
                    _showFullScreenMedia(context, mediaItems);
                  },
                  child: Hero(
                    tag: 'post-media-${widget.post['_id']}',
                    child: CachedNetworkImage(
                      imageUrl: mediaItems[0]['url'] ?? mediaItems[0].toString(),
                      fit: BoxFit.cover,
                      placeholder: (context, url) => const Center(
                        child: CircularProgressIndicator(),
                      ),
                      errorWidget: (context, url, error) => const Icon(
                        Icons.error,
                        size: 50,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Post interactions
          PostInteractionBar(
            isLiked: _isLiked,
            isInterested: _isInterested,
            isChoice: _isChoice,
            likesCount: _likesCount,
            interestedCount: _interestedCount,
            choiceCount: _choiceCount,
            commentsCount: _commentsCount,
            onLike: _handleLike,
            onInterested: _handleInterested,
            onChoice: _handleChoice,
            onComment: _showCommentsSheet,
            onShare: () {}, // À implémenter
            isProducerPost: isProducerPost,
            isLeisureProducer: isLeisureProducer,
          ),
          
          // Post location reference if any
          if (widget.post['locationName'] != null && widget.post['locationName'].toString().isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.location_on, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    widget.post['locationName'],
                    style: TextStyle(
                      color: Colors.grey[600],
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

  void _showFullScreenMedia(BuildContext context, List<dynamic> mediaItems) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: PageView.builder(
            itemCount: mediaItems.length,
            itemBuilder: (context, index) {
              final mediaUrl = mediaItems[index]['url'] ?? mediaItems[index].toString();
              return GestureDetector(
                onTap: () {
                  Navigator.of(context).pop();
                },
                child: Center(
                  child: Hero(
                    tag: index == 0 ? 'post-media-${widget.post['_id']}' : 'post-media-${widget.post['_id']}-$index',
                    child: CachedNetworkImage(
                      imageUrl: mediaUrl,
                      fit: BoxFit.contain,
                      placeholder: (context, url) => const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                      errorWidget: (context, url, error) => const Icon(
                        Icons.error,
                        size: 100,
                        color: Colors.white54,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _navigateToProfile(BuildContext context, String id, bool isProducer, bool isLeisure) {
    if (id.isEmpty) return;
    
    if (isProducer) {
      if (isLeisure) {
        // Navigate to leisure producer profile
        _fetchAndNavigateToLeisureProducer(context, id);
      } else {
        // Navigate to restaurant producer profile
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProducerScreen(producerId: id),
          ),
        );
      }
    } else {
      // Navigate to user profile
      // TODO: Implement navigation to user profile
    }
  }

  Future<void> _fetchAndNavigateToLeisureProducer(BuildContext context, String id) async {
    try {
      final url = Uri.parse('${getBaseUrl()}/api/leisureProducers/$id');
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProducerLeisureScreen(producerData: data),
          ),
        );
      } else {
        print('❌ Failed to fetch leisure producer: ${response.body}');
      }
    } catch (e) {
      print('❌ Error fetching leisure producer: $e');
    }
  }

  void _showPostOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.content_copy),
                title: const Text('Copier le contenu'),
                onTap: () {
                  Navigator.pop(context);
                  Clipboard.setData(ClipboardData(text: widget.post['content'] ?? ''));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Contenu copié !')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.report),
                title: const Text('Signaler'),
                onTap: () {
                  Navigator.pop(context);
                  // TODO: Implement report functionality
                },
              ),
              ListTile(
                leading: const Icon(Icons.share),
                title: const Text('Partager'),
                onTap: () {
                  Navigator.pop(context);
                  // TODO: Implement share functionality
                },
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatTimestamp(String timeStr) {
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
}
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import '../models/post.dart';
import '../services/api_service.dart' as api_service;
import '../widgets/choice_carousel.dart';
import '../models/media.dart' as media_model;
import '../models/comment.dart';
import '../models/post_location.dart';
import '../widgets/comment_item.dart';
import '../services/analytics_service.dart';
import '../widgets/comment_tile.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils.dart' show getImageProvider;

class PostDetailScreen extends StatefulWidget {
  final String postId;
  final String userId;
  final String? referringScreen;
  
  const PostDetailScreen({
    Key? key,
    required this.postId,
    required this.userId,
    this.referringScreen,
  }) : super(key: key);

  @override
  _PostDetailScreenState createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final api_service.ApiService _apiService = api_service.ApiService();
  final AnalyticsService _analyticsService = AnalyticsService();
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final Map<String, VideoPlayerController> _videoControllers = {};
  final ChoiceCarouselController _carouselController = ChoiceCarouselController();
  
  Post _postData = Post(
    id: '',
    userId: '',
    userName: '',
    description: '',
    createdAt: DateTime.now(),
    content: '',
    title: '',
    tags: [],
    commentsCount: 0,
    mediaUrls: [],
  );
  bool _isLoading = true;
  bool _isPostDataInitialized = false;
  bool _isCommenting = false;
  String? _errorMessage;
  String? _error;
  bool _isLoadingComments = false;
  String? _commentsError;
  List<Comment> _comments = [];
  
  // Liste de commentaires factices pour l'affichage
  final List<Map<String, dynamic>> commentsMapList = [
    {
      'authorId': 'user1',
      'authorName': 'Sophie Martin',
      'authorAvatar': 'https://randomuser.me/api/portraits/women/44.jpg',
      'text': 'Super endroit, je recommande fortement !',
      'date': DateTime.now().subtract(const Duration(days: 2)),
      'likes': 5,
    },
    {
      'authorId': 'user2',
      'authorName': 'Thomas Dubois',
      'authorAvatar': 'https://randomuser.me/api/portraits/men/32.jpg',
      'text': 'Les plats sont délicieux, surtout le dessert !',
      'date': DateTime.now().subtract(const Duration(days: 1)),
      'likes': 3,
    },
    // Ajoutez d'autres commentaires fictifs au besoin
  ];
  
  // Variables ajoutées
  bool _showControls = true;
  bool _isLiked = false;
  bool _isInterested = false;
  
  @override
  void initState() {
    super.initState();
    _loadPostDetails();
    _fetchComments();
  }
  
  Future<void> _loadPostDetails() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final postDataMap = await _apiService.getPostDetails(widget.postId);
      if (postDataMap != null) {
        // Convert Map to Post object
        final formattedPost = await _convertDynamicPostToPost(postDataMap); // Pass non-null map
        if (mounted) {
          setState(() {
            _postData = formattedPost;
            _isPostDataInitialized = true;
            _isLiked = _postData.isLiked ?? false;
            _isInterested = _postData.isInterested ?? false; // Initialize interest state
            _isLoading = false;
          });
        }
      } else {
         throw Exception('Post data not found.');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Erreur: Impossible de charger les détails du post. ($e)";
          _isLoading = false;
        });
      }
    }
  }
  
  Future<void> _fetchComments() async {
    setState(() {
      _isLoadingComments = true;
      _commentsError = null;
    });

    try {
      // Construire l'URL pour récupérer les commentaires
      final commentsUrl = Uri.parse('${api_service.ApiService.getBaseUrl()}/api/posts/${widget.postId}/comments');
      final response = await http.get(commentsUrl);

      if (response.statusCode == 200) {
        final List<dynamic> commentsData = jsonDecode(response.body);
        setState(() {
          _comments = commentsData.map((data) => Comment.fromJson(data)).toList();
          _isLoadingComments = false;
        });
      } else {
        setState(() {
          _commentsError = 'Erreur lors de la récupération des commentaires';
          _isLoadingComments = false;
        });
      }
    } catch (e) {
      setState(() {
        _commentsError = 'Exception: $e';
        _isLoadingComments = false;
      });
    }
  }
  
  Future<Post> _convertDynamicPostToPost(Map<String, dynamic> postMap) async {
    // Extract basic post data
    final String postId = postMap['_id'] ?? '';
    final String content = postMap['content'] ?? '';
    
    // Get author info
    String authorName = '';
    String authorAvatar = '';
    String authorId = '';
    
    if (postMap['author'] is Map) {
      final author = postMap['author'] as Map;
      authorName = author['name'] ?? '';
      authorAvatar = author['avatar'] ?? '';
      authorId = author['id'] ?? '';
    } else {
      authorName = postMap['author_name'] ?? '';
      authorAvatar = postMap['author_avatar'] ?? postMap['author_photo'] ?? '';
      authorId = postMap['author_id'] ?? postMap['user_id'] ?? '';
    }
    
    // Get post timestamp
    DateTime postedAt = DateTime.now();
    if (postMap['posted_at'] != null) {
      try {
        postedAt = DateTime.parse(postMap['posted_at'].toString());
      } catch (e) {
        print('❌ Error parsing timestamp: $e');
      }
    } else if (postMap['time_posted'] != null) {
      try {
        postedAt = DateTime.parse(postMap['time_posted'].toString());
      } catch (e) {
        print('❌ Error parsing timestamp: $e');
      }
    }
    
    // Determine if this is a producer post
    final bool isProducerPost = postMap['isProducerPost'] == true || 
                             postMap['producer_id'] != null;
    final bool isLeisureProducer = postMap['isLeisureProducer'] == true;
    
    // Convert media items
    List<media_model.Media> mediaItems = [];
    if (postMap['media'] is List) {
      for (var media in postMap['media']) {
        if (media is Map) {
          final url = media['url'] ?? '';
          final type = media['type'] ?? 'image';
          
          if (url.isNotEmpty) {
            mediaItems.add(media_model.Media(
              url: url,
              type: type,
            ));
          }
        }
      }
    }
    
    // Convert comments to Map format
    List<Map<String, dynamic>> commentsMapList = [];
    if (postMap['comments'] is List) {
      for (var comment in postMap['comments']) {
        if (comment is Map) {
          commentsMapList.add({
            'id': comment['_id'] ?? '',
            'authorId': comment['author_id'] ?? '',
            'authorName': comment['author_name'] ?? '',
            'username': comment['username'] ?? comment['author_name'] ?? '',
            'authorAvatar': comment['author_avatar'] ?? '',
            'content': comment['content'] ?? '',
            'postedAt': comment['posted_at'] != null 
                ? comment['posted_at'].toString()
                : comment['created_at'] != null
                    ? comment['created_at'].toString()
                    : DateTime.now().toIso8601String(),
          });
        }
      }
    }
    
    // Return constructed Post object
    return Post(
      id: postId,
      title: '',  // Titre vide par défaut
      content: content,
      userId: authorId,  // Utiliser l'ID de l'auteur comme ID utilisateur
      userName: authorName, // Ajouter le nom d'utilisateur
      createdAt: DateTime.now(),
      tags: [],  // Tableau vide pour les tags
      authorId: authorId,
      authorName: authorName,
      authorAvatar: authorAvatar,
      postedAt: postedAt,
      mediaUrls: [],
      commentsCount: commentsMapList.length,  // Utiliser le nombre d'éléments dans la liste
      media: mediaItems,
      isProducerPost: isProducerPost,
      isLeisureProducer: isLeisureProducer,
      isInterested: postMap['interested'] == true || postMap['isInterested'] == true,
      isChoice: postMap['choice'] == true || postMap['isChoice'] == true,
      interestedCount: postMap['interested_count'] ?? postMap['interestedCount'] ?? 0,
      choiceCount: postMap['choice_count'] ?? postMap['choiceCount'] ?? 0,
      isLiked: postMap['isLiked'] == true,
      likesCount: postMap['likes_count'] ?? postMap['likesCount'] ?? 
              (postMap['likes'] is List ? (postMap['likes'] as List).length : 0),
      description: content,  // Utiliser le contenu comme description
    );
  }
  
  void _initializeVideoControllers() {
    if (!_isPostDataInitialized) return;
    
    for (int i = 0; i < _postData.media.length; i++) {
      final media = _postData.media[i];
      if (media.type == 'video') {
        _initializeVideoController('${_postData.id}-$i', media.url);
      }
    }
  }
  
  Future<void> _initializeVideoController(String id, String videoUrl) async {
    if (_videoControllers.containsKey(id)) return;
    
    try {
      final controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
      _videoControllers[id] = controller;
      
      await controller.initialize();
      controller.setLooping(true);
      
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('❌ Error initializing video controller: $e');
    }
  }
  
  @override
  void dispose() {
    for (var controller in _videoControllers.values) {
      controller.dispose();
    }
    _videoControllers.clear();
    _commentController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Détails du post'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              _showPostOptions();
            },
          ),
        ],
      ),
      body: !_isPostDataInitialized
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Scrollable post content and comments
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Post header with author info
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundImage: _postData.authorAvatar?.isNotEmpty == true
                                  ? getImageProvider(_postData.authorAvatar!) ?? const AssetImage('assets/images/default_avatar.png')
                                  : const AssetImage('assets/images/default_avatar.png'),
                                child: _postData.authorAvatar == null || _postData.authorAvatar!.isEmpty
                                  ? Icon(Icons.person, color: Colors.grey[400])
                                  : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _postData.authorName ?? 'Utilisateur',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      _formatTimestamp(_postData.postedAt ?? DateTime.now()),
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
                        ),
                        
                        // Post content
                        if (_postData.content?.isNotEmpty == true)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: Text(
                              _postData.content ?? '',
                              style: const TextStyle(
                                fontSize: 16,
                                height: 1.4,
                              ),
                            ),
                          ),
                        
                        // Post media
                        if (_postData.media.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          
                          ChoiceCarousel.builder(
                            controller: _carouselController,
                            itemCount: _postData.media.length,
                            options: ChoiceCarouselOptions(
                              height: 400,
                              enlargeCenterPage: true,
                              enableInfiniteScroll: false,
                              viewportFraction: 1.0,
                            ),
                            itemBuilder: (context, index, _) {
                              final media = _postData.media[index];
                              final mediaId = '${_postData.id}-$index';
                              
                              return Container(
                                width: MediaQuery.of(context).size.width,
                                color: Colors.black,
                                child: media.type == 'video'
                                    ? _buildVideoPlayer(mediaId, media.url)
                                    : (() {
                                      final imageProvider = getImageProvider(media.url);
                                      if (imageProvider != null) {
                                        return GestureDetector(
                                          onTap: _toggleControlsVisibility,
                                          child: InteractiveViewer(
                                            minScale: 0.5,
                                            maxScale: 4.0,
                                            child: Image(
                                              image: imageProvider,
                                              fit: BoxFit.contain,
                                              errorBuilder: (context, error, stackTrace) => Container(
                                                color: Colors.black,
                                                child: const Center(child: Icon(Icons.broken_image, color: Colors.white70, size: 50)),
                                              ),
                                            ),
                                          ),
                                        );
                                      } else {
                                        return Container(
                                          color: Colors.black,
                                          child: const Center(child: Icon(Icons.broken_image, color: Colors.white70, size: 50)),
                                        );
                                      }
                                    })(),
                              );
                            },
                          ),
                        ],
                        
                        // Post statistics and interaction buttons
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              // Like count
                              Row(
                                children: [
                                  Icon(
                                    Icons.favorite,
                                    color: Colors.red[400],
                                    size: 18,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${_postData.likesCount ?? 0}',
                                    style: TextStyle(
                                      color: Colors.grey[700],
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              
                              const SizedBox(width: 24),
                              
                              // Interested count (if producer post)
                              if (_postData.isProducerPost ?? false) ...[
                                Row(
                                  children: [
                                    Icon(
                                      Icons.star,
                                      color: Colors.amber[700],
                                      size: 18,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${_postData.interestedCount}',
                                      style: TextStyle(
                                        color: Colors.grey[700],
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                
                                const SizedBox(width: 24),
                                
                                // Choice count (if producer post)
                                Row(
                                  children: [
                                    Icon(
                                      Icons.check_box,
                                      color: Colors.green[700],
                                      size: 18,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${_postData.choiceCount}',
                                      style: TextStyle(
                                        color: Colors.grey[700],
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              
                              const Spacer(),
                              
                              // Comment count
                              Row(
                                children: [
                                  Icon(
                                    Icons.mode_comment_outlined,
                                    color: Colors.blue[700],
                                    size: 18,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${_postData.commentsCount}',
                                    style: TextStyle(
                                      color: Colors.grey[700],
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        
                        // Interaction buttons
                        Container(
                          decoration: BoxDecoration(
                            border: Border(
                              top: BorderSide(color: Colors.grey[200]!),
                              bottom: BorderSide(color: Colors.grey[200]!),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: _buildActionButton(
                                  icon: (_postData.isLiked ?? false)
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  label: 'Like',
                                  color: (_postData.isLiked ?? false)
                                      ? Colors.red[400]!
                                      : Colors.grey[700]!,
                                  onPressed: _handleLike,
                                ),
                              ),
                              
                              if (_postData.isProducerPost ?? false) ...[
                                Expanded(
                                  child: _buildActionButton(
                                    icon: (_postData.isInterested ?? false)
                                        ? Icons.star
                                        : Icons.star_border,
                                    label: 'Intéressé',
                                    color: (_postData.isInterested ?? false)
                                        ? Colors.amber[700]!
                                        : Colors.grey[700]!,
                                    onPressed: _handleInterested,
                                  ),
                                ),
                                
                                Expanded(
                                  child: _buildActionButton(
                                    icon: (_postData.isChoice ?? false)
                                        ? Icons.check_box
                                        : Icons.check_box_outline_blank,
                                    label: 'Choice',
                                    color: (_postData.isChoice ?? false)
                                        ? Colors.green[700]!
                                        : Colors.grey[700]!,
                                    onPressed: _handleChoice,
                                  ),
                                ),
                              ],
                              
                              Expanded(
                                child: _buildActionButton(
                                  icon: Icons.mode_comment_outlined,
                                  label: 'Comment',
                                  color: Colors.grey[700]!,
                                  onPressed: () {
                                    // Focus the comment field
                                    FocusScope.of(context).requestFocus(_focusNode);
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Comments section
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Commentaires (${_postData.commentsCount})',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(height: 16),
                              
                              // Comment list
                              if (_postData.commentsCount == 0)
                                Center(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 24),
                                    child: Column(
                                      children: [
                                        Icon(
                                          Icons.chat_bubble_outline,
                                          size: 48,
                                          color: Colors.grey[400],
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          'Aucun commentaire pour le moment',
                                          style: TextStyle(
                                            color: Colors.grey[700],
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Soyez le premier à commenter',
                                          style: TextStyle(
                                            color: Colors.grey[500],
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              else
                                ..._buildCommentsList(commentsMapList),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Comment input area
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        spreadRadius: 1,
                        blurRadius: 3,
                        offset: const Offset(0, -1),
                      ),
                    ],
                  ),
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 8,
                    bottom: 8 + MediaQuery.of(context).padding.bottom,
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundImage: const NetworkImage(
                          'https://via.placeholder.com/150',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _commentController,
                          focusNode: _focusNode,
                          decoration: InputDecoration(
                            hintText: 'Ajouter un commentaire...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Colors.grey[100],
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                          ),
                          minLines: 1,
                          maxLines: 4,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _isCommenting
                          ? const SizedBox(
                              width: 36,
                              height: 36,
                              child: CircularProgressIndicator(),
                            )
                          : IconButton(
                              icon: const Icon(Icons.send),
                              color: Colors.deepPurple,
                              onPressed: _handleAddComment,
                            ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
  
  Widget _buildVideoPlayer(String id, String videoUrl) {
    if (!_videoControllers.containsKey(id)) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    
    final controller = _videoControllers[id]!;
    if (!controller.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    
    return Stack(
      alignment: Alignment.center,
      children: [
        AspectRatio(
          aspectRatio: controller.value.aspectRatio,
          child: VideoPlayer(controller),
        ),
        IconButton(
          icon: Icon(
            controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
            color: Colors.white,
            size: 48,
          ),
          onPressed: () {
            setState(() {
              if (controller.value.isPlaying) {
                controller.pause();
              } else {
                controller.play();
              }
            });
          },
        ),
      ],
    );
  }
  
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Construire la section de commentaires
  List<Widget> _buildCommentsList(List<Map<String, dynamic>> comments) {
    final List<Widget> commentWidgets = [];
    
    for (final commentMap in comments) {
      final comment = Comment.fromJson(commentMap);
      commentWidgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: CommentTile(
            comment: comment,
            onLike: () => _handleCommentLike(comment),
            onReply: () => _handleCommentReply(comment.authorName),
          ),
        ),
      );
    }
    
    return commentWidgets;
  }
  
  void _handleCommentLike(Comment comment) {
    // TODO: Implémenter le like de commentaire
  }
  
  void _handleCommentReply(String authorName) {
    _commentController.text = '@$authorName ';
    _commentController.selection = TextSelection.fromPosition(
      TextPosition(offset: _commentController.text.length),
    );
    
    // Focus sur le champ de commentaire
    FocusScope.of(context).requestFocus(_focusNode);
  }
  
  void _handleLike() async {
    try {
      // Optimistic update
      setState(() {
        final bool isCurrentlyLiked = _postData.isLiked ?? false;
        final int currentLikes = _postData.likesCount ?? 0;
        
        _postData = _postData.copyWith(
          isLiked: !isCurrentlyLiked,
          likesCount: isCurrentlyLiked ? currentLikes - 1 : currentLikes + 1,
        );
      });
      
      // Call API
      await _apiService.toggleLike(widget.userId, _postData.id);
    } catch (e) {
      print('❌ Error liking post: $e');
      
      // Revert on error
      setState(() {
        final bool isCurrentlyLiked = _postData.isLiked ?? false;
        final int currentLikes = _postData.likesCount ?? 0;
        
        _postData = _postData.copyWith(
          isLiked: !isCurrentlyLiked,
          likesCount: isCurrentlyLiked ? currentLikes - 1 : currentLikes + 1,
        );
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erreur lors de l\'interaction. Veuillez réessayer.'),
        ),
      );
    }
  }
  
  void _handleInterested() async {
    try {
      // Optimistic update
      setState(() {
        final bool isCurrentlyInterested = _postData.isInterested ?? false;
        final int currentInterested = _postData.interestedCount ?? 0;
        
        _postData = _postData.copyWith(
          isInterested: !isCurrentlyInterested,
          interestedCount: isCurrentlyInterested 
              ? (currentInterested > 0 ? currentInterested - 1 : 0)
              : currentInterested + 1,
        );
      });
      
      // Call API
      await _apiService.markInterested(
        widget.userId,
        _postData.id,
        isLeisureProducer: _postData.isLeisureProducer ?? false,
        interested: !(_postData.isInterested ?? false),
        source: 'post_detail',
      );
    } catch (e) {
      print('❌ Error marking interested: $e');
      
      // Revert on error
      setState(() {
        final bool isCurrentlyInterested = _postData.isInterested ?? false;
        final int currentInterested = _postData.interestedCount ?? 0;
        
        _postData = _postData.copyWith(
          isInterested: !isCurrentlyInterested,
          interestedCount: isCurrentlyInterested 
              ? (currentInterested > 0 ? currentInterested - 1 : 0)
              : currentInterested + 1,
        );
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erreur lors de l\'interaction. Veuillez réessayer.'),
        ),
      );
    }
  }
  
  void _handleChoice() async {
    try {
      // Optimistic update
      setState(() {
        final bool isCurrentlyChoice = _postData.isChoice ?? false;
        
        _postData = _postData.copyWith(
          isChoice: !isCurrentlyChoice,
          choiceCount: _postData.choiceCount != null 
              ? (isCurrentlyChoice ? (_postData.choiceCount! - 1) : (_postData.choiceCount! + 1))
              : (isCurrentlyChoice ? 0 : 1),
        );
      });
      
      // Call API
      await _apiService.markChoice(widget.userId, _postData.id);
    } catch (e) {
      print('❌ Error marking choice: $e');
      
      // Revert on error
      setState(() {
        final bool isCurrentlyChoice = _postData.isChoice ?? false;
        
        _postData = _postData.copyWith(
          isChoice: !isCurrentlyChoice,
          choiceCount: _postData.choiceCount != null 
              ? (isCurrentlyChoice ? (_postData.choiceCount! - 1) : (_postData.choiceCount! + 1))
              : (isCurrentlyChoice ? 0 : 1),
        );
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erreur lors de l\'interaction. Veuillez réessayer.'),
        ),
      );
    }
  }
  
  void _handleAddComment() {
    if (_commentController.text.isEmpty) return;
    
    setState(() {
      // Créer un nouveau commentaire factice
      final newComment = {
        'authorId': widget.userId,
        'authorName': 'Vous',
        'authorAvatar': 'https://randomuser.me/api/portraits/men/1.jpg',
        'text': _commentController.text,
        'date': DateTime.now(),
        'likes': 0,
      };
      
      // Ajouter le commentaire à la liste
      commentsMapList.insert(0, newComment);
      
      // Incrémenter le compteur de commentaires
      _postData = _postData.copyWith(commentsCount: (_postData.commentsCount as int) + 1);
      
      // Effacer le champ de commentaire
      _commentController.clear();
    });
    
    // Analyser l'action de commentaire
    _analyticsService.trackUserAction(
      'add_comment',
      {
        'post_id': _postData.id,
        'author_id': _postData.authorId,
      },
    );
  }
  
  void _showPostOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.bookmark_border),
              title: const Text('Enregistrer le post'),
              onTap: () {
                Navigator.pop(context);
                _handleSavePost();
              },
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Partager'),
              onTap: () {
                Navigator.pop(context);
                // Handle share post
              },
            ),
            ListTile(
              leading: const Icon(Icons.report_outlined),
              title: const Text('Signaler'),
              onTap: () {
                Navigator.pop(context);
                // Handle report post
              },
            ),
          ],
        ),
      ),
    );
  }
  
  void _handleSavePost() async {
    try {
      final success = await _apiService.savePost(widget.userId, _postData.id);
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post enregistré avec succès'),
          ),
        );
      }
    } catch (e) {
      print('❌ Error saving post: $e');
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erreur lors de l\'enregistrement du post'),
        ),
      );
    }
  }
  
  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inSeconds < 60) {
      return 'À l\'instant';
    } else if (difference.inMinutes < 60) {
      return 'Il y a ${difference.inMinutes} min';
    } else if (difference.inHours < 24) {
      return 'Il y a ${difference.inHours} h';
    } else if (difference.inDays < 7) {
      return 'Il y a ${difference.inDays} j';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }

  void _toggleControlsVisibility() {
    setState(() {
      _showControls = !_showControls;
    });
  }
}

// Ajouter une extension pour adapter le modèle Post si elle n'existe pas déjà
extension PostAdapter on Post {
  // Propriétés calculées pour la compatibilité
  List<media_model.Media> get media => 
      imageUrl != null ? [media_model.Media(url: imageUrl!, type: 'image')] : [];
  
  String? get authorId => userId;
  
  String? get authorAvatar => userPhotoUrl;
  
  String? get authorName => userName;
  
  DateTime get postedAt => createdAt;
  
  String get content => description;
  
  String get title => metadata?['title'] ?? '';
}

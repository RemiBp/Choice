import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import '../models/post.dart';
import '../models/comment.dart';
import '../models/media.dart';
import '../services/api_service.dart';
import '../widgets/choice_carousel.dart';

class PostDetailScreen extends StatefulWidget {
  final dynamic post;
  final String userId;

  const PostDetailScreen({
    Key? key, 
    required this.post,
    required this.userId,
  }) : super(key: key);

  @override
  _PostDetailScreenState createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _commentController = TextEditingController();
  final Map<String, VideoPlayerController> _videoControllers = {};
  final ChoiceCarouselController _carouselController = ChoiceCarouselController();
  
  late Post _postData;
  bool _isPostDataInitialized = false;
  bool _isCommenting = false;
  
  @override
  void initState() {
    super.initState();
    _initializePostData();
  }
  
  void _initializePostData() {
    if (widget.post is Post) {
      _postData = widget.post;
      _isPostDataInitialized = true;
      _initializeVideoControllers();
    } else if (widget.post is Map<String, dynamic>) {
      // Convert dynamic Map to Post object
      _convertDynamicPostToPost().then((post) {
        setState(() {
          _postData = post;
          _isPostDataInitialized = true;
        });
        _initializeVideoControllers();
      });
    }
  }
  
  Future<Post> _convertDynamicPostToPost() async {
    final Map<String, dynamic> postMap = widget.post;
    
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
    List<Media> mediaItems = [];
    if (postMap['media'] is List) {
      for (var media in postMap['media']) {
        if (media is Map) {
          final url = media['url'] ?? '';
          final type = media['type'] ?? 'image';
          
          if (url.isNotEmpty) {
            mediaItems.add(Media(
              url: url,
              type: type,
              width: media['width']?.toDouble() ?? 0.0,
              height: media['height']?.toDouble() ?? 0.0,
            ));
          }
        }
      }
    }
    
    // Convert comments
    List<Comment> comments = [];
    if (postMap['comments'] is List) {
      for (var comment in postMap['comments']) {
        if (comment is Map) {
          comments.add(Comment(
            id: comment['_id'] ?? '',
            authorId: comment['author_id'] ?? '',
            authorName: comment['author_name'] ?? '',
            username: comment['username'] ?? comment['author_name'] ?? '',
            authorAvatar: comment['author_avatar'] ?? '',
            content: comment['content'] ?? '',
            postedAt: comment['posted_at'] != null 
                ? DateTime.parse(comment['posted_at'].toString())
                : comment['created_at'] != null
                    ? DateTime.parse(comment['created_at'].toString())
                    : DateTime.now(),
          ));
        }
      }
    }
    
    // Return constructed Post object
    return Post(
      id: postId,
      authorId: authorId,
      authorName: authorName,
      authorAvatar: authorAvatar,
      content: content,
      postedAt: postedAt,
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
      comments: comments,
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
                                backgroundImage: CachedNetworkImageProvider(
                                  _postData.authorAvatar.isNotEmpty
                                      ? _postData.authorAvatar
                                      : 'https://via.placeholder.com/150',
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _postData.authorName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      _formatTimestamp(_postData.postedAt),
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
                        if (_postData.content.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: Text(
                              _postData.content,
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
                                    : CachedNetworkImage(
                                        imageUrl: media.url,
                                        fit: BoxFit.contain,
                                        placeholder: (context, url) => const Center(
                                          child: CircularProgressIndicator(),
                                        ),
                                        errorWidget: (context, url, error) => const Center(
                                          child: Icon(
                                            Icons.error,
                                            color: Colors.white60,
                                            size: 48,
                                          ),
                                        ),
                                      ),
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
                              if (_postData.isProducerPost) ...[
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
                                    '${_postData.comments.length}',
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
                                  icon: _postData.isLiked == true
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  label: 'Like',
                                  color: _postData.isLiked == true
                                      ? Colors.red[400]!
                                      : Colors.grey[700]!,
                                  onPressed: _handleLike,
                                ),
                              ),
                              
                              if (_postData.isProducerPost) ...[
                                Expanded(
                                  child: _buildActionButton(
                                    icon: _postData.isInterested
                                        ? Icons.star
                                        : Icons.star_border,
                                    label: 'Intéressé',
                                    color: _postData.isInterested
                                        ? Colors.amber[700]!
                                        : Colors.grey[700]!,
                                    onPressed: _handleInterested,
                                  ),
                                ),
                                
                                Expanded(
                                  child: _buildActionButton(
                                    icon: _postData.isChoice
                                        ? Icons.check_box
                                        : Icons.check_box_outline_blank,
                                    label: 'Choice',
                                    color: _postData.isChoice
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
                                    FocusScope.of(context).requestFocus(FocusNode());
                                    // Scroll to comment field
                                    WidgetsBinding.instance.addPostFrameCallback((_) {
                                      // Focus comment field
                                      FocusScope.of(context).requestFocus(FocusNode());
                                    });
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
                                'Commentaires (${_postData.comments.length})',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(height: 16),
                              
                              // Comment list
                              if (_postData.comments.isEmpty)
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
                                ..._postData.comments.map(_buildCommentItem).toList(),
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
  
  Widget _buildCommentItem(Comment comment) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundImage: CachedNetworkImageProvider(
              comment.authorAvatar.isNotEmpty
                  ? comment.authorAvatar
                  : 'https://via.placeholder.com/150',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      comment.authorName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatTimestamp(comment.postedAt),
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  comment.content,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    TextButton(
                      onPressed: () {
                        // Like comment
                      },
                      style: TextButton.styleFrom(
                        minimumSize: Size.zero,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Like',
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 12,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        // Reply to comment
                        _commentController.text = '@${comment.authorName} ';
                        FocusScope.of(context).requestFocus(FocusNode());
                      },
                      style: TextButton.styleFrom(
                        minimumSize: Size.zero,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Répondre',
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
      await _apiService.markInterested(widget.userId, _postData.id);
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
        final bool isCurrentlyInterested = _postData.isInterested;
        final int currentInterested = _postData.interestedCount;
        
        _postData = _postData.copyWith(
          isInterested: !isCurrentlyInterested,
          interestedCount: isCurrentlyInterested 
              ? currentInterested - 1 
              : currentInterested + 1,
        );
      });
      
      // Call API
      await _apiService.markInterested(
        widget.userId,
        _postData.id,
        isLeisureProducer: _postData.isLeisureProducer,
      );
    } catch (e) {
      print('❌ Error marking interested: $e');
      
      // Revert on error
      setState(() {
        final bool isCurrentlyInterested = _postData.isInterested;
        final int currentInterested = _postData.interestedCount;
        
        _postData = _postData.copyWith(
          isInterested: !isCurrentlyInterested,
          interestedCount: isCurrentlyInterested 
              ? currentInterested - 1 
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
        final bool isCurrentlyChoice = _postData.isChoice;
        final int currentChoice = _postData.choiceCount;
        
        _postData = _postData.copyWith(
          isChoice: !isCurrentlyChoice,
          choiceCount: isCurrentlyChoice 
              ? currentChoice - 1 
              : currentChoice + 1,
        );
      });
      
      // Call API
      await _apiService.markChoice(widget.userId, _postData.id);
    } catch (e) {
      print('❌ Error marking choice: $e');
      
      // Revert on error
      setState(() {
        final bool isCurrentlyChoice = _postData.isChoice;
        final int currentChoice = _postData.choiceCount;
        
        _postData = _postData.copyWith(
          isChoice: !isCurrentlyChoice,
          choiceCount: isCurrentlyChoice 
              ? currentChoice - 1 
              : currentChoice + 1,
        );
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erreur lors de l\'interaction. Veuillez réessayer.'),
        ),
      );
    }
  }
  
  void _handleAddComment() async {
    final commentText = _commentController.text.trim();
    if (commentText.isEmpty) return;
    
    setState(() {
      _isCommenting = true;
    });
    
    try {
      // Call API to add comment
      final Comment newComment = await _apiService.addComment(
        _postData.id,
        widget.userId,
        commentText,
      );
      
      // Comment returned from API might not have username field set properly
      // We ensure it has username by using the authorName as fallback if needed
      print('🧪 Comment from API: ${newComment.username}');
      
      // Update state
      setState(() {
        _isCommenting = false;
        _commentController.clear();
        
        // Add new comment to post
        final List<Comment> updatedComments = List.from(_postData.comments);
        updatedComments.add(newComment);
        _postData = _postData.copyWith(comments: updatedComments);
      });
    } catch (e) {
      print('❌ Error adding comment: $e');
      
      setState(() {
        _isCommenting = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erreur lors de l\'ajout du commentaire. Veuillez réessayer.'),
        ),
      );
    }
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
}
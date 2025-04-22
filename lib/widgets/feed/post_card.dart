import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../../models/post.dart';
import '../../models/media.dart';
import '../../models/comment.dart';
import 'post_media.dart';
import 'post_interaction_bar.dart';
import 'comments_sheet.dart';
import 'media_detail_view.dart';
import '../../utils/constants.dart';
import 'animations/double_tap_animation.dart';
import '../../services/api_service.dart';
import '../../screens/profile_screen.dart';
import '../../screens/post_detail_screen.dart';
import '../translatable_content.dart';
import '../../utils.dart' show getImageProvider;

typedef PostCallback = Function(Post);

class PostCard extends StatefulWidget {
  final Post post;
  final PostCallback onLike;
  final PostCallback onInterested;
  final PostCallback onChoice;
  final PostCallback onCommentTap;
  final VoidCallback onUserTap;
  final PostCallback onShare;
  final PostCallback onSave;

  const PostCard({
    Key? key,
    required this.post,
    required this.onLike,
    required this.onInterested,
    required this.onChoice,
    required this.onCommentTap,
    required this.onUserTap,
    required this.onShare,
    required this.onSave,
  }) : super(key: key);

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  bool _isLiked = false;
  bool _isSaved = false;
  bool _isInterested = false;
  bool _isChoice = false;
  int _likesCount = 0;
  int _interestedCount = 0;
  int _choiceCount = 0;
  int _commentsCount = 0;
  bool _isExpanded = false;
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmittingComment = false;
  bool _isVideoPlaying = false;
  VideoPlayerController? _videoController;
  bool _isMuted = true;
  bool _hasRecordedView = false;
  final ApiService _apiService = ApiService();
  Post get post => widget.post;

  @override
  void initState() {
    super.initState();
    _initializeState();
    if (post.media.isNotEmpty && post.media.first.type == 'video') {
      _initVideoController(Uri.parse(post.media.first.url));
    }
    
    // Enregistrer la vue du post après un court délai
    // pour s'assurer que le post est réellement affiché à l'utilisateur
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _recordView();
    });
  }

  void _initializeState() {
    _isLiked = post.isLiked ?? false;
    _isInterested = post.isInterested ?? false;
    _isChoice = post.isChoice ?? false;
    _likesCount = post.likesCount ?? 0;
    _interestedCount = post.interestedCount ?? 0;
    _choiceCount = post.choiceCount ?? 0;
    _commentsCount = _getCommentsCount(post);
  }

  void _initVideoController(Uri videoUri) async {
    _videoController = VideoPlayerController.networkUrl(videoUri);
    await _videoController!.initialize();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Enregistrer la vue du post
    _recordView();
    
    return Container(
      margin: const EdgeInsets.only(bottom: 1),
      decoration: BoxDecoration(
        color: (post.isProducerPost ?? false) ? Colors.black : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: (post.isProducerPost ?? false) ? Colors.grey[900]! : Colors.grey[200]!,
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          if (post.media.isNotEmpty) _buildMedia(),
          _buildContent(),
          _buildInteractionBar(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final authorImageProvider = getImageProvider(post.authorAvatar);
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Hero(
            tag: 'profile-${post.authorId}',
            child: GestureDetector(
              onTap: _openProfile,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: (post.isLeisureProducer ?? false) 
                        ? Colors.purple.shade300 
                        : ((post.isProducerPost ?? false) ? Colors.amber.shade300 : Colors.blue.shade300),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: authorImageProvider != null
                    ? Image(
                        image: authorImageProvider,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: Colors.grey[200],
                          child: Center(
                            child: Icon(
                              (post.isProducerPost ?? false) ? Icons.store : Icons.person,
                              color: Colors.grey[400],
                            ),
                          ),
                        ),
                      )
                    : Center(
                        child: Icon(
                          (post.isProducerPost ?? false) ? Icons.store : Icons.person,
                          color: Colors.grey[400],
                        ),
                      ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: _openProfile,
                  child: Text(
                    post.authorName ?? 'Utilisateur',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: (post.isProducerPost ?? false) ? Colors.white : Colors.black,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                if (post.locationName != null && post.locationName!.isNotEmpty)
                  Text(
                    post.locationName!,
                    style: TextStyle(
                      fontSize: 12,
                      color: (post.isProducerPost ?? false) ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                if (post.postedAt != null)
                  Text(
                    _formatTimeDifference(post.postedAt!),
                    style: TextStyle(
                      fontSize: 11,
                      color: (post.isProducerPost ?? false) ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.more_horiz,
              color: (post.isProducerPost ?? false) ? Colors.white : Colors.black,
            ),
            onPressed: () => _showPostOptions(context),
          ),
        ],
      ),
    );
  }

  Widget _buildMedia() {
    return DoubleTapAnimation(
      onDoubleTap: () {
        if (!_isLiked) {
          setState(() {
            _isLiked = true;
            _likesCount++;
          });
          widget.onLike(post);
        }
      },
      child: AspectRatio(
        aspectRatio: 1,
        child: PageView.builder(
          itemCount: post.media.length,
          itemBuilder: (context, index) {
            final media = post.media[index];
            final mediaProvider = getImageProvider(media.url);
            if (media.type == 'video') {
              return _buildVideoPlayer(media.url);
            }
            return mediaProvider != null
              ? Image(
                  image: mediaProvider,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.error),
                )
              : Container(
                  color: Colors.grey[200],
                  child: const Center(child: Icon(Icons.broken_image)),
                );
          },
        ),
      ),
    );
  }

  Widget _buildVideoPlayer(String videoUrl) {
    if (_videoController == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        VideoPlayer(_videoController!),
        if (!_isVideoPlaying)
          IconButton(
            icon: const Icon(Icons.play_arrow, size: 50, color: Colors.white),
            onPressed: () {
              setState(() {
                _isVideoPlaying = true;
                _videoController!.play();
              });
            },
          ),
      ],
    );
  }

  Widget _buildContent() {
    if (post.description?.isEmpty ?? true) return const SizedBox();

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            post.description!,
            style: TextStyle(
              fontSize: 14,
              color: (post.isProducerPost ?? false) ? Colors.white : Colors.black87,
            ),
            maxLines: _isExpanded ? null : 3,
            overflow: _isExpanded ? null : TextOverflow.ellipsis,
          ),
          if (post.description!.length > 100)
            GestureDetector(
              onTap: () {
                setState(() {
                  _isExpanded = !_isExpanded;
                });
              },
              child: Text(
                _isExpanded ? 'Voir moins' : 'Voir plus',
                style: TextStyle(
                  color: (post.isProducerPost ?? false) ? Colors.blue[300] : Colors.blue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          // Post content
          if (post.content?.isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TranslatableContent(
                text: post.content ?? '',
                style: const TextStyle(fontSize: 16, height: 1.3),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInteractionBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                // Like button
                _buildInteractionButton(
                  icon: _isLiked ? Icons.favorite : Icons.favorite_border,
                  label: 'J\'aime',
                  count: _likesCount,
                  isActive: _isLiked,
                  color: Colors.red,
                  onPressed: () => _handleLike(),
                ),
                
                // Interest button (for producer posts)
                if (post.isProducerPost ?? false)
                  _buildInteractionButton(
                    icon: _isInterested ? Icons.star : Icons.star_border,
                    label: 'Intéressé',
                    count: _interestedCount,
                    isActive: _isInterested,
                    color: (post.isLeisureProducer ?? false) ? Colors.purple : Colors.amber,
                    onPressed: () => _handleInterested(),
                  ),
                
                // Comment button
                _buildInteractionButton(
                  icon: Icons.chat_bubble_outline,
                  label: 'Commentaires',
                  count: _commentsCount,
                  isActive: false,
                  color: Colors.blue,
                  onPressed: () => widget.onCommentTap(post),
                ),
              ],
            ),
          ),
          
          // Right side buttons
          Row(
            children: [
              // Share button
              IconButton(
                onPressed: () => widget.onShare(post),
                icon: Icon(
                  Icons.share_outlined,
                  color: (post.isProducerPost ?? false) ? Colors.white : Colors.black54,
                  size: 22,
                ),
              ),
              
              // Save button
              IconButton(
                onPressed: () {
                  setState(() {
                    _isSaved = !_isSaved;
                  });
                  widget.onSave(post);
                },
                icon: Icon(
                  _isSaved ? Icons.bookmark : Icons.bookmark_border,
                  color: _isSaved
                      ? ((post.isProducerPost ?? false) ? Colors.white : Colors.black)
                      : ((post.isProducerPost ?? false) ? Colors.white70 : Colors.black54),
                  size: 22,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInteractionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
    bool isActive = false,
    int? count,
  }) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(
        icon,
        color: isActive ? color : Colors.grey[600],
        size: 20,
      ),
      label: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: isActive ? color : Colors.grey[600],
              fontSize: 14,
            ),
          ),
          if (count != null && count > 0)
            Padding(
              padding: const EdgeInsets.only(left: 4.0),
              child: Text(
                count.toString(),
                style: TextStyle(
                  color: isActive ? color : Colors.grey[600],
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        minimumSize: Size.zero,
      ),
    );
  }

  void _showPostOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: (post.isProducerPost ?? false) ? Colors.grey[900] : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                Icons.flag,
                color: (post.isProducerPost ?? false) ? Colors.white : Colors.black,
              ),
              title: Text(
                'Signaler',
                style: TextStyle(
                  color: (post.isProducerPost ?? false) ? Colors.white : Colors.black,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement report functionality
              },
            ),
            ListTile(
              leading: Icon(
                Icons.copy,
                color: (post.isProducerPost ?? false) ? Colors.white : Colors.black,
              ),
              title: Text(
                'Copier le lien',
                style: TextStyle(
                  color: (post.isProducerPost ?? false) ? Colors.white : Colors.black,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement copy link functionality
              },
            ),
            ListTile(
              leading: Icon(
                Icons.block,
                color: (post.isProducerPost ?? false) ? Colors.white : Colors.black,
              ),
              title: Text(
                'Masquer',
                style: TextStyle(
                  color: (post.isProducerPost ?? false) ? Colors.white : Colors.black,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement hide functionality
              },
            ),
          ],
        ),
      ),
    );
  }

  void _handleLike() {
    final wasLiked = _isLiked;
    setState(() {
      _isLiked = !_isLiked;
      _likesCount = _isLiked ? _likesCount + 1 : _likesCount - 1;
    });
    
    // Call the callback
    widget.onLike(post);
    
    // Show feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(wasLiked ? 'Post unliked' : 'Post liked'),
        duration: const Duration(seconds: 1),
        backgroundColor: wasLiked ? Colors.grey : Colors.pink,
      ),
    );
  }
  
  void _handleInterested() {
    final wasInterested = _isInterested;
    setState(() {
      _isInterested = !_isInterested;
      _interestedCount = _isInterested ? _interestedCount + 1 : _interestedCount - 1;
    });
    
    // Call the callback
    widget.onInterested(post);
    
    // Show feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(wasInterested ? 'Interest removed' : 'Interest added'),
        duration: const Duration(seconds: 1),
        backgroundColor: wasInterested 
            ? Colors.grey 
            : ((post.isLeisureProducer ?? false) ? Colors.purple : Colors.amber),
      ),
    );
  }

  // Format time difference
  String _formatTimeDifference(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);
    
    if (difference.inSeconds < 60) {
      return 'À l\'instant';
    } else if (difference.inMinutes < 60) {
      return 'Il y a ${difference.inMinutes} min';
    } else if (difference.inHours < 24) {
      return 'Il y a ${difference.inHours} h';
    } else if (difference.inDays < 7) {
      return 'Il y a ${difference.inDays} j';
    } else {
      return '${time.day}/${time.month}/${time.year}';
    }
  }

  // Enregistrer que l'utilisateur a vu ce post
  void _recordView() async {
    if (_hasRecordedView) return; // Éviter les doublons
    
    try {
      if (post.id.isNotEmpty) {
        await _apiService.recordPostView(post.id);
        
        setState(() {
          _hasRecordedView = true;
        });
      }
    } catch (e) {
      print('❌ Error recording post view: $e');
    }
  }

  void _openProfile() {
    final authorId = post.authorId ?? '';
    if (authorId.isNotEmpty) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ProfileScreen(userId: authorId),
        ),
      );
    }
  }

  // Vérifier si un post a des commentaires
  bool _hasComments(Post post) {
    return post.comments.isNotEmpty;
  }

  // Obtenir le nombre de commentaires
  int _getCommentsCount(Post post) {
    return post.commentsCount;
  }
}

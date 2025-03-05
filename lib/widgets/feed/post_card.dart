import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import '../../models/post.dart';
import '../../models/media.dart';
import '../../models/comment.dart';
import 'post_media.dart';
import 'post_interaction_bar.dart';
import 'comments_sheet.dart';
import 'media_detail_view.dart';
import '../../utils/constants.dart';

class PostCard extends StatelessWidget {
  final Post post;
  final Function(String) onInterested;
  final Function(String) onChoice;
  final Function(Post) onCommentTap;

  const PostCard({
    Key? key,
    required this.post,
    required this.onInterested,
    required this.onChoice,
    required this.onCommentTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 1),
      decoration: BoxDecoration(
        color: post.isProducerPost ? Colors.black : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: post.isProducerPost ? Colors.grey[900]! : Colors.grey[200]!,
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          if (post.media.isNotEmpty) _buildMedia(),
          _buildContent(),
          _buildInteractionBar(),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _navigateToProfile(context),
            child: Hero(
              tag: 'avatar-${post.id}',
              child: CircleAvatar(
                radius: 20,
                backgroundImage: CachedNetworkImageProvider(post.authorAvatar),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post.authorName,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: post.isProducerPost ? Colors.white : Colors.black,
                  ),
                ),
                Text(
                  _formatTimeAgo(post.postedAt),
                  style: TextStyle(
                    fontSize: 13,
                    color: post.isProducerPost ? Colors.white60 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.more_horiz,
              color: post.isProducerPost ? Colors.white60 : Colors.black54,
            ),
            onPressed: () => _showOptions(context),
          ),
        ],
      ),
    );
  }

  Widget _buildMedia() {
    return AspectRatio(
      aspectRatio: 1,
      child: PageView.builder(
        itemCount: post.media.length,
        itemBuilder: (context, index) {
          final media = post.media[index];
          if (media.type == MediaType.video) {
            return _VideoPlayer(url: media.url);
          }
          return CachedNetworkImage(
            imageUrl: media.url,
            fit: BoxFit.cover,
            placeholder: (context, url) => const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
              ),
            ),
            errorWidget: (context, url, error) => const Icon(Icons.error),
          );
        },
      ),
    );
  }

  Widget _buildContent() {
    if (post.content.isEmpty) return const SizedBox();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Text(
        post.content,
        style: TextStyle(
          fontSize: 14,
          color: post.isProducerPost ? Colors.white : Colors.black87,
        ),
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildInteractionBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          _InteractionButton(
            icon: Icons.star,
            text: 'Interest',
            isActive: post.isInterested,
            activeColor: Colors.amber,
            onTap: () => onInterested(post.id),
          ),
          const SizedBox(width: 20),
          _InteractionButton(
            icon: Icons.check_circle_outline,
            text: 'Choice',
            isActive: post.isChoice,
            activeColor: Colors.green,
            onTap: () => onChoice(post.id),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.comment_outlined),
            color: post.isProducerPost ? Colors.white70 : Colors.black54,
            onPressed: () => onCommentTap(post),
          ),
        ],
      ),
    );
  }

  void _showMediaDetail(BuildContext context, Post post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MediaDetailView(
        media: post.media,
        comments: post.comments,
        postId: post.id,
        onCommentSubmitted: (comment) => _handleNewComment(post.id, comment),
        isProducerPost: post.isProducerPost,
      ),
    );
  }

  void _navigateToProfile(BuildContext context) {
    // Implémentation de la navigation vers le profil
  }

  String _formatTimeAgo(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h';
    }
    return '${difference.inDays}d';
  }

  void _showOptions(BuildContext context) {
    // Implémentation du menu d'options
  }
  
  void _handleNewComment(String postId, String comment) {
    // This method would typically call a function passed from the parent
    // In this case, we would forward it to a callback from the parent widget
    // For now, it's here as a placeholder
  }
}

class _VideoPlayer extends StatefulWidget {
  final String url;

  const _VideoPlayer({required this.url});

  @override
  State<_VideoPlayer> createState() => _VideoPlayerState();
}

class _VideoPlayerState extends State<_VideoPlayer> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    _controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.url),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );

    try {
      await _controller.initialize();
      if (mounted) {
        setState(() => _isInitialized = true);
      }
    } catch (e) {
      debugPrint('Erreur d\'initialisation vidéo: $e');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          _controller.value.isPlaying ? _controller.pause() : _controller.play();
        });
      },
      child: AspectRatio(
        aspectRatio: _controller.value.aspectRatio,
        child: Stack(
          alignment: Alignment.center,
          children: [
            VideoPlayer(_controller),
            if (!_controller.value.isPlaying)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                  size: 50,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _InteractionButton extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool isActive;
  final Color activeColor;
  final VoidCallback onTap;

  const _InteractionButton({
    required this.icon,
    required this.text,
    required this.isActive,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(
            icon,
            color: isActive ? activeColor : Colors.grey,
            size: 20,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: isActive ? activeColor : Colors.grey,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

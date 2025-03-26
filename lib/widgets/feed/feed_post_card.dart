import 'package:flutter/material.dart';
import 'dart:math';
import '../../models/post.dart';
import '../../services/api_service.dart';
import '../../screens/post_detail_screen.dart';
import '../profile/user_avatar.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../post_interaction_bar.dart';

class FeedPostCard extends StatefulWidget {
  final Post post;
  final String currentUserId;
  final VoidCallback onUserTap;
  final VoidCallback onLocationTap;
  final Function(bool) onInterestChanged;
  final Function(bool) onChoiceChanged;
  final Function() onLike;
  final Function() onInterested;
  final Function() onChoice;
  final Function() onComment;

  const FeedPostCard({
    Key? key,
    required this.post,
    required this.currentUserId,
    required this.onUserTap,
    required this.onLocationTap,
    required this.onInterestChanged,
    required this.onChoiceChanged,
    required this.onLike,
    required this.onInterested,
    required this.onChoice,
    required this.onComment,
  }) : super(key: key);

  @override
  State<FeedPostCard> createState() => _FeedPostCardState();
}

class _FeedPostCardState extends State<FeedPostCard> {
  final ApiService _apiService = ApiService();
  bool _isInterested = false;
  bool _hasChosen = false;
  bool _isLoading = false;
  bool _showComments = false;

  @override
  void initState() {
    super.initState();
    _isInterested = widget.post.interests.contains(widget.currentUserId);
    _hasChosen = widget.post.choices.contains(widget.currentUserId);
  }

  Future<void> _toggleInterest() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final success = await _apiService.markInterested(
        widget.currentUserId,
        widget.post.id,
        isLeisureProducer: widget.post.type == 'leisure',
      );

      if (success) {
        setState(() {
          _isInterested = !_isInterested;
        });
        widget.onInterestChanged(_isInterested);
      }
    } catch (e) {
      print('❌ Erreur lors du like: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleChoice() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final success = await _apiService.markChoice(
        widget.currentUserId,
        widget.post.id,
      );

      if (success) {
        setState(() {
          _hasChosen = !_hasChosen;
        });
        widget.onChoiceChanged(_hasChosen);
      }
    } catch (e) {
      print('❌ Erreur lors du choice: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PostDetailScreen(
              postId: widget.post.id,
              userId: widget.currentUserId,
            ),
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.all(8),
        elevation: 1.0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.0),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User info and timestamp
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: widget.onUserTap,
                    child: CircleAvatar(
                      backgroundImage: CachedNetworkImageProvider(
                        widget.post.authorAvatar.isNotEmpty
                            ? widget.post.authorAvatar
                            : 'https://via.placeholder.com/40',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.post.authorName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (widget.post.locationName != null && widget.post.locationName!.isNotEmpty)
                          Text(
                            widget.post.locationName!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Timestamp and options
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _formatTimestamp(widget.post.postedAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          // Show options menu
                        },
                        child: const Icon(
                          Icons.more_horiz,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Post content
            if (widget.post.content.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Text(widget.post.content),
              ),

            // Post media
            if (widget.post.media.isNotEmpty)
              GestureDetector(
                onTap: () {
                  // View media in fullscreen
                },
                child: widget.post.media.first.type == 'video'
                    ? _buildVideoPreview(widget.post.media.first.url)
                    : CachedNetworkImage(
                        imageUrl: widget.post.media.first.url,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const Center(
                          child: CircularProgressIndicator(),
                        ),
                        errorWidget: (context, url, error) => const Icon(Icons.error),
                      ),
              ),

            // Interaction bar
            PostInteractionBar(
              isLiked: widget.post.isLiked ?? false,
              isInterested: widget.post.isInterested ?? false,
              isChoice: widget.post.isChoice ?? false,
              likesCount: widget.post.likesCount ?? 0,
              interestedCount: widget.post.interestedCount ?? 0,
              choiceCount: widget.post.choiceCount ?? 0,
              commentsCount: widget.post.comments.length,
              onLike: () => widget.onLike(),
              onInterested: () => widget.onInterested(),
              onChoice: () => widget.onChoice(),
              onComment: () => widget.onComment(),
              onShare: () {}, // Implémentation du partage à venir
              isProducerPost: widget.post.isProducerPost,
              isLeisureProducer: widget.post.isLeisureProducer,
            ),

            // Recent comments
            if (widget.post.comments.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 12, right: 12, bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < min(2, widget.post.comments.length); i++)
                      _buildCommentPreview(widget.post.comments[i]),
                    if (widget.post.comments.length > 2)
                      TextButton(
                        onPressed: () => widget.onComment(),
                        child: Text(
                          'Voir tous les ${widget.post.comments.length} commentaires',
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentPreview(Map<String, dynamic> comment) {
    final String avatarUrl = comment['author_avatar'] ?? '';
    final String authorName = comment['author_name'] ?? 'Utilisateur';
    final String content = comment['content'] ?? '';
    
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundImage: CachedNetworkImageProvider(
              avatarUrl.isNotEmpty 
                  ? avatarUrl 
                  : 'https://via.placeholder.com/24'
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(color: Colors.black, fontSize: 13),
                children: [
                  TextSpan(
                    text: '$authorName ',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: content),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime postedAt) {
    // Implement the logic to format the timestamp based on the current time
    return '${DateTime.now().difference(postedAt).inMinutes} minutes ago';
  }

  Widget _buildVideoPreview(String url) {
    // Implement the logic to build a video preview
    return Container(
      height: 200,
      color: Colors.black,
      child: const Center(
        child: Icon(
          Icons.play_circle_fill,
          color: Colors.white,
          size: 48,
        ),
      ),
    );
  }
} 
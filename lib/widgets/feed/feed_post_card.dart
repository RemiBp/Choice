import 'package:flutter/material.dart';
import 'dart:math';
import '../../models/post.dart';
import '../../services/api_service.dart';
import '../../screens/post_detail_screen.dart';
import '../profile/user_avatar.dart';
import '../../widgets/translatable_content.dart';
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
  final Function()? onRefresh;

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
    this.onRefresh,
  }) : super(key: key);

  @override
  State<FeedPostCard> createState() => _FeedPostCardState();
}

class _FeedPostCardState extends State<FeedPostCard> {
  final ApiService _apiService = ApiService();
  bool _isInterested = false;
  bool _hasChosen = false;
  bool _isLiked = false;
  bool _isLoading = false;
  bool _showComments = false;

  @override
  void initState() {
    super.initState();
    _isInterested = widget.post.interests.contains(widget.currentUserId);
    _hasChosen = widget.post.choices.contains(widget.currentUserId);
    _isLiked = widget.post.likes.contains(widget.currentUserId);
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

  Future<void> _toggleLike() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final success = await _apiService.toggleLike(
        widget.currentUserId,
        widget.post.id,
      );

      if (success) {
        setState(() {
          _isLiked = !_isLiked;
        });
        widget.onLike();
      }
    } catch (e) {
      print('❌ Erreur lors du like: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Format timestamp for display
  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()}a';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()}m';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}j';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}min';
    } else {
      return 'À l\'instant';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
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
                  child: GestureDetector(
                    onTap: widget.onUserTap,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                widget.post.authorName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (widget.post.isAutomated == true)
                              const SizedBox(width: 4),
                            if (widget.post.isAutomated == true)
                              const Text(
                                '🤖',
                                style: TextStyle(fontSize: 14),
                              ),
                          ],
                        ),
                        if (widget.post.locationName != null && widget.post.locationName!.isNotEmpty)
                          GestureDetector(
                            onTap: widget.onLocationTap,
                            child: Text(
                              widget.post.locationName!,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                // Timestamp and post type badge
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
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: widget.post.isLeisureProducer 
                            ? Colors.purple.shade50
                            : (widget.post.isProducerPost ? Colors.amber.shade50 : Colors.blue.shade50),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        widget.post.isLeisureProducer 
                            ? 'Loisir' 
                            : (widget.post.isProducerPost ? 'Restaurant' : 'Utilisateur'),
                        style: TextStyle(
                          fontSize: 10,
                          color: widget.post.isLeisureProducer 
                              ? Colors.purple.shade700
                              : (widget.post.isProducerPost ? Colors.amber.shade700 : Colors.blue.shade700),
                          fontWeight: FontWeight.w500,
                        ),
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
              child: TranslatableContent(
                text: widget.post.content,
                style: const TextStyle(fontSize: 16),
              ),
            ),

          // Post media
          if (widget.post.media.isNotEmpty)
            GestureDetector(
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
              child: CachedNetworkImage(
                imageUrl: widget.post.media.first.url,
                fit: BoxFit.cover,
                placeholder: (context, url) => const Center(
                  child: CircularProgressIndicator(),
                ),
                errorWidget: (context, url, error) => const Icon(Icons.error),
              ),
            ),

          // Custom interaction bar
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Like button
                _buildInteractionButton(
                  icon: Icons.favorite,
                  activeIcon: Icons.favorite,
                  inactiveIcon: Icons.favorite_border,
                  activeColor: Colors.red,
                  inactiveColor: Colors.grey,
                  label: 'Like',
                  count: widget.post.likesCount ?? widget.post.likes.length,
                  isActive: _isLiked,
                  onPressed: _toggleLike,
                ),
                
                // Interest button (for producer posts)
                if (widget.post.isProducerPost || widget.post.isLeisureProducer)
                  _buildInteractionButton(
                    icon: Icons.star,
                    activeIcon: Icons.star,
                    inactiveIcon: Icons.star_border,
                    activeColor: Colors.amber,
                    inactiveColor: Colors.grey,
                    label: 'Intéressé',
                    count: widget.post.interestedCount ?? widget.post.interests.length,
                    isActive: _isInterested,
                    onPressed: _toggleInterest,
                  ),
                
                // Choice button (for producer posts)
                if (widget.post.isProducerPost || widget.post.isLeisureProducer)
                  _buildInteractionButton(
                    icon: Icons.check_circle,
                    activeIcon: Icons.check_circle,
                    inactiveIcon: Icons.check_circle_outline,
                    activeColor: Colors.green,
                    inactiveColor: Colors.grey,
                    label: 'Choice',
                    count: widget.post.choiceCount ?? widget.post.choices.length,
                    isActive: _hasChosen,
                    onPressed: _toggleChoice,
                  ),
                
                // Comments button
                IconButton(
                  icon: const Icon(Icons.chat_bubble_outline),
                  color: Colors.grey,
                  onPressed: widget.onComment,
                ),
                
                // Share button
                IconButton(
                  icon: const Icon(Icons.share_outlined),
                  color: Colors.grey,
                  onPressed: () {
                    // Handle sharing
                  },
                ),
              ],
            ),
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
                      onPressed: widget.onComment,
                      child: Text(
                        'Voir les ${widget.post.comments.length} commentaires',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // Build comment preview
  Widget _buildCommentPreview(Map<String, dynamic> comment) {
    final String authorName = comment['author_name'] ?? comment['authorName'] ?? 'Utilisateur';
    final String content = comment['content'] ?? '';
    
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: RichText(
        text: TextSpan(
          style: DefaultTextStyle.of(context).style,
          children: [
            TextSpan(
              text: authorName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(
              text: ' $content',
              style: const TextStyle(fontWeight: FontWeight.normal),
            ),
          ],
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  // Build interaction button
  Widget _buildInteractionButton({
    required IconData icon,
    required IconData activeIcon,
    required IconData inactiveIcon,
    required Color activeColor,
    required Color inactiveColor,
    required String label,
    required int count,
    required bool isActive,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            Icon(
              isActive ? activeIcon : inactiveIcon,
              color: isActive ? activeColor : inactiveColor,
              size: 20,
            ),
            const SizedBox(width: 4),
            Text(
              count > 0 ? count.toString() : label,
              style: TextStyle(
                fontSize: 14,
                color: isActive ? activeColor : inactiveColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _convertPostToMap() {
    return {
      'id': widget.post.id,
      'author_id': widget.post.authorId,
      'author_name': widget.post.authorName,
      'author_avatar': widget.post.authorAvatar,
      'content': widget.post.content,
      'media': widget.post.media.map((m) => m.toMap()).toList(),
      'likes': widget.post.likes,
      'interests': widget.post.interests,
      'choices': widget.post.choices,
      'comments': widget.post.comments,
      'likes_count': widget.post.likesCount ?? widget.post.likes.length,
      'interested_count': widget.post.interestedCount ?? widget.post.interests.length,
      'choice_count': widget.post.choiceCount ?? widget.post.choices.length,
      'isProducerPost': widget.post.isProducerPost,
      'isLeisureProducer': widget.post.isLeisureProducer,
    };
  }
} 
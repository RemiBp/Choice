import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:video_player/video_player.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/post.dart'; // Assuming Post model path
import '../../models/comment.dart'; // Assuming Comment model path
import '../../utils.dart'; // For getImageProvider AND HELPER FUNCTIONS
import '../../screens/producer_screen.dart'; // For navigation
import '../../screens/producerLeisure_screen.dart'; // For navigation
import '../../screens/wellness_producer_screen.dart'; // For navigation
import '../../screens/profile_screen.dart'; // For navigation
import '../../screens/reels_view_screen.dart'; // For reels view
// Import other necessary screens or services
// import '../../screens/post_detail_screen.dart'; // Example
// Correct import path for local widget
import '../choice_carousel.dart';

// --- REMOVED HELPER FUNCTIONS (Moved to utils.dart) ---
// Color _getPostTypeColor(dynamic post) { ... }
// String _getVisualBadge(dynamic post) { ... }
// String _getPostTypeLabel(dynamic post) { ... }
// String _formatTimestamp(DateTime timestamp) { ... }
// --- End Removed Helpers ---


class ProducerPostCard extends StatefulWidget {
  final dynamic post; // Can be Post or Map<String, dynamic>
  final String currentUserId;
  final Function(dynamic) onLike;
  final Function(dynamic) onComment;
  final Function(dynamic) onShare; // Placeholder
  final Function(dynamic) onShowStats;
  final Function(dynamic) onShowOptions;
  final Function(dynamic, String)? onNavigateToProfile; // Optional callback for profile navigation
  final Function(String, double, String?) onVisibilityChanged;
  final Map<String, VideoPlayerController> videoControllers; // Pass controllers map
  final Function(String, String) initializeVideoController; // Pass initialization function
  final Function(dynamic, String) openReelsView; // Pass function to open reels
  final Function(dynamic) openDetails; // Pass function to open details/comments


  const ProducerPostCard({
    Key? key,
    required this.post,
    required this.currentUserId,
    required this.onLike,
    required this.onComment,
    required this.onShare,
    required this.onShowStats,
    required this.onShowOptions,
    required this.onVisibilityChanged,
    required this.videoControllers,
    required this.initializeVideoController,
    required this.openReelsView,
    required this.openDetails,
    this.onNavigateToProfile,
  }) : super(key: key);

  @override
  _ProducerPostCardState createState() => _ProducerPostCardState();
}

class _ProducerPostCardState extends State<ProducerPostCard> {

  // Extracted data fields for easier access
  late String postId;
  late String content;
  late bool isProducerPost;
  late bool isLeisureProducer;
  late bool isWellnessProducer; // Added
  late String authorName;
  late String authorAvatar;
  late String authorId;
  late List<Map<String, dynamic>> mediaItems;
  late DateTime postedAt;
  late int likesCount;
  late int commentsCount;
  late bool isLikedByCurrentUser;
  late bool isAutomated;
  late bool hasReferencedEvent;
  late bool hasTarget;
  late String visualBadge;
  late String postTypeLabel;
  late Color postTypeColor;
  List<dynamic> comments = []; // Store comments data
  bool _isLiking = false; // Add state variable for like operation

  @override
  void initState() {
    super.initState();
    _extractPostData();
  }

  @override
  void didUpdateWidget(covariant ProducerPostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-extract data if the post object itself changes identity
    if (widget.post is Map && oldWidget.post is Map && widget.post['_id'] != oldWidget.post['_id']) {
       _extractPostData();
    } else if (widget.post is Post && oldWidget.post is Post && widget.post.id != oldWidget.post.id) {
        _extractPostData();
    }
    // TODO: Consider more granular updates if only specific fields like likes change
  }


  void _extractPostData() {
     if (widget.post is Post) {
        final p = widget.post as Post;
        postId = p.id;
        content = p.content ?? '';
        isProducerPost = p.isProducerPost ?? false;
        // Use the boolean flags set by backend pre-save hook preferably
        isLeisureProducer = p.isLeisureProducer ?? false;
        isWellnessProducer = p.isBeautyProducer ?? false; // Map from existing flag if needed
        authorId = p.authorId ?? '';
        authorName = p.authorName ?? 'Auteur inconnu';
        authorAvatar = p.authorAvatar ?? ''; // Backend should provide producer photo here
        mediaItems = p.media.map((m) => {'url': m.url, 'type': m.type}).toList();
        postedAt = p.postedAt ?? DateTime.now();
        likesCount = p.likesCount ?? 0;
        comments = p.comments; // Get comments list
        commentsCount = comments.length;
        isLikedByCurrentUser = p.isLiked ?? false;
        isAutomated = p.isAutomated ?? false;
        hasReferencedEvent = p.referencedEventId != null;
        hasTarget = p.targetId != null;
        // Use helpers from utils.dart
        postTypeColor = getPostTypeColor(p);
        postTypeLabel = getPostTypeLabel(p);
        visualBadge = getVisualBadge(p);

     } else if (widget.post is Map<String, dynamic>) {
        final p = widget.post as Map<String, dynamic>;
        postId = p['_id'] ?? '';
        content = p['content'] ?? '';
        // Determine producer status robustly
        isProducerPost = p['isProducerPost'] == true || p['producer_id'] != null;
        // Use boolean flags if available, otherwise infer
        isLeisureProducer = p['isLeisureProducer'] == true;
        isWellnessProducer = p['isWellnessProducer'] == true || p['is_wellness_producer'] == true || p['isBeautyProducer'] == true; // Check multiple potential flags
        // isRestaurantProducer = isProducerPost && !isLeisureProducer && !isWellnessProducer; // Infer if needed

        // Get author info robustly
        if (p['author'] is Map) {
          final author = p['author'] as Map;
          authorName = author['name'] ?? 'Auteur inconnu';
          // Use 'avatar' first, then 'photo' as fallback for producers
          authorAvatar = author['avatar'] ?? author['photo'] ?? '';
          authorId = author['id'] ?? '';
        } else {
          authorName = p['author_name'] ?? 'Auteur inconnu';
          authorAvatar = p['author_avatar'] ?? p['author_photo'] ?? ''; // Prioritize avatar, fallback to photo
          authorId = p['author_id'] ?? p['user_id'] ?? '';
        }

        // Handle media
        mediaItems = [];
        if (p['media'] is List) {
          for (var media in p['media']) {
            if (media is Map) {
              final url = media['url'] ?? '';
              final type = media['type'] ?? 'image';
              if (url.isNotEmpty) {
                mediaItems.add({'url': url, 'type': type});
              }
            }
          }
        }

        // Get post timestamp
        postedAt = DateTime.now(); // Default
        final timePostedStr = p['time_posted']?.toString() ?? p['posted_at']?.toString() ?? p['createdAt']?.toString();
         if (timePostedStr != null) {
            try {
              postedAt = DateTime.parse(timePostedStr).toLocal(); // Ensure local time
            } catch (e) {
              print('❌ Error parsing timestamp for post $postId: $e');
            }
         }

        // Get counts
        likesCount = p['stats']?['likes_count'] ?? p['likes_count'] ?? p['likesCount'] ?? (p['likes'] is List ? (p['likes'] as List).length : 0);
        // Get comments robustly
        comments = p['comments'] is List ? p['comments'] : [];
        commentsCount = p['stats']?['comments_count'] ?? p['comments_count'] ?? p['commentsCount'] ?? comments.length;

        isLikedByCurrentUser = p['isLiked'] == true; // Needs to be set by backend based on currentUserId
        isAutomated = p['is_automated'] == true;
        hasReferencedEvent = p['hasReferencedEvent'] == true || p['referenced_event_id'] != null;
        hasTarget = p['hasTarget'] == true || p['target_id'] != null;

        // Use helpers from utils.dart
        postTypeColor = getPostTypeColor(p);
        postTypeLabel = getPostTypeLabel(p);
        visualBadge = p['visualBadge'] ?? getVisualBadge(p); // Use provided badge or generate

     } else {
         // Handle error case - display a placeholder or error card?
          print("❌ ProducerPostCard received unsupported post type: ${widget.post.runtimeType}");
          postId = '';
          content = 'Erreur: Type de post non supporté.';
          isProducerPost = false;
          isLeisureProducer = false;
          isWellnessProducer = false;
          authorName = '';
          authorAvatar = '';
          authorId = '';
          mediaItems = [];
          postedAt = DateTime.now();
          likesCount = 0;
          commentsCount = 0;
          isLikedByCurrentUser = false;
          isAutomated = false;
          hasReferencedEvent = false;
          hasTarget = false;
          visualBadge = '❓';
          postTypeLabel = 'Inconnu';
          postTypeColor = Colors.grey;
          comments = [];
     }
  }


  @override
  Widget build(BuildContext context) {
    if (postId.isEmpty) {
       // Render an error state if extraction failed
       return Card(
         margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
         color: Colors.red.shade50,
         child: const Padding(
           padding: EdgeInsets.all(16.0),
           child: Text("Impossible d'afficher ce post."),
         )
       );
    }

    String? firstVideoUrl;
    if (mediaItems.isNotEmpty && mediaItems.first['type'] == 'video') {
      firstVideoUrl = mediaItems.first['url'];
    }

    return VisibilityDetector(
      key: Key('post-$postId'), // Use extracted postId
      onVisibilityChanged: (info) {
        widget.onVisibilityChanged(postId, info.visibleFraction, firstVideoUrl);
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        elevation: 1,
        // Use postTypeColor for border? Or keep it neutral?
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          // side: BorderSide(color: postTypeColor.withOpacity(0.5), width: 1), // Optional colored border
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell( // Make card tappable for details
           onTap: () => widget.openDetails(widget.post),
           borderRadius: BorderRadius.circular(12),
           child: Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               _buildPostHeader(context),
               if (content.isNotEmpty)
                 Padding(
                   padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                   child: Text(
                     content,
                     style: GoogleFonts.poppins(fontSize: 15, height: 1.4), // Consistent font
                   ),
                 ),
               if (mediaItems.isNotEmpty) _buildPostMedia(context),
               _buildPostActions(context),
               if (comments.isNotEmpty) _buildCommentsPreview(context),
             ],
           ),
        ),
      ),
    );
  }

  Widget _buildPostHeader(BuildContext context) {
      final bool isDarkTheme = Theme.of(context).brightness == Brightness.dark;
      final Color headerTextColor = isDarkTheme ? Colors.white : Colors.black87;
      final Color subtitleColor = Colors.grey.shade600;

      // Enhanced Avatar with Fallback
      ImageProvider? avatarImageProvider = getImageProvider(authorAvatar); // Use util
      Widget avatarDisplay;
      if (avatarImageProvider != null) {
         avatarDisplay = CircleAvatar(
             radius: 20,
             backgroundColor: Colors.grey[200], // Background for loading/error
             backgroundImage: avatarImageProvider,
         );
      } else {
         // Placeholder with initials or icon
          avatarDisplay = CircleAvatar(
             radius: 20,
             backgroundColor: postTypeColor.withOpacity(0.2),
             child: Text(
                 authorName.isNotEmpty ? authorName[0].toUpperCase() : '?',
                 style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: postTypeColor),
             ),
          );
      }


      return Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Avatar with type badge
            InkWell( // Make avatar tappable
               onTap: () {
                 if (widget.onNavigateToProfile != null) {
                    // Determine type string expected by navigation
                    String profileType = 'user';
                    if (isLeisureProducer) profileType = 'leisureProducer';
                    else if (isWellnessProducer) profileType = 'wellnessProducer';
                    else if (isProducerPost) profileType = 'restaurant'; // Assuming 'Producer' maps to restaurant

                    widget.onNavigateToProfile!(authorId, profileType);
                 } else {
                    // Fallback or default navigation if no callback provided
                    // _defaultNavigateToProfile(context, authorId, ...)
                 }
               },
               child: Stack(
                 alignment: Alignment.bottomRight,
                 children: [
                    Container( // Border container
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: postTypeColor, width: 1.5),
                      ),
                      padding: const EdgeInsets.all(2),
                      child: avatarDisplay,
                    ),
                   // Visual Badge
                   Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                         color: Colors.white,
                         shape: BoxShape.circle,
                         boxShadow: [
                           BoxShadow(color: Colors.grey.withOpacity(0.3), spreadRadius: 1, blurRadius: 2),
                         ],
                      ),
                     child: Text(visualBadge, style: const TextStyle(fontSize: 10)),
                   ),
                   // Automated indicator (optional)
                   if (isAutomated)
                       Positioned(
                          top: 0, right: 0,
                          child: Container(
                             padding: const EdgeInsets.all(2),
                             decoration: BoxDecoration(color: Colors.red.shade100, shape: BoxShape.circle),
                             child: const Text('🤖', style: TextStyle(fontSize: 10)),
                          ),
                       ),
                 ],
               ),
            ),
            const SizedBox(width: 12),
            // Author Name and Timestamp/Type
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                     children: [
                        Flexible(
                           child: Text(
                             authorName,
                             style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15, color: headerTextColor),
                             overflow: TextOverflow.ellipsis,
                           ),
                        ),
                       if (isAutomated) const Text(' 🤖', style: TextStyle(fontSize: 14)),
                     ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        formatTimestamp(postedAt), // Use helper from utils.dart
                        style: TextStyle(color: subtitleColor, fontSize: 12),
                      ),
                      const SizedBox(width: 6),
                       // Type Label Chip
                       Container(
                         padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                         decoration: BoxDecoration(
                           // Use a less saturated color for the background
                           color: postTypeColor.withOpacity(0.15),
                           borderRadius: BorderRadius.circular(10),
                         ),
                         child: Text(
                           postTypeLabel,
                           style: TextStyle(
                             fontSize: 10,
                             // Use the main type color for the text for contrast
                             color: postTypeColor,
                             fontWeight: FontWeight.w600, // Slightly bolder
                           ),
                         ),
                       ),
                       // Event/Target indicators
                       if (hasReferencedEvent || hasTarget)
                          Container(
                            margin: const EdgeInsets.only(left: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              hasReferencedEvent ? 'Événement' : 'Lieu',
                              style: TextStyle(fontSize: 10, color: Colors.green.shade700, fontWeight: FontWeight.w500),
                            ),
                          ),
                    ],
                  ),
                ],
              ),
            ),
            // More Options Button
            IconButton(
              icon: Icon(Icons.more_horiz, color: subtitleColor),
              onPressed: () => widget.onShowOptions(widget.post),
              tooltip: 'Plus d\'options',
            ),
          ],
        ),
      );
  }


 Widget _buildPostMedia(BuildContext context) {
    if (mediaItems.length == 1) {
      // Single Media Item
      final media = mediaItems.first;
      final isVideo = media['type'] == 'video';
      return GestureDetector(
        onTap: () {
          if (isVideo) {
             widget.openReelsView(widget.post, media['url']);
          } else {
             widget.openDetails(widget.post); // Or a dedicated image viewer
          }
        },
        child: Container(
          constraints: const BoxConstraints(maxHeight: 450), // Max height for single item
          width: double.infinity,
          color: Colors.grey.shade100, // Background for loading/error
          child: isVideo
              ? _buildVideoPlayer(postId, media['url'])
              : _buildImage(media['url'], BoxFit.cover), // Use cover for single image
        ),
      );
    } else {
      // Multiple Media Items (Carousel)
      return ChoiceCarousel.builder( // Use the specific ChoiceCarousel
        itemCount: mediaItems.length,
        options: ChoiceCarouselOptions(
          height: 350, // Height for carousel
          enableInfiniteScroll: false,
          enlargeCenterPage: false, // Standard carousel view
          viewportFraction: 0.9, // Show parts of next/prev items
          autoPlay: false,
        ),
        itemBuilder: (context, index, _) {
          final media = mediaItems[index];
          final isVideo = media['type'] == 'video';
          return GestureDetector(
             onTap: () {
                if (isVideo) {
                   widget.openReelsView(widget.post, media['url']);
                } else {
                   widget.openDetails(widget.post); // Or image viewer with index
                }
              },
             child: Container(
               margin: const EdgeInsets.symmetric(horizontal: 4.0), // Spacing between items
               width: double.infinity,
               color: Colors.black, // Black background for carousel items
               child: isVideo
                   ? _buildVideoPlayer('$postId-$index', media['url'])
                   : _buildImage(media['url'], BoxFit.contain), // Use contain for carousel
             ),
           );
        },
      );
    }
 }

  Widget _buildImage(String url, BoxFit fit) {
     ImageProvider? provider = getImageProvider(url);
     if (provider != null) {
       return Image(
         image: provider,
         fit: fit,
         width: double.infinity, // Ensure image tries to fill width
         // Loading builder (optional shimmer)
         loadingBuilder: (context, child, loadingProgress) {
           if (loadingProgress == null) return child;
           return Container(
             color: Colors.grey[200],
             height: 300, // Match potential height
             child: Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                      : null,
                  strokeWidth: 2,
                )
             ),
           );
         },
         // Error builder
         errorBuilder: (context, error, stackTrace) => Container(
           color: Colors.grey[200],
           height: 300,
           child: Center(child: Icon(Icons.broken_image_outlined, color: Colors.grey[400], size: 40)),
         ),
       );
     } else {
       // Fallback if URL is invalid from the start
       return Container(
         color: Colors.grey[200],
         height: 300,
         child: Center(child: Icon(Icons.image_not_supported_outlined, color: Colors.grey[400], size: 40)),
       );
     }
  }

  Widget _buildVideoPlayer(String videoPostId, String videoUrl) {
    // Check if controller needs initialization
    if (!widget.videoControllers.containsKey(videoPostId)) {
      // Trigger initialization via the callback passed from the parent
      widget.initializeVideoController(videoPostId, videoUrl);
      // Show loading indicator while initializing
      return const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white)));
    }

    final controller = widget.videoControllers[videoPostId]!;

    if (!controller.value.isInitialized) {
      // Still initializing or failed
      return const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white)));
    }

    // Controller is ready, build player
    return Stack(
      alignment: Alignment.center, // Center play/pause button
      children: [
        AspectRatio(
          aspectRatio: controller.value.aspectRatio,
          child: VideoPlayer(controller),
        ),
        // Play/Pause Button Overlay
        GestureDetector(
           onTap: () {
              if (controller.value.isPlaying) {
                 controller.pause();
              } else {
                 controller.play();
              }
              setState(() {}); // Rebuild to update icon
           },
           child: Container(
              color: Colors.black.withOpacity(0.3), // Slight overlay for button visibility
              child: Icon(
                 controller.value.isPlaying ? Icons.pause_circle_outline : Icons.play_circle_outline,
                 color: Colors.white.withOpacity(0.8),
                 size: 60,
              ),
           ),
        ),
        // Mute/Unmute Button (Bottom Right)
        Positioned(
           bottom: 8, right: 8,
           child: DecoratedBox(
             decoration: BoxDecoration(
               color: Colors.black.withOpacity(0.6),
               borderRadius: BorderRadius.circular(20),
             ),
             child: IconButton(
               icon: Icon(
                 controller.value.volume > 0 ? Icons.volume_up_outlined : Icons.volume_off_outlined,
                 color: Colors.white,
                 size: 18, // Smaller mute icon
               ),
               padding: EdgeInsets.zero, // Remove default padding
               constraints: const BoxConstraints(), // Remove default constraints
               onPressed: () {
                 controller.setVolume(controller.value.volume > 0 ? 0 : 1.0);
                 setState(() {}); // Rebuild to update icon
               },
             ),
           ),
        ),
      ],
    );
  }

  Widget _buildPostActions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0), // Reduced vertical padding
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween, // Space out buttons
        children: [
          // Like Button
          _buildInteractionButton(
            context: context,
            icon: isLikedByCurrentUser ? Icons.favorite : Icons.favorite_border,
            activeIcon: Icons.favorite, // Icon when active
            label: 'Like', // Keep label for accessibility/clarity if needed
            count: likesCount,
            isActive: isLikedByCurrentUser,
            activeColor: Colors.redAccent,
            onPressed: _handleLike,
          ),
          // Comment Button
          _buildInteractionButton(
            context: context,
            icon: Icons.chat_bubble_outline,
            label: 'Commenter',
            count: commentsCount,
            activeColor: Theme.of(context).primaryColor, // Use theme color
            onPressed: () => widget.onComment(widget.post),
          ),
          // Share Button (Placeholder)
          _buildInteractionButton(
            context: context,
            icon: Icons.share_outlined,
            label: 'Partager',
             activeColor: Colors.purple, // Example color
            onPressed: () => widget.onShare(widget.post),
          ),
          // Stats Button (Only for producer posts)
          if (isProducerPost)
            _buildInteractionButton(
              context: context,
              icon: Icons.bar_chart_outlined,
              label: 'Stats',
              activeColor: Colors.teal, // Example color
              onPressed: () => widget.onShowStats(widget.post),
            ),
        ],
      ),
    );
  }

  // Internal handler for like button press
  Future<void> _handleLike() async {
    if (_isLiking) return; // Prevent multiple clicks

    setState(() {
      _isLiking = true;
      // Optimistic UI update (optional but recommended)
      isLikedByCurrentUser = !isLikedByCurrentUser;
      likesCount += isLikedByCurrentUser ? 1 : -1;
    });

    try {
      await widget.onLike(widget.post); // Call the actual like function passed via props
      // If API call fails, the controller should revert the state
    } finally {
      if (mounted) {
        setState(() {
          _isLiking = false;
        });
      }
    }
  }

  // Reusable Interaction Button
  Widget _buildInteractionButton({
    required BuildContext context,
    required IconData icon,
    IconData? activeIcon, // Optional separate icon for active state
    required String label,
    int count = 0,
    bool isActive = false,
    required Color activeColor,
    required VoidCallback onPressed,
  }) {
    final Color iconColor = isActive ? activeColor : (Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade400 : Colors.grey.shade600);
    final Color textColor = isActive ? activeColor : (Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade400 : Colors.grey.shade700);
    final FontWeight fontWeight = isActive ? FontWeight.bold : FontWeight.normal;

    return TextButton.icon(
        onPressed: onPressed,
        style: TextButton.styleFrom(
           foregroundColor: iconColor, // Color for splash/hover
           padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), // Adjust padding
           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), // Rounded shape
        ),
        icon: Icon(isActive ? (activeIcon ?? icon) : icon, color: iconColor, size: 20),
        label: Text(
           count > 0 ? formatNumber(count) : label, // Use formatted number or label
           style: GoogleFonts.poppins(
               fontSize: 12,
               fontWeight: fontWeight,
               color: textColor,
           ),
        ),
     );
  }

  // Helper to format large numbers (e.g., 1234 -> 1.2k) - Move to utils.dart if used elsewhere
  String formatNumber(int number) {
    if (number < 1000) return number.toString();
    if (number < 1000000) return '${(number / 1000).toStringAsFixed(1)}k';
    return '${(number / 1000000).toStringAsFixed(1)}M';
  }

  Widget _buildCommentsPreview(BuildContext context) {
    final commentsToShow = comments.take(2).toList();
    if (commentsToShow.isEmpty) return const SizedBox.shrink();

     final bool isDarkTheme = Theme.of(context).brightness == Brightness.dark;
     final Color previewTextColor = isDarkTheme ? Colors.grey.shade300 : Colors.black87;
     final Color authorColor = isDarkTheme ? Colors.white : Colors.black;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8), // Consistent padding
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           Text(
             'Commentaires', // Simple header
             style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[700]),
           ),
           const SizedBox(height: 6),
          ...commentsToShow.map((comment) => _buildSingleCommentPreview(context, comment, authorColor, previewTextColor)).toList(),
          if (commentsCount > 2)
            Padding(
               padding: const EdgeInsets.only(top: 4.0),
               child: InkWell(
                 onTap: () => widget.onComment(widget.post), // Open full comments view
                 child: Text(
                   'Voir les ${commentsCount - 2} autres commentaires...',
                   style: GoogleFonts.poppins(
                     fontSize: 13,
                     color: Theme.of(context).primaryColor, // Use theme color
                     fontWeight: FontWeight.w500,
                   ),
                 ),
               ),
            ),
        ],
      ),
    );
  }

  Widget _buildSingleCommentPreview(BuildContext context, dynamic commentData, Color authorColor, Color textColor) {
     String authorName = 'Utilisateur';
     String commentContent = '';
     String authorAvatarUrl = ''; // Default empty

     if (commentData is Comment) { // Handle strongly typed Comment object
        authorName = commentData.authorName ?? 'Utilisateur';
        commentContent = commentData.content ?? '';
        authorAvatarUrl = commentData.authorAvatar ?? '';
     } else if (commentData is Map<String, dynamic>) { // Handle Map object
        final commentMap = commentData;
        authorName = commentMap['author_name']?.toString() ?? commentMap['authorName']?.toString() ?? 'Utilisateur';
        commentContent = commentMap['content']?.toString() ?? commentMap['text']?.toString() ?? '';
        // Check multiple keys for avatar
        authorAvatarUrl = commentMap['author_avatar']?.toString() ?? commentMap['authorAvatar']?.toString() ?? '';
     } else {
        // Unsupported comment format, maybe log an error
         return const SizedBox.shrink();
     }

     // Avatar for comment author
     ImageProvider? commentAuthorProvider = getImageProvider(authorAvatarUrl);
     Widget commentAvatarWidget;
     if (commentAuthorProvider != null) {
         commentAvatarWidget = CircleAvatar(radius: 12, backgroundImage: commentAuthorProvider, backgroundColor: Colors.grey[200]);
     } else {
         commentAvatarWidget = CircleAvatar(
             radius: 12,
             backgroundColor: Colors.grey.shade300, // Placeholder background
             child: Text(authorName.isNotEmpty ? authorName[0].toUpperCase() : '?', style: const TextStyle(fontSize: 10)),
         );
     }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0), // Reduced vertical padding
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           commentAvatarWidget,
           const SizedBox(width: 8),
           Expanded(
            // Use RichText for better formatting (bold name)
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.poppins(fontSize: 13, color: textColor), // Default style
                children: [
                  TextSpan(
                    text: '$authorName ',
                    style: TextStyle(fontWeight: FontWeight.bold, color: authorColor),
                  ),
                  TextSpan(text: commentContent),
                ],
              ),
              maxLines: 2, // Limit lines for preview
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

} 
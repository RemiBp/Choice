import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:video_player/video_player.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:like_button/like_button.dart'; // Using like_button package
import 'package:provider/provider.dart'; // <<< ADDED

import '../../models/post.dart'; // Assuming Post model path
import '../../models/comment.dart'; // Assuming Comment model path
import '../../utils.dart'; // For getImageProvider AND HELPER FUNCTIONS
import '../../screens/producer_screen.dart'; // For navigation
import '../../screens/producerLeisure_screen.dart'; // For navigation
import '../../screens/wellness_producer_screen.dart'; // For navigation
import '../../screens/profile_screen.dart'; // For navigation
import '../../screens/reels_view_screen.dart'; // For reels view
import '../../screens/post_detail_screen.dart'; // <<< ADDED
import '../../services/api_service.dart'; // <<< ADDED
// Import other necessary screens or services
// Correct import path for local widget
import '../choice_carousel.dart';
import 'package:intl/intl.dart'; // For date formatting

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
  final Function(dynamic) onTap; // ADDED: Callback for general card tap
  final Function(dynamic) onShare; // Placeholder
  final Function(dynamic) onShowStats;
  final Function(dynamic) onShowOptions;
  final Function(dynamic, String)? onNavigateToProfile; // Optional callback for profile navigation
  final Function(String, double, String?) onVisibilityChanged;
  final Map<String, VideoPlayerController> videoControllers; // Pass controllers map
  final Function(String, String) initializeVideoController; // Pass initialization function
  final Function(dynamic, String) openReelsView; // Pass function to open reels
  final VoidCallback? onShowLikers; // <-- Add this callback
  final ApiService? apiService; // Optional: Pass ApiService if needed by PostDetailScreen


  const ProducerPostCard({
    Key? key,
    required this.post,
    required this.currentUserId,
    required this.onLike,
    required this.onComment,
    required this.onTap, // ADDED: Add to constructor
    required this.onShare,
    required this.onShowStats,
    required this.onShowOptions,
    required this.onVisibilityChanged,
    required this.videoControllers,
    required this.initializeVideoController,
    required this.openReelsView,
    this.onNavigateToProfile,
    this.onShowLikers, // <-- Add to constructor
    this.apiService, // <<< ADDED
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

  // Ajouter cette fonction helper pour obtenir l'icône appropriée en fonction du type de post
  IconData getPostTypeIcon(String postType) {
    switch (postType.toLowerCase()) {
      case 'restaurant':
        return Icons.restaurant;
      case 'leisure producer':
      case 'leisureproducer':
        return Icons.local_activity;
      case 'wellness producer':
      case 'wellnessproducer':
      case 'beautyproducer':
        return Icons.spa;
      case 'user':
        return Icons.person;
      default:
        return Icons.article;
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

    // Define the content that will be wrapped by OpenContainer
    Widget cardContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPostHeader(),
        if (content.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Text(
              content,
              key: ValueKey('$postId-content'),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
          ),
        if (mediaItems.isNotEmpty)
          _buildMediaContent(firstVideoUrl),
        _buildPostFooter(),
      ],
    );

    // REMOVE OpenContainer, use simple Card with InkWell
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => widget.onTap(widget.post), // Use the new onTap callback
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: cardContent,
        ),
      ),
    );
  }

  Widget _buildPostHeader() {
     return GestureDetector(
       onTap: () {
         if(widget.onNavigateToProfile != null) {
           widget.onNavigateToProfile!(authorId, postTypeLabel.toLowerCase().replaceAll(' ', ''));
         } else {
            _defaultNavigateToProfile(authorId, postTypeLabel.toLowerCase().replaceAll(' ', ''));
         }
       },
       child: Row(
         children: [
           CircleAvatar(
             radius: 22,
             backgroundImage: authorAvatar.isNotEmpty ? getImageProvider(authorAvatar) : null,
             backgroundColor: authorAvatar.isEmpty ? postTypeColor.withOpacity(0.7) : postTypeColor,
             child: authorAvatar.isEmpty ? Icon(getPostTypeIcon(postTypeLabel), color: Colors.white, size: 20) : null,
           ),
           const SizedBox(width: 12),
           Expanded(
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 Text(
                   authorName,
                   style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                 ),
                 Text(
                   postTypeLabel,
                   style: TextStyle(fontSize: 12, color: postTypeColor, fontWeight: FontWeight.w500),
                 ),
               ],
             ),
           ),
           Text(
              formatTimestamp(postedAt), // Use helper from utils.dart
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
           ),
           const SizedBox(width: 4),
           // Options Button
           IconButton(
             icon: Icon(Icons.more_vert, color: Colors.grey[500]),
             iconSize: 20,
             padding: EdgeInsets.zero,
             constraints: const BoxConstraints(),
             tooltip: 'Options',
             onPressed: () => widget.onShowOptions(widget.post),
           ),
         ],
       ),
     );
  }

  // Default navigation if callback not provided
  void _defaultNavigateToProfile(String profileId, String type) {
     Widget? screen;
     switch (type) {
       case 'restaurant': screen = ProducerScreen(producerId: profileId); break;
       case 'leisureproducer': screen = ProducerLeisureScreen(producerId: profileId); break;
       case 'wellnessproducer': screen = WellnessProducerScreen(producerId: profileId); break;
       case 'user': screen = ProfileScreen(userId: profileId); break;
       default: print("Unknown profile type for default navigation: $type");
     }
     if (screen != null) {
        Navigator.push(context, MaterialPageRoute(builder: (context) => screen!));
     }
  }

  Widget _buildMediaContent(String? firstVideoUrl) {
       if (mediaItems.isEmpty) return const SizedBox.shrink();

       final firstMedia = mediaItems.first;
       final isVideo = firstMedia['type'] == 'video';
       final mediaUrl = firstMedia['url'] as String? ?? '';

       if (mediaUrl.isEmpty) return const SizedBox.shrink();

       // Use VisibilityDetector for video playback control
       return VisibilityDetector(
         key: Key('$postId-media'),
         onVisibilityChanged: (visibilityInfo) {
            widget.onVisibilityChanged(postId, visibilityInfo.visibleFraction, firstVideoUrl);
         },
         // AspectRatio might be needed depending on media dimensions
         child: ClipRRect(
           borderRadius: BorderRadius.circular(12.0),
           child: isVideo
               ? _buildVideoPlayer(mediaUrl)
               : _buildImage(mediaUrl),
         ),
       );
  }

  Widget _buildVideoPlayer(String videoUrl) {
      final controller = widget.videoControllers[postId];

      // Placeholder while initializing or if controller is null
      if (controller == null || !controller.value.isInitialized) {
         // Ensure initialization is triggered by the parent screen
         // widget.initializeVideoController(postId, videoUrl);
         return AspectRatio(
           aspectRatio: 16 / 9, // Default aspect ratio
           child: Container(
             decoration: BoxDecoration(
               color: Colors.black,
               borderRadius: BorderRadius.circular(12.0), // Match rounding
             ),
             child: const Center(
                 child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54)
              ),
           ),
         );
      }

      // Display video player
      return AspectRatio(
         aspectRatio: controller.value.aspectRatio,
         child: Stack(
           alignment: Alignment.center,
           children: [
             VideoPlayer(controller),
             // Simple play icon overlay when paused
             if (!controller.value.isPlaying)
                 Icon(Icons.play_arrow_rounded, color: Colors.white.withOpacity(0.7), size: 60),
           ],
         ),
      );
   }

   Widget _buildImage(String imageUrl) {
      return CachedNetworkImage(
         imageUrl: imageUrl,
         fit: BoxFit.cover,
         width: double.infinity,
         // Constrained height for consistency
         height: 280,
         placeholder: (context, url) => Container(
           height: 280,
           decoration: BoxDecoration(
             color: Colors.grey[200],
             borderRadius: BorderRadius.circular(12.0), // Match rounding
           ),
           child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.grey[400])),
         ),
         errorWidget: (context, url, error) => Container(
           height: 280,
           decoration: BoxDecoration(
             color: Colors.grey[300],
             borderRadius: BorderRadius.circular(12.0), // Match rounding
           ),
           child: Center(child: Icon(Icons.broken_image_outlined, color: Colors.grey[600], size: 40)),
         ),
       );
   }

  Widget _buildPostFooter() {
     // Use LikeButton package for like animation
     return Padding(
       padding: const EdgeInsets.only(top: 10.0),
       child: Row(
         mainAxisAlignment: MainAxisAlignment.spaceBetween,
         children: [
           // Like Button
           LikeButton(
             key: ValueKey('$postId-like'), // Add key
             isLiked: isLikedByCurrentUser,
             likeCount: likesCount,
             size: 22,
             padding: const EdgeInsets.all(6), // Add padding for easier tapping
             circleColor: const CircleColor(start: Color(0xffFF5252), end: Color(0xffff0000)),
             bubblesColor: const BubblesColor(
               dotPrimaryColor: Color(0xffFF5252),
               dotSecondaryColor: Color(0xffff4040),
             ),
             likeBuilder: (bool isLiked) {
               return Icon(
                 isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                 color: isLiked ? Colors.redAccent : Colors.grey[600],
                 size: 22,
               );
             },
             countBuilder: (int? count, bool isLiked, String text) {
               var color = isLiked ? Colors.redAccent : Colors.grey[600];
               // Display count only if > 0
               // Add GestureDetector to show likers
               return GestureDetector(
                   onTap: () {
                     if (widget.onShowLikers != null && (count ?? 0) > 0) {
                       widget.onShowLikers!();
                     }
                   },
                   child: Text(
                     count == null || count == 0 ? " J'aime" : " $text",
                     style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w500),
                   ),
               );
             },
             likeCountPadding: const EdgeInsets.only(left: 4.0),
             onTap: (isLiked) async {
                 if (_isLiking) return isLiked; // Prevent concurrent calls
                 setState(() { _isLiking = true; });
                 bool success = false;
                 try {
                   // Call the actual like function passed from parent
                   await widget.onLike(widget.post);
                   // The parent should handle state update which rebuilds this widget
                   // We *assume* success changes the state
                   success = true;
                   // Return the OPPOSITE of the current visual state for the animation
                   return !isLiked;
                 } catch (e) {
                    print("Error in LikeButton onTap: $e");
                    // Return the CURRENT visual state to prevent animation flip on error
                    return isLiked;
                 } finally {
                    // Add a small delay before allowing another tap, even on error
                    await Future.delayed(const Duration(milliseconds: 200));
                    if(mounted) { // Check if widget is still mounted
                       setState(() { _isLiking = false; });
                    }
                 }
             },
           ),

           // Comment Button
           TextButton.icon(
             icon: Icon(Icons.mode_comment_outlined, color: Colors.grey[600], size: 20),
             label: Text(
                commentsCount > 0 ? commentsCount.toString() : 'Commenter',
                style: TextStyle(color: Colors.grey[700], fontSize: 13, fontWeight: FontWeight.w500)
             ),
             // This now uses the specific onComment callback passed in,
             // which should trigger the navigation/focus action in the parent screen.
             onPressed: () => widget.onComment(widget.post),
             style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10)),
           ),

           // Share Button
           TextButton.icon(
             icon: Icon(Icons.share_outlined, color: Colors.grey[600], size: 20),
             label: Text('Partager', style: TextStyle(color: Colors.grey[700], fontSize: 13, fontWeight: FontWeight.w500)),
             onPressed: () => widget.onShare(widget.post),
             style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10)),
           ),
         ],
       ),
     );
  }
} 
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:like_button/like_button.dart';
import 'dart:math' as math;

import '../services/api_service.dart'; // For making API calls
import '../models/user_model.dart'; // For getting user info (optional)
import '../models/comment.dart'; // To potentially parse response
import '../utils.dart'; // For getImageProvider
import '../screens/profile_screen.dart'; // Import profile screen

// Comments Widget
class CommentsWidget extends StatefulWidget {
  final String postId;
  final Map<String, dynamic> postData; // Pass necessary post info
  final String userId; // Logged-in user
  final Function(dynamic)? onNewComment; // Callback after adding a comment
  final ApiService? apiService; // Optional ApiService instance

  const CommentsWidget({
    Key? key,
    required this.postId,
    required this.postData,
    required this.userId,
    this.onNewComment,
    this.apiService, // Add to constructor
  }) : super(key: key);

  @override
  State<CommentsWidget> createState() => _CommentsWidgetState();
}

class _CommentsWidgetState extends State<CommentsWidget> {
  final TextEditingController _commentController = TextEditingController();
  late ApiService _apiService;
  late String _userName = 'Vous'; // Default name, can be fetched
  late String? _userAvatar = ''; // Default avatar, can be fetched

  List<dynamic> _comments = [];
  bool _isLoading = false;
  bool _isPosting = false; // Flag for posting state
  Map<String, bool> _isLikingComment = {}; // Track liking state per comment

  @override
  void initState() {
    super.initState();
    // Use provided ApiService if available, otherwise lookup
    _apiService = widget.apiService ?? Provider.of<ApiService>(context, listen: false);
    if (widget.postData['comments'] is List) {
        _comments = List.from(widget.postData['comments']);
    }
    _fetchComments(); // Fetch fresh comments on init
    _loadUserInfo(); // Attempt to load user info for better display
  }

  Future<void> _loadUserInfo() async {
    // Optionally load the current user's name/avatar for immediate display
    // final userData = await Provider.of<AuthService>(context, listen: false).getUserInfo();
    // if (mounted && userData != null) {
    //   setState(() {
    //     _userName = userData['name'] ?? _userName;
    //     _userAvatar = userData['avatar'] ?? _userAvatar;
    //   });
    // }
  }

  Future<void> _fetchComments() async {
    setState(() { _isLoading = true; });
    try {
      print("🔄 Fetching comments for post ${widget.postId}...");
      // Adjust API call as needed (e.g., getCommentsByPostId)
      final fetchedComments = await _apiService.getComments(widget.postId);
      if (mounted) {
        setState(() {
          _comments = fetchedComments ?? []; // Update with fetched comments
          _isLoading = false;
          print("✅ Comments loaded: ${_comments.length}");
        });
      }
    } catch (e) {
      print("❌ Error fetching comments: $e");
      if (mounted) {
        setState(() { _isLoading = false; });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur chargement commentaires: ${e.toString()}'), backgroundColor: Colors.red)
        );
      }
    }
  }

  Future<void> _addComment() async {
    if (_commentController.text.trim().isEmpty || _isPosting) return;

    final String text = _commentController.text.trim();
    final String originalText = text; // Keep original text for potential revert
    _commentController.clear();
    FocusScope.of(context).unfocus();

    // Optimistic UI update
    final tempComment = {
      // No server ID yet
      'content': text,
      'author_id': widget.userId,
      'author_name': _userName, // Use loaded user name
      'author_avatar': _userAvatar, // Use loaded user avatar
      'created_at': DateTime.now().toIso8601String(),
      'isOptimistic': true, // Flag for potential removal on error
    };
    setState(() {
      _comments.insert(0, tempComment); // Add to the top optimistically
      _isPosting = true;
    });

    try {
      print("📤 Adding comment: '$text' to post ${widget.postId} by user ${widget.userId}");
      // Call API with updated method signature
      final newCommentData = await _apiService.addComment(
        widget.postId,
        widget.userId,
        text,
      );

      if (mounted) {
        // Update the optimistic comment with server data or replace it
        setState(() {
          final index = _comments.indexWhere((c) => c['isOptimistic'] == true && c['content'] == text);
          if (index != -1) {
            _comments[index] = newCommentData..remove('isOptimistic'); // Update or remove flag
          }
          _isPosting = false;
        });

        // Notify parent screen
        if (widget.onNewComment != null) {
          widget.onNewComment!(newCommentData);
        }
      }
      print("✅ Comment added successfully.");
    } catch (e) {
      print("❌ Error adding comment: $e");
      if (mounted) {
        // Revert optimistic update on error
        setState(() {
          _comments.removeWhere((c) => c['isOptimistic'] == true && c['content'] == text);
          _isPosting = false;
          _commentController.text = originalText; // Restore text field content
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur envoi commentaire: ${e.toString()}'), backgroundColor: Colors.red)
        );
      }
    }
  }

  // --- Navigation --- 
  void _navigateToUserProfile(BuildContext context, String userId) {
    if (userId.isEmpty) {
      print("Cannot navigate to profile: User ID is empty.");
      return;
    }
    print("Navigating to user profile: $userId");
    // TODO: Determine if it's a producer profile based on some logic/data if needed
    Navigator.push(context, MaterialPageRoute(builder: (context) => ProfileScreen(userId: userId)));
  }

  // --- Like Comment Logic ---
  Future<void> _likeComment(String commentId, bool currentStatus) async {
    if (_isLikingComment[commentId] == true) return; // Prevent double taps

    setState(() {
      _isLikingComment[commentId] = true;
      // Optimistic UI update
      _updateCommentLikeState(commentId, !currentStatus);
    });

    try {
      // Call API service
      await _apiService.likeComment(widget.userId, widget.postId, commentId);
       print("✅ Comment $commentId liked successfully via API");
       // Keep optimistic state
       if (mounted) {
           setState(() {
              _isLikingComment.remove(commentId);
           });
       }
    } catch (e) {
      print("❌ Error liking comment $commentId: $e");
      // Revert optimistic update on error
      if (mounted) {
        setState(() {
          _updateCommentLikeState(commentId, currentStatus); // Revert to original status
          _isLikingComment.remove(commentId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors du like: ${e.toString()}'), backgroundColor: Colors.red)
        );
      }
    }
  }

  // Helper to update the like status and count in the local _comments list
  void _updateCommentLikeState(String commentId, bool newLikeStatus) {
      final index = _comments.indexWhere((c) => (c is Map && (c['_id'] == commentId || c['id'] == commentId)) || (c is Comment && c.id == commentId));
      if (index != -1) {
          final comment = _comments[index];
          int currentLikes = 0;
          bool currentStatus = false;

          if (comment is Comment) {
             currentLikes = comment.likes ?? 0;
             currentStatus = comment.isLiked ?? false;
          } else if (comment is Map<String, dynamic>) {
             currentLikes = comment['likes'] as int? ?? 0;
             currentStatus = comment['isLiked'] as bool? ?? false;
          }

          final int newLikesCount = newLikeStatus ? currentLikes + 1 : math.max(0, currentLikes - 1);

           if (comment is Comment) {
               // This won't work directly as Comment is likely immutable.
               // We need to replace it with a new instance or use Maps.
               // Using Maps for simplicity here.
                final Map<String, dynamic> mutableComment = comment.toJson(); // Assuming toJson exists
                mutableComment['isLiked'] = newLikeStatus;
                mutableComment['likes'] = newLikesCount;
               _comments[index] = mutableComment;
           } else if (comment is Map<String, dynamic>) {
               final mutableComment = Map<String, dynamic>.from(comment);
               mutableComment['isLiked'] = newLikeStatus;
               mutableComment['likes'] = newLikesCount;
               _comments[index] = mutableComment;
           }
           // No need for setState here as it's called within _likeComment
      }
  }

  Widget _buildCommentTile(dynamic commentData) {
    String authorName = 'Utilisateur';
    String commentContent = '';
    String authorAvatarUrl = '';
    String authorId = ''; // <-- Extract authorId
    bool isOptimistic = false;
    String commentId = '';
    bool isLiked = false;
    int likeCount = 0;

    if (commentData is Comment) {
      authorName = commentData.authorName ?? 'Utilisateur';
      commentContent = commentData.content ?? '';
      authorAvatarUrl = commentData.authorAvatar ?? '';
      authorId = commentData.authorId ?? ''; // <-- Get ID from Comment model
      commentId = commentData.id ?? '';
      isLiked = commentData.isLiked ?? false;
      likeCount = commentData.likes ?? 0;
    } else if (commentData is Map<String, dynamic>) {
      final commentMap = commentData;
      authorName = commentMap['author_name']?.toString() ?? commentMap['authorName']?.toString() ?? 'Utilisateur';
      commentContent = commentMap['content']?.toString() ?? commentMap['text']?.toString() ?? '';
      authorAvatarUrl = commentMap['author_avatar']?.toString() ?? commentMap['authorAvatar']?.toString() ?? '';
      authorId = commentMap['author_id']?.toString() ?? commentMap['authorId']?.toString() ?? ''; // <-- Get ID from Map
      commentId = commentMap['_id']?.toString() ?? commentMap['id']?.toString() ?? '';
      isOptimistic = commentMap['isOptimistic'] == true;
      isLiked = commentMap['isLiked'] as bool? ?? false;
      likeCount = commentMap['likes'] as int? ?? 0;
    } else {
      return const SizedBox.shrink();
    }

    ImageProvider? commentAuthorProvider = getImageProvider(authorAvatarUrl);
    Widget commentAvatarWidget = CircleAvatar(
        radius: 18,
        backgroundColor: Colors.grey.shade300,
        backgroundImage: commentAuthorProvider,
        child: commentAuthorProvider == null ? Text(authorName.isNotEmpty ? authorName[0].toUpperCase() : '?', style: const TextStyle(fontSize: 14)) : null,
    );

    return Opacity(
      opacity: isOptimistic ? 0.6 : 1.0,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Make avatar clickable
            GestureDetector(
              onTap: () => _navigateToUserProfile(context, authorId),
              child: commentAvatarWidget,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Make name clickable
                  GestureDetector(
                     onTap: () => _navigateToUserProfile(context, authorId),
                     child: Text(
                       authorName,
                       style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14),
                     ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    commentContent,
                    style: GoogleFonts.poppins(fontSize: 14, color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.8)),
                  ),
                  // --- Add Like Button for Comment ---
                  if (!isOptimistic && commentId.isNotEmpty)
                     Padding(
                       padding: const EdgeInsets.only(left: 8.0), // Add some spacing
                       child: LikeButton(
                         size: 20, // Smaller size for comment like
                         isLiked: isLiked,
                         likeCount: likeCount,
                         padding: EdgeInsets.zero,
                         likeBuilder: (bool isLiked) {
                           return Icon(
                             isLiked ? Icons.favorite : Icons.favorite_border,
                             color: isLiked ? Colors.redAccent : Colors.grey,
                             size: 20,
                           );
                         },
                         countBuilder: (int? count, bool isLiked, String text) {
                           // Optionally hide count if zero
                           return count == 0
                               ? const SizedBox.shrink()
                               : Text(
                                   text,
                                   style: TextStyle(
                                     color: isLiked ? Colors.redAccent : Colors.grey,
                                     fontSize: 12,
                                   ),
                                 );
                         },
                         onTap: (bool currentStatus) async {
                           await _likeComment(commentId, currentStatus);
                           // Return the *new* status after the async operation for the button
                           // We need to find the updated status in our local state
                            final updatedComment = _comments.firstWhere((c) => (c is Map && (c['_id'] == commentId || c['id'] == commentId)) || (c is Comment && c.id == commentId), orElse: () => null);
                            bool finalStatus = currentStatus; // Default to original if not found
                            if(updatedComment is Map) finalStatus = updatedComment['isLiked'] ?? currentStatus;
                            if(updatedComment is Comment) finalStatus = updatedComment.isLiked ?? currentStatus;
                           return finalStatus;
                         },
                       ),
                     ),
                  // --- End Like Button ---
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentInputArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _commentController,
              decoration: InputDecoration(
                hintText: 'Ajouter un commentaire...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              textCapitalization: TextCapitalization.sentences,
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _addComment(),
            ),
          ),
          const SizedBox(width: 8),
          _isPosting
              ? const SizedBox(
                  width: 48,
                  height: 48,
                  child: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.send_rounded),
                  color: Theme.of(context).primaryColor,
                  onPressed: _addComment,
                ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Commentaires (${_comments.length})'),
        elevation: 1,
      ),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchComments, // Allow pull-to-refresh
              child: _isLoading && _comments.isEmpty // Show loading only if comments list is empty initially
                  ? const Center(child: CircularProgressIndicator())
                  : _comments.isEmpty
                      ? Center(
                         child: ListView( // Ensure refresh works even when empty
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: const [Padding(padding: EdgeInsets.all(50.0), child: Text('Aucun commentaire pour le moment.', textAlign: TextAlign.center,))],
                         ),
                      )
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          itemCount: _comments.length,
                          itemBuilder: (context, index) {
                            final comment = _comments[index];
                            return _buildCommentTile(comment);
                          },
                        ),
            ),
          ),
          // Input field area
          _buildCommentInputArea(),
        ],
      ),
    );
  }
} 
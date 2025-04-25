import 'package:flutter/foundation.dart';
// Import with prefix to avoid ambiguity
import '../services/api_service.dart' as api_service;
import '../models/post.dart'; // KEEP: Defines the Post model
import '../models/dialogic_ai_message.dart'; // KEEP: Defines the AI message model
import 'dart:math' as math;

// No separate import needed if api_service.dart is imported fully
// import '../services/api_service.dart' show ProducerFeedLoadState;

// Enum pour les filtres
enum ProducerFeedFilterType { localTrends, venue, interactions, followers }

// Mapper pour convertir de ProducerFeedContentType vers ProducerFeedFilterType
extension ProducerFeedContentTypeExtension on api_service.ProducerFeedContentType {
  ProducerFeedFilterType toFilterType() {
    switch (this) {
      case api_service.ProducerFeedContentType.localTrends:
        return ProducerFeedFilterType.localTrends;
      case api_service.ProducerFeedContentType.venue:
        return ProducerFeedFilterType.venue;
      case api_service.ProducerFeedContentType.interactions:
        return ProducerFeedFilterType.interactions;
      case api_service.ProducerFeedContentType.followers:
        return ProducerFeedFilterType.followers;
      default:
        return ProducerFeedFilterType.localTrends;
    }
  }
}

// Enum pour les états de chargement
enum ProducerFeedLoadState { initial, loading, loaded, loadingMore, error }

// --- Placeholder ProducerFeedController ---
class ProducerFeedController with ChangeNotifier {
  final String userId;
  final String producerTypeString;
  // Use prefixed ApiService type
  final api_service.ApiService _apiService = api_service.ApiService(); // Instance of your API service

  List<dynamic> _feedItems = [];
  // Use prefixed enum
  ProducerFeedLoadState _loadState = ProducerFeedLoadState.initial;
  ProducerFeedFilterType _currentFilter = ProducerFeedFilterType.localTrends;
  String _errorMessage = '';
  bool _hasMorePosts = true;
  int _currentPage = 1;
  String? _currentCategory; // Add category state

  ProducerFeedController({
    required this.userId,
    required this.producerTypeString,
  });

  // --- Getters ---
  List<dynamic> get feedItems => _feedItems;
  // Use prefixed enum
  ProducerFeedLoadState get loadState => _loadState;
  String get errorMessage => _errorMessage;
  bool get hasMorePosts => _hasMorePosts;
  // Use prefixed enum
  ProducerFeedFilterType get currentFilter => _currentFilter; // Expose current filter
  String? get currentCategory => _currentCategory; // Expose current category

  // --- Core Methods ---
  Future<void> _fetchProducerFeed({bool isRefresh = false}) async {
    // Prevent concurrent loads
    if (_loadState == ProducerFeedLoadState.loading || _loadState == ProducerFeedLoadState.loadingMore) return;

    // Set loading state
    _loadState = isRefresh ? ProducerFeedLoadState.loading : (_currentPage == 1 ? ProducerFeedLoadState.loading : ProducerFeedLoadState.loadingMore);
    _errorMessage = '';
    notifyListeners();

    print("🔄 [Controller] Fetching page $_currentPage for filter: $_currentFilter, category: ${_currentCategory ?? 'All'}");

    try {
      // Call the updated ApiService method with the correct filter enum
      final response = await _apiService.getProducerFeed(
        userId, // This should be the ID of the producer whose feed we are viewing
        filter: _currentFilter, // Pass the enum directly
        page: _currentPage,
        limit: 10, // Or adjust as needed
        producerType: producerTypeString, // Pass the type of the producer viewing the feed for context
        category: _currentCategory,
      );

      final List<dynamic> rawItems = response['items'] ?? [];
      final List<dynamic> newItems = rawItems.map((item) {
        try {
          // Try parsing as Post, ensure all fields needed by the UI are present
          return Post.fromJson(item as Map<String, dynamic>);
        } catch (e) {
          print("⚠️ Could not parse item as Post: $e. Item: $item");
          // Potentially handle other types like AI messages if necessary
          // if (item['type'] == 'ai_message') return DialogicAIMessage.fromJson(item);
          return item; // Keep raw map if parsing fails or it's another type
        }
      }).toList();

      // Update pagination state from the response
      _hasMorePosts = response['hasMore'] ?? false;
      // _currentPage = response['currentPage'] ?? _currentPage; // API now drives current page

      if (isRefresh || _currentPage == 1) {
        _feedItems = newItems;
      } else {
        _feedItems.addAll(newItems); // Append new items
      }

      print("✅ [Controller] Feed loaded. Total items: ${_feedItems.length}, Has more: $_hasMorePosts, Current Page: $_currentPage");
      _loadState = ProducerFeedLoadState.loaded;

    } catch (e) {
      _errorMessage = e.toString();
      _loadState = ProducerFeedLoadState.error; // Set error state
      print('❌ Error fetching producer feed: $_errorMessage');
       // If it was a 'loadMore' attempt, revert state but keep existing items
       if (!isRefresh && _currentPage > 1) {
           _loadState = ProducerFeedLoadState.loaded;
           _currentPage--; // Revert page increment if loadMore failed
           _hasMorePosts = true; // Assume we might still have more
       }
    } finally {
      // Important: Ensure listeners are notified even after errors
      // to update UI state (e.g., hide loading indicator, show error)
      notifyListeners();
    }
  }

  // Pull-to-refresh or initial load
  Future<void> refreshFeed() async {
    print("🔄 [Controller] Refreshing feed...");
    _currentPage = 1;
    _hasMorePosts = true; // Reset pagination
    await _fetchProducerFeed(isRefresh: true);
  }

  // Called by the scroll listener
  Future<void> loadMore() async {
    if (_hasMorePosts && _loadState != ProducerFeedLoadState.loadingMore) {
       print("🔄 [Controller] Loading more posts (Page ${_currentPage + 1})...");
      _currentPage++; // Increment page number *before* fetching
      await _fetchProducerFeed();
    } else {
       print("ℹ️ [Controller] Cannot load more. HasMore: $_hasMorePosts, State: $_loadState");
    }
  }

  // Called when a tab is changed
  void filterFeed(ProducerFeedFilterType newFilter) {
    if (_currentFilter == newFilter) return;
    print("🔄 [Controller] Filtering feed to: $newFilter");
    _currentFilter = newFilter;
    _currentPage = 1; // Reset page
    _hasMorePosts = true;
    _feedItems = []; // Clear existing items for new filter
    _fetchProducerFeed(isRefresh: true); // Fetch page 1 for the new filter
  }

  // Called when a category chip is selected
  void changeCategory(String? newCategory) {
    final categoryToSet = (newCategory == 'Tous') ? null : newCategory;
    if (_currentCategory == categoryToSet) return;
    print("🔄 [Controller] Changing category to: ${categoryToSet ?? 'All'}");
    _currentCategory = categoryToSet;
    _currentPage = 1; // Reset page
    _hasMorePosts = true;
    _feedItems = []; // Clear existing items for new category
    _fetchProducerFeed(isRefresh: true); // Fetch page 1 for the new category
  }

  // --- API Interaction ---
  Future<void> likePost(dynamic postData) async {
    String? postId;
    bool? currentLikeStatus;
    int currentLikesCount = 0;

    // Extract ID and current status safely
    if (postData is Post) {
      postId = postData.id;
      currentLikeStatus = postData.isLiked;
      currentLikesCount = postData.likesCount ?? 0;
    } else if (postData is Map<String, dynamic>) {
      postId = postData['_id']?.toString() ?? postData['id']?.toString();
      currentLikeStatus = postData['isLiked'] as bool?;
      // Try different keys for likes count
      currentLikesCount = postData['likesCount'] as int? ??
                          postData['likes_count'] as int? ??
                          (postData['likes'] is List ? (postData['likes'] as List).length : 0);
    }

    if (postId == null || currentLikeStatus == null) {
      print("❌ Cannot like post: Missing ID or like status.");
      return;
    }

    // Optimistic UI update
    final index = _feedItems.indexWhere((item) => _getPostId(item) == postId);
    if (index != -1) {
      final bool newLikeStatus = !currentLikeStatus;
      final int newLikesCount = newLikeStatus ? currentLikesCount + 1 : math.max(0, currentLikesCount - 1); // Ensure count doesn't go below 0
      _updatePostState(postId, isLiked: newLikeStatus, likesCount: newLikesCount); // Update UI immediately
    } else {
       print("⚠️ Could not find post $postId in local feed items for optimistic update.");
    }


    // API call
    try {
      // Use the ID of the user *performing* the like action (loggedInUserId from AuthService or similar)
      // For the producer feed, this is likely the producer's own ID
      await _apiService.toggleLike(userId, postId);
      print("✅ [Controller] Post $postId like toggled successfully via API.");
      // Optional: You could re-fetch the specific post here to confirm server state,
      // but optimistic update is usually sufficient for UX.
    } catch (e) {
      print("❌ Error toggling like for post $postId: $e");
      // Revert optimistic update on error
      if (index != -1) {
        _updatePostState(postId, isLiked: currentLikeStatus, likesCount: currentLikesCount);
      }
      // Optionally show an error message to the user
    }
  }

   void trackPostView(dynamic post) {
     String? postId = _getPostId(post);
     if (postId == null) return;

     try {
       _apiService.trackPostView(postId: postId, userId: userId);
     } catch (e) {
       print('❌ [Controller] Error tracking post view for $postId: $e');
     }
   }

  // --- Internal Helpers ---
  void _handleError(String action, Object e) {
     print('❌ [Controller] Error $action: $e');
     // Use prefixed enum
     _loadState = ProducerFeedLoadState.error;
     _errorMessage = "Erreur lors de l\'action: $action. Détails: ${e.toString()}";
     // Don't notify here, let the calling method handle it
  }

   String? _getPostId(dynamic item) {
     if (item is Post) return item.id;
     if (item is Map<String, dynamic>) return item['_id']?.toString() ?? item['id']?.toString();
     return null;
   }

   bool _getPostLikedStatus(dynamic post) {
     if (post is Post) return post.isLiked ?? false;
     if (post is Map<String, dynamic>) return post['isLiked'] == true;
     return false;
   }

   int _getPostLikesCount(dynamic post) {
     if (post is Post) return post.likesCount ?? 0;
     if (post is Map<String, dynamic>) {
        return post['stats']?['likes_count'] ?? post['likes_count'] ?? 0;
     }
     return 0;
   }

   // Updates the state of a post within the _feedItems list
   void _updatePostState(String postId, {required bool isLiked, required int likesCount}) {
     final index = _feedItems.indexWhere((item) => _getPostId(item) == postId);
     if (index != -1) {
       final item = _feedItems[index];
           dynamic updatedItem;
       if (item is Post) {
               updatedItem = item.copyWith(isLiked: isLiked, likesCount: likesCount);
       } else if (item is Map<String, dynamic>) {
               updatedItem = Map<String, dynamic>.from(item); // Create a mutable copy
               updatedItem['isLiked'] = isLiked;
               updatedItem['likesCount'] = likesCount; // Ensure this key is used by the UI
               // Also update nested stats if they exist and are used
               if (updatedItem['stats'] is Map) {
                  updatedItem['stats'] = Map<String, dynamic>.from(updatedItem['stats']);
                  updatedItem['stats']['likes_count'] = likesCount;
               }
           }
           if (updatedItem != null) {
              _feedItems[index] = updatedItem;
              notifyListeners();
           }
       }
   }
}

// Helper extension for Post model if needed for copyWith
extension PostCopyWith on Post {
  Post copyWith({
    bool? isLiked,
    int? likesCount,
    // Add other fields you might need to update optimistically
  }) {
    return Post(
      // Copy all existing fields
      id: this.id,
      userId: this.userId,
      userName: this.userName,
      userPhotoUrl: this.userPhotoUrl,
      imageUrl: this.imageUrl,
      createdAt: this.createdAt,
      location: this.location,
      locationName: this.locationName,
      description: this.description,
      likes: this.likes,
      comments: this.comments,
      category: this.category,
      metadata: this.metadata,
      targetId: this.targetId,
      title: this.title,
      subtitle: this.subtitle,
      content: this.content,
      authorId: this.authorId,
      authorName: this.authorName,
      authorAvatar: this.authorAvatar,
      postedAt: this.postedAt,
      media: this.media,
      tags: this.tags,
      mediaUrls: this.mediaUrls,
      type: this.type,
      author: this.author,
      relevanceScore: this.relevanceScore,
      producerId: this.producerId,
      url: this.url,
      choiceCount: this.choiceCount,
      interestedCount: this.interestedCount,
      isChoice: this.isChoice,
      isInterested: this.isInterested,
      isProducerPost: this.isProducerPost,
      isLeisureProducer: this.isLeisureProducer,
      isWellnessProducer: this.isWellnessProducer,
      isRestaurationProducer: this.isRestaurationProducer,
      isAutomated: this.isAutomated,
      referencedEventId: this.referencedEventId,

      // Apply updates
      isLiked: isLiked ?? this.isLiked,
      likesCount: likesCount ?? this.likesCount,
    );
  }
} 
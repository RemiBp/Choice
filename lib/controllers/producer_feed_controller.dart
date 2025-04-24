import 'package:flutter/foundation.dart';
// Import with prefix to avoid ambiguity
import '../services/api_service.dart' as api_service;
import '../models/post.dart'; // KEEP: Defines the Post model
import '../models/dialogic_ai_message.dart'; // KEEP: Defines the AI message model

// No separate import needed if api_service.dart is imported fully
// import '../services/api_service.dart' show ProducerFeedLoadState;

// --- Placeholder ProducerFeedController ---
class ProducerFeedController with ChangeNotifier {
  final String userId;
  final String producerTypeString;
  // Use prefixed ApiService type
  final api_service.ApiService _apiService = api_service.ApiService(); // Instance of your API service

  List<dynamic> _feedItems = [];
  // Use prefixed enum
  api_service.ProducerFeedLoadState _loadState = api_service.ProducerFeedLoadState.initial;
  api_service.ProducerFeedContentType _currentFilter = api_service.ProducerFeedContentType.venue;
  String _errorMessage = '';
  bool _hasMorePosts = true;
  int _page = 1;
  String? _currentCategory; // Add category state

  ProducerFeedController({
    required this.userId,
    required this.producerTypeString,
  });

  // --- Getters ---
  List<dynamic> get feedItems => _feedItems;
  // Use prefixed enum
  api_service.ProducerFeedLoadState get loadState => _loadState;
  String get errorMessage => _errorMessage;
  bool get hasMorePosts => _hasMorePosts;
  // Use prefixed enum
  api_service.ProducerFeedContentType get currentFilter => _currentFilter; // Expose current filter
  String? get currentCategory => _currentCategory; // Expose current category

  // --- Core Methods ---
  Future<void> loadFeed({String? category}) async {
    if (_loadState == api_service.ProducerFeedLoadState.loading) return;
    print("🔄 [Controller] Loading feed for $userId - Filter: $_currentFilter, Category: ${category ?? 'All'} (Page: 1)");
    _loadState = api_service.ProducerFeedLoadState.loading;
    _page = 1;
    _currentCategory = category; // Set the category
    notifyListeners();

    try {
      final response = await _fetchProducerFeed(_page, _currentFilter, _currentCategory);
      _feedItems = response['items'] ?? [];
      _hasMorePosts = response['hasMore'] ?? false;
      _loadState = api_service.ProducerFeedLoadState.loaded;
      print("✅ [Controller] Feed loaded: ${_feedItems.length} items, hasMore: $_hasMorePosts");
    } catch (e) {
      _handleError("loading feed", e);
    } finally {
      if (notifyListeners != null) notifyListeners(); // Ensure notifyListeners is called even on error
    }
  }

  Future<void> loadMore() async {
    if (_loadState == api_service.ProducerFeedLoadState.loadingMore ||
        _loadState == api_service.ProducerFeedLoadState.loading ||
        !_hasMorePosts) {
      return;
    }
    print("🔄 [Controller] Loading more feed items... (Page: ${_page + 1})");
    _loadState = api_service.ProducerFeedLoadState.loadingMore;
    notifyListeners();

    try {
      final response = await _fetchProducerFeed(_page + 1, _currentFilter, _currentCategory);
      final newItems = response['items'] ?? [];
      _feedItems.addAll(newItems);
      _hasMorePosts = response['hasMore'] ?? false;
      _page++;
      _loadState = api_service.ProducerFeedLoadState.loaded;
       print("✅ [Controller] More items loaded: ${newItems.length}, Total: ${_feedItems.length}, hasMore: $_hasMorePosts");
    } catch (e) {
       _handleError("loading more items", e);
       // Keep existing items on load more error
       _loadState = api_service.ProducerFeedLoadState.loaded; // Revert state but don't clear items
    } finally {
       if (notifyListeners != null) notifyListeners();
    }
  }

  Future<void> refreshFeed() async {
    print("🔄 [Controller] Refreshing feed...");
    await loadFeed(category: _currentCategory);
  }

  void filterFeed(api_service.ProducerFeedContentType filter) {
    if (_currentFilter == filter && _loadState != api_service.ProducerFeedLoadState.initial) return;
    print("🔄 [Controller] Filtering feed to: $filter");
    _currentFilter = filter;
    // Reset feed before loading new filter type, KEEP category for now
    _feedItems = [];
    _hasMorePosts = true; // Assume has more initially
    loadFeed(category: _currentCategory); // Load data for the new filter, keep category
  }

  // New method to change category without changing the main filter type
  void changeCategory(String? category) {
    // Treat 'Tous' or null as no specific category
    final String? newCategory = (category == 'Tous' || category == null) ? null : category;
    if (_currentCategory == newCategory) return; // No change
    print("🔄 [Controller] Changing category to: ${newCategory ?? 'All'}");
    // No need to reset filter type, just load feed with new category
    loadFeed(category: newCategory);
  }

  // --- API Interaction ---
  Future<Map<String, dynamic>> _fetchProducerFeed(int page, api_service.ProducerFeedContentType filter, String? category) async {
    try {
      // Use the actual ApiService method - Update call signature
      return await _apiService.getProducerFeed(
        userId,
        contentType: filter,
        page: page,
        limit: 10,
        producerType: filter == api_service.ProducerFeedContentType.followers ? producerTypeString : null,
        category: category, // Pass category
      );
    } catch (e) {
      print('❌ [Controller] Error in _fetchProducerFeed: $e');
      rethrow; // Rethrow the error so the caller can handle state
    }
  }

  // --- Post Actions ---
  Future<void> likePost(dynamic post) async {
    String? postId = _getPostId(post);
    if (postId == null) return;

    final originalLikedStatus = _getPostLikedStatus(post);
    final originalLikesCount = _getPostLikesCount(post);

    // Optimistic UI update
    _updatePostState(postId, isLiked: !originalLikedStatus, likesCountDelta: originalLikedStatus ? -1 : 1);

    try {
      await _apiService.toggleLike(userId, postId); // Use actual user ID for liking
      print("✅ [Controller] Post $postId like toggled successfully.");
      // API call successful, UI is already updated
    } catch (e) {
       _handleError("liking post $postId", e);
       // Revert UI on error
       _updatePostState(postId, isLiked: originalLikedStatus, likesCount: originalLikesCount);
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
     _loadState = api_service.ProducerFeedLoadState.error;
     _errorMessage = "Erreur lors de l\'action: $action. Détails: ${e.toString()}";
     // Don't notify here, let the calling method handle it
  }

   String? _getPostId(dynamic post) {
     if (post is Post) return post.id;
     if (post is Map<String, dynamic>) return post['_id'];
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
   void _updatePostState(String postId, {bool? isLiked, int? likesCountDelta, int? likesCount}) {
     final index = _feedItems.indexWhere((item) => _getPostId(item) == postId);
     if (index != -1) {
       final item = _feedItems[index];
       if (item is Post) {
         // Create a new Post object with updated values
         final currentLikes = item.likesCount ?? 0;
         final currentLiked = item.isLiked ?? false;
         _feedItems[index] = item.copyWith(
           isLiked: isLiked ?? currentLiked,
           likesCount: likesCount ?? (currentLikes + (likesCountDelta ?? 0)),
         );
       } else if (item is Map<String, dynamic>) {
         // Update the map directly (create a new map to ensure change notification)
         final newItem = Map<String, dynamic>.from(item);
         final currentLikes = _getPostLikesCount(newItem);
         final currentLiked = _getPostLikedStatus(newItem);

         if (isLiked != null) newItem['isLiked'] = isLiked;
         if (likesCount != null) {
            newItem['likes_count'] = likesCount;
            if (newItem['stats'] is Map) newItem['stats']['likes_count'] = likesCount;
         } else if (likesCountDelta != null) {
            final newCount = currentLikes + likesCountDelta;
            newItem['likes_count'] = newCount;
             if (newItem['stats'] is Map) newItem['stats']['likes_count'] = newCount;
         }
         _feedItems[index] = newItem;
       }
       notifyListeners(); // Notify after update
     }
   }
} 
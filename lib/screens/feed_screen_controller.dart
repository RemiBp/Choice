import 'package:flutter/material.dart';
import 'dart:math';
import '../models/post.dart';
import '../services/api_service.dart';
import '../services/dialogic_ai_feed_service.dart';

enum FeedContentType {
  all,
  restaurants,
  leisure,
  userPosts,
  aiDialogic,
}

enum FeedLoadState {
  initial,
  loading,
  loaded,
  error,
  loadingMore,
}

class FeedScreenController extends ChangeNotifier {
  final String userId;
  final ApiService _apiService = ApiService();
  final DialogicAIFeedService _dialogicService = DialogicAIFeedService();
  
  List<dynamic> _feedItems = [];
  List<dynamic> get feedItems => _feedItems;
  
  FeedLoadState _loadState = FeedLoadState.initial;
  FeedLoadState get loadState => _loadState;
  
  String? _errorMessage;
  String? get errorMessage => _errorMessage;
  
  int _currentPage = 1;
  final int _postsPerPage = 10;
  bool _hasMorePosts = true;
  bool get hasMorePosts => _hasMorePosts;

  FeedContentType _currentFilter = FeedContentType.all;
  FeedContentType get currentFilter => _currentFilter;

  // Track recently viewed posts for AI contextual messages
  final List<dynamic> _recentlyViewedPosts = [];
  final List<String> _recentInteractions = [];

  // Controls how often AI messages appear in the feed
  final int _aiMessageFrequency = 5; // Show AI message every X posts
  int _postsSinceLastAiMessage = 0;

  FeedScreenController({required this.userId});

  /// Initial load of feed content
  Future<void> loadFeed({FeedContentType filter = FeedContentType.all}) async {
    if (_loadState == FeedLoadState.loading || _loadState == FeedLoadState.loadingMore) {
      return;
    }
    
    _setLoadState(FeedLoadState.loading);
    _currentFilter = filter;
    _currentPage = 1;
    _feedItems = [];
    
    try {
      await _fetchFeedContent();
      _setLoadState(FeedLoadState.loaded);
    } catch (e) {
      _setErrorState('Erreur lors du chargement : $e');
    }
  }

  /// Load more content when scrolling
  Future<void> loadMore() async {
    if (_loadState == FeedLoadState.loading || 
        _loadState == FeedLoadState.loadingMore || 
        !_hasMorePosts) {
      return;
    }
    
    _setLoadState(FeedLoadState.loadingMore);
    _currentPage++;
    
    try {
      await _fetchFeedContent(isLoadingMore: true);
      _setLoadState(FeedLoadState.loaded);
    } catch (e) {
      _currentPage--; // Revert page increment on error
      _setErrorState('Erreur lors du chargement : $e');
    }
  }

  /// Add a view to recently viewed posts for context
  void trackPostView(dynamic post) {
    // Keep track of recently viewed posts for context (limit to 20)
    _recentlyViewedPosts.add(post);
    if (_recentlyViewedPosts.length > 20) {
      _recentlyViewedPosts.removeAt(0);
    }
  }

  /// Track user interactions for AI context
  void trackInteraction(String interactionType, String targetId) {
    _recentInteractions.add('$interactionType:$targetId');
    if (_recentInteractions.length > 20) {
      _recentInteractions.removeAt(0);
    }
  }

  /// Handle like interaction for both Post objects and Map posts
  Future<void> likePost(dynamic postData) async {
    if (postData is Post) {
      // Handle Post object
      final int index = _feedItems.indexWhere((item) => 
          item is Post && item.id == postData.id);
      
      if (index != -1) {
        // Get current state
        final bool isCurrentlyLiked = postData.isLiked ?? false;
        final int currentLikes = postData.likesCount ?? 0;
        
        // Optimistic update - toggle like state
        final updatedPost = postData.copyWith(
          isLiked: !isCurrentlyLiked,
          likesCount: isCurrentlyLiked 
              ? (currentLikes > 0 ? currentLikes - 1 : 0) 
              : currentLikes + 1,
        );
        
        _feedItems[index] = updatedPost;
        notifyListeners();
        
        // Track this interaction
        trackInteraction('like', postData.id);
        
        try {
          // Call API to update backend
          await _apiService.markInterested(userId, postData.id);
        } catch (e) {
          print('❌ Error liking post: $e');
          // Revert on error
          _feedItems[index] = postData;
          notifyListeners();
        }
      }
    } else if (postData is Map<String, dynamic>) {
      // Handle Map-based post
      final String postId = postData['_id'] ?? '';
      final int index = _feedItems.indexWhere((item) {
        if (item is Map<String, dynamic>) {
          return item['_id'] == postId;
        }
        return false;
      });
      
      if (index != -1 && postId.isNotEmpty) {
        // Get current state
        final bool isCurrentlyLiked = postData['isLiked'] == true;
        final int currentLikes = 
            postData['likes_count'] ?? 
            postData['likesCount'] ?? 
            (postData['likes'] is List ? (postData['likes'] as List).length : 0);
        
        // Optimistic update
        final Map<String, dynamic> updatedPost = Map.from(postData);
        updatedPost['isLiked'] = !isCurrentlyLiked;
        updatedPost['likes_count'] = isCurrentlyLiked 
            ? (currentLikes > 0 ? currentLikes - 1 : 0) 
            : currentLikes + 1;
        updatedPost['likesCount'] = updatedPost['likes_count']; // Sync both fields
        
        _feedItems[index] = updatedPost;
        notifyListeners();
        
        // Track this interaction
        trackInteraction('like', postId);
        
        try {
          // Call API to update backend
          await _apiService.markInterested(userId, postId);
        } catch (e) {
          print('❌ Error liking post: $e');
          // Revert on error
          _feedItems[index] = postData;
          notifyListeners();
        }
      }
    }
  }

  /// Handle interest interaction
  Future<void> markInterested(String targetId, dynamic postData, {bool isLeisureProducer = false}) async {
    try {
      // Find the post in the feed
      final int index = _findPostIndex(postData);
      if (index == -1) return;
      
      // Call API
      final success = await _apiService.markInterested(
        userId, 
        targetId,
        isLeisureProducer: isLeisureProducer
      );
      
      if (success) {
        // Update local state based on post type
        if (_feedItems[index] is Post) {
          final post = _feedItems[index] as Post;
          final bool isCurrentlyInterested = post.isInterested;
          
          _feedItems[index] = post.copyWith(
            isInterested: !isCurrentlyInterested,
            interestedCount: isCurrentlyInterested 
                ? (post.interestedCount > 0 ? post.interestedCount - 1 : 0)
                : post.interestedCount + 1,
          );
        } else if (_feedItems[index] is Map<String, dynamic>) {
          final map = _feedItems[index] as Map<String, dynamic>;
          final bool isCurrentlyInterested = map['interested'] == true || map['isInterested'] == true;
          final int currentCount = map['interested_count'] ?? map['interestedCount'] ?? 0;
          
          map['interested'] = !isCurrentlyInterested;
          map['isInterested'] = !isCurrentlyInterested; // Sync both fields
          map['interested_count'] = isCurrentlyInterested 
              ? (currentCount > 0 ? currentCount - 1 : 0)
              : currentCount + 1;
          map['interestedCount'] = map['interested_count']; // Sync both fields
        }
        
        // Track interaction
        trackInteraction('interest', targetId);
        notifyListeners();
      }
    } catch (e) {
      print('❌ Error marking interested: $e');
    }
  }

  /// Handle choice interaction
  Future<void> markChoice(String targetId, dynamic postData, {bool isLeisureProducer = false}) async {
    try {
      // Find the post in the feed
      final int index = _findPostIndex(postData);
      if (index == -1) return;
      
      // Call API
      final success = await _apiService.markChoice(userId, targetId);
      
      if (success) {
        // Update local state based on post type
        if (_feedItems[index] is Post) {
          final post = _feedItems[index] as Post;
          final bool isCurrentlyChoice = post.isChoice;
          
          _feedItems[index] = post.copyWith(
            isChoice: !isCurrentlyChoice,
            choiceCount: isCurrentlyChoice 
                ? (post.choiceCount > 0 ? post.choiceCount - 1 : 0)
                : post.choiceCount + 1,
          );
        } else if (_feedItems[index] is Map<String, dynamic>) {
          final map = _feedItems[index] as Map<String, dynamic>;
          final bool isCurrentlyChoice = map['choice'] == true || map['isChoice'] == true;
          final int currentCount = map['choice_count'] ?? map['choiceCount'] ?? 0;
          
          map['choice'] = !isCurrentlyChoice;
          map['isChoice'] = !isCurrentlyChoice; // Sync both fields
          map['choice_count'] = isCurrentlyChoice 
              ? (currentCount > 0 ? currentCount - 1 : 0)
              : currentCount + 1;
          map['choiceCount'] = map['choice_count']; // Sync both fields
        }
        
        // Track interaction
        trackInteraction('choice', targetId);
        notifyListeners();
      }
    } catch (e) {
      print('❌ Error marking choice: $e');
    }
  }

  /// Handle AI message interaction
  Future<DialogicAIMessage> interactWithAiMessage(String userResponse) async {
    try {
      final aiResponse = await _dialogicService.getResponseToUserInteraction(
        userId, 
        userResponse
      );
      
      // Track interaction
      trackInteraction('ai_interaction', userResponse);
      
      return aiResponse;
    } catch (e) {
      print('❌ Error interacting with AI: $e');
      return DialogicAIMessage(
        content: "Je suis désolé, je n'ai pas pu traiter votre demande.",
        isInteractive: true,
        suggestions: ["Essayer à nouveau", "Voir des recommandations"],
      );
    }
  }

  /// Set user mood for emotional recommendations
  Future<List<String>> setUserMood(String mood) async {
    try {
      return await _dialogicService.getEmotionalRecommendations(mood);
    } catch (e) {
      print('❌ Error setting mood: $e');
      return [];
    }
  }

  /// Filter feed content
  void filterFeed(FeedContentType filter) {
    if (_currentFilter == filter) return;
    
    _currentFilter = filter;
    loadFeed(filter: filter);
  }

  /// Refresh feed content
  Future<void> refreshFeed() async {
    _currentPage = 1;
    _hasMorePosts = true;
    await loadFeed(filter: _currentFilter);
  }

  // Private methods

  /// Main method to fetch feed content from API
  Future<void> _fetchFeedContent({bool isLoadingMore = false}) async {
    try {
      // Fetch posts from API based on current filter
      List<dynamic> newItems = [];
      
      switch (_currentFilter) {
        case FeedContentType.all:
          final posts = await _apiService.getFeedPosts(
            userId: userId,
            page: _currentPage,
            limit: _postsPerPage,
          );
          newItems.addAll(posts);
          break;
          
        case FeedContentType.restaurants:
          // Add filter for restaurant posts
          final posts = await _apiService.getFeedPosts(
            userId: userId,
            page: _currentPage,
            limit: _postsPerPage,
          );
          newItems.addAll(posts.where((post) => 
            post.isProducerPost && !post.isLeisureProducer
          ));
          break;
          
        case FeedContentType.leisure:
          // Add filter for leisure posts
          final posts = await _apiService.getFeedPosts(
            userId: userId,
            page: _currentPage,
            limit: _postsPerPage,
          );
          newItems.addAll(posts.where((post) => 
            post.isProducerPost && post.isLeisureProducer
          ));
          break;
          
        case FeedContentType.userPosts:
          // Add filter for user posts
          final posts = await _apiService.getFeedPosts(
            userId: userId,
            page: _currentPage,
            limit: _postsPerPage,
          );
          newItems.addAll(posts.where((post) => !post.isProducerPost));
          break;
          
        case FeedContentType.aiDialogic:
          // Fetch AI dialogic messages
          final aiMessages = await _dialogicService.getDialogicFeedContent(
            userId,
            userInterests: _extractInterests(),
          );
          
          // Convert AI messages to a format that can be displayed in feed
          newItems.addAll(aiMessages);
          break;
      }
      
      // Add dialogic AI content interspersed with regular posts
      if (_currentFilter != FeedContentType.aiDialogic && 
          !isLoadingMore && 
          _currentPage == 1) {
        // Add initial AI greeting at the top of the feed
        final contextualMessage = await _dialogicService.getContextualMessage(
          userId, 
          _convertToPostList(_recentlyViewedPosts), 
          _recentInteractions
        );
        
        // Insert AI message at the beginning of the feed
        newItems.insert(0, contextualMessage);
      } else if (_currentFilter != FeedContentType.aiDialogic && 
                _postsSinceLastAiMessage >= _aiMessageFrequency) {
        // Add periodic AI message within feed
        final contextualMessage = await _dialogicService.getContextualMessage(
          userId, 
          _convertToPostList(_recentlyViewedPosts), 
          _recentInteractions
        );
        
        // Insert AI message randomly within the new items
        final int insertPosition = min(
          Random().nextInt(newItems.length), 
          newItems.length
        );
        newItems.insert(insertPosition, contextualMessage);
        _postsSinceLastAiMessage = 0;
      } else {
        _postsSinceLastAiMessage += newItems.length;
      }
      
      // Update feed items
      if (isLoadingMore) {
        _feedItems.addAll(newItems);
      } else {
        _feedItems = newItems;
      }
      
      // Check if there might be more posts
      _hasMorePosts = newItems.length >= _postsPerPage;
      
      notifyListeners();
    } catch (e) {
      print('❌ Error fetching feed content: $e');
      throw e;
    }
  }

  /// Helper to extract user interests from recently viewed posts
  List<String> _extractInterests() {
    Set<String> interests = {};
    
    for (final dynamic postItem in _recentlyViewedPosts) {
      if (postItem is Post) {
        // Handle Post object
        if (postItem.isProducerPost) {
          interests.add(postItem.isLeisureProducer ? 'leisure' : 'restaurant');
        }
        // Post objects don't have tags field currently
      } else if (postItem is Map<String, dynamic>) {
        // Handle Map-based post
        final bool isProducer = postItem['isProducerPost'] == true || 
                             postItem['producer_id'] != null;
        final bool isLeisure = postItem['isLeisureProducer'] == true;
        
        if (isProducer) {
          interests.add(isLeisure ? 'leisure' : 'restaurant');
        }
        
        // Extract from tags if available
        if (postItem['tags'] is List) {
          interests.addAll((postItem['tags'] as List).map((tag) => tag.toString()));
        }
      }
    }
    
    return interests.toList();
  }

  // Find a post in the feed items by ID (works with both Post objects and Map posts)
  int _findPostIndex(dynamic postData) {
    String postId = '';
    
    if (postData is Post) {
      postId = postData.id;
    } else if (postData is Map<String, dynamic>) {
      postId = postData['_id'] ?? '';
    }
    
    for (int i = 0; i < _feedItems.length; i++) {
      String currentId = '';
      
      if (_feedItems[i] is Post) {
        currentId = (_feedItems[i] as Post).id;
      } else if (_feedItems[i] is Map<String, dynamic>) {
        currentId = (_feedItems[i] as Map<String, dynamic>)['_id'] ?? '';
      }
      
      if (currentId == postId) {
        return i;
      }
    }
    
    return -1;
  }

  // Convert dynamic items to Post objects
  List<Post> _convertToPostList(List<dynamic> items) {
    List<Post> result = [];
    
    for (var item in items) {
      if (item is Post) {
        // Already a Post, just add it
        result.add(item);
      } else if (item is Map<String, dynamic>) {
        // Try to convert Map to Post
        try {
          final String postId = item['_id'] ?? '';
          final String content = item['content'] ?? '';
          
          // Get author info
          String authorName = '';
          String authorAvatar = '';
          String authorId = '';
          
          if (item['author'] is Map) {
            final author = item['author'] as Map;
            authorName = author['name'] ?? '';
            authorAvatar = author['avatar'] ?? '';
            authorId = author['id'] ?? '';
          } else {
            authorName = item['author_name'] ?? '';
            authorAvatar = item['author_avatar'] ?? item['author_photo'] ?? '';
            authorId = item['author_id'] ?? item['user_id'] ?? '';
          }
          
          // Get post timestamp
          DateTime postedAt = DateTime.now();
          if (item['posted_at'] != null) {
            try {
              postedAt = DateTime.parse(item['posted_at'].toString());
            } catch (e) {
              print('❌ Error parsing timestamp: $e');
            }
          } else if (item['time_posted'] != null) {
            try {
              postedAt = DateTime.parse(item['time_posted'].toString());
            } catch (e) {
              print('❌ Error parsing timestamp: $e');
            }
          }
          
          // Determine if this is a producer post
          final bool isProducerPost = item['isProducerPost'] == true || 
                                  item['producer_id'] != null;
          final bool isLeisureProducer = item['isLeisureProducer'] == true;
          
          // Convert to Post object and add to result
          result.add(Post(
            id: postId,
            authorId: authorId,
            authorName: authorName,
            authorAvatar: authorAvatar,
            content: content,
            postedAt: postedAt,
            media: [],  // Not converting media for simplicity
            isProducerPost: isProducerPost,
            isLeisureProducer: isLeisureProducer,
            isInterested: item['interested'] == true || item['isInterested'] == true,
            isChoice: item['choice'] == true || item['isChoice'] == true,
            interestedCount: item['interested_count'] ?? item['interestedCount'] ?? 0,
            choiceCount: item['choice_count'] ?? item['choiceCount'] ?? 0,
            isLiked: item['isLiked'] == true,
            likesCount: item['likes_count'] ?? item['likesCount'] ?? 
                    (item['likes'] is List ? (item['likes'] as List).length : 0),
            comments: [],  // Not converting comments for simplicity
          ));
        } catch (e) {
          print('❌ Error converting map to Post: $e');
          // Skip this item if conversion fails
        }
      }
    }
    
    return result;
  }

  void _setLoadState(FeedLoadState state) {
    _loadState = state;
    notifyListeners();
  }

  void _setErrorState(String message) {
    _loadState = FeedLoadState.error;
    _errorMessage = message;
    notifyListeners();
  }
}
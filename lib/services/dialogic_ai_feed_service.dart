import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../models/post.dart';
import 'ai_service.dart';

class DialogicAIMessage {
  final String content;
  final bool isInteractive;
  final List<String> suggestions;
  final DateTime timestamp;

  DialogicAIMessage({
    required this.content,
    this.isInteractive = false,
    this.suggestions = const [],
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory DialogicAIMessage.fromJson(Map<String, dynamic> json) {
    return DialogicAIMessage(
      content: json['content'] ?? '',
      isInteractive: json['is_interactive'] ?? false,
      suggestions: (json['suggestions'] as List?)?.map((e) => e.toString()).toList() ?? [],
      timestamp: json['timestamp'] != null 
          ? DateTime.parse(json['timestamp']) 
          : DateTime.now(),
    );
  }
}

class DialogicAIFeedService {
  static final DialogicAIFeedService _instance = DialogicAIFeedService._internal();
  factory DialogicAIFeedService() => _instance;
  DialogicAIFeedService._internal();

  final String _baseUrl = getBaseUrl();
  final AIService _aiService = AIService();

  /// Fetches AI-driven dialogic feed content that can be integrated into the feed
  Future<List<DialogicAIMessage>> getDialogicFeedContent(
    String userId, {
    String? userLocation,
    List<String>? userInterests,
    String? userMood,
  }) async {
    try {
      final url = Uri.parse('$_baseUrl/api/ai/dialogic-feed');
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'userId': userId,
          'location': userLocation,
          'interests': userInterests,
          'mood': userMood,
        }),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((item) => DialogicAIMessage.fromJson(item)).toList();
      } else {
        print('❌ Error fetching dialogic feed: ${response.statusCode}');
        return _getFallbackMessages(); // Fallback in case of error
      }
    } catch (e) {
      print('❌ Exception in getDialogicFeedContent: $e');
      return _getFallbackMessages(); // Fallback in case of exception
    }
  }

  /// Gets contextual AI message based on user's feed behavior
  Future<DialogicAIMessage> getContextualMessage(
    String userId, 
    List<Post> recentlyViewedPosts,
    List<String> recentInteractions,
  ) async {
    try {
      // Use the existing AI service to generate a contextual message
      final prompt = "Based on the user's recent activity, generate a personalized feed message";
      
      AIQueryResponse aiResponse = await _aiService.simpleQuery(prompt);
      
      return DialogicAIMessage(
        content: aiResponse.response,
        isInteractive: true,
        suggestions: _generateSuggestions(recentlyViewedPosts, recentInteractions),
      );
    } catch (e) {
      print('❌ Error generating contextual message: $e');
      return DialogicAIMessage(
        content: "Découvrez des lieux qui pourraient vous plaire aujourd'hui!",
        isInteractive: true,
        suggestions: ["Restaurants près de moi", "Événements ce weekend", "Activités populaires"],
      );
    }
  }

  /// Generates response when user interacts with AI message in feed
  Future<DialogicAIMessage> getResponseToUserInteraction(
    String userId,
    String userInput,
  ) async {
    try {
      AIQueryResponse aiResponse = await _aiService.userQuery(userId, userInput);
      
      return DialogicAIMessage(
        content: aiResponse.response,
        isInteractive: true,
        suggestions: aiResponse.suggestions ?? [],
      );
    } catch (e) {
      print('❌ Error generating response to interaction: $e');
      return DialogicAIMessage(
        content: "Je serais ravi de vous aider à trouver de nouveaux endroits à explorer!",
        isInteractive: true,
        suggestions: ["Explorer des restaurants", "Événements populaires", "Lieux tendance"],
      );
    }
  }

  /// Maps emotional tone to post recommendations
  Future<List<String>> getEmotionalRecommendations(String mood) async {
    try {
      final url = Uri.parse('$_baseUrl/api/ai/vibe-map/emotions');
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'mood': mood,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return (data['recommendations'] as List?)?.map((e) => e.toString()).toList() ?? [];
      } else {
        return ["restaurant romantique", "concert jazz", "café tranquille"];
      }
    } catch (e) {
      print('❌ Error getting emotional recommendations: $e');
      return ["restaurant romantique", "concert jazz", "café tranquille"];
    }
  }

  /// Private helper method to generate fallback AI messages
  List<DialogicAIMessage> _getFallbackMessages() {
    return [
      DialogicAIMessage(
        content: "Bonjour! Qu'aimeriez-vous découvrir aujourd'hui?",
        isInteractive: true,
        suggestions: ["Restaurants près de moi", "Événements ce weekend", "Lieux tendance"],
      ),
      DialogicAIMessage(
        content: "Voici des lieux qui pourraient vous plaire en fonction de vos goûts.",
        isInteractive: false,
      ),
    ];
  }

  /// Private helper method to generate relevant suggestions based on user activity
  List<String> _generateSuggestions(
    List<Post> recentlyViewedPosts,
    List<String> recentInteractions,
  ) {
    // Default suggestions if we can't generate anything specific
    List<String> suggestions = [
      "Restaurants près de moi",
      "Événements ce weekend",
      "Lieux populaires"
    ];
    
    // Check for patterns in recent posts to generate more specific suggestions
    if (recentlyViewedPosts.isNotEmpty) {
      // Check if user viewed many restaurant posts
      bool restaurantFocus = recentlyViewedPosts
          .where((post) => 
              post.isProducerPost && !post.isLeisureProducer)
          .length > (recentlyViewedPosts.length / 3);
          
      // Check if user viewed many leisure/event posts
      bool leisureFocus = recentlyViewedPosts
          .where((post) => 
              post.isProducerPost && post.isLeisureProducer)
          .length > (recentlyViewedPosts.length / 3);
          
      if (restaurantFocus) {
        suggestions.add("Nouveaux restaurants");
        suggestions.add("Cuisine populaire");
      }
      
      if (leisureFocus) {
        suggestions.add("Activités du weekend");
        suggestions.add("Événements à venir");
      }
    }
    
    return suggestions.take(3).toList(); // Limit to 3 suggestions
  }
}
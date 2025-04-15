import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import '../utils/constants.dart' as constants;
import '../models/post.dart';
import 'ai_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DialogicAIMessage {
  final String id;
  final String content;
  final List<String> suggestions;
  final bool isInteractive;
  final DateTime timestamp;
  final List<Map<String, dynamic>>? profiles;
  final String? sender;

  DialogicAIMessage({
    required this.id,
    required this.content,
    this.suggestions = const [],
    this.isInteractive = true,
    DateTime? timestamp,
    this.profiles,
    this.sender,
  }) : timestamp = timestamp ?? DateTime.now();

  // Add getter for messageId that returns the id
  String? get messageId => id;

  factory DialogicAIMessage.fromJson(Map<String, dynamic> json) {
    return DialogicAIMessage(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      content: json['content'] ?? 'Pas de contenu disponible.',
      suggestions: json['suggestions'] is List ? List<String>.from(json['suggestions']) : [],
      isInteractive: json['isInteractive'] ?? true,
      timestamp: json['timestamp'] != null ? DateTime.parse(json['timestamp']) : DateTime.now(),
      profiles: json['profiles'] is List ? List<Map<String, dynamic>>.from(json['profiles']) : null,
      sender: json['sender'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'suggestions': suggestions,
      'isInteractive': isInteractive,
      'timestamp': timestamp.toIso8601String(),
      'profiles': profiles,
      'type': 'ai_message'
    };
  }
}

class DialogicAIFeedService {
  static final DialogicAIFeedService _instance = DialogicAIFeedService._internal();
  factory DialogicAIFeedService() => _instance;
  DialogicAIFeedService._internal();

  String getBaseUrl() {
    return constants.getBaseUrl();
  }
  final AIService _aiService = AIService();

  // Cache des messages récents pour éviter les répétitions
  final List<String> _recentMessageContents = [];

  /// Générer un message IA contextuel basé sur les posts récemment vus
  Future<DialogicAIMessage> generateContextualFeedMessage(List<dynamic> recentPosts, {List<String>? interactions}) async {
    try {
      // Extraire le contexte des posts récents
      final context = _extractContextFromPosts(recentPosts);
      
      // Si l'API n'est pas disponible, générer un message localement
      if (!await _isApiAvailable()) {
        return _generateLocalMessage(context);
      }
      
      // Essayer d'appeler l'API pour un message personnalisé
      final url = Uri.parse('${constants.API_URL}/api/ai/feed-message');
      final body = {
        'context': context,
        'interactions': interactions ?? [],
        'recentMessages': _recentMessageContents,
      };
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final message = DialogicAIMessage.fromJson(data);
        
        // Ajouter au cache pour éviter les répétitions
        if (_recentMessageContents.length >= 5) {
          _recentMessageContents.removeAt(0);
        }
        _recentMessageContents.add(message.content);
        
        return message;
      } else {
        // En cas d'erreur API, générer localement
        return _generateLocalMessage(context);
      }
    } catch (e) {
      print('❌ Erreur lors de la génération du message IA: $e');
      return _generateLocalMessage({});
    }
  }
  
  // Extraire le contexte des posts récents
  Map<String, dynamic> _extractContextFromPosts(List<dynamic> posts) {
    if (posts.isEmpty) return {};
    
    // Compter les types de contenus vus
    int restaurantCount = 0;
    int leisureCount = 0;
    int userCount = 0;
    
    // Collecter les tags et lieux pour analyse
    final Set<String> tags = {};
    final Set<String> locations = {};
    final Set<String> producerIds = {};
    
    for (var post in posts) {
      if (post is Post) {
        if (post.isProducerPost ?? false) {
          if (post.isLeisureProducer ?? false) {
            leisureCount++;
          } else {
            restaurantCount++;
          }
          if (post.authorId != null) {
            producerIds.add(post.authorId!);
          }
        } else {
          userCount++;
        }
        
        // Collecter les tags
        if (post.tags != null) {
          tags.addAll(post.tags!);
        }
        
        // Collecter les lieux
        if (post.location != null && post.location is String) {
          locations.add(post.location!.toString());
        } else if (post.locationName != null) {
          locations.add(post.locationName!);
        }
      } else if (post is Map<String, dynamic>) {
        if (post['isProducerPost'] == true || post['producer_id'] != null) {
          if (post['isLeisureProducer'] == true) {
            leisureCount++;
          } else {
            restaurantCount++;
          }
          final String? authorId = post['authorId'] ?? post['author_id'];
          if (authorId != null) {
            producerIds.add(authorId);
          }
        } else {
          userCount++;
        }
        
        // Collecter les tags
        if (post['tags'] is List) {
          for (var tag in post['tags']) {
            if (tag is String) tags.add(tag);
          }
        }
        
        // Collecter les lieux
        if (post['location'] != null) {
          if (post['location'] is String) {
            locations.add(post['location']);
          } else if (post['location'] is Map && post['location']['name'] != null) {
            locations.add(post['location']['name']);
          }
        } else if (post['locationName'] != null) {
          locations.add(post['locationName']);
        }
      }
    }
    
    return {
      'contentTypes': {
        'restaurant': restaurantCount,
        'leisure': leisureCount,
        'user': userCount,
      },
      'tags': tags.toList(),
      'locations': locations.toList(),
      'producerIds': producerIds.toList(),
    };
  }
  
  // Vérifier si l'API est disponible
  Future<bool> _isApiAvailable() async {
    try {
      final url = Uri.parse('${constants.API_URL}/api/status');
      final response = await http.get(url).timeout(const Duration(seconds: 3));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
  
  // Générer un message localement avec des suggestions basées sur le contexte
  DialogicAIMessage _generateLocalMessage(Map<String, dynamic> context) {
    // Messages génériques pour le fallback
    final List<String> genericMessages = [
      "Bonjour ! Avez-vous découvert de nouveaux restaurants récemment ?",
      "Recherchez-vous des activités à faire ce weekend ?",
      "Des suggestions pour vos sorties aujourd'hui ?",
      "Envie de découvrir de nouveaux lieux près de chez vous ?",
    ];
    
    // Suggestions génériques
    final List<String> genericSuggestions = [
      "Restaurants tendance",
      "Activités du weekend",
      "Près de chez moi",
      "Recommandations"
    ];
    
    // Sélectionner un message en fonction du contexte
    String message;
    List<String> suggestions;
    List<Map<String, dynamic>> profiles = [];
    
    // Si on a du contexte, essayer de personnaliser le message
    if (context.isNotEmpty) {
      final contentTypes = context['contentTypes'] as Map<String, dynamic>? ?? {};
      final int restaurantCount = contentTypes['restaurant'] ?? 0;
      final int leisureCount = contentTypes['leisure'] ?? 0;
      
      if (restaurantCount > leisureCount && restaurantCount > 0) {
        message = "Je vois que vous vous intéressez aux restaurants. Voulez-vous découvrir des options similaires à celles que vous avez consultées ?";
        suggestions = [
          "Restaurants similaires",
          "Cuisines du monde",
          "Établissements populaires",
          "Bonnes adresses"
        ];
      } else if (leisureCount > restaurantCount && leisureCount > 0) {
        message = "Vous semblez apprécier les activités de loisirs. Souhaitez-vous explorer d'autres options ?";
        suggestions = [
          "Activités similaires",
          "Événements à venir",
          "Expériences uniques",
          "Sorties culturelles"
        ];
      } else {
        // Mix de restaurants et loisirs ou peu de données
        message = "Découvrez des expériences uniques près de chez vous ! Que souhaitez-vous explorer ?";
        suggestions = [
          "Restaurants", 
          "Loisirs et activités",
          "Événements", 
          "Tendances actuelles"
        ];
      }
    } else {
      // Aucun contexte, utiliser un message générique
      message = genericMessages[DateTime.now().millisecondsSinceEpoch % genericMessages.length];
      suggestions = genericSuggestions;
    }
    
    // Générer un ID unique basé sur le timestamp
    final String id = 'ai-msg-${DateTime.now().millisecondsSinceEpoch}';
    
    return DialogicAIMessage(
      id: id,
      content: message,
      suggestions: suggestions,
      isInteractive: true,
      profiles: profiles.isEmpty ? null : profiles,
      sender: null,
    );
  }

  // Répondre à un message utilisateur
  Future<DialogicAIMessage> respondToUserMessage(String userMessage, {List<dynamic>? context}) async {
    // Implémenter la logique de réponse
    try {
      // Essayer d'appeler l'API pour une réponse
      final url = Uri.parse('${constants.API_URL}/api/ai/chat');
      final body = {
        'message': userMessage,
        'context': context ?? [],
      };
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return DialogicAIMessage.fromJson(data);
      }
    } catch (e) {
      print('❌ Erreur lors de la réponse au message: $e');
    }
    
    // Réponse par défaut en cas d'échec
    return DialogicAIMessage(
      id: 'response-${DateTime.now().millisecondsSinceEpoch}',
      content: "Je suis désolé, je ne peux pas traiter votre demande pour le moment. Comment puis-je vous aider autrement ?",
      suggestions: ["Restaurants", "Activités", "Retour"],
      isInteractive: true,
      profiles: null,
      sender: null,
    );
  }

  /// Fetches AI-driven dialogic feed content that can be integrated into the feed
  Future<List<DialogicAIMessage>> getDialogicFeedContent(
    String userId, {
    String? userLocation,
    List<String>? userInterests,
    String? userMood,
  }) async {
    try {
      final url = Uri.parse('${getBaseUrl()}/api/ai/dialogic-feed');
      
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
        final messages = data.map((item) => DialogicAIMessage.fromJson(item)).toList();
        
        // If the messages contain profiles, enrich them with displayable data
        for (var message in messages) {
          if (message.profiles != null && message.profiles!.isNotEmpty) {
            await _enrichProfiles(message.profiles!);
          }
        }
        
        return messages;
      } else {
        print('❌ Error fetching dialogic feed: ${response.statusCode}');
        return _getFallbackMessages(); // Fallback in case of error
      }
    } catch (e) {
      print('❌ Exception in getDialogicFeedContent: $e');
      return _getFallbackMessages(); // Fallback in case of exception
    }
  }

  /// Méthode pour récupérer le contenu du feed dialogique formaté pour l'intégration dans le feed principal
  Future<List<dynamic>> getDialogicFeed({
    required String userId,
    List<dynamic>? recentPosts,
    List<String>? recentInteractions,
    int page = 1,
    int limit = 10,
  }) async {
    try {
      // Récupérer le contenu dialogique
      final messages = await getDialogicFeedContent(userId);
      
      // Transformer les messages en format compatible avec le feed
      final feedItems = messages.map((message) {
        // Créer un format compatible avec Post pour l'affichage dans le feed
        return {
          '_id': message.id,
          'id': message.id,
          'content': message.content,
          'type': 'ai_message',
          'author_name': 'Choice Assistant',
          'author_photo': 'https://storage.googleapis.com/choice-app-resources/choice_assistant_avatar.png',
          'posted_at': message.timestamp.toIso8601String(),
          'is_ai': true,
          'suggestions': message.suggestions,
          'is_interactive': message.isInteractive,
          'profiles': message.profiles,
        };
      }).toList();
      
      // Limiter les résultats selon la pagination
      final startIndex = (page - 1) * limit;
      final endIndex = startIndex + limit;
      
      if (startIndex >= feedItems.length) {
        return [];
      }
      
      final paginatedItems = feedItems.sublist(
        startIndex, 
        endIndex > feedItems.length ? feedItems.length : endIndex
      );
      
      return paginatedItems;
    } catch (e) {
      print('❌ Exception dans getDialogicFeed: $e');
      return [];
    }
  }

  /// Gets contextual AI message based on user's feed behavior
  Future<DialogicAIMessage> getContextualMessage(
    String userId, 
    List<Post> recentlyViewedPosts,
    List<String> recentInteractions,
  ) async {
    try {
      // Get insights from the AI service
      final url = Uri.parse('${getBaseUrl()}/api/ai/insights/user/$userId');
      
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Extract profiles and enrich them
        List<Map<String, dynamic>> profiles = [];
        if (data['profiles'] != null && data['profiles'] is List) {
          profiles = List<Map<String, dynamic>>.from(data['profiles']);
          await _enrichProfiles(profiles);
        }
        
        return DialogicAIMessage(
          id: data['messageId'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
          content: data['response'] ?? "Voici des recommandations basées sur vos goûts",
          suggestions: _generateSuggestions(recentlyViewedPosts, recentInteractions),
          isInteractive: true,
          profiles: profiles.isNotEmpty ? profiles : null,
          sender: null,
        );
      } else {
        // Fallback to simpler query if insights endpoint fails
        final prompt = "Based on the user's recent activity, generate a personalized feed message";
        AIQueryResponse aiResponse = await _aiService.simpleQuery(prompt);
        
        return DialogicAIMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          content: aiResponse.response,
          suggestions: _generateSuggestions(recentlyViewedPosts, recentInteractions),
          isInteractive: true,
          profiles: null,
          sender: null,
        );
      }
    } catch (e) {
      print('❌ Error generating contextual message: $e');
      return DialogicAIMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: "Découvrez des lieux qui pourraient vous plaire aujourd'hui!",
        suggestions: ["Restaurants près de moi", "Événements ce weekend", "Activités populaires"],
        isInteractive: true,
        profiles: null,
        sender: null,
      );
    }
  }

  /// Generates response when user interacts with AI message in feed
  Future<DialogicAIMessage> getResponseToUserInteraction(
    String userId,
    String userInput,
  ) async {
    try {
      // Use the AI service to get a detailed response
      AIQueryResponse aiResponse = await _aiService.userQuery(userId, userInput);
      
      // Check if we have profiles in the response
      List<Map<String, dynamic>> profiles = [];
      if (aiResponse.profiles != null && aiResponse.profiles!.isNotEmpty) {
        // Convertir chaque ProfileData en Map<String, dynamic>
        profiles = aiResponse.profiles!.map((profileData) => {
          'id': profileData.id,
          'type': profileData.type,
          'name': profileData.name,
          'address': profileData.address,
          'description': profileData.description,
          'rating': profileData.rating,
          'photo': profileData.image, // Mapper image à photo pour la cohérence
          'category': profileData.category,
          'price_level': profileData.priceLevel,
          'highlighted_item': profileData.highlightedItem,
          'targetId': profileData.id, // Utiliser l'ID comme targetId pour les redirections
        }).toList();
        
        await _enrichProfiles(profiles);
      }
      
      return DialogicAIMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: aiResponse.response,
        suggestions: aiResponse.suggestions ?? [],
        isInteractive: true,
        profiles: profiles.isNotEmpty ? profiles : null,
        sender: null,
      );
    } catch (e) {
      print('❌ Error generating response to interaction: $e');
      return DialogicAIMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: "Je serais ravi de vous aider à trouver de nouveaux endroits à explorer!",
        suggestions: ["Explorer des restaurants", "Événements populaires", "Lieux tendance"],
        isInteractive: true,
        profiles: null,
        sender: null,
      );
    }
  }
  /// Enrich profiles with proper display data for the feed
  Future<void> _enrichProfiles(List<Map<String, dynamic>> profiles) async {
    for (var profile in profiles) {
      try {
        // Step 1: Ensure each profile has a proper name
        _ensureProfileName(profile);
        
        // Step 2: Ensure each profile has a working image URL
        _ensureProfilePhoto(profile);
        
        // Step 3: Determine the correct profile type
        _determineProfileType(profile);
        
        // Step 4: Ensure proper targetId for redirections
        _ensureTargetId(profile);
        
        // Step 5: Format for display in the feed
        _formatForFeedDisplay(profile);
        
      } catch (e) {
        print('❌ Error enriching profile: $e');
        // Ensure at least minimal data is available
        _applyFallbackProfileData(profile);
      }
    }
  }
  
  /// Ensures profile has a proper name
  void _ensureProfileName(Map<String, dynamic> profile) {
    // Try various possible name fields
    if (profile['name'] == null || profile['name'].toString().isEmpty) {
      if (profile['nom'] != null && profile['nom'].toString().isNotEmpty) {
        profile['name'] = profile['nom'];
      } else if (profile['title'] != null && profile['title'].toString().isNotEmpty) {
        profile['name'] = profile['title'];
      } else if (profile['lieu'] != null && profile['lieu'].toString().isNotEmpty) {
        profile['name'] = profile['lieu'];
      } else {
        // Default name based on type
        if (_isRestaurantType(profile)) {
          profile['name'] = 'Restaurant Recommandé';
        } else if (_isLeisureType(profile)) {
          profile['name'] = 'Lieu Culturel Recommandé';
        } else {
          profile['name'] = 'Lieu Recommandé';
        }
      }
    }
  }
  
  /// Ensures profile has a proper photo URL
  void _ensureProfilePhoto(Map<String, dynamic> profile) {
    // Try various possible photo fields
    List<String> photoFields = ['photo', 'image', 'photo_url', 'image_url', 'avatar', 'picture'];
    
    bool hasPhoto = false;
    for (var field in photoFields) {
      if (profile[field] != null && profile[field].toString().isNotEmpty) {
        profile['photo'] = profile[field];
        hasPhoto = true;
        break;
      }
    }
    
    // If no photo found, use appropriate placeholder
    if (!hasPhoto) {
      if (_isRestaurantType(profile)) {
        profile['photo'] = 'https://choice-app.fr/assets/images/restaurant-placeholder.jpg';
      } else if (_isLeisureType(profile)) {
        profile['photo'] = 'https://choice-app.fr/assets/images/leisure-placeholder.jpg';
      } else {
        profile['photo'] = 'https://choice-app.fr/assets/images/venue-placeholder.jpg';
      }
    }
    
    // Validate URL format and apply http if missing
    String photoUrl = profile['photo'].toString();
    if (!photoUrl.startsWith('http')) {
      // If it's a relative URL, make it absolute
      if (photoUrl.startsWith('/')) {
        profile['photo'] = 'https://choice-app.fr$photoUrl';
      } else {
        profile['photo'] = 'https://$photoUrl';
      }
    }
  }
  
  /// Determines correct profile type based on available data
  void _determineProfileType(Map<String, dynamic> profile) {
    if (profile['type'] == null || profile['type'].toString().isEmpty) {
      // Try to infer type from categories
      if (profile['category'] != null) {
        if (profile['category'] is List && (profile['category'] as List).isNotEmpty) {
          String category = (profile['category'] as List).first.toString().toLowerCase();
          _assignTypeFromCategory(profile, category);
        } else if (profile['category'] is String) {
          String category = profile['category'].toString().toLowerCase();
          _assignTypeFromCategory(profile, category);
        }
      }
      
      // Try to infer from tags if still no type
      if ((profile['type'] == null || profile['type'].toString().isEmpty) && 
          profile['tags'] != null && profile['tags'] is List) {
        List<String> tags = (profile['tags'] as List).map((t) => t.toString().toLowerCase()).toList();
        for (var tag in tags) {
          if (tag.contains('restaurant') || tag.contains('cuisine') || tag.contains('gastronomie')) {
            profile['type'] = 'restaurant';
            break;
          } else if (tag.contains('loisir') || tag.contains('culture') || 
                    tag.contains('art') || tag.contains('théâtre') || 
                    tag.contains('musée') || tag.contains('concert')) {
            profile['type'] = 'leisure';
            break;
          }
        }
      }
      
      // Default to generic venue if still not set
      if (profile['type'] == null || profile['type'].toString().isEmpty) {
        profile['type'] = 'venue';
      }
    }
  }
  
  /// Helper to assign type based on category
  void _assignTypeFromCategory(Map<String, dynamic> profile, String category) {
    if (category.contains('restaurant') || category.contains('cuisine') || 
        category.contains('gastronomie') || category.contains('bistro')) {
      profile['type'] = 'restaurant';
    } else if (category.contains('loisir') || category.contains('culture') || 
              category.contains('art') || category.contains('théâtre') || 
              category.contains('musée') || category.contains('concert')) {
      profile['type'] = 'leisure';
    }
  }
  
  /// Ensures profile has a valid targetId for redirections
  void _ensureTargetId(Map<String, dynamic> profile) {
    // Try various possible ID fields
    List<String> idFields = ['targetId', '_id', 'id', 'objectID', 'producer_id'];
    
    bool hasId = false;
    for (var field in idFields) {
      if (profile[field] != null && profile[field].toString().isNotEmpty) {
        profile['targetId'] = profile[field].toString();
        hasId = true;
        break;
      }
    }
    
    // Generate a unique ID if none found, this ensures redirections work
    if (!hasId) {
      profile['targetId'] = 'ai-rec-${DateTime.now().millisecondsSinceEpoch}-${profile['name'].hashCode}';
    }
  }
  
  /// Formats profile data for consistent display in feed
  void _formatForFeedDisplay(Map<String, dynamic> profile) {
    // Required author info for feed
    profile['author_name'] = profile['name'];
    profile['author_avatar'] = profile['photo'];
    profile['author_id'] = profile['targetId'];
    
    // Set post type flags required by feed display
    profile['isProducerPost'] = true;
    profile['isLeisureProducer'] = _isLeisureType(profile);
    
    // Ensure content is available for display
    if (profile['content'] == null || profile['content'].toString().isEmpty) {
      List<String> contentFields = ['description', 'about', 'summary', 'details'];
      
      bool hasContent = false;
      for (var field in contentFields) {
        if (profile[field] != null && profile[field].toString().isNotEmpty) {
          profile['content'] = profile[field];
          hasContent = true;
          break;
        }
      }
      
      // Create default content if none found
      if (!hasContent) {
        if (_isRestaurantType(profile)) {
          profile['content'] = 'Un restaurant qui pourrait vous plaire selon vos goûts et préférences.';
        } else if (_isLeisureType(profile)) {
          profile['content'] = 'Un lieu culturel ou de loisir qui correspond à vos centres d\'intérêt.';
        } else {
          profile['content'] = 'Un lieu recommandé pour vous en fonction de votre profil.';
        }
      }
    }
    
    // Add additional fields required for display
    profile['timestamp'] = DateTime.now().toIso8601String();
    profile['likes'] = 0;
    profile['comments'] = [];
  }
  
  /// Applies fallback data to ensure profile can be displayed
  void _applyFallbackProfileData(Map<String, dynamic> profile) {
    // Set minimum required fields with fallback values
    profile['name'] = profile['name'] ?? 'Lieu Recommandé';
    profile['photo'] = profile['photo'] ?? 'https://choice-app.fr/assets/images/venue-placeholder.jpg';
    profile['type'] = profile['type'] ?? 'venue';
    profile['targetId'] = profile['targetId'] ?? 'ai-rec-fallback-${DateTime.now().millisecondsSinceEpoch}';
    profile['content'] = profile['content'] ?? 'Un lieu recommandé pour vous par notre assistant.';
    
    // Format for feed display
    _formatForFeedDisplay(profile);
  }
  
  /// Helper to check if profile is restaurant type
  bool _isRestaurantType(Map<String, dynamic> profile) {
    String type = (profile['type'] ?? '').toString().toLowerCase();
    return type == 'restaurant' || type == 'food' || type == 'producer' || type == 'gastronomy';
  }
  
  /// Helper to check if profile is leisure type
  bool _isLeisureType(Map<String, dynamic> profile) {
    String type = (profile['type'] ?? '').toString().toLowerCase();
    return type == 'leisure' || type == 'event' || type == 'culture' || 
           type == 'art' || type == 'theatre' || type == 'museum';
  }
  /// Maps emotional tone to post recommendations
  Future<List<String>> getEmotionalRecommendations(String mood) async {
    try {
      final url = Uri.parse('${getBaseUrl()}/api/ai/vibe-map/emotions');
      
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

  /// Generates fallback AI messages with proper display data
  List<DialogicAIMessage> _getFallbackMessages() {
    // Create high-quality sample profiles for recommendations
    List<Map<String, dynamic>> sampleProfiles = [
      {
        'name': 'Restaurant La Belle Vue',
        'photo': 'https://choice-app.fr/assets/images/restaurant-sample.jpg',
        'type': 'restaurant',
        'targetId': 'sample-restaurant-1',
        'description': 'Un restaurant avec une vue exceptionnelle et une cuisine délicieuse inspirée des produits de saison. Parfait pour un dîner romantique ou un repas entre amis.',
        'address': '15 Rue de la Paix, Paris',
        'rating': 4.7,
        'price_level': '€€€',
      },
      {
        'name': 'Théâtre Moderne',
        'photo': 'https://choice-app.fr/assets/images/theatre-sample.jpg',
        'type': 'leisure',
        'targetId': 'sample-theatre-1',
        'description': 'Découvrez les meilleures pièces de théâtre contemporain dans un cadre historique. Programmation variée et représentations de qualité.',
        'address': '23 Boulevard des Arts, Paris',
        'upcoming_events': ['Cyrano de Bergerac', 'Le Misanthrope'],
        'rating': 4.8,
      },
      {
        'name': 'Café des Artistes',
        'photo': 'https://choice-app.fr/assets/images/cafe-sample.jpg',
        'type': 'restaurant',
        'targetId': 'sample-cafe-1',
        'description': 'Un café chaleureux fréquenté par les artistes locaux. Excellent café, pâtisseries maison et ambiance inspirante pour travailler ou se détendre.',
        'address': '7 Rue des Peintres, Paris',
        'rating': 4.5,
        'price_level': '€€',
      },
    ];
    
    // Enrich with display data
    for (var profile in sampleProfiles) {
      _formatForFeedDisplay(profile);
    }
    
    return [
      DialogicAIMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: "Bonjour! Qu'aimeriez-vous découvrir aujourd'hui?",
        suggestions: ["Restaurants près de moi", "Événements ce weekend", "Lieux tendance"],
        isInteractive: true,
        profiles: null,
        sender: null,
      ),
      DialogicAIMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: "Voici des lieux soigneusement sélectionnés qui pourraient vous plaire en fonction de vos préférences et de votre emplacement actuel.",
        suggestions: [],
        isInteractive: false,
        profiles: sampleProfiles,
        sender: null,
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
              (post.isProducerPost ?? false) && !(post.isLeisureProducer ?? false))
          .length > (recentlyViewedPosts.length / 3);
          
      // Check if user viewed many leisure/event posts
      bool leisureFocus = recentlyViewedPosts
          .where((post) => 
              (post.isProducerPost ?? false) && (post.isLeisureProducer ?? false))
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

  Future<List<Post>> getPersonalizedMessages(String userId, {int limit = 2}) async {
    try {
      await Future.delayed(Duration(milliseconds: 500));
      
      final messages = [
        DialogicAIMessage(
          id: "ai_${DateTime.now().millisecondsSinceEpoch}_1",
          content: "Bonjour! Voici quelques recommandations basées sur vos intérêts.",
          suggestions: [],
          isInteractive: true,
          profiles: null,
          sender: null,
        ),
        DialogicAIMessage(
          id: "ai_${DateTime.now().millisecondsSinceEpoch}_2",
          content: "Avez-vous visité les nouveaux restaurants dans votre quartier?",
          suggestions: [],
          isInteractive: true,
          profiles: null,
          sender: null,
        ),
      ];
      
      final posts = messages.map((message) => Post(
        id: message.id,
        userId: userId,
        userName: 'Assistant IA',
        description: message.content,
        createdAt: message.timestamp,
        content: message.content,
        title: '',
        tags: [],
        authorId: userId,
        authorName: 'Assistant IA',
        authorAvatar: 'assets/images/ai_avatar.png',
        postedAt: message.timestamp,
        mediaUrls: [],
        media: [],
        comments: [],
        isProducerPost: false,
        isLeisureProducer: false,
        isInterested: false,
        isChoice: false,
        interestedCount: 0,
        choiceCount: 0,
        isLiked: false,
        likesCount: 0,
      )).toList();
      
      return posts.take(limit).toList();
    } catch (e) {
      print('❌ Error getting personalized messages: $e');
      return [];
    }
  }

  Future<List<Post>> _convertMessagesToPosts(List<dynamic> messages, String userId) async {
    final posts = messages.map((message) => Post(
      id: message['id'] ?? '',
      userId: userId,
      userName: message['author'] ?? 'Assistant',
      description: message['content'] ?? '',
      createdAt: DateTime.parse(message['timestamp'] ?? DateTime.now().toIso8601String()),
      content: message['content'] ?? '',
      title: message['title'] ?? '',
      tags: [],
      authorId: userId,
      authorName: message['author'] ?? 'Assistant',
      authorAvatar: message['author_photo'] ?? '',
      postedAt: DateTime.parse(message['timestamp'] ?? DateTime.now().toIso8601String()),
      mediaUrls: [],
      media: [],
      comments: [],
      isProducerPost: false,
      isLeisureProducer: false,
      isInterested: false,
      isChoice: false,
      interestedCount: 0,
      choiceCount: 0,
      isLiked: false,
      likesCount: 0,
    )).toList();

    return posts;
  }

  Future<List<Post>> getFeedPosts(String userId, {int limit = 10}) async {
    try {
      final messages = await getDialogicFeedContent(userId);
      final posts = await _convertMessagesToPosts(messages, userId);
      return posts.take(limit).toList();
    } catch (e) {
      print('❌ Erreur lors de la récupération des posts: $e');
      return [];
    }
  }

  Post _createDefaultPost() {
    return Post(
      id: '',
      userId: '',
      userName: '',
      description: '',
      createdAt: DateTime.now(),
      content: '',
      title: '',
      tags: [],
      comments: [],
      mediaUrls: [],
    );
  }
}
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart' as constants;
import '../config/api_config.dart';
import '../services/auth_service.dart';

// Define the Tenor API Key from environment variables
const String _tenorApiKey = String.fromEnvironment('TENOR_API_KEY', defaultValue: '');

class ConversationService {
  final String baseUrl = ApiConfig.baseUrl;
  final AuthService _authService = AuthService();

  // Constructor doesn't take any parameters
  ConversationService();

  // Méthode pour obtenir le token d'authentification
  Future<String> _getToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      if (token.isEmpty) {
        // Tenter de récupérer le token via l'AuthService si disponible
        try {
          return _authService.token ?? '';
        } catch (e) {
          print("❌ Impossible de récupérer le token depuis l'AuthService: $e");
          return '';
        }
      }
      return token;
    } catch (e) {
      print('❌ Erreur lors de la récupération du token: $e');
      return '';
    }
  }

  // Méthode pour obtenir l'URL de base de façon cohérente
  String getBaseUrl() {
    return constants.getBaseUrl();
  }
  
  // Récupérer toutes les conversations d'un utilisateur
  Future<List<Map<String, dynamic>>> getConversations(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      final baseUrl = getBaseUrl();
      
      final response = await http.get(
        Uri.parse('$baseUrl/api/conversations/$userId/conversations'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> rawConversations = json.decode(response.body);
        return await _processConversations(rawConversations, userId);
      } else if (response.statusCode == 404) {
        // Si les conversations ne sont pas trouvées, retourner une liste vide
        // plutôt que de lever une exception
        print('⚠️ Aucune conversation trouvée (404): ${response.body}');
        return [];
      } else {
        throw Exception('Échec de la récupération des conversations: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Erreur lors de la récupération des conversations: $e');
    }
  }
  
  // Récupérer les messages d'une conversation
  Future<Map<String, dynamic>> getConversationMessages(String conversationId, String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      final baseUrl = getBaseUrl();
      
      print('🔍 Récupération des messages de la conversation: $conversationId');
      
      // Construire l'URL complète pour un meilleur débogage
      final url = '$baseUrl/api/conversations/$conversationId/messages?userId=$userId';
      print('🔗 URL des messages: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      // Afficher la réponse brute pour le débogage (limiter à 100 caractères pour éviter de surcharger les logs)
      if (response.body.isNotEmpty) {
        final previewLength = min(100, response.body.length);
        print('📄 Réponse brute: ${response.statusCode} - ${response.body.substring(0, previewLength)}...');
      } else {
        print('📄 Réponse brute: ${response.statusCode} - (vide)');
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ Messages récupérés avec succès');
        
        // Traiter les messages pour assurer la cohérence des types
        List<Map<String, dynamic>> processedMessages = [];
        
        if (data is Map && data['messages'] != null && data['messages'] is List) {
          print('✅ Format standard avec clé "messages": ${data['messages']?.length ?? 0} messages');
          processedMessages = _processMessageList(data['messages']);
        } else if (data is List) {
          print('✅ Format alternatif (liste directe): ${data.length} messages');
          processedMessages = _processMessageList(data);
        } else {
          print('⚠️ Format de réponse inhabituel, tentative d\'adaptation');
          // Tentative de récupérer les messages dans une structure inconnue
          if (data is Map) {
            // Chercher une clé qui pourrait contenir les messages
            final possibleMessageKeys = ['messages', 'data', 'result', 'results', 'items'];
            for (final key in possibleMessageKeys) {
              if (data[key] is List) {
                print('✅ Messages trouvés sous la clé: $key');
                processedMessages = _processMessageList(data[key]);
                break;
              }
            }
          }
        }
        
        return {
          'messages': processedMessages,
          'participants': data is Map ? (data['participants'] ?? {}) : {},
        };
      } else {
        print('❌ Erreur lors de la récupération des messages: ${response.statusCode}');
        print('❌ Réponse: ${response.body}');
        
        // Essayer une autre route si l'API principale échoue
        return _fallbackGetMessages(conversationId, userId, token);
      }
    } catch (e) {
      print('❌ Exception lors de la récupération des messages: $e');
      throw Exception('Erreur lors de la récupération des messages: $e');
    }
  }
  
  // Envoyer un message avec correction de la signature de la méthode
  Future<Map<String, dynamic>> sendMessage(
    String conversationId,
    String senderId,
    String content,
    [List<String>? mediaUrls, List<Map<String, dynamic>>? mentions]
  ) async {
    try {
      final baseUrl = getBaseUrl();
      
      final Map<String, dynamic> messageData = {
        'senderId': senderId,
        'content': content,
      };
      
      // Ajouter des médias si présents
      if (mediaUrls != null && mediaUrls.isNotEmpty) {
        messageData['media'] = mediaUrls;
      }
      
      // Ajouter des mentions si présentes
      if (mentions != null && mentions.isNotEmpty) {
        messageData['mentions'] = mentions;
      }

      print('📤 Envoi de message: conversationId=$conversationId, senderId=$senderId, content=$content');
      print('📤 Payload: ${json.encode(messageData)}');

      // Utiliser la route directe pour l'envoi de messages
      final url = '$baseUrl/api/conversations/$conversationId/send';
      print('🔗 URL d\'envoi: $url');
      
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode(messageData),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final result = json.decode(response.body);
        print('✅ Message envoyé avec succès: ${result['message']?['_id'] ?? 'ID non disponible'}');
        return result;
      } else {
        print('❌ Erreur envoi message: ${response.statusCode}, body: ${response.body}');
        
        // Essayer une route alternative si la première échoue
        return _fallbackSendMessage(conversationId, senderId, content, mediaUrls, mentions);
      }
    } catch (e) {
      print('❌ Exception envoi message: $e');
      throw Exception('Erreur lors de l\'envoi du message: $e');
    }
  }
  
  // Créer une nouvelle conversation ou en récupérer une existante
  Future<Map<String, dynamic>> createOrGetConversation(String userId, String targetUserId, {String? producerType}) async {
    try {
      final baseUrl = await getBaseUrl();
      
      final Map<String, dynamic> requestBody = {
        'userId': userId,
        'targetUserId': targetUserId,
      };
      
      // Add producerType parameter if it's provided
      if (producerType != null && producerType.isNotEmpty) {
        requestBody['producerType'] = producerType;
      }
      
      final response = await http.post(
        Uri.parse('$baseUrl/api/conversations/create-or-get-conversation'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode(requestBody),
      );
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to create or get conversation: ${response.body}');
      }
    } catch (e) {
      print('Error creating or getting conversation: $e');
      throw Exception('Failed to create or get conversation: $e');
    }
  }
  
  // Rechercher des contacts pour la création de groupes
  Future<List<Map<String, dynamic>>> searchUsersForGroup(String query) async {
    try {
      if (query.length < 2) {
        print('ℹ️ searchUsersForGroup - Query trop courte: "$query"');
        return [];
      }
      
      final baseUrl = getBaseUrl();
      print('🔍 searchUsersForGroup - URL: $baseUrl/api/conversations/search?query=$query');
      
      // Utiliser l'endpoint spécialisé pour la recherche d'utilisateurs pour les groupes
      final response = await http.get(
        Uri.parse('$baseUrl/api/conversations/search?query=$query'),
        headers: {
          'Content-Type': 'application/json',
        },
      );
      
      print('🔍 searchUsersForGroup - Status code: ${response.statusCode}, query: "$query"');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data is Map && data.containsKey('results') && data['results'] is List) {
          final List<dynamic> results = data['results'];
          
          // Convertir en format standard
          return results.map((item) {
            if (item is Map) {
              final Map<String, dynamic> user = Map<String, dynamic>.from(item);
              return {
                'id': user['id'] ?? user['_id'] ?? '',
                'name': user['name'] ?? user['username'] ?? 'Utilisateur',
                'avatar': user['avatar'] ?? user['profilePicture'] ?? 'https://via.placeholder.com/150',
                'type': 'user'
              };
            }
            return <String, dynamic>{};
          }).where((user) => user.isNotEmpty).toList();
        }
      }
      
      print('❌ searchUsersForGroup - Aucun résultat ou erreur: ${response.statusCode}');
      return [];
    } catch (e) {
      print('❌ searchUsersForGroup - Exception: $e');
      return [];
    }
  }
  
  // Créer un groupe de conversation
  Future<Map<String, dynamic>> createGroupConversation(
    String creatorId,
    List<String> participantIds,
    String groupName,
    {String groupType = 'general', String? groupAvatar}
  ) async {
    try {
      // Vérifier que le creatorId est valide
      if (creatorId.isEmpty) {
        throw Exception('ID créateur vide ou non valide');
      }
      
      // Vérifier qu'il y a au moins un participant
      if (participantIds.isEmpty) {
        throw Exception('Liste de participants vide ou non valide');
      }
      
      // Vérifier que le nom du groupe est valide
      if (groupName.isEmpty) {
        throw Exception('Nom du groupe vide ou non valide');
      }
      
      // Assurer que le créateur est inclus dans les participants
      if (!participantIds.contains(creatorId)) {
        participantIds.add(creatorId);
      }
      
      // Filtrer les ID vides
      participantIds = participantIds.where((id) => id.isNotEmpty).toList();
      
      if (participantIds.isEmpty) {
        throw Exception('Aucun participant valide');
      }

      final baseUrl = getBaseUrl();
      
      final Map<String, dynamic> requestData = {
        'creatorId': creatorId,
        'participantIds': participantIds,
        'groupName': groupName,
        'groupType': groupType,
      };
      
      // Ajouter l'avatar s'il est fourni
      if (groupAvatar != null && groupAvatar.isNotEmpty) {
        requestData['groupAvatar'] = groupAvatar;
      } else {
        // Créer un avatar par défaut basé sur le type et le nom
        final String avatarUrl = 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(groupName)}&background=${_getColorHexForGroupType(groupType)}&color=fff&size=128';
        requestData['groupAvatar'] = avatarUrl;
      }
      
      print('🔍 Création de groupe - Payload: ${json.encode(requestData)}');

      final response = await http.post(
        Uri.parse('$baseUrl/api/conversations/create-group'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode(requestData),
      );
      
      print('📤 Réponse création groupe: ${response.statusCode}, body: ${response.body}');

      if (response.statusCode == 201) {
        final result = json.decode(response.body);
        print('✅ Groupe créé avec succès: ${result['conversation_id']}');
        
        // Adapter la réponse pour assurer la cohérence
        return {
          'conversationId': result['conversation_id'],
          'conversation_id': result['conversation_id'],
          '_id': result['conversation_id'],
          'groupName': groupName,
          'participants': participantIds,
          'avatar': result['groupAvatar'] ?? requestData['groupAvatar'],
        };
      } else {
        print('❌ Erreur création groupe: ${response.statusCode}, body: ${response.body}');
        throw Exception('Échec de la création du groupe: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('❌ Exception création groupe: $e');
      throw Exception('Erreur lors de la création du groupe: $e');
    }
  }
  
  // Rechercher des utilisateurs, restaurants et loisirs
  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    if (query.length < 2) return [];
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      final baseUrl = getBaseUrl();
      
      final response = await http.get(
        Uri.parse('$baseUrl/api/search?query=$query'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Transformer les résultats en format uniforme
        List<Map<String, dynamic>> results = [];
        
        // Ajouter les utilisateurs
        if (data['users'] != null) {
          for (var user in data['users']) {
            results.add({
              'id': user['_id'],
              'name': user['name'] ?? user['username'] ?? 'Utilisateur',
              'avatar': user['photo_url'] ?? user['profilePicture'] ?? 'https://via.placeholder.com/150',
              'type': 'user',
            });
          }
        }
        
        // Ajouter les restaurants
        if (data['restaurants'] != null) {
          for (var restaurant in data['restaurants']) {
            results.add({
              'id': restaurant['_id'],
              'name': restaurant['name'] ?? 'Restaurant',
              'avatar': restaurant['photo_url'] ?? restaurant['logo'] ?? 'https://via.placeholder.com/150',
              'type': 'restaurant',
            });
          }
        }
        
        // Ajouter les loisirs
        if (data['leisure'] != null) {
          for (var leisure in data['leisure']) {
            results.add({
              'id': leisure['_id'],
              'name': leisure['name'] ?? 'Loisir',
              'avatar': leisure['photo_url'] ?? leisure['image'] ?? 'https://via.placeholder.com/150',
              'type': 'leisure',
            });
          }
        }
        
        return results;
      } else {
        throw Exception('Échec de la recherche: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Erreur lors de la recherche: $e');
    }
  }
  
  // Rechercher parmi les followers/amis d'un utilisateur
  Future<List<Map<String, dynamic>>> searchFollowers(String userId, String query) async {
    if (query.length < 2) return [];
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      final baseUrl = getBaseUrl();
      
      final response = await http.get(
        Uri.parse('$baseUrl/api/users/$userId/followers/search?query=$query'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        
        // Transformer les résultats en format uniforme
        List<Map<String, dynamic>> results = [];
        
        for (var follower in data) {
          results.add({
            'id': follower['_id'],
            'name': follower['name'] ?? follower['username'] ?? 'Utilisateur',
            'avatar': follower['avatar'] ?? follower['profilePicture'] ?? 'https://via.placeholder.com/150',
            'type': 'user',
          });
        }
        
        return results;
      } else {
        throw Exception('Échec de la recherche des followers: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Erreur lors de la recherche des followers: $e');
    }
  }
  
  // Récupérer les informations sur un utilisateur
  Future<Map<String, dynamic>> getUserInfo(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/users/$userId/info'),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }

      // Fallback: essayer de trouver via l'API unifiée
      final unifiedResponse = await http.get(
        Uri.parse('$baseUrl/api/unified/$userId'),
      );
      
      if (unifiedResponse.statusCode == 200) {
        final data = json.decode(unifiedResponse.body);
        return {
          'name': data['name'] ?? data['lieu'] ?? 'Utilisateur',
          'avatar': data['photo'] ?? data['image'] ?? data['profilePicture'] ?? 'https://via.placeholder.com/150',
          'type': data['type'] ?? 'user',
        };
      }

      throw Exception('Impossible de récupérer les informations de l\'utilisateur');
    } catch (e) {
      throw Exception('Erreur lors de la récupération des informations: $e');
    }
  }
  
  // Transformation des données brutes de conversations
  Future<List<Map<String, dynamic>>> _processConversations(List<dynamic> rawConversations, String currentUserId) async {
    final List<Map<String, dynamic>> processedConversations = [];

    for (var rawConv in rawConversations) {
      if (rawConv is! Map<String, dynamic>) {
        if (kDebugMode) {
          print("⚠️ Skipping invalid conversation data: Not a Map. Data: $rawConv");
        }
        continue; // Skip if the item is not a map
      }
      // Use safe access for all fields from the primary conversation data
      final Map<String, dynamic> conv = Map<String, dynamic>.from(rawConv);
      final String convId = _safeGet<String>(conv, 'id', 'unknown_${DateTime.now().millisecondsSinceEpoch}');
      final List<String> participants = _safeGet<List<String>>(conv, 'participants', []);
      final String groupName = _safeGet<String>(conv, 'groupName', 'Groupe');
      final String groupAvatar = _safeGet<String>(conv, 'groupAvatar', '');
      final String lastMessageContent = _safeGet<String>(conv, 'lastMessage', '');
      final String timeStr = _safeGet<String>(conv, 'time', DateTime.now().toIso8601String());
      final int unreadCount = _safeGet<int>(conv, 'unreadCount', 0); // Get unread count safely
      final bool isGroupFlag = _safeGet<bool>(conv, 'isGroup', false);
      final bool isRestaurantFlag = _safeGet<bool>(conv, 'isRestaurant', false);
      final bool isLeisureFlag = _safeGet<bool>(conv, 'isLeisure', false);

      // Determine if group based on flag or participant count
      bool isGroup = isGroupFlag || participants.length > 2;

      if (isGroup) {
        // Traitement pour une conversation de groupe
        final String fallbackGroupName = groupName.isNotEmpty && groupName != 'Groupe' 
            ? groupName 
            : (convId.isNotEmpty ? convId.substring(0, min(convId.length, 2)) : '??');
        final String finalGroupAvatar = (groupAvatar.isNotEmpty && groupAvatar.startsWith('http'))
            ? groupAvatar 
            : 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(fallbackGroupName)}&background=random&size=128';

        processedConversations.add({
          'id': convId,
          'name': groupName,
          'avatar': finalGroupAvatar, // Use final safe group avatar URL
          'lastMessage': lastMessageContent,
          'time': timeStr,
          'unreadCount': unreadCount, // Use safe unread count
          'isGroup': true,
          'isRestaurant': false, // Explicitly false for groups
          'isLeisure': false, // Explicitly false for groups
          'participants': participants,
        });
      } else {
        // Traitement pour une conversation individuelle
        // Use the flags directly from the processed data

        // Extract name and avatar first, using potential nested structure
        // Initialize with defaults
        String processedName = _safeGet<String>(conv, 'name', 'Utilisateur');
        String processedAvatar = _safeGet<String>(conv, 'avatar', '');

        // Check for producerInfo (assuming backend adds this for producer convs)
        final producerInfo = _safeGet<Map<String, dynamic>?>(conv, 'producerInfo', null);
        if (producerInfo != null) {
            processedName = _safeGet<String>(producerInfo, 'name', processedName);
            processedAvatar = _safeGet<String>(producerInfo, 'photo', processedAvatar);
        } else {
            // Check for participantsInfo (assuming backend adds this for user convs)
            final participantsInfo = _safeGet<List<dynamic>>(conv, 'participantsInfo', []);
            if (participantsInfo.isNotEmpty && participantsInfo[0] is Map) {
                final otherParticipantData = Map<String, dynamic>.from(participantsInfo[0]);
                processedName = _safeGet<String>(otherParticipantData, 'name', 
                                _safeGet<String>(otherParticipantData, 'username', processedName));
                processedAvatar = _safeGet<String>(otherParticipantData, 'profilePicture', 
                                _safeGet<String>(otherParticipantData, 'photo_url', processedAvatar));
            }
        }

        // Fallback avatar generation (now uses the potentially updated processedName)
        final String fallbackAvatarName = processedName.isNotEmpty && processedName != 'Utilisateur' 
            ? processedName 
            : (convId.isNotEmpty ? convId.substring(0, min(convId.length, 2)) : '??');
        final String finalAvatar = (processedAvatar.isNotEmpty && (processedAvatar.startsWith('http')))
            ? processedAvatar 
            : 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(fallbackAvatarName)}&background=random&size=128';

        // Find the other participant ID
        final String otherParticipantId = participants.firstWhere(
          (p) => p != currentUserId, 
          orElse: () => ''
        );

        // Determine participant type based on flags
        String participantType = 'user'; // Default to user
        if (isRestaurantFlag) {
          participantType = 'restaurant';
        } else if (isLeisureFlag) {
          participantType = 'leisure';
        } else if (_safeGet<bool>(conv, 'isWellness', false)) {
           participantType = 'wellness';
        } else if (_safeGet<bool>(conv, 'isBeauty', false)) {
           participantType = 'beauty';
        }

        processedConversations.add({
          'id': convId,
          'name': processedName, // Use the extracted/updated name
          'avatar': finalAvatar, // Use the extracted/updated avatar
          'lastMessage': lastMessageContent,
          'time': timeStr,
          'unreadCount': unreadCount, // Use safe unread count
          'isGroup': false,
          'isRestaurant': isRestaurantFlag, // Use safe flag
          'isLeisure': isLeisureFlag, // Use safe flag
          'participants': participants,
          // Add other participant info needed for profile navigation
          'otherParticipantId': otherParticipantId,
          'participantType': participantType,
          // Optionally keep producerInfo if provided
          'producerInfo': _safeGet<Map<String, dynamic>?>(conv, 'producerInfo', null),
        });
      }
    }

    return processedConversations;
  }

  // Obtenir la couleur hexadécimale en fonction du type de groupe
  String _getColorHexForGroupType(String groupType) {
    switch (groupType) {
      case 'restaurant':
        return 'FF9800'; // Orange
      case 'leisure':
        return '9C27B0'; // Violet
      case 'wellness':
        return '4CAF50'; // Vert
      case 'general':
      default:
        return '607D8B'; // Bleu gris
    }
  }

  // Récupérer les conversations d'un producteur
  Future<List<Map<String, dynamic>>> getProducerConversations(
    String producerId,
    String producerType,
  ) async {
    try {
      // Utiliser la même méthode que getConversations pour récupérer les conversations
      // en passant l'ID du producteur comme userId.
      // Le backend devrait être capable de gérer les IDs de producteurs.
      print('🔍 Récupération conversations pour producteur (via getConversations): producerId=$producerId');
      return await getConversations(producerId);
    } catch (e) {
      print('❌ Exception récupération conversations producteur: $e');
      throw Exception('Erreur lors de la récupération des conversations: $e');
    }
  }
  
  // Rechercher des contacts tous types confondus
  Future<List<Map<String, dynamic>>> searchAll(String query) async {
    try {
      if (query.length < 2) {
        print('⚠️ Requête trop courte: $query');
        return [];
      }
      
      final baseUrl = getBaseUrl();
      
      print('🔍 Recherche unifiée pour: $query');
      
      // Utiliser l'API unifiée qui cherche dans tous les types d'entités
      final response = await http.get(
        Uri.parse('$baseUrl/api/unified/search?query=$query'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> results = json.decode(response.body);
        print('✅ Résultats trouvés: ${results.length}');
        
        // Convertir les résultats en format standard
        return results.map((result) {
          return {
            'id': result['id'] ?? result['_id'] ?? '',
            '_id': result['id'] ?? result['_id'] ?? '',
            'name': result['name'] ?? 'Sans nom',
            'avatar': result['avatar'] ?? 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(result['name'] ?? 'U')}&background=random',
            'type': result['type'] ?? 'user',
            'address': result['address'],
            'category': _getCategory(result['type']),
          };
        }).toList();
      } else {
        print('❌ Erreur lors de la recherche: ${response.statusCode}');
        print('❌ Réponse: ${response.body}');
        return [];
      }
    } catch (e) {
      print('❌ Exception lors de la recherche: $e');
      return [];
    }
  }
  
  // Rechercher des contacts par type
  Future<List<Map<String, dynamic>>> searchProducersByType(String query, String producerType) async {
    try {
      if (query.length < 2) {
        print('⚠️ Requête trop courte: $query');
        return [];
      }
      
      final baseUrl = getBaseUrl();
      final String type;
      
      // Convertir le type de producteur au format attendu par l'API unifiée
      switch (producerType) {
        case 'restaurant':
          type = 'restaurant';
          break;
        case 'leisure':
        case 'leisureProducer':
          type = 'leisureProducer';
          break;
        case 'wellness':
        case 'wellnessProducer':
          type = 'wellnessProducer';
          break;
        case 'beauty':
        case 'beautyPlace':
          type = 'beautyPlace';
          break;
        default:
          type = producerType;
          break;
      }
      
      print('🔍 Recherche par type ($type) pour: $query');
      
      // Utiliser l'API unifiée qui est plus fiable et standardisée
      final url = '$baseUrl/api/unified/search?query=$query&type=$type';
      print('🔗 URL de recherche: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> results = json.decode(response.body);
        print('✅ Résultats de type $type trouvés: ${results.length}');
        
        // Convertir les résultats en format standard
        return results.map((result) {
          return {
            'id': result['id'] ?? result['_id'] ?? '',
            '_id': result['id'] ?? result['_id'] ?? '',
            'name': result['name'] ?? 'Sans nom',
            'avatar': result['avatar'] ?? 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(result['name'] ?? 'U')}&background=random',
            'type': result['type'] ?? type,
            'address': result['address'],
            'category': _getCategory(result['type']),
          };
        }).toList();
      } else {
        print('❌ Erreur lors de la recherche: ${response.statusCode}');
        print('❌ Réponse: ${response.body}');
        
        // Essayer une API alternative (ancienne version)
        return _fallbackSearchProducers(query, producerType);
      }
    } catch (e) {
      print('❌ Exception lors de la recherche: $e');
      return [];
    }
  }

  // Méthode de secours pour la recherche de producteurs (utilise l'ancienne API)
  Future<List<Map<String, dynamic>>> _fallbackSearchProducers(String query, String producerType) async {
    try {
      final baseUrl = getBaseUrl();
      final Uri url;
      
      // Créer l'URL en fonction du type de producteur
      switch (producerType) {
        case 'restaurant':
          url = Uri.parse('$baseUrl/api/producers/search?query=$query&type=restaurant');
          break;
        case 'leisureProducer':
        case 'leisure':
          url = Uri.parse('$baseUrl/api/producers/search?query=$query&type=leisure');
          break;
        case 'wellnessProducer':
        case 'wellness':
          url = Uri.parse('$baseUrl/api/producers/search?query=$query&type=wellness');
          break;
        default:
          url = Uri.parse('$baseUrl/api/producers/search?query=$query');
          break;
      }
      
      print('🔍 Recherche fallback de producteurs: $url');
      
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
        }
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        print('✅ Résultats fallback: ${data.length} producteurs trouvés');
        
        // Transformer les données en un format utilisable
        return data.map((item) {
          final String itemType = producerType == 'leisure' || producerType == 'leisureProducer' 
                                ? 'leisureProducer' 
                                : (producerType == 'wellness' || producerType == 'wellnessProducer' 
                                  ? 'wellnessProducer' 
                                  : producerType);
          
          return {
            'id': item['_id'] ?? '',
            '_id': item['_id'] ?? '',
            'name': item['name'] ?? item['businessName'] ?? item['intitulé'] ?? item['lieu'] ?? 'Sans nom',
            'avatar': item['avatar'] ?? item['image'] ?? item['photo'] ?? 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(item['name'] ?? 'P')}&background=random',
            'type': item['type'] ?? itemType,
            'category': _getCategory(itemType),
          };
        }).toList();
      } else {
        print('❌ Erreur recherche fallback: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ Exception recherche fallback: $e');
      return [];
    }
  }

  // Méthode helper pour obtenir la catégorie à partir du type
  String _getCategory(String? type) {
    switch (type) {
      case 'restaurant':
        return 'Restaurant';
      case 'leisureProducer':
        return 'Loisir';
      case 'wellnessProducer':
        return 'Bien-être';
      case 'beautyPlace':
        return 'Beauté';
      case 'event':
        return 'Événement';
      case 'user':
        return 'Utilisateur';
      default:
        return 'Autre';
    }
  }

  // Rechercher spécifiquement les followers d'un producteur
  Future<List<Map<String, dynamic>>> searchProducerFollowers(String producerId, String query) async {
    try {
      final baseUrl = await getBaseUrl();
      final url = Uri.parse('$baseUrl/api/producers/$producerId/followers?query=$query');
      
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        
        return data.map((item) => {
          'id': item['_id'] ?? '',
          'name': item['username'] ?? item['name'] ?? 'Sans nom',
          'avatar': item['profilePicture'] ?? item['avatar'] ?? 'https://via.placeholder.com/150',
          'type': 'user',
        }).toList();
      } else {
        throw Exception('Erreur lors de la recherche des followers');
      }
    } catch (e) {
      print('Erreur de recherche: $e');
      return [];
    }
  }
  
  // Supprimer une conversation
  Future<bool> deleteConversation(String conversationId, String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      final baseUrl = await getBaseUrl();
      
      final response = await http.delete(
        Uri.parse('$baseUrl/api/conversations/$conversationId/users/$userId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      return response.statusCode == 200;
    } catch (e) {
      throw Exception('Erreur lors de la suppression: $e');
    }
  }
  
  // Marquer la conversation comme lue
  Future<bool> markConversationAsRead(String conversationId, String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      final baseUrl = await getBaseUrl();
      
      final response = await http.post(
        Uri.parse('$baseUrl/api/conversations/$conversationId/read'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'userId': userId,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      throw Exception('Erreur lors du marquage de la conversation: $e');
    }
  }
  
  // Activer/désactiver les notifications pour une conversation
  Future<bool> toggleNotifications(String conversationId, String userId, bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      final baseUrl = await getBaseUrl();
      
      final response = await http.put(
        Uri.parse('$baseUrl/api/conversations/$conversationId/notifications'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'userId': userId,
          'enabled': enabled,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      throw Exception('Erreur lors de la modification des notifications: $e');
    }
  }
  
  // Ajouter des participants à un groupe existant
  Future<Map<String, dynamic>> addParticipantsToGroup(
    String conversationId,
    List<String> newParticipantIds,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      final baseUrl = await getBaseUrl();
      
      final response = await http.post(
        Uri.parse('$baseUrl/api/conversations/$conversationId/participants'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'participantIds': newParticipantIds,
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }

      throw Exception('Impossible d\'ajouter les participants');
    } catch (e) {
      throw Exception('Erreur lors de l\'ajout de participants: $e');
    }
  }
  
  // Renommer un groupe
  Future<Map<String, dynamic>> renameGroup(
    String conversationId,
    String newGroupName,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      final baseUrl = await getBaseUrl();
      
      final response = await http.put(
        Uri.parse('$baseUrl/api/conversations/$conversationId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'groupName': newGroupName,
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }

      throw Exception('Impossible de renommer le groupe');
    } catch (e) {
      throw Exception('Erreur lors du renommage du groupe: $e');
    }
  }
  
  // Partager du contenu dans une conversation
  Future<Map<String, dynamic>> shareContent(
    String conversationId,
    String senderId,
    String contentType,
    Map<String, dynamic> content,
    {String? message}
  ) async {
    try {
      final Map<String, dynamic> requestData = {
        'senderId': senderId,
        'contentType': contentType,
        'sharedContent': content,
      };
      
      if (message != null) {
        requestData['content'] = message;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/api/conversations/$conversationId/share'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestData),
      );

      if (response.statusCode == 201) {
        return json.decode(response.body);
      }

      throw Exception('Impossible de partager le contenu');
    } catch (e) {
      throw Exception('Erreur lors du partage de contenu: $e');
    }
  }
  
  // Récupérer les détails d'une conversation
  Future<Map<String, dynamic>> getConversationDetails(String conversationId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/conversations/$conversationId'),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }

      throw Exception('Impossible de récupérer les détails de la conversation');
    } catch (e) {
      throw Exception('Erreur lors de la récupération des détails: $e');
    }
  }

  // Rechercher des contacts
  Future<List<Map<String, dynamic>>> searchContacts(String query, String type) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/producers/search?query=$query&type=$type'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.cast<Map<String, dynamic>>();
      }

      throw Exception('Recherche impossible');
    } catch (e) {
      throw Exception('Erreur lors de la recherche: $e');
    }
  }

  // Recherche unifiée des contacts (tous types)
  Future<List<Map<String, dynamic>>> searchAllContacts(String query) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/unified/search?query=$query'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.cast<Map<String, dynamic>>();
      }

      throw Exception('Recherche unifiée impossible');
    } catch (e) {
      throw Exception('Erreur lors de la recherche unifiée: $e');
    }
  }

  // Mettre à jour un message (modification)
  Future<Map<String, dynamic>> updateMessage(
    String conversationId,
    String messageId,
    String newContent
  ) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/conversations/$conversationId/messages/$messageId'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'content': newContent,
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }

      throw Exception('Impossible de mettre à jour le message');
    } catch (e) {
      throw Exception('Erreur lors de la mise à jour du message: $e');
    }
  }
  
  // Supprimer un message
  Future<bool> deleteMessage(
    String conversationId,
    String messageId,
    {bool forEveryone = true}
  ) async {
    try {
      final uri = Uri.parse('$baseUrl/api/conversations/$conversationId/messages/$messageId')
        .replace(queryParameters: {'forEveryone': forEveryone.toString()});
        
      final response = await http.delete(
        uri,
        headers: {'Content-Type': 'application/json'},
      );

      return response.statusCode == 200;
    } catch (e) {
      throw Exception('Erreur lors de la suppression du message: $e');
    }
  }
  
  // Réagir à un message
  Future<Map<String, dynamic>> reactToMessage(
    String conversationId,
    String messageId,
    String userId,
    String reaction
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/conversations/$conversationId/messages/$messageId/reactions'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'userId': userId,
          'reaction': reaction,
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }

      throw Exception('Impossible d\'ajouter la réaction');
    } catch (e) {
      throw Exception('Erreur lors de l\'ajout de la réaction: $e');
    }
  }
  
  // Transférer un message
  Future<Map<String, dynamic>> forwardMessage(
    String sourceConversationId,
    String messageId,
    String targetConversationId,
    String senderId
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/conversations/$targetConversationId/forward'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'sourceConversationId': sourceConversationId,
          'messageId': messageId,
          'senderId': senderId,
        }),
      );

      if (response.statusCode == 201) {
        return json.decode(response.body);
      }

      throw Exception('Impossible de transférer le message');
    } catch (e) {
      throw Exception('Erreur lors du transfert du message: $e');
    }
  }

  // Retirer un participant d'un groupe
  Future<bool> removeParticipantFromGroup(
    String conversationId,
    String participantId,
  ) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/conversations/$conversationId/participants/$participantId'),
        headers: {'Content-Type': 'application/json'},
      );

      return response.statusCode == 200;
    } catch (e) {
      throw Exception('Erreur lors du retrait du participant: $e');
    }
  }
  
  // Quitter un groupe
  Future<bool> leaveGroup(
    String conversationId,
    String userId,
  ) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/conversations/$conversationId/leave'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'userId': userId,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      throw Exception('Erreur lors de la sortie du groupe: $e');
    }
  }
  
  // Mettre à jour l'avatar du groupe
  Future<Map<String, dynamic>> updateGroupAvatar(
    String conversationId,
    String avatarUrl,
  ) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/conversations/$conversationId/avatar'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'avatar': avatarUrl,
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }

      throw Exception('Impossible de mettre à jour l\'avatar du groupe');
    } catch (e) {
      throw Exception('Erreur lors de la mise à jour de l\'avatar: $e');
    }
  }

  // Récupérer les détails d'un groupe
  Future<Map<String, dynamic>> getGroupDetails(String conversationId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/conversations/$conversationId/group-details'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Impossible de récupérer les détails du groupe: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Erreur lors de la récupération des détails du groupe: $e');
    }
  }

  // Recherche des participants pour une conversation
  Future<Map<String, dynamic>> searchParticipants(String query, String type) async {
    try {
      final token = await _getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/api/conversations/search-participants?query=$query&type=$type'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print('❌ Erreur lors de la recherche de participants: ${response.statusCode}');
        print('❌ Réponse: ${response.body}');
        throw Exception('Erreur lors de la recherche de participants');
      }
    } catch (e) {
      print('❌ Exception lors de la recherche de participants: $e');
      throw Exception('Erreur de connexion: $e');
    }
  }
  
  // Créer un groupe de conversation
  Future<Map<String, dynamic>> createGroup(String creatorId, List<String> participantIds, String groupName) async {
    try {
      final token = await _getToken();
      final response = await http.post(
        Uri.parse('$baseUrl/api/conversations/create-group'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'creatorId': creatorId,
          'participantIds': participantIds,
          'groupName': groupName,
        }),
      );
      
      if (response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        print('❌ Erreur lors de la création du groupe: ${response.statusCode}');
        print('❌ Réponse: ${response.body}');
        throw Exception('Erreur lors de la création du groupe');
      }
    } catch (e) {
      print('❌ Exception lors de la création du groupe: $e');
      throw Exception('Erreur de connexion: $e');
    }
  }

  // Méthode pour obtenir l'URL correcte des messages
  Future<String> getConversationMessagesUrl(String conversationId) async {
    // Essayer d'abord avec le chemin standard
    final baseUrl = await getBaseUrl();
    
    // Pour faciliter le débogage, afficher l'URL complète
    final url = '$baseUrl/api/conversations/$conversationId/messages';
    print('🔗 URL des messages: $url');
    
    return url;
  }

  // Version améliorée de getConversationMessages
  Future<Map<String, dynamic>> getConversationMessagesV2(String conversationId, String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      final url = await getConversationMessagesUrl(conversationId);
      
      print('🔍 Récupération des messages de la conversation: $conversationId');
      print('🔗 URL: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      // Afficher la réponse brute pour le débogage
      print('📄 Réponse brute: ${response.statusCode} - ${response.body.substring(0, min(100, response.body.length))}...');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Gérer la structure de réponse variable selon l'API
        List<Map<String, dynamic>> processedMessages = [];
        
        if (data is Map && data['messages'] != null && data['messages'] is List) {
          print('✅ Format standard: ${data['messages']?.length ?? 0} messages');
          processedMessages = _processMessageList(data['messages']);
        } else if (data is List) {
          print('✅ Format alternatif (liste directe): ${data.length} messages');
          processedMessages = _processMessageList(data);
        } else {
          print('⚠️ Format de réponse inhabituel, tentative d\'adaptation');
          // Tentative de récupérer les messages dans une structure inconnue
          if (data is Map) {
            // Chercher une clé qui pourrait contenir les messages
            final possibleMessageKeys = ['messages', 'data', 'result', 'results', 'items'];
            for (final key in possibleMessageKeys) {
              if (data[key] is List) {
                print('✅ Messages trouvés sous la clé: $key');
                processedMessages = _processMessageList(data[key]);
                break;
              }
            }
          }
        }
        
        return {
          'messages': processedMessages,
          'participants': data is Map ? (data['participants'] ?? {}) : {},
        };
      } else {
        print('❌ Erreur lors de la récupération des messages: ${response.statusCode}');
        print('❌ Réponse: ${response.body}');
        
        // Essayer une autre route si l'API principale échoue
        return _fallbackGetMessages(conversationId, userId, token);
      }
    } catch (e) {
      print('❌ Exception lors de la récupération des messages: $e');
      throw Exception('Erreur lors de la récupération des messages: $e');
    }
  }

  // Méthode de secours pour la récupération de messages
  Future<Map<String, dynamic>> _fallbackGetMessages(String conversationId, String userId, String token) async {
    try {
      final baseUrl = await getBaseUrl();
      
      // Essayer différentes alternatives d'URL
      final List<String> alternativeUrls = [
        '$baseUrl/api/messages/$conversationId',
        '$baseUrl/api/v1/conversations/$conversationId/messages',
        '$baseUrl/api/conversations/$conversationId/message/list'
      ];
      
      for (final alternativeUrl in alternativeUrls) {
        print('🔍 Essai de récupération avec URL alternative: $alternativeUrl');
        
        try {
          final response = await http.get(
            Uri.parse(alternativeUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          ).timeout(const Duration(seconds: 5)); // Timeout court pour ne pas bloquer trop longtemps
          
          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            print('✅ Messages récupérés via URL alternative: $alternativeUrl');
            
            List<Map<String, dynamic>> processedMessages = [];
            if (data is Map && data['messages'] != null) {
              processedMessages = _processMessageList(data['messages']);
            } else if (data is List) {
              processedMessages = _processMessageList(data);
            }
            
            return {
              'messages': processedMessages,
              'participants': data is Map ? (data['participants'] ?? {}) : {},
            };
          } else {
            print('❌ Échec avec l\'URL alternative $alternativeUrl: ${response.statusCode}');
          }
        } catch (e) {
          print('❌ Exception avec URL alternative $alternativeUrl: $e');
          // Continuer à essayer la prochaine URL
        }
      }
      
      // Si toutes les alternatives échouent, retourner une liste vide
      print('⚠️ Toutes les tentatives ont échoué, retour d\'une liste vide');
      return { 'messages': [], 'participants': {} };
    } catch (e) {
      print('❌ Exception générale avec URL alternatives: $e');
      return { 'messages': [], 'participants': {} };
    }
  }

  // Méthode pour traiter les listes de messages de différents formats
  List<Map<String, dynamic>> _processMessageList(List messages) {
    return messages.map((msg) {
      if (msg is Map<String, dynamic>) {
        return msg;
      } else if (msg is Map) {
        return Map<String, dynamic>.from(msg);
      } else {
        return <String, dynamic>{};
      }
    }).toList();
  }

  // Méthode de secours pour l'envoi de messages
  Future<Map<String, dynamic>> _fallbackSendMessage(
    String conversationId,
    String senderId,
    String content,
    [List<String>? mediaUrls, List<Map<String, dynamic>>? mentions]
  ) async {
    try {
      final baseUrl = await getBaseUrl();
      // Essayer une route alternative pour l'envoi
      final alternativeUrl = '$baseUrl/api/messages/$conversationId';
      print('🔍 Essai d\'envoi avec URL alternative: $alternativeUrl');
      
      final Map<String, dynamic> messageData = {
        'senderId': senderId,
        'content': content,
        'media': mediaUrls ?? [],
        'mentions': mentions ?? [],
      };
      
      final response = await http.post(
        Uri.parse(alternativeUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode(messageData),
      );
      
      if (response.statusCode == 201 || response.statusCode == 200) {
        final result = json.decode(response.body);
        print('✅ Message envoyé via URL alternative');
        return result;
      } else {
        print('❌ Échec avec l\'URL alternative: ${response.statusCode}');
        throw Exception('Impossible d\'envoyer le message: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Exception avec URL alternative: $e');
      throw Exception('Erreur lors de l\'envoi du message: $e');
    }
  }

  // Helper function to safely get values from a map
  T _safeGet<T>(Map<String, dynamic> map, String key, T defaultValue) {
    try {
      final value = map[key];
      if (value is T) {
        return value;
      }
      // Attempt type conversion for common cases
      if (T == int && value is num) {
        return value.toInt() as T;
      }
      if (T == double && value is num) {
        return value.toDouble() as T;
      }
      if (T == String && value != null) {
        return value.toString() as T;
      }
      if (T == bool && value is int) {
        return (value == 1) as T;
      }
      if (T == bool && value is String) {
        return (value.toLowerCase() == 'true' || value == '1') as T;
      }
      // Handle List<String> conversion by checking type string representation
      if (T.toString() == 'List<String>' && value is List) {
        try {
          return value.map((e) => e.toString()).toList() as T;
        } catch (castError) {
          // Handle potential cast error if elements aren't strings
          print("⚠️ Error casting List elements to String for key '$key': $castError");
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print("⚠️ Error safely getting key '$key': $e. Using default: $defaultValue");
      }
    }
    return defaultValue;
  }

  // Créer une conversation avec un producteur (restaurant, loisir, etc.)
  Future<Map<String, dynamic>> createProducerConversation(
    String userId,
    String producerId,
    String producerType, // 'restaurant', 'leisure', 'wellness', 'beauty'
  ) async {
    try {
      // Vérifier que les identifiants ne sont pas vides
      if (userId.isEmpty) {
        throw Exception('ID utilisateur vide ou non valide');
      }

      if (producerId.isEmpty) {
        throw Exception('ID producteur vide ou non valide');
      }
      
      if (producerType.isEmpty) {
        throw Exception('Type de producteur vide ou non valide');
      }

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      final baseUrl = getBaseUrl();
      
      // Utiliser des noms de paramètres clairs pour l'API
      // 'initiatorId' est celui qui lance la conversation (peut être user ou producer)
      // 'targetId' est celui qui est contacté (peut être user ou producer)
      // Le backend devrait pouvoir déterminer les types à partir des IDs ou via des paramètres supplémentaires
      print('🔍 Tentative de création/récupération conversation: initiatorId=$userId, targetId=$producerId, initiatorType=$producerType');
      
      final response = await http.post(
        // Utiliser l'endpoint standard create-or-get-conversation
        Uri.parse('$baseUrl/api/conversations/create-or-get-conversation'), 
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'initiatorId': userId, 
          'targetId': producerId,
          'initiatorType': producerType, // Fournir le type de l'initiateur si nécessaire au backend
          // Le backend devrait déterminer le type de targetId ou on pourrait l'ajouter ici si connu
        }),
      );
      
      print('📤 Réponse create-or-get: ${response.statusCode}, body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final result = json.decode(response.body);
        print('✅ Conversation créée/récupérée: ${result['conversation']?['_id'] ?? result['conversationId'] ?? 'ID non trouvé'}');
        
        // Retourner la conversation trouvée ou créée
        return result['conversation'] ?? result ?? {};
      } else {
        print('❌ Erreur create-or-get: ${response.statusCode}, body: ${response.body}');
        throw Exception('Échec create-or-get conversation: ${response.body}');
      }
    } catch (e) {
      print('❌ Exception create-or-get: $e');
      throw Exception('Erreur lors de create-or-get: $e');
    }
  }

  // Méthode pour démarrer une conversation avec un établissement
  Future<Map<String, dynamic>> startConversationWithBusiness(
    String userId,
    String businessId,
    String businessType,
    String initialMessage
  ) async {
    try {
      final token = await _getToken();
      final baseUrl = getBaseUrl();
      
      final Map<String, dynamic> payload = {
        'userId': userId,
        'businessId': businessId,
        'businessType': businessType,
        'initialMessage': initialMessage,
      };
      
      print('🚀 Démarrage d\'une conversation avec un établissement: $businessType');
      print('🚀 Payload: ${json.encode(payload)}');
      
      final response = await http.post(
        Uri.parse('$baseUrl/api/conversations'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(payload),
      );
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final result = json.decode(response.body);
        print('✅ Conversation démarrée avec succès: ${result['conversation']?['_id'] ?? 'ID non disponible'}');
        
        // Formater la réponse pour l'interface utilisateur
        Map<String, dynamic> conversation = result['conversation'] ?? {};
        
        // Assurer que certains champs sont présents
        if (!conversation.containsKey('title') && conversation.containsKey('producerInfo')) {
          conversation['title'] = conversation['producerInfo']['name'] ?? 'Nouvelle conversation';
        }
        
        return conversation;
      } else {
        print('❌ Erreur démarrage conversation: ${response.statusCode}, body: ${response.body}');
        throw Exception('Échec du démarrage de la conversation: ${response.body}');
      }
    } catch (e) {
      print('❌ Exception démarrage conversation: $e');
      throw Exception('Erreur lors du démarrage de la conversation: $e');
    }
  }

  // Placeholder/Example for fetching the current user ID
  // Replace with your actual authentication logic (e.g., using AuthService)
  Future<String> getCurrentUserId() async {
    // Use the userId from AuthService instance
    final userId = _authService.userId;

    if (userId == null || userId.isEmpty) {
       print("❌ ERROR: getCurrentUserId failed - User ID is null or empty in AuthService.");
       // Throw an exception or handle this case as appropriate for your app
       // For example, redirecting to login or showing an error message.
       throw Exception("User is not authenticated or user ID is missing.");
    }
    print("ℹ️ getCurrentUserId retrieved ID: $userId");
    return userId;
  }

  // Method to get conversation details by ID (used in GroupDetailScreen)
  Future<Map<String, dynamic>> getConversationById(String conversationId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/conversations/$conversationId'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
         if (data is Map<String, dynamic>) {
             return {
                'id': data['id'] ?? data['_id'] ?? conversationId,
                'name': data['groupName'] ?? data['name'] ?? 'Groupe',
                'avatarUrl': data['groupImage'] ?? data['groupAvatar'] ?? data['avatar'],
                'isPinned': data['isPinned'] ?? false,
                'isMuted': data['isMuted'] ?? false,
                ...data,
             };
         } else {
            print('⚠️ Unexpected format for conversation details: ${response.body}');
            throw Exception('Unexpected response format for conversation details');
         }
      } else {
        throw Exception('Failed to fetch conversation details: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Exception fetching conversation details: $e');
      rethrow;
    }
  }

  // Method to get participants of a conversation
   Future<List<dynamic>> getConversationParticipants(String conversationId) async {
     try {
       final response = await http.get(
         Uri.parse('$baseUrl/api/conversations/$conversationId/participants'),
       );

       if (response.statusCode == 200) {
         final data = json.decode(response.body);
         if (data['success'] == true && data['participants'] is List) {
           return List<Map<String, dynamic>>.from(data['participants'].map((item) {
              return item;
           }));
         } else {
            print('⚠️ Participants fetch failed or returned unexpected format: ${response.body}');
           return [];
         }
       } else {
         throw Exception('Failed to fetch participants: ${response.statusCode}');
       }
     } catch (e) {
       print('❌ Exception fetching participants: $e');
       rethrow;
     }
   }

   // --- File Upload & Group helpers ----
   Future<String?> uploadFile(File file) async {
    print("ℹ️ Uploading file: ${file.path}");
    String? currentUserId;
    try {
      currentUserId = await getCurrentUserId(); // Get user ID for potential authorization or logging
    } catch (e) {
       print("⚠️ Could not get user ID for file upload: $e. Proceeding without it.");
       // Decide if user ID is strictly required for upload endpoint
    }

    final token = await _getToken(); // Get auth token

    // --- Actual Upload Logic ---
    try {
      final baseUrlValue = getBaseUrl();
      // Define your backend upload endpoint URL here
      final url = '$baseUrlValue/api/upload'; // <-- ADJUST THIS URL TO YOUR ACTUAL ENDPOINT
      print("⬆️ Uploading to: $url");

      var request = http.MultipartRequest('POST', Uri.parse(url));

      // Add Authorization header if your endpoint requires it
      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      // Add User ID header if needed by your backend
      // if (currentUserId != null && currentUserId.isNotEmpty) {
      //   request.headers['X-User-ID'] = currentUserId;
      // }

      // Determine content type
      String mimeType = 'application/octet-stream'; // Default
      String fileExtension = file.path.split('.').last.toLowerCase();
      if (['jpg', 'jpeg'].contains(fileExtension)) {
          mimeType = 'image/jpeg';
      } else if (fileExtension == 'png') {
          mimeType = 'image/png';
      } else if (fileExtension == 'gif') {
         mimeType = 'image/gif';
      } else if (fileExtension == 'mp4') {
         mimeType = 'video/mp4';
      } // Add more types as needed

      // Add the file to the request
      request.files.add(await http.MultipartFile.fromPath(
        'file', // The field name expected by your backend API for the file
        file.path,
        contentType: MediaType.parse(mimeType), // Use parsed MediaType
      ));

      // Optional: Add other fields if needed by your backend
      // request.fields['userId'] = currentUserId ?? '';
      // request.fields['description'] = 'Group Avatar Upload';

      // Send the request
      var response = await request.send();

      // Process the response
      final responseBody = await response.stream.bytesToString();
      print("☁️ Upload Response Status: ${response.statusCode}");
      print("☁️ Upload Response Body: $responseBody");

      if (response.statusCode == 200 || response.statusCode == 201) {
        var jsonResponse = jsonDecode(responseBody);
        // IMPORTANT: Adjust the key ('url', 'fileUrl', 'link', etc.) based on your backend response
        final uploadedUrl = jsonResponse['url'] ?? jsonResponse['fileUrl'] ?? jsonResponse['link'];
        if (uploadedUrl != null && uploadedUrl is String && uploadedUrl.isNotEmpty) {
           print("✅ File uploaded successfully. URL: $uploadedUrl");
           return uploadedUrl;
        } else {
            print("❌ File upload succeeded but URL not found in response: $responseBody");
            throw Exception("Upload succeeded but URL was missing in the response.");
        }
      } else {
        print('❌ File upload failed with status: ${response.statusCode}');
        throw Exception('File upload failed: ${response.statusCode} - $responseBody');
      }
    } catch (e) {
      print('❌ Exception during file upload: $e');
      // Rethrow the exception so the calling method can handle it
      rethrow;
    }
  }

  // Update group details (name, avatar, pin, mute status)
  Future<void> updateGroupDetails(
    String conversationId, {
    String? name,
    File? avatarFile,
    bool? isPinned,
    bool? isMuted,
  }) async {
    String? avatarUrl;

    // 1. Upload avatar if provided
    if (avatarFile != null) {
      print('ℹ️ Avatar file provided, attempting upload...');
      try {
         avatarUrl = await uploadFile(avatarFile);
         if (avatarUrl == null) {
            print('❌ Avatar upload returned null. Cannot update group avatar.');
            // Decide if you want to proceed with name change only or throw error
            // throw Exception('Failed to upload avatar (returned null).');
         } else {
            print('✅ Avatar uploaded, URL: $avatarUrl');
         }
      } catch (e) {
         print('❌ Avatar upload failed with exception: $e. Cannot update group avatar.');
         // Optionally rethrow or handle the error (e.g., show a message to the user)
         // throw Exception('Failed to upload avatar: $e');
         // For now, we'll proceed without the avatar change if upload fails
         avatarUrl = null; // Ensure avatarUrl is null if upload failed
      }
    }

    // 2. Prepare data for PATCH request
    final Map<String, dynamic> updateData = {};
    bool hasChanges = false;
    if (name != null) {
      updateData['groupName'] = name;
      hasChanges = true;
    }
    if (avatarUrl != null) {
      updateData['groupAvatar'] = avatarUrl;
      hasChanges = true;
    }
    if (isPinned != null) {
       updateData['isPinned'] = isPinned;
       hasChanges = true;
    }
    if (isMuted != null) {
       updateData['isMuted'] = isMuted;
       hasChanges = true;
    }

    if (!hasChanges) {
      print('ℹ️ No changes detected or upload failed. Skipping group details update API call.');
      return; // Nothing to update
    }

    // 3. Send PATCH request
    try {
      final token = await _getToken();
      final baseUrlValue = getBaseUrl();
      final url = '$baseUrlValue/api/conversations/$conversationId';
      print('⬆️ Updating group details: $url with data: ${json.encode(updateData)}');

      final response = await http.patch(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(updateData),
      );

      if (response.statusCode == 200) {
        print('✅ Group details updated successfully via API.');
      } else {
        print('❌ Failed to update group details via API: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to update group details: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Exception updating group details via API: $e');
      throw Exception('Error updating group details: $e');
    }
  }

  // Add participants to a group
  Future<void> addParticipantsByIds(String conversationId, List<String> participantIds) async {
    // ... existing code ...
  }

  // Remove a participant from a group
  Future<void> removeParticipant(String conversationId, String participantId) async {
    // ... existing code ...
  }

  // Fetch GIFs from Tenor
  Future<List<Map<String, dynamic>>> searchGifs(String query, {int limit = 20}) async {
    if (_tenorApiKey.isEmpty) {
      print("❌ Tenor API Key is missing. Please provide it via --dart-define=TENOR_API_KEY=YOUR_KEY");
      return [];
    }
    if (query.isEmpty) {
      return await fetchTrendingGifs(limit: limit);
    }

    // Define the URL within the method scope
    final String requestUrl = "https://tenor.googleapis.com/v2/search?q=${Uri.encodeComponent(query)}&key=$_tenorApiKey&limit=$limit&media_filter=minimal";
    print("🔍 Searching GIFs on Tenor: $requestUrl");

    try {
      final response = await http.get(Uri.parse(requestUrl)); // Use the defined URL variable
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'] as List?;
        if (results != null) {
          // Map results safely
          return results.map((gif) {
            // Ensure gif is a Map<String, dynamic> before accessing keys
            if (gif is Map<String, dynamic>) {
               final mediaFormats = gif['media_formats'] as Map<String, dynamic>?;
               final previewUrl = mediaFormats?['nanogif']?['url'] ?? mediaFormats?['tinygif']?['url'] ?? mediaFormats?['gif']?['url'];
               final gifUrl = mediaFormats?['gif']?['url'];
               return {
                 'id': gif['id'],
                 'previewUrl': previewUrl, 
                 'url': gifUrl,
                 'description': gif['content_description'],
               };
            } else {
               return <String, dynamic>{}; // Return empty map for invalid items
            }
          }).where((gif) => gif.containsKey('previewUrl') && gif['previewUrl'] != null && gif.containsKey('url') && gif['url'] != null).toList(); // Filter valid results
        }
        return [];
      } else {
         print("❌ Failed to fetch GIFs from Tenor: ${response.statusCode} - ${response.body}");
        return [];
      }
    } catch (e) {
      print("❌ Exception fetching GIFs: $e");
      return [];
    }
  }

  // Fetch Trending GIFs from Tenor
  Future<List<Map<String, dynamic>>> fetchTrendingGifs({int limit = 20}) async {
    if (_tenorApiKey.isEmpty) {
       print("❌ Tenor API Key is missing for trending GIFs.");
      return [];
    }
    // Define the URL within the method scope
    final String requestUrl = "https://tenor.googleapis.com/v2/featured?key=$_tenorApiKey&limit=$limit&media_filter=minimal";
     print("📈 Fetching Trending GIFs from Tenor: $requestUrl");

    try {
      final response = await http.get(Uri.parse(requestUrl)); // Use the defined URL variable
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'] as List?;
         if (results != null) {
          // Map results safely
          return results.map((gif) {
             // Ensure gif is a Map<String, dynamic> before accessing keys
             if (gif is Map<String, dynamic>) {
                final mediaFormats = gif['media_formats'] as Map<String, dynamic>?;
                final previewUrl = mediaFormats?['nanogif']?['url'] ?? mediaFormats?['tinygif']?['url'] ?? mediaFormats?['gif']?['url'];
                final gifUrl = mediaFormats?['gif']?['url'];
                return {
                  'id': gif['id'],
                  'previewUrl': previewUrl,
                  'url': gifUrl,
                  'description': gif['content_description'],
                };
             } else {
                 return <String, dynamic>{}; // Return empty map for invalid items
             }
          }).where((gif) => gif.containsKey('previewUrl') && gif['previewUrl'] != null && gif.containsKey('url') && gif['url'] != null).toList(); // Filter valid results
        }
        return [];
      } else {
         print("❌ Failed to fetch trending GIFs: ${response.statusCode} - ${response.body}");
        return [];
      }
    } catch (e) {
      print("❌ Exception fetching trending GIFs: $e");
      return [];
    }
  }
} 
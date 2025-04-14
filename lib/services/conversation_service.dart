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
        Uri.parse('$baseUrl/api/users/$userId/conversations'),
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
  Future<Map<String, dynamic>> createOrGetConversation(
    String userId,
    String recipientId,
  ) async {
    try {
      // Vérifier que les identifiants ne sont pas vides
      if (userId == null || userId.isEmpty) {
        throw Exception('ID utilisateur vide ou non valide');
      }

      if (recipientId == null || recipientId.isEmpty) {
        throw Exception('ID destinataire vide ou non valide');
      }

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      final baseUrl = getBaseUrl();
      
      print('🔍 Création de conversation avec: userId=$userId, recipientId=$recipientId');
      
      final response = await http.post(
        Uri.parse('$baseUrl/api/users/conversations'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'participantIds': [userId, recipientId],
        }),
      );

      print('📤 Réponse création conversation: ${response.statusCode}, body: ${response.body}');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final result = json.decode(response.body);
        print('✅ Conversation créée ou récupérée avec succès: $result');
        
        // Adapter la réponse pour assurer la cohérence
        return {
          'conversationId': result['_id'],
          'conversation_id': result['_id'], // Assurer la compatibilité avec les deux formats
          '_id': result['_id'],
          'participants': result['participants'],
        };
      } else {
        print('❌ Erreur création conversation: ${response.statusCode}, body: ${response.body}');
        throw Exception('Échec de la création de la conversation: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Exception création conversation: $e');
      throw Exception('Erreur lors de la création de la conversation: $e');
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
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    final baseUrl = getBaseUrl();
    final List<Map<String, dynamic>> processedConversations = [];
    
    for (var conv in rawConversations) {
      final List<dynamic> participants = conv['participants'];
      bool isGroup = participants.length > 2;
      
      if (isGroup) {
        // Traitement pour une conversation de groupe
        processedConversations.add({
          'id': conv['_id'],
          'name': conv['groupName'] ?? 'Groupe',
          'avatar': conv['groupAvatar'] ?? 'https://via.placeholder.com/150',
          'lastMessage': conv['lastMessage'] ?? 'Conversation de groupe',
          'time': conv['lastUpdated'] ?? DateTime.now().toIso8601String(),
          'unreadCount': conv['unreadMessages'] ?? 0,
          'isGroup': true,
          'isRestaurant': false,
          'isLeisure': false,
          'participants': participants,
        });
        continue;
      }
      
      // Trouver l'ID du destinataire (qui n'est pas l'utilisateur actuel)
      String recipientId = '';
      for (var participantId in participants) {
        if (participantId != currentUserId) {
          recipientId = participantId;
          break;
        }
      }
      
      if (recipientId.isEmpty) continue;
      
      // Récupérer les détails du participant (nom, photo, etc.)
      try {
        final userResponse = await http.get(
          Uri.parse('$baseUrl/api/users/$recipientId'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );
        
        if (userResponse.statusCode == 200) {
          final userData = json.decode(userResponse.body);
          
          // Déterminer si c'est un restaurant, loisir ou utilisateur standard
          bool isRestaurant = userData['type'] == 'restaurant';
          bool isLeisure = userData['type'] == 'leisure';
          
          processedConversations.add({
            'id': conv['_id'],
            'recipientId': recipientId,
            'name': userData['name'] ?? userData['username'] ?? 'Utilisateur',
            'avatar': userData['photo_url'] ?? userData['profilePicture'] ?? userData['avatar'] ?? 'https://via.placeholder.com/150',
            'lastMessage': conv['lastMessage'] ?? 'Démarrer une conversation',
            'time': conv['lastUpdated'] ?? DateTime.now().toIso8601String(),
            'unreadCount': userData['unreadMessages'] ?? 0,
            'isRestaurant': isRestaurant,
            'isLeisure': isLeisure,
            'isGroup': false,
          });
        }
      } catch (e) {
        print('Erreur lors de la récupération des détails du participant: $e');
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

  // Obtenir les conversations d'un producteur
  Future<List<Map<String, dynamic>>> getProducerConversations(
    String producerId,
    String producerType,
  ) async {
    try {
      final baseUrl = getBaseUrl();
      
      // Essayer d'abord l'endpoint spécifique aux conversations de producteurs
      final response = await http.get(
        Uri.parse('$baseUrl/api/producers/$producerId/conversations?producerType=$producerType'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.cast<Map<String, dynamic>>();
      }

      // Si cela échoue, essayer l'endpoint de fallback
      final fallbackResponse = await http.get(
        Uri.parse('$baseUrl/api/users/$producerId/producer-conversations?type=$producerType'),
      );

      if (fallbackResponse.statusCode == 200) {
        final List<dynamic> data = json.decode(fallbackResponse.body);
        return data.cast<Map<String, dynamic>>();
      }

      throw Exception('Impossible de récupérer les conversations');
    } catch (e) {
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
} 
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../utils/constants.dart' as constants;
import 'package:shared_preferences/shared_preferences.dart';

/// Modèle d'utilisateur enrichi pour correspondre aux données du backend
class UserModel extends ChangeNotifier {
  String? _id;
  String? _username;
  String? _email;
  String? _token;
  String? _name;
  String? _stripeCustomerId;
  String? _photoUrl;
  String? _profilePicture;
  String? _bio;
  bool _isEmailVerified = false;
  bool _isLoggedIn = false;
  
  // Données sociales
  List<String> _followers = [];
  List<String> _following = [];
  List<String> _followingProducers = [];
  int _followersCount = 0;
  
  // Métriques et statistiques
  int _influenceScore = 0;
  Map<String, dynamic> _interactionMetrics = {};
  
  // Préférences et intérêts
  List<String> _likedTags = [];
  List<dynamic> _interests = [];
  Map<String, dynamic> _sectorPreferences = {};
  
  // Activité
  List<String> _posts = [];
  List<String> _choices = [];
  List<String> _likedPosts = [];
  
  // Données supplémentaires
  bool _onboardingCompleted = false;
  Map<String, dynamic>? _userData;
  Map<String, dynamic>? _consumptionBehavior;
  Map<String, dynamic>? _preferredContentFormat;
  
  /// Constructeur du modèle utilisateur
  UserModel({
    String? id,
    String? username,
    String? email,
    String? token,
    String? name,
    String? stripeCustomerId,
    String? photoUrl,
    String? profilePicture,
    String? bio,
    bool isEmailVerified = false,
    bool isLoggedIn = false,
    List<String>? followers,
    List<String>? following,
    List<String>? followingProducers,
    int? followersCount,
    int? influenceScore,
    Map<String, dynamic>? interactionMetrics,
    List<String>? likedTags,
    List<dynamic>? interests,
    Map<String, dynamic>? sectorPreferences,
    List<String>? posts,
    List<String>? choices,
    List<String>? likedPosts,
    bool? onboardingCompleted,
    Map<String, dynamic>? userData,
    Map<String, dynamic>? consumptionBehavior,
    Map<String, dynamic>? preferredContentFormat,
  }) {
    _id = id;
    _username = username;
    _email = email;
    _token = token;
    _name = name;
    _stripeCustomerId = stripeCustomerId;
    _photoUrl = photoUrl;
    _profilePicture = profilePicture;
    _bio = bio;
    _isEmailVerified = isEmailVerified;
    _isLoggedIn = isLoggedIn || (token != null && token.isNotEmpty);
    _followers = followers ?? [];
    _following = following ?? [];
    _followingProducers = followingProducers ?? [];
    _followersCount = followersCount ?? 0;
    _influenceScore = influenceScore ?? 0;
    _interactionMetrics = interactionMetrics ?? {};
    _likedTags = likedTags ?? [];
    _interests = interests ?? [];
    _sectorPreferences = sectorPreferences ?? {};
    _posts = posts ?? [];
    _choices = choices ?? [];
    _likedPosts = likedPosts ?? [];
    _onboardingCompleted = onboardingCompleted ?? false;
    _userData = userData;
    _consumptionBehavior = consumptionBehavior;
    _preferredContentFormat = preferredContentFormat;
  }

  /// Getters
  String? get id => _id;
  String? get username => _username;
  String? get email => _email;
  String? get token => _token;
  String? get name => _name;
  String? get stripeCustomerId => _stripeCustomerId;
  String? get photoUrl => _photoUrl ?? _profilePicture;
  String? get bio => _bio;
  bool get isEmailVerified => _isEmailVerified;
  bool get isLoggedIn => _isLoggedIn;
  List<String> get followers => _followers;
  List<String> get following => _following;
  List<String> get followingProducers => _followingProducers;
  int get followersCount => _followersCount;
  int get influenceScore => _influenceScore;
  Map<String, dynamic> get interactionMetrics => _interactionMetrics;
  List<String> get likedTags => _likedTags;
  List<dynamic> get interests => _interests;
  Map<String, dynamic> get sectorPreferences => _sectorPreferences;
  List<String> get posts => _posts;
  List<String> get choices => _choices;
  List<String> get likedPosts => _likedPosts;
  bool get onboardingCompleted => _onboardingCompleted;
  Map<String, dynamic>? get userData => _userData;
  Map<String, dynamic>? get consumptionBehavior => _consumptionBehavior;
  Map<String, dynamic>? get preferredContentFormat => _preferredContentFormat;

  // Getters pour faciliter l'accès à certaines données
  int get postsCount => _posts.length;
  int get choicesCount => _choices.length;
  int get followingCount => _following.length;
  int get totalInteractions => _interactionMetrics['total_interactions'] ?? 0;
  int get commentsGiven => _interactionMetrics['comments_given'] ?? 0;
  int get choicesGiven => _interactionMetrics['choices_given'] ?? 0;
  int get sharesGiven => _interactionMetrics['shares_given'] ?? 0;

  // Getter pour savoir si on est en mode simulation (toujours false désormais)
  bool get isSimulationMode => false;

  /// Crée un objet UserModel à partir d'un JSON
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['_id'] ?? json['id'] ?? '',
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      token: json['token'] ?? '',
      name: json['name'] ?? json['fullName'] ?? '',
      stripeCustomerId: json['stripeCustomerId'] ?? '',
      photoUrl: json['photo_url'] ?? '',
      profilePicture: json['profilePicture'] ?? '',
      bio: json['bio'] ?? '',
      isEmailVerified: json['isEmailVerified'] ?? false,
      isLoggedIn: json['isLoggedIn'] ?? false,
      followers: _parseStringList(json['followers']),
      following: _parseStringList(json['following']),
      followingProducers: _parseStringList(json['followingProducers']),
      followersCount: json['followers_count'] ?? 0,
      influenceScore: json['influence_score'] ?? 0,
      interactionMetrics: json['interaction_metrics'] ?? {},
      likedTags: _parseStringList(json['liked_tags']),
      interests: json['interests'] ?? [],
      sectorPreferences: json['sector_preferences'] ?? {},
      posts: _parseStringList(json['posts']),
      choices: _parseStringList(json['choices']),
      likedPosts: _parseStringList(json['liked_posts']),
      onboardingCompleted: json['onboarding_completed'] ?? false,
      userData: json['userData'] ?? json,
      consumptionBehavior: json['consumption_behavior'] ?? {},
      preferredContentFormat: json['preferred_content_format'] ?? {},
    );
  }

  /// Méthode utilitaire pour parser les listes de façon sûre
  static List<String> _parseStringList(dynamic list) {
    if (list == null) return [];
    if (list is! List) return [];
    return list.map((item) => item.toString()).toList();
  }

  /// Convertit l'objet UserModel en JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'token': token,
      'name': name,
      'stripeCustomerId': stripeCustomerId,
      'photo_url': photoUrl,
      'profilePicture': _profilePicture,
      'bio': bio,
      'isEmailVerified': isEmailVerified,
      'isLoggedIn': isLoggedIn,
      'followers': followers,
      'following': following,
      'followingProducers': followingProducers,
      'followers_count': followersCount,
      'influence_score': influenceScore,
      'interaction_metrics': interactionMetrics,
      'liked_tags': likedTags,
      'interests': interests,
      'sector_preferences': sectorPreferences,
      'posts': posts,
      'choices': choices,
      'liked_posts': likedPosts,
      'onboarding_completed': onboardingCompleted,
      'userData': userData,
      'consumption_behavior': consumptionBehavior,
      'preferred_content_format': preferredContentFormat,
    };
  }

  /// Crée une copie de l'objet UserModel avec certaines propriétés modifiées
  UserModel copyWith({
    String? id,
    String? username,
    String? email,
    String? token,
    String? name,
    String? stripeCustomerId,
    String? photoUrl,
    String? profilePicture,
    String? bio,
    bool? isEmailVerified,
    bool? isLoggedIn,
    List<String>? followers,
    List<String>? following,
    List<String>? followingProducers,
    int? followersCount,
    int? influenceScore,
    Map<String, dynamic>? interactionMetrics,
    List<String>? likedTags,
    List<dynamic>? interests,
    Map<String, dynamic>? sectorPreferences,
    List<String>? posts,
    List<String>? choices,
    List<String>? likedPosts,
    bool? onboardingCompleted,
    Map<String, dynamic>? userData,
    Map<String, dynamic>? consumptionBehavior,
    Map<String, dynamic>? preferredContentFormat,
  }) {
    return UserModel(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      token: token ?? this.token,
      name: name ?? this.name,
      stripeCustomerId: stripeCustomerId ?? this.stripeCustomerId,
      photoUrl: photoUrl ?? this._photoUrl,
      profilePicture: profilePicture ?? this._profilePicture,
      bio: bio ?? this.bio,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      followers: followers ?? this.followers,
      following: following ?? this.following,
      followingProducers: followingProducers ?? this.followingProducers,
      followersCount: followersCount ?? this.followersCount,
      influenceScore: influenceScore ?? this.influenceScore,
      interactionMetrics: interactionMetrics ?? this.interactionMetrics,
      likedTags: likedTags ?? this.likedTags,
      interests: interests ?? this.interests,
      sectorPreferences: sectorPreferences ?? this.sectorPreferences,
      posts: posts ?? this.posts,
      choices: choices ?? this.choices,
      likedPosts: likedPosts ?? this.likedPosts,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      userData: userData ?? this.userData,
      consumptionBehavior: consumptionBehavior ?? this.consumptionBehavior,
      preferredContentFormat: preferredContentFormat ?? this.preferredContentFormat,
    );
  }

  // Méthode pour vérifier si l'utilisateur suit un autre utilisateur ou producteur
  bool isFollowing(String targetId) {
    return following.contains(targetId) || followingProducers.contains(targetId);
  }

  // Méthode pour suivre ou ne plus suivre un utilisateur ou un producteur
  Future<bool> toggleFollow(String targetId, bool isProducer) async {
    if (_id == null || _token == null) {
      print('❌ Erreur: utilisateur non connecté lors de la tentative de suivi');
      return false;
    }
    
    try {
      // Créer l'URL en fonction du type (utilisateur ou producteur)
      final endpoint = isProducer 
          ? '/api/producers/$targetId/follow' 
          : '/api/users/$targetId/follow';
      
      final url = Uri.parse('${constants.getBaseUrl()}$endpoint');
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
        body: json.encode({'userId': _id}),
      );
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final bool isNowFollowing = responseData['isFollowing'] ?? 
                                   !isFollowing(targetId);
        
        // Mettre à jour les données locales
        if (isProducer) {
          if (isNowFollowing && !_followingProducers.contains(targetId)) {
            _followingProducers.add(targetId);
          } else if (!isNowFollowing && _followingProducers.contains(targetId)) {
            _followingProducers.remove(targetId);
          }
        } else {
          if (isNowFollowing && !_following.contains(targetId)) {
            _following.add(targetId);
          } else if (!isNowFollowing && _following.contains(targetId)) {
            _following.remove(targetId);
          }
        }
        
        notifyListeners();
        return true;
      } else {
        print('❌ Erreur lors du suivi: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ Exception lors du suivi: $e');
      return false;
    }
  }
  
  // Méthode pour marquer un producteur comme un "choice"
  Future<bool> toggleChoice(String producerId) async {
    if (_id == null || _token == null) {
      print('❌ Erreur: utilisateur non connecté lors de la tentative de marquer un choix');
      return false;
    }
    
    try {
      final url = Uri.parse('${constants.getBaseUrl()}/api/interactions/choice');
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
        body: json.encode({
          'userId': _id,
          'producerId': producerId,
          'action': _choices.contains(producerId) ? 'remove' : 'add',
        }),
      );
      
      if (response.statusCode == 200) {
        // Mettre à jour les données locales
        if (_choices.contains(producerId)) {
          _choices.remove(producerId);
        } else {
          _choices.add(producerId);
        }
        
        // Mettre à jour les métriques d'interaction
        _interactionMetrics['choices_given'] = (_interactionMetrics['choices_given'] ?? 0) + 
                                              (_choices.contains(producerId) ? 1 : -1);
        
        notifyListeners();
        return true;
      } else {
        print('❌ Erreur lors du marquage de choix: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ Exception lors du marquage de choix: $e');
      return false;
    }
  }
  
  // Méthode pour marquer un intérêt pour un tag spécifique
  Future<bool> toggleTagInterest(String tag) async {
    if (_id == null || _token == null) {
      print('❌ Erreur: utilisateur non connecté lors de la tentative de marquer un intérêt pour un tag');
      return false;
    }
    
    try {
      final url = Uri.parse('${constants.getBaseUrl()}/api/users/$_id/tags');
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
        body: json.encode({
          'tag': tag,
          'action': _likedTags.contains(tag) ? 'remove' : 'add',
        }),
      );
      
      if (response.statusCode == 200) {
        // Mettre à jour les données locales
        if (_likedTags.contains(tag)) {
          _likedTags.remove(tag);
        } else {
          _likedTags.add(tag);
        }
        
        notifyListeners();
        return true;
      } else {
        print('❌ Erreur lors de la mise à jour des tags: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ Exception lors de la mise à jour des tags: $e');
      return false;
    }
  }
  
  // Méthode pour mettre à jour les statistiques d'interaction avec un producteur
  Future<bool> recordInteraction(String producerId, String interactionType) async {
    if (_id == null || _token == null) {
      print('❌ Erreur: utilisateur non connecté lors de la tentative d\'enregistrement d\'interaction');
      return false;
    }
    
    try {
      final url = Uri.parse('${constants.getBaseUrl()}/api/interactions/record');
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
        body: json.encode({
          'userId': _id,
          'targetId': producerId,
          'type': interactionType,
        }),
      );
      
      if (response.statusCode == 200) {
        // Mettre à jour les statistiques locales
        _interactionMetrics['total_interactions'] = 
            (_interactionMetrics['total_interactions'] ?? 0) + 1;
            
        String metricKey = '${interactionType}s_given';
        _interactionMetrics[metricKey] = (_interactionMetrics[metricKey] ?? 0) + 1;
        
        notifyListeners();
        return true;
      } else {
        print('❌ Erreur lors de l\'enregistrement de l\'interaction: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ Exception lors de l\'enregistrement de l\'interaction: $e');
      return false;
    }
  }
  
  // Méthode pour vérifier si un producteur fait partie des choix de l'utilisateur
  bool isChoice(String producerId) {
    return _choices.contains(producerId);
  }
  
  // Méthode pour vérifier si un tag est aimé par l'utilisateur
  bool isTagLiked(String tag) {
    return _likedTags.contains(tag);
  }
  
  // Obtenir les trois tags les plus aimés (pour affichage dans l'interface)
  List<String> getTopTags() {
    return _likedTags.take(3).toList();
  }
  
  // Méthode pour suggérer des producteurs basés sur les intérêts de l'utilisateur
  Future<List<Map<String, dynamic>>> getSuggestedProducers() async {
    if (_id == null || _token == null) {
      print('❌ Erreur: utilisateur non connecté lors de la tentative de récupération de suggestions');
      return [];
    }
    
    try {
      final url = Uri.parse('${constants.getBaseUrl()}/api/users/$_id/suggestions');
      
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $_token',
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['suggestions'] ?? []);
      } else {
        print('❌ Erreur lors de la récupération des suggestions: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ Exception lors de la récupération des suggestions: $e');
      return [];
    }
  }

  // Méthode de connexion étendue pour récupérer les données complètes
  Future<bool> login(String email, String password) async {
    try {
      // Créer l'URL pour l'endpoint de login
      final url = Uri.parse('${constants.getBaseUrl()}/api/users/login');
      
      // Faire la requête d'authentification
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'password': password,
        }),
      );
      
      // Vérifier la réponse
      if (response.statusCode == 200) {
        // Décoder la réponse JSON
        final responseData = json.decode(response.body);
        
        // Récupérer le token et l'utilisateur
        final userData = responseData['user'];
        final token = responseData['token'];
        
        // Sauvegarder les données de l'utilisateur
        _id = userData['_id'];
        _username = userData['username'];
        _email = userData['email'];
        _name = userData['name'];
        _token = token;
        _isLoggedIn = true;
        _photoUrl = userData['photo_url'] ?? userData['profilePicture'];
        _bio = userData['bio'] ?? '';
        
        // Sauvegarder les préférences localStorage
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_token', token);
        await prefs.setString('user_id', _id!);
        
        // Récupérer les données complètes de l'utilisateur
        await fetchUserData();
        
        notifyListeners();
        return true;
      } else {
        // Gérer les erreurs d'authentification
        final error = json.decode(response.body)['error'] ?? 'Erreur de connexion';
        print('❌ Erreur de connexion: ${response.statusCode} - $error');
        throw Exception(error);
      }
    } catch (e) {
      print('❌ Exception lors de la connexion: $e');
      throw Exception('Erreur de connexion: $e');
    }
  }

  /// Déconnecte l'utilisateur
  Future<void> logout() async {
    try {
      _id = null;
      _username = null;
      _email = null;
      _name = null;
      _bio = null;
      _photoUrl = null;
      _token = null;
      _followersCount = 0;
      _influenceScore = 0;
      _followers = [];
      _following = [];
      _followingProducers = [];
      _likedTags = [];
      _posts = [];
      _choices = [];
      _likedPosts = [];
      _interests = [];
      _interactionMetrics = {};
      _sectorPreferences = {};
      _consumptionBehavior = {};
      _preferredContentFormat = {};
      _onboardingCompleted = false;
      _userData = null;
      
      // Supprimer les préférences locales
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_token');
      await prefs.remove('user_id');
      
      notifyListeners();
      print('✅ Utilisateur déconnecté');
    } catch (e) {
      print('❌ Erreur lors de la déconnexion: $e');
    }
  }
  
  // Mise à jour des données utilisateur
  Future<void> fetchUserData() async {
    try {
      // Vérifier si nous avons un ID utilisateur qui ressemble à un ID MongoDB valide
      final bool hasRealId = _id != null && RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(_id!);
      
      if (_token != null) {
        final url = Uri.parse('${constants.getBaseUrl()}/api/users/$_id');
        
        // Préparation des en-têtes avec le token d'authentification
        final Map<String, String> headers = {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        };
        
        print('📱 Requête données utilisateur: $url');
        final response = await http.get(url, headers: headers);
        
        if (response.statusCode == 200) {
          print('✅ Données utilisateur récupérées avec succès');
          final userData = json.decode(response.body);
          
          // Mettre à jour les données de base
          _username = userData['username'] ?? _username;
          _email = userData['email'] ?? _email;
          _name = userData['name'] ?? _name;
          _bio = userData['bio'] ?? _bio;
          _photoUrl = userData['photo_url'] ?? _photoUrl;
          _followersCount = userData['followers_count'] ?? _followersCount;
          _influenceScore = userData['influence_score'] ?? _influenceScore;
          
          // Traiter les tableaux avec sécurité
          _followers = _parseStringList(userData['followers']);
          _following = _parseStringList(userData['following']);
          _followingProducers = _parseStringList(userData['followingProducers']);
          _likedTags = _parseStringList(userData['liked_tags']);
          _posts = _parseStringList(userData['posts']);
          _choices = _parseStringList(userData['choices']);
          _likedPosts = _parseStringList(userData['liked_posts']);
          _interests = userData['interests'] ?? [];
          
          // Autres données
          _interactionMetrics = userData['interaction_metrics'] ?? {};
          _sectorPreferences = userData['sector_preferences'] ?? {};
          _consumptionBehavior = userData['consumption_behavior'] ?? {};
          _preferredContentFormat = userData['preferred_content_format'] ?? {};
          _onboardingCompleted = userData['onboarding_completed'] ?? false;
          
          // Stocker les données brutes
          _userData = userData;
        } else {
          print('❌ Erreur lors de la récupération des données: ${response.statusCode} - ${response.body}');
          print('⚠️ Erreur de connexion au backend - Vérifiez que le serveur est en marche');
          throw Exception('Erreur lors de la récupération des données utilisateur: ${response.statusCode}');
        }
      } else {
        print('❌ Erreur: Aucun token d\'authentification');
        throw Exception('Erreur: Vous devez être connecté pour accéder à ces données');
      }
      
      notifyListeners();
    } catch (e) {
      print('❌ Erreur lors de la récupération des données: $e');
      // Ne plus utiliser de données factices en cas d'erreur
      throw Exception('Erreur de connexion: $e');
    }
  }
  
  // Mise à jour des préférences
  Future<void> updatePreferences(Map<String, dynamic> newPreferences) async {
    // Simuler un délai réseau
    await Future.delayed(const Duration(milliseconds: 300));
    
    // Mettre à jour les préférences
    if (_userData != null && _userData!.containsKey('preferences')) {
      _userData!['preferences'] = {
        ..._userData!['preferences'] as Map<String, dynamic>,
        ...newPreferences,
      };
      
      notifyListeners();
    }
  }
  
  // Mise à jour du profil
  Future<bool> updateProfile({String? name, String? bio, String? photoUrl}) async {
    try {
      // Simuler un appel API
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (name != null) _name = name;
      if (bio != null) _bio = bio;
      if (photoUrl != null) _photoUrl = photoUrl;
      
      notifyListeners();
      return true;
    } catch (e) {
      print('Erreur lors de la mise à jour du profil: $e');
      return false;
    }
  }

  // Obtenir la couleur d'influence basée sur le score
  Color getInfluenceColor() {
    if (_influenceScore >= 80) return Colors.purple;
    if (_influenceScore >= 60) return Colors.teal;
    if (_influenceScore >= 40) return Colors.blue;
    if (_influenceScore >= 20) return Colors.amber;
    return Colors.grey;
  }

  /// Récupère les posts du feed de l'utilisateur
  Future<List<Map<String, dynamic>>> fetchFeedPosts({int page = 1, int limit = 10}) async {
    if (_id == null) {
      print('❌ Utilisateur non connecté lors de la tentative de récupération du feed');
      return [];
    }
    
    try {
      final url = Uri.parse('${constants.getBaseUrl()}/api/feed?userId=$_id&page=$page&limit=$limit');
      
      // Token si disponible
      final Map<String, String> headers = {'Content-Type': 'application/json'};
      if (_token != null) {
        headers['Authorization'] = 'Bearer $_token';
      }
      
      print('📱 Requête feed: $url');
      final response = await http.get(url, headers: headers);
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        
        // Extraire les posts selon la structure de la réponse
        List<dynamic> rawPosts;
        if (responseData is List) {
          // Si la réponse est directement une liste de posts
          rawPosts = responseData;
        } else if (responseData is Map && responseData.containsKey('posts')) {
          // Si la réponse est un objet avec une clé 'posts'
          rawPosts = responseData['posts'];
        } else {
          // Structure inconnue
          print('⚠️ Structure de réponse du feed inconnue');
          return [];
        }
        
        print('✅ Posts récupérés et traités: ${rawPosts.length}');
        
        // Convertir en List<Map<String, dynamic>> pour une utilisation cohérente
        return rawPosts
            .map((post) => post is Map<String, dynamic> 
                ? post 
                : {"id": post.toString()})
            .toList();
      } else {
        print('❌ Erreur lors de la récupération du feed: ${response.statusCode}');
        print('📄 Corps de la réponse: ${response.body}');
        return [];
      }
    } catch (e) {
      print('❌ Exception lors de la récupération du feed: $e');
      return [];
    }
  }
} 
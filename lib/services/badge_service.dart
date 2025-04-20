import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/badges/badge_model.dart';
import '../models/badges/badge_collection.dart';
import '../utils/constants.dart' as constants;
import 'analytics_service.dart';
import 'auth_service.dart';

// Ajouter l'énumération BadgeFilter
enum BadgeFilter {
  all,        // Tous les badges
  unlocked,   // Badges déverrouillés
  locked,     // Badges verrouillés
  completed,  // Badges complétés
  inProgress, // Badges en cours
}

/// Service pour gérer les badges des utilisateurs
class BadgeService extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final AnalyticsService _analyticsService = AnalyticsService();
  final BadgeCollection _badgeCollection = BadgeCollection();
  
  Map<String, dynamic> _userBadges = {};
  bool _isLoading = false;
  String? _error;
  bool _initialized = false;
  
  // Getters
  Map<String, dynamic> get userBadges => _userBadges;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get initialized => _initialized;
  BadgeCollection get badgeCollection => _badgeCollection;
  
  // Points accumulés par l'utilisateur
  int getTotalPoints() {
    int total = 0;
    for (var badge in _userBadges.values) {
      total += (badge['rewardPoints'] as num).toInt();
    }
    return total;
  }
  
  // Pourcentage de badges obtenus
  double get completionPercentage {
    final allBadges = _badgeCollection.getAllBadges();
    if (allBadges.isEmpty) return 0.0;
    
    final obtainedCount = _userBadges.length;
    return obtainedCount / allBadges.length;
  }
  
  /// Singleton pattern
  static final BadgeService _instance = BadgeService._internal();
  factory BadgeService() => _instance;
  BadgeService._internal();
  
  /// Initialiser le service de badges
  Future<void> initialize() async {
    if (_authService.userId == null) return;
    
    await loadUserBadges();
    
    // Vérifier les badges à débloquer à chaque démarrage
    checkForNewBadges();
    
    _initialized = true;
    notifyListeners();
  }
  
  /// Charger les badges de l'utilisateur depuis le serveur
  Future<void> loadUserBadges() async {
    if (_authService.userId == null) return;
    
    _setLoading(true);
    
    try {
      final userId = _authService.userId;
      final url = Uri.parse('${constants.getBaseUrl()}/api/users/$userId/badges');
      
      final response = await http.get(
        url,
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> badgesJson = json.decode(response.body)['badges'];
        
        // Convertir les données JSON en objets Badge
        _userBadges = {};
        
        for (final badgeJson in badgesJson) {
          final badge = AppBadge.fromJson(badgeJson);
          
          // Mettre à jour le badge dans la liste utilisateur
          _updateBadgeInList(badge);
        }
        
        // Sauvegarder les badges localement
        _saveBadgesToLocal();
        
        notifyListeners();
      } else {
        // En cas d'erreur, charger depuis le cache local
        await _loadBadgesFromLocal();
        
        _setError('Erreur lors du chargement des badges depuis le serveur. Utilisation du cache local.');
      }
    } catch (e) {
      // En cas d'erreur, essayer de charger depuis le cache local
      await _loadBadgesFromLocal();
      
      _setError('Erreur: $e. Utilisation du cache local.');
    } finally {
      _setLoading(false);
    }
  }
  
  /// Enregistrer l'action d'un utilisateur et vérifier s'il a obtenu un nouveau badge
  Future<List<AppBadge>> trackUserAction(String actionType, {Map<String, dynamic>? additionalData}) async {
    if (_authService.userId == null) return [];
    
    final obtainedBadges = <AppBadge>[];
    
    try {
      // Envoyer l'action au serveur
      final url = Uri.parse('${constants.getBaseUrl()}/api/users/${_authService.userId}/actions');
      
      final payload = {
        'actionType': actionType,
        'additionalData': additionalData ?? {},
        'timestamp': DateTime.now().toIso8601String(),
      };
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      );
      
      if (response.statusCode == 200) {
        final dynamic data = json.decode(response.body);
        
        // Vérifier si de nouveaux badges ont été débloqués
        if (data['newBadges'] != null && data['newBadges'] is List) {
          final List<dynamic> newBadgesJson = data['newBadges'];
          
          for (final badgeJson in newBadgesJson) {
            final badge = AppBadge.fromJson(badgeJson);
            
            // Ajouter ou mettre à jour le badge dans la liste utilisateur
            _updateBadgeInList(badge);
            
            obtainedBadges.add(badge);
          }
          
          if (obtainedBadges.isNotEmpty) {
            _saveBadgesToLocal();
            notifyListeners();
            
            // Enregistrer l'obtention dans les analytics
            for (final badge in obtainedBadges) {
              _analyticsService.logEvent(
                name: 'badge_unlocked',
                parameters: {
                  'badge_id': badge.id,
                  'badge_name': badge.name,
                  'badge_category': badge.category,
                },
              );
              _analyticsService.logEvent(
                name: 'badge_progress',
                parameters: {
                  'badge_id': badge.id,
                  'badge_name': badge.name,
                  'badge_category': badge.category,
                  'progress': badge.progress,
                },
              );
            }
          }
        }
      }
    } catch (e) {
      _setError('Erreur lors du suivi de l\'action: $e');
    }
    
    return obtainedBadges;
  }
  
  /// Vérifier si l'utilisateur peut obtenir de nouveaux badges
  Future<List<AppBadge>> checkForNewBadges() async {
    if (_authService.userId == null) return [];
    
    final obtainedBadges = <AppBadge>[];
    
    try {
      final url = Uri.parse('${constants.getBaseUrl()}/api/users/${_authService.userId}/badges/check');
      
      final response = await http.get(
        url,
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        final dynamic data = json.decode(response.body);
        
        // Vérifier si de nouveaux badges ont été débloqués
        if (data['newBadges'] != null && data['newBadges'] is List) {
          final List<dynamic> newBadgesJson = data['newBadges'];
          
          for (final badgeJson in newBadgesJson) {
            final badge = AppBadge.fromJson(badgeJson);
            
            // Ajouter ou mettre à jour le badge dans la liste utilisateur
            _updateBadgeInList(badge);
            
            obtainedBadges.add(badge);
          }
          
          if (obtainedBadges.isNotEmpty) {
            _saveBadgesToLocal();
            notifyListeners();
            
            // Enregistrer l'obtention dans les analytics
            for (final badge in obtainedBadges) {
              _analyticsService.logEvent(
                name: 'badge_unlocked',
                parameters: {
                  'badge_id': badge.id,
                  'badge_name': badge.name,
                  'badge_category': badge.category,
                },
              );
              _analyticsService.logEvent(
                name: 'badge_progress',
                parameters: {
                  'badge_id': badge.id,
                  'badge_name': badge.name,
                  'badge_category': badge.category,
                  'progress': badge.progress,
                },
              );
            }
          }
        }
      }
    } catch (e) {
      _setError('Erreur lors de la vérification des badges: $e');
    }
    
    return obtainedBadges;
  }
  
  /// Épingler ou désépingler un badge
  Future<bool> togglePinBadge(String badgeId) async {
    if (_authService.userId == null) return false;
    
    try {
      // Trouver le badge dans la liste
      if (!_userBadges.containsKey(badgeId)) return false;
      
      final badge = _userBadges[badgeId];
      final isPinned = !badge['isPinned']; // Inverser l'état
      
      // Mettre à jour le badge dans la liste locale
      _userBadges[badgeId] = {
        ...badge,
        'isPinned': isPinned,
      };
      
      // Mettre à jour sur le serveur
      final url = Uri.parse('${constants.getBaseUrl()}/api/users/${_authService.userId}/badges/$badgeId');
      
      final response = await http.patch(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'isPinned': isPinned}),
      );
      
      if (response.statusCode == 200) {
        _saveBadgesToLocal();
        notifyListeners();
        return true;
      } else {
        // Rétablir l'état précédent en cas d'échec
        _userBadges[badgeId] = badge;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _setError('Erreur lors de la mise à jour du badge: $e');
      return false;
    }
  }
  
  /// Obtenir les badges mis en avant par l'utilisateur
  List<AppBadge> getPinnedBadges() {
    return _userBadges.values
        .where((badge) => badge['isPinned'] == true)
        .map((badge) => AppBadge(
              id: badge['id'] ?? '',
              name: badge['name'] ?? '',
              description: badge['description'] ?? '',
              iconPath: badge['iconPath'] ?? '',
              rewardPoints: (badge['rewardPoints'] as num).toInt(),
              isLocked: badge['isLocked'] ?? true,
              isComplete: badge['isComplete'] ?? false,
            ))
        .toList();
  }
  
  /// Obtenir les derniers badges obtenus par l'utilisateur
  List<AppBadge> getRecentBadges({int limit = 5}) {
    final badges = _userBadges.values
        .where((badge) => badge['dateObtained'] != null)
        .map((badge) => AppBadge(
              id: badge['id'] ?? '',
              name: badge['name'] ?? '',
              description: badge['description'] ?? '',
              iconPath: badge['iconPath'] ?? '',
              rewardPoints: (badge['rewardPoints'] as num).toInt(),
              isLocked: badge['isLocked'] ?? true,
              isComplete: badge['isComplete'] ?? false,
              dateObtained: DateTime.parse(badge['dateObtained']),
            ))
        .toList();
    
    badges.sort((a, b) => b.dateObtained!.compareTo(a.dateObtained!));
    return badges.take(limit).toList();
  }
  
  /// Obtenir les badges regroupés par catégorie
  Map<String, List<AppBadge>> getBadgesByCategory() {
    final result = <String, List<AppBadge>>{};
    
    for (var badge in _userBadges.values) {
      final category = badge['category'] ?? '';
      if (!result.containsKey(category)) {
        result[category] = [];
      }
      result[category]!.add(AppBadge(
        id: badge['id'] ?? '',
        name: badge['name'] ?? '',
        description: badge['description'] ?? '',
        iconPath: badge['iconPath'] ?? '',
        rewardPoints: (badge['rewardPoints'] as num).toInt(),
        isLocked: badge['isLocked'] ?? true,
        isComplete: badge['isComplete'] ?? false,
      ));
    }
    
    return result;
  }
  
  /// Obtenir la prochaine liste de badges à débloquer
  List<AppBadge> getNextBadgesToUnlock({int limit = 5}) {
    final inProgressBadges = _userBadges.values
        .where((badge) => !badge['isComplete'] && badge['progress'] > 0 && !badge['isSecret'])
        .map((badge) => AppBadge(
              id: badge['id'] ?? '',
              name: badge['name'] ?? '',
              description: badge['description'] ?? '',
              iconPath: badge['iconPath'] ?? '',
              rewardPoints: (badge['rewardPoints'] as num).toInt(),
              isLocked: badge['isLocked'] ?? true,
              isComplete: badge['isComplete'] ?? false,
            ))
        .toList();
    
    inProgressBadges.sort((a, b) => b.progress.compareTo(a.progress));
    return inProgressBadges.take(limit).toList();
  }
  
  /// Obtenir les badges visibles pour l'utilisateur
  List<AppBadge> getVisibleBadges() {
    final visibleBadges = <AppBadge>[];
    
    for (var badgeId in _userBadges.keys) {
      final badgeData = _userBadges[badgeId];
      final appBadge = AppBadge(
        id: badgeId,
        name: badgeData['name'] ?? '',
        description: badgeData['description'] ?? '',
        iconPath: badgeData['iconPath'] ?? '',
        rewardPoints: (badgeData['rewardPoints'] as num).toInt(),
        isLocked: badgeData['isLocked'] ?? true,
        isComplete: badgeData['isComplete'] ?? false,
      );
      
      if (!appBadge.isSecret || badgeData['isComplete'] == true) {
        visibleBadges.add(appBadge);
      }
    }
    
    return visibleBadges;
  }
  
  // Méthodes privées
  
  /// Mettre à jour un badge dans la liste des badges de l'utilisateur
  void _updateBadgeInList(AppBadge badge) {
    _userBadges[badge.id] = {
      'id': badge.id,
      'name': badge.name,
      'description': badge.description,
      'iconPath': badge.iconPath,
      'rewardPoints': badge.rewardPoints,
      'isLocked': badge.isLocked,
      'isComplete': badge.isComplete,
      'dateObtained': badge.dateObtained?.toIso8601String(),
      'progress': badge.progress,
      'isPinned': badge.isPinned,
    };
  }
  
  /// Sauvegarder les badges dans les préférences locales
  Future<void> _saveBadgesToLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Convertir les badges en JSON
      final badgesJson = {};
      
      for (var badge in _userBadges.values) {
        badgesJson[badge['id']] = {
          'obtained': badge['obtained'],
          'dateObtained': badge['dateObtained'],
          'progress': badge['progress'],
          'isPinned': badge['isPinned'],
        };
      }
      
      // Sauvegarder sous forme de chaîne JSON
      await prefs.setString('user_badges', json.encode(badgesJson));
    } catch (e) {
      _setError('Erreur lors de la sauvegarde locale des badges: $e');
    }
  }
  
  /// Charger les badges depuis les préférences locales
  Future<void> _loadBadgesFromLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final badgesJsonString = prefs.getString('user_badges');
      
      if (badgesJsonString == null) return;
      
      final badgesJson = json.decode(badgesJsonString) as Map<String, dynamic>;
      
      // Récupérer tous les badges de la collection
      final allBadges = _badgeCollection.getAllBadges();
      
      // Mettre à jour l'état des badges selon les données locales
      _userBadges = {};
      
      for (var appBadge in allBadges) {
        final badgeData = badgesJson[appBadge.id] as Map<String, dynamic>?;
        
        // N'ajouter que les badges visibles ou déjà obtenus
        if (!appBadge.isSecret || (badgeData != null && badgeData['obtained'] == true)) {
          final updatedBadge = appBadge.copyWith(
            dateObtained: badgeData != null && badgeData['obtained'] == true
                ? DateTime.parse(badgeData['dateObtained'])
                : null,
            progress: badgeData != null ? badgeData['progress'] : 0,
            isPinned: badgeData != null ? badgeData['isPinned'] ?? false : false,
          );
          
          _userBadges[updatedBadge.id] = {
            'obtained': updatedBadge.isObtained,
            'dateObtained': updatedBadge.dateObtained?.toIso8601String(),
            'progress': updatedBadge.progress,
            'isPinned': updatedBadge.isPinned,
          };
        }
      }
      
      notifyListeners();
    } catch (e) {
      _setError('Erreur lors du chargement local des badges: $e');
    }
  }
  
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
  
  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }

  // Mise à jour d'un badge d'utilisateur
  Future<void> updateBadge(String badgeId, int newProgress, {bool notify = true}) async {
    if (_authService.userId == null) return;
    
    try {
      // Récupérer le badge (soit depuis la collection soit depuis les badges de l'utilisateur)
      AppBadge? appBadge;
      
      // Chercher d'abord dans les badges de l'utilisateur
      if (_userBadges.containsKey(badgeId)) {
        appBadge = _userBadges[badgeId];
      } else {
        // Sinon, chercher dans la collection de badges
        appBadge = _badgeCollection.getBadgeById(badgeId);
      }
      
      if (appBadge == null) return;
      
      // Mettre à jour le badge dans la liste locale
      _userBadges[badgeId] = {
        ...appBadge.toJson(),
        'progress': newProgress,
      };
      
      // Mettre à jour sur le serveur
      final url = Uri.parse('${constants.getBaseUrl()}/api/users/${_authService.userId}/badges/$badgeId');
      
      final response = await http.patch(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'progress': newProgress}),
      );
      
      if (response.statusCode == 200) {
        _saveBadgesToLocal();
        notifyListeners();
      } else {
        // Rétablir l'état précédent en cas d'échec
        _userBadges[badgeId] = appBadge.toJson();
        notifyListeners();
      }
    } catch (e) {
      _setError('Erreur lors de la mise à jour du badge: $e');
    }
  }

  /// Obtenir le total des points de récompense
  int getTotalRewardPoints() {
    int total = 0;
    for (var badge in _userBadges.values) {
      total += (badge['rewardPoints'] as num).toInt();
    }
    return total;
  }
  
  /// Obtenir la liste complète des badges disponibles
  List<AppBadge> getAllBadges() {
    return _userBadges.values
        .map((badge) => AppBadge(
              id: badge['id'] ?? '',
              name: badge['name'] ?? '',
              description: badge['description'] ?? '',
              iconPath: badge['iconPath'] ?? '',
              rewardPoints: (badge['rewardPoints'] as num).toInt(),
              isLocked: badge['isLocked'] ?? true,
              isComplete: badge['isComplete'] ?? false,
            ))
        .toList();
  }
  
  /// Obtenir les badges en cours
  List<AppBadge> getInProgressBadges({int limit = 5}) {
    return _userBadges.values
        .where((badge) => !badge['isLocked'] && !badge['isComplete'])
        .map((badge) => AppBadge(
              id: badge['id'] ?? '',
              name: badge['name'] ?? '',
              description: badge['description'] ?? '',
              iconPath: badge['iconPath'] ?? '',
              rewardPoints: (badge['rewardPoints'] as num).toInt(),
              isLocked: badge['isLocked'] ?? true,
              isComplete: badge['isComplete'] ?? false,
            ))
        .take(limit)
        .toList();
  }
  
  /// Obtenir un badge par son ID
  AppBadge getBadgeById(String badgeId) {
    final badge = _userBadges[badgeId];
    if (badge != null) {
      return AppBadge(
        id: badge['id'] ?? '',
        name: badge['name'] ?? '',
        description: badge['description'] ?? '',
        iconPath: badge['iconPath'] ?? '',
        rewardPoints: (badge['rewardPoints'] as num).toInt(),
        isLocked: badge['isLocked'] ?? true,
        isComplete: badge['isComplete'] ?? false,
      );
    }
    return const AppBadge(
      id: '',
      name: '',
      description: '',
      iconPath: '',
      rewardPoints: 0,
      isLocked: true,
      isComplete: false,
    );
  }

  List<AppBadge> _getFilteredBadges(BadgeFilter filter) {
    List<AppBadge> allBadges = getAllBadges();
    
    switch (filter) {
      case BadgeFilter.all:
        return allBadges;
      case BadgeFilter.unlocked:
        return allBadges.where((badge) => !badge.isLocked).toList();
      case BadgeFilter.locked:
        return allBadges.where((badge) => badge.isLocked).toList();
      case BadgeFilter.completed:
        return allBadges.where((badge) => badge.isComplete).toList();
      case BadgeFilter.inProgress:
        return getInProgressBadges(limit: 100);
      default:
        return allBadges;
    }
  }

  // Obtenir tous les badges de l'utilisateur
  List<AppBadge> getUserBadges() {
    return _userBadges.values
        .map((badge) => AppBadge(
              id: badge['id'] ?? '',
              name: badge['name'] ?? '',
              description: badge['description'] ?? '',
              iconPath: badge['iconPath'] ?? '',
              rewardPoints: (badge['rewardPoints'] as num).toInt(),
              isLocked: badge['isLocked'] ?? true,
              isComplete: badge['isComplete'] ?? false,
            ))
        .toList();
  }

  // Corriger la méthode getLockedBadges
  List<AppBadge> getLockedBadges() {
    return _userBadges.values
        .where((badge) => badge['isLocked'] ?? true)
        .map((badge) => AppBadge(
              id: badge['id'] ?? '',
              name: badge['name'] ?? '',
              description: badge['description'] ?? '',
              iconPath: badge['iconPath'] ?? '',
              rewardPoints: (badge['rewardPoints'] as num).toInt(),
              isLocked: badge['isLocked'] ?? true,
              isComplete: badge['isComplete'] ?? false,
            ))
        .toList();
  }

  // Corriger la méthode getCompletedBadges
  List<AppBadge> getCompletedBadges() {
    return _userBadges.values
        .where((badge) => badge['isComplete'] ?? false)
        .map((badge) => AppBadge(
              id: badge['id'] ?? '',
              name: badge['name'] ?? '',
              description: badge['description'] ?? '',
              iconPath: badge['iconPath'] ?? '',
              rewardPoints: (badge['rewardPoints'] as num).toInt(),
              isLocked: badge['isLocked'] ?? true,
              isComplete: badge['isComplete'] ?? false,
            ))
        .toList();
  }
} 
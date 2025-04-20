import 'package:flutter/material.dart';
import 'badge_model.dart';

/// Collection de badges disponibles dans l'application
class BadgeCollection {
  /// Singleton pattern
  static final BadgeCollection _instance = BadgeCollection._internal();
  
  factory BadgeCollection() => _instance;
  
  final Map<String, AppBadge> _badges = {};

  BadgeCollection._internal() {
    _initializeBadges();
  }

  void _initializeBadges() {
    // Badge d'exploration
    _badges['explorer'] = AppBadge(
      id: 'explorer',
      name: 'Explorateur',
      description: 'A découvert 10 nouveaux lieux',
      iconPath: 'assets/badges/explorer.png',
      rewardPoints: 100,
      isLocked: true,
      isComplete: false,
      level: 1,
      category: 'discovery',
      color: 0xFF4CAF50,
      requiredActions: 10,
    );

    // Badge social
    _badges['social_butterfly'] = AppBadge(
      id: 'social_butterfly',
      name: 'Papillon Social',
      description: 'A partagé 5 activités avec des amis',
      iconPath: 'assets/badges/social.png',
      rewardPoints: 150,
      isLocked: true,
      isComplete: false,
      level: 2,
      category: 'social',
      color: 0xFF2196F3,
      requiredActions: 5,
    );

    // Badge de fidélité
    _badges['loyal_customer'] = AppBadge(
      id: 'loyal_customer',
      name: 'Client Fidèle',
      description: 'A visité le même lieu 5 fois',
      iconPath: 'assets/badges/loyal.png',
      rewardPoints: 200,
      isLocked: true,
      isComplete: false,
      level: 3,
      category: 'engagement',
      color: 0xFF9C27B0,
      requiredActions: 5,
    );

    // Badge de challenge
    _badges['challenge_master'] = AppBadge(
      id: 'challenge_master',
      name: 'Maître des Challenges',
      description: 'A complété 3 challenges',
      iconPath: 'assets/badges/challenge.png',
      rewardPoints: 250,
      isLocked: true,
      isComplete: false,
      level: 4,
      category: 'challenge',
      color: 0xFFFF9800,
      requiredActions: 3,
    );

    // Badge spécial
    _badges['early_adopter'] = AppBadge(
      id: 'early_adopter',
      name: 'Early Adopter',
      description: 'Un des premiers utilisateurs de l\'application',
      iconPath: 'assets/badges/special.png',
      rewardPoints: 300,
      isLocked: true,
      isComplete: false,
      level: 5,
      category: 'special',
      color: 0xFFF44336,
      isRare: true,
      requiredActions: 1,
    );
  }

  /// Obtenir tous les badges disponibles
  List<AppBadge> getAllBadges() {
    return _badges.values.toList();
  }
  
  /// Obtenir un badge par son ID
  AppBadge? getBadgeById(String id) {
    return _badges[id];
  }
  
  /// Obtenir les badges d'une catégorie
  List<AppBadge> getBadgesByCategory(String category) {
    return _badges.values
        .where((badge) => badge.category == category)
        .toList();
  }
  
  /// Récupérer les badges par niveau
  List<AppBadge> getBadgesByLevel(int level) {
    return _badges.values
        .where((badge) => badge.level == level)
        .toList();
  }
  
  /// Récupérer uniquement les badges visibles (non secrets)
  List<AppBadge> getVisibleBadges() {
    return _badges.values.where((badge) => !badge.isSecret).toList();
  }
  
  /// Obtenir les badges rares
  List<AppBadge> getRareBadges() {
    return _badges.values.where((badge) => badge.isRare).toList();
  }
  
  /// Obtenir les badges secrets
  List<AppBadge> getSecretBadges() {
    return _badges.values.where((badge) => badge.isSecret).toList();
  }
  
  /// Calculer des points de récompense totaux pour une catégorie
  int calculateCategoryRewardPoints(String category, List<AppBadge> userBadges) {
    return userBadges
        .where((badge) => badge.category == category && badge.isObtained)
        .fold(0, (sum, badge) => sum + badge.rewardPoints);
  }
  
  /// Calculer des points de récompense totaux
  int calculateTotalRewardPoints(List<AppBadge> userBadges) {
    return userBadges.fold(0, (sum, badge) => sum + (badge.isObtained ? badge.rewardPoints : 0));
  }
} 
import 'package:flutter/material.dart';

/// Modèle représentant un badge dans l'application
class AppBadge {
  /// Identifiant unique du badge
  final String id;
  
  /// Nom court du badge
  final String name;
  
  /// Description détaillée du badge
  final String description;
  
  /// Niveau du badge (débutant, intermédiaire, expert, etc.)
  final int level;
  
  /// Catégorie du badge (exploration, social, fidélité, etc.)
  final String category;
  
  /// URL ou chemin d'accès à l'image du badge
  final String iconPath;
  
  /// Couleur principale du badge
  final int color;
  
  /// Date d'obtention du badge par l'utilisateur, null si non obtenu
  final DateTime? dateObtained;
  
  /// Progrès actuel vers l'obtention du badge (0.0 à 1.0)
  final double progress;
  
  /// Points de récompense associés à ce badge
  final int rewardPoints;
  
  /// Nombre d'actions requises pour obtenir le badge
  final int requiredActions;
  
  /// Est-ce que ce badge est considéré comme rare
  final bool isRare;
  
  /// Est-ce que ce badge est épinglé par l'utilisateur
  final bool isPinned;
  
  /// Est-ce que ce badge est secret (non visible avant d'être obtenu)
  final bool isSecret;
  
  /// Liste des récompenses spécifiques débloquées par ce badge
  final List<String> unlockedFeatures;
  
  /// Est-ce que ce badge est bloqué (non obtenu)
  final bool isLocked;
  
  /// Est-ce que ce badge est complet (obtenu)
  final bool isComplete;

  const AppBadge({
    required this.id,
    required this.name,
    required this.description,
    required this.iconPath,
    required this.rewardPoints,
    required this.isLocked,
    required this.isComplete,
    this.level = 1,
    this.category = '',
    this.color = 0xFF808080,
    this.dateObtained,
    this.progress = 0.0,
    this.isRare = false,
    this.isSecret = false,
    this.isPinned = false,
    this.unlockedFeatures = const [],
    this.requiredActions = 1,
  });

  /// Vérifie si le badge a été obtenu
  bool get isObtained => dateObtained != null;

  /// Chemin d'accès à l'icône en fonction de l'état du badge
  String get displayIconPath {
    if (isObtained) {
      return iconPath;
    } else if (isSecret) {
      return 'assets/badges/secret_badge.png';
    } else {
      return 'assets/badges/locked_badge.png';
    }
  }

  /// Crée une copie de ce badge avec des valeurs spécifiques modifiées
  AppBadge copyWith({
    String? id,
    String? name,
    String? description,
    String? iconPath,
    int? rewardPoints,
    bool? isLocked,
    bool? isComplete,
    int? level,
    String? category,
    int? color,
    DateTime? dateObtained,
    double? progress,
    bool? isRare,
    bool? isSecret,
    bool? isPinned,
    List<String>? unlockedFeatures,
    int? requiredActions,
  }) {
    return AppBadge(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      iconPath: iconPath ?? this.iconPath,
      rewardPoints: rewardPoints ?? this.rewardPoints,
      isLocked: isLocked ?? this.isLocked,
      isComplete: isComplete ?? this.isComplete,
      level: level ?? this.level,
      category: category ?? this.category,
      color: color ?? this.color,
      dateObtained: dateObtained ?? this.dateObtained,
      progress: progress ?? this.progress,
      isRare: isRare ?? this.isRare,
      isSecret: isSecret ?? this.isSecret,
      isPinned: isPinned ?? this.isPinned,
      unlockedFeatures: unlockedFeatures ?? this.unlockedFeatures,
      requiredActions: requiredActions ?? this.requiredActions,
    );
  }

  /// Crée un objet AppBadge à partir des données JSON
  factory AppBadge.fromJson(Map<String, dynamic> json) {
    return AppBadge(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      iconPath: json['iconPath'] ?? 'assets/badges/default_badge.png',
      rewardPoints: (json['rewardPoints'] as num?)?.toInt() ?? 0,
      isLocked: json['isLocked'] ?? true,
      isComplete: json['isComplete'] ?? false,
      level: json['level'] ?? 1,
      category: json['category'] ?? '',
      color: json['color'] ?? 0xFF808080,
      dateObtained: json['dateObtained'] != null 
          ? DateTime.parse(json['dateObtained']) 
          : null,
      progress: (json['progress'] ?? 0.0).toDouble(),
      isRare: json['isRare'] ?? false,
      isSecret: json['isSecret'] ?? false,
      isPinned: json['isPinned'] ?? false,
      unlockedFeatures: json['unlockedFeatures'] != null
          ? List<String>.from(json['unlockedFeatures'])
          : [],
      requiredActions: json['requiredActions'] ?? 1,
    );
  }

  /// Convertit le badge en format JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'iconPath': iconPath,
      'rewardPoints': rewardPoints,
      'isLocked': isLocked,
      'isComplete': isComplete,
      'level': level,
      'category': category,
      'color': color,
      'dateObtained': dateObtained?.toIso8601String(),
      'progress': progress,
      'isRare': isRare,
      'isSecret': isSecret,
      'isPinned': isPinned,
      'unlockedFeatures': unlockedFeatures,
      'requiredActions': requiredActions,
    };
  }

  /// Obtenir la couleur réelle à partir de la valeur entière
  Color getColor() {
    return Color(color);
  }
}

/// Enum pour les catégories de badges
enum BadgeCategory {
  engagement,
  discovery,
  social,
  challenge,
  special
}

/// Extension pour les propriétés des catégories de badges
extension BadgeCategoryExtension on BadgeCategory {
  String get name {
    switch (this) {
      case BadgeCategory.engagement: return 'engagement';
      case BadgeCategory.discovery: return 'discovery';
      case BadgeCategory.social: return 'social';
      case BadgeCategory.challenge: return 'challenge';
      case BadgeCategory.special: return 'special';
    }
  }
  
  String get displayName {
    switch (this) {
      case BadgeCategory.engagement: return 'Engagement';
      case BadgeCategory.discovery: return 'Découverte';
      case BadgeCategory.social: return 'Social';
      case BadgeCategory.challenge: return 'Challenge';
      case BadgeCategory.special: return 'Spécial';
    }
  }
  
  Color getColor() {
    switch (this) {
      case BadgeCategory.engagement: return Colors.blue;
      case BadgeCategory.discovery: return Colors.green;
      case BadgeCategory.social: return Colors.orange;
      case BadgeCategory.challenge: return Colors.purple;
      case BadgeCategory.special: return Colors.red;
    }
  }
} 
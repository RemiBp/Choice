// Constantes pour les différents types de feed
import 'package:flutter/material.dart';

/// Types de producteurs
enum ProducerType {
  restaurant,
  leisure,
}

/// Types de contenus pour un producteur restaurant
enum RestaurantContentType {
  dish,        // Plat
  promotion,   // Promotion ou offre
  event,       // Événement culinaire
  update,      // Mise à jour générale
  review,      // Avis client reposté
  menu,        // Changement de menu
}

/// Types de contenus pour un producteur loisir
enum LeisureContentType {
  event,       // Événement culturel
  exhibition,  // Exposition
  promotion,   // Promotion ou offre
  update,      // Mise à jour générale
  review,      // Avis client reposté
  activity,    // Activité
}

/// Types d'interactions utilisateurs
enum UserInteractionType {
  like,
  comment,
  interested,
  choice,
  share,
  save,
  view,
}

/// Constantes pour la génération de feed
class FeedConstants {
  // Priorités pour l'algorithme de tri (valeurs plus élevées = priorité plus élevée)
  static const Map<String, double> contentWeights = {
    'post': 1.0,
    'event': 1.5,
    'dish': 1.3,
    'promotion': 1.4,
    'review': 1.2,
    'exhibition': 1.5,
    'activity': 1.3,
  };
  
  // Facteurs d'engagement (combien un engagement augmente le score d'un post)
  static const Map<UserInteractionType, double> engagementMultipliers = {
    UserInteractionType.like: 1.0,
    UserInteractionType.comment: 2.0,
    UserInteractionType.interested: 1.5,
    UserInteractionType.choice: 3.0,
    UserInteractionType.share: 2.5,
    UserInteractionType.save: 1.8,
    UserInteractionType.view: 0.3,
  };
  
  // Décroissance temporelle des posts (en heures)
  static const double baseHalfLifeHours = 48.0;  // Score divisé par 2 après 48 heures
  
  // Limite de résultats par page
  static const int defaultPageSize = 10;
  
  // Score minimum pour apparaître dans les tendances
  static const double trendingScoreThreshold = 10.0;
  
  // Couleurs par défaut pour les différents types de producteurs
  static const Color restaurantPrimaryColor = Colors.orange;
  static const Color leisurePrimaryColor = Colors.deepPurple;
  
  // Templates de messages IA pour différents contextes
  static const Map<String, List<String>> aiMessageTemplates = {
    'newVisitors': [
      'Votre établissement a attiré {count} nouveaux visiteurs cette semaine !',
      'Découvrez le profil de vos {count} nouveaux visiteurs.',
    ],
    'feedback': [
      'Nouvelles réactions à votre dernier post : {count} likes et {commentCount} commentaires !',
      'Votre post sur {subject} génère beaucoup d\'engagement !',
    ],
    'trends': [
      'Tendance : Les utilisateurs recherchent "{trend}" en ce moment',
      'Les {trend} sont populaires dans votre région actuellement',
    ],
    'tip': [
      'Astuce : Publiez des photos de {suggestion} pour augmenter votre visibilité',
      'Conseil : Les posts publiés le {day} ont 30% plus de vues !',
    ],
  };
  
  // Génère un facteur de fraîcheur temporelle
  static double calculateTimeFactor(DateTime postTime) {
    final now = DateTime.now();
    final difference = now.difference(postTime);
    final hoursSincePosted = difference.inHours;
    
    // Formule: 2^(-hours/halfLife)
    // Cela donne une courbe de décroissance exponentielle
    return pow(2, -hoursSincePosted / baseHalfLifeHours) as double;
  }
  
  // Calcule le score d'un post pour l'algorithme de tri
  static double calculatePostScore(Map<String, dynamic> post) {
    // Score de base par type de contenu
    final String postType = post['type'] ?? 'post';
    double score = contentWeights[postType] ?? 1.0;
    
    // Ajouter les facteurs d'engagement
    final int likesCount = post['likes_count'] ?? post['likesCount'] ?? 0;
    final int commentsCount = post['comments']?.length ?? 0;
    final int interestedCount = post['interested_count'] ?? post['interestedCount'] ?? 0;
    final int choicesCount = post['choice_count'] ?? post['choiceCount'] ?? 0;
    final int viewsCount = post['views_count'] ?? post['viewsCount'] ?? 0;
    
    score += likesCount * engagementMultipliers[UserInteractionType.like]!;
    score += commentsCount * engagementMultipliers[UserInteractionType.comment]!;
    score += interestedCount * engagementMultipliers[UserInteractionType.interested]!;
    score += choicesCount * engagementMultipliers[UserInteractionType.choice]!;
    score += viewsCount * engagementMultipliers[UserInteractionType.view]!;
    
    // Facteur temporel
    final String timestampStr = post['posted_at'] ?? post['time_posted'] ?? post['createdAt'] ?? DateTime.now().toIso8601String();
    final DateTime timestamp = DateTime.parse(timestampStr);
    
    score *= calculateTimeFactor(timestamp);
    
    // Modificateurs spéciaux
    if (post['is_trending'] == true) {
      score *= 1.5; // Boost pour les posts tendance
    }
    
    if (post['is_pinned'] == true) {
      score += 100; // Les posts épinglés devraient toujours apparaître en premier
    }
    
    return score;
  }
  
  // Trier les posts par score
  static List<Map<String, dynamic>> sortPostsByScore(List<Map<String, dynamic>> posts) {
    // Calculer les scores pour chaque post
    final Map<String, double> postScores = {};
    for (final post in posts) {
      final String postId = post['_id'] ?? post['id'] ?? '';
      postScores[postId] = calculatePostScore(post);
    }
    
    // Trier par score
    posts.sort((a, b) {
      final String aId = a['_id'] ?? a['id'] ?? '';
      final String bId = b['_id'] ?? b['id'] ?? '';
      
      final double aScore = postScores[aId] ?? 0;
      final double bScore = postScores[bId] ?? 0;
      
      return bScore.compareTo(aScore); // Ordre décroissant
    });
    
    return posts;
  }
}

// Helper pour calculer l'exposant en double
double pow(num x, num exponent) {
  return x.toDouble() * exponent.toDouble();
} 
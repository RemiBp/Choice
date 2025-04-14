import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/constants.dart' as constants;

class GrowthAnalyticsService {
  static final GrowthAnalyticsService _instance = GrowthAnalyticsService._internal();
  factory GrowthAnalyticsService() => _instance;
  GrowthAnalyticsService._internal();

  String getBaseUrl() {
    return constants.getBaseUrlSync();
  }

  /// Récupère un aperçu global des statistiques de croissance
  Future<Map<String, dynamic>> getOverview(String producerId, {String period = '30'}) async {
    try {
      final url = Uri.parse('${getBaseUrl()}/api/growth-analytics/$producerId/overview?period=$period');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        print('❌ Erreur API: ${response.statusCode}');
        throw Exception('Erreur lors de la récupération des statistiques (${response.statusCode})');
      }
    } catch (e) {
      print('❌ Exception: $e');
      // En cas d'erreur, renvoyer des données mockées pour démonstration
      return _getMockOverview(producerId, period);
    }
  }

  /// Récupère les tendances temporelles des performances
  Future<Map<String, dynamic>> getTrends(String producerId, {String period = '90'}) async {
    try {
      final url = Uri.parse('${getBaseUrl()}/api/growth-analytics/$producerId/trends?period=$period');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        print('❌ Erreur API: ${response.statusCode}');
        throw Exception('Erreur lors de la récupération des tendances (${response.statusCode})');
      }
    } catch (e) {
      print('❌ Exception: $e');
      // En cas d'erreur, renvoyer des données mockées pour démonstration
      return _getMockTrends(period);
    }
  }

  /// Récupère les recommandations stratégiques
  Future<Map<String, dynamic>> getRecommendations(String producerId) async {
    try {
      final url = Uri.parse('${getBaseUrl()}/api/growth-analytics/$producerId/recommendations');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        print('❌ Erreur API: ${response.statusCode}');
        throw Exception('Erreur lors de la récupération des recommandations (${response.statusCode})');
      }
    } catch (e) {
      print('❌ Exception: $e');
      // En cas d'erreur, renvoyer des données mockées pour démonstration
      return _getMockRecommendations();
    }
  }

  /// Données mockées pour l'aperçu global
  Map<String, dynamic> _getMockOverview(String producerId, String period) {
    bool isRestaurant = !producerId.contains('leisure');
    
    return {
      "producer": {
        "id": producerId,
        "name": isRestaurant ? "Restaurant Le Gourmet" : "Galerie d'Art Moderne",
        "type": isRestaurant ? "restaurant" : "leisure",
        "category": isRestaurant ? ["Bistro", "Français", "Gastronomique"] : ["Art", "Galerie", "Exposition"],
        "photo": "https://picsum.photos/id/445/200/200"
      },
      "period": int.parse(period),
      "engagement": {
        "posts": 18,
        "likes": 342,
        "comments": 87,
        "shares": 26,
        "average_per_post": 25.3
      },
      "followers": {
        "total": 125,
        "new": 12,
        "growth_rate": 10.7
      },
      "reach": {
        "mentions": 8,
        "interested_users": 64,
        "choice_users": 37,
        "conversion_rate": 29.6
      },
      "demographics": {
        "age": {
          "18-24": 15.2,
          "25-34": 42.7,
          "35-44": 25.1,
          "45-54": 12.3,
          "55+": 4.7
        },
        "gender": {
          "Homme": 48.3,
          "Femme": 51.7
        },
        "location": {
          "Paris": 45.2,
          "Boulogne-Billancourt": 12.5,
          "Neuilly-sur-Seine": 8.9,
          "Versailles": 6.4,
          "Saint-Denis": 4.2
        }
      },
      "competitors": [
        {
          "id": "comp_1",
          "name": isRestaurant ? "Bistro Parisien" : "Musée du Louvre",
          "photo": "https://picsum.photos/id/429/200/200",
          "rating": 4.5,
          "followers": 248,
          "recent_posts": 22
        },
        {
          "id": "comp_2",
          "name": isRestaurant ? "La Bonne Table" : "Théâtre du Châtelet",
          "photo": "https://picsum.photos/id/431/200/200",
          "rating": 4.2,
          "followers": 186,
          "recent_posts": 14
        }
      ]
    };
  }

  /// Données mockées pour les tendances
  Map<String, dynamic> _getMockTrends(String period) {
    final now = DateTime.now();
    final intervalType = int.parse(period) <= 30 ? 'day' : (int.parse(period) <= 90 ? 'week' : 'month');
    
    final List<Map<String, dynamic>> timeSeries = [];
    
    // Générer des données de série temporelle
    for (int i = int.parse(period); i >= 0; i--) {
      final date = DateTime(now.year, now.month, now.day - i);
      
      String dateStr;
      if (intervalType == 'day') {
        dateStr = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
      } else if (intervalType == 'week') {
        // Calculer le lundi de la semaine
        final dayOfWeek = date.weekday;
        final daysToSubtract = dayOfWeek - 1;
        final monday = DateTime(date.year, date.month, date.day - daysToSubtract);
        dateStr = "${monday.year}-${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}";
      } else {
        dateStr = "${date.year}-${date.month.toString().padLeft(2, '0')}";
      }
      
      // Ajouter seulement la date si elle n'existe pas déjà
      if (!timeSeries.any((item) => item['date'] == dateStr)) {
        timeSeries.add({
          "date": dateStr,
          "posts": (i % 7 == 0) ? 2 : (i % 3 == 0 ? 1 : 0),
          "likes": 10 + (i % 5) * 8,
          "comments": 3 + (i % 4) * 2,
          "shares": 1 + (i % 6)
        });
      }
    }
    
    return {
      "engagement": timeSeries,
      "top_posts": [
        {
          "id": "post_1",
          "content": "Nouvelle spécialité du chef à découvrir ce weekend !",
          "posted_at": DateTime.now().subtract(Duration(days: 3)).toIso8601String(),
          "media": "https://picsum.photos/id/488/600/400",
          "engagement": {
            "likes": 56,
            "comments": 12,
            "shares": 7
          },
          "score": 94
        },
        {
          "id": "post_2",
          "content": "Merci à tous nos clients pour cette soirée exceptionnelle !",
          "posted_at": DateTime.now().subtract(Duration(days: 10)).toIso8601String(),
          "media": "https://picsum.photos/id/493/600/400",
          "engagement": {
            "likes": 48,
            "comments": 8,
            "shares": 5
          },
          "score": 74
        }
      ],
      "peak_times": [
        {
          "hour": 18,
          "posts": 5,
          "average_engagement": 32.6
        },
        {
          "hour": 12,
          "posts": 4,
          "average_engagement": 28.2
        },
        {
          "hour": 20,
          "posts": 3,
          "average_engagement": 26.8
        }
      ],
      "weekly_distribution": [
        {
          "day": "Lundi",
          "posts": 2,
          "average_engagement": 24.5
        },
        {
          "day": "Mardi",
          "posts": 1,
          "average_engagement": 18.0
        },
        {
          "day": "Mercredi",
          "posts": 3,
          "average_engagement": 26.3
        },
        {
          "day": "Jeudi",
          "posts": 2,
          "average_engagement": 22.0
        },
        {
          "day": "Vendredi",
          "posts": 4,
          "average_engagement": 32.5
        },
        {
          "day": "Samedi",
          "posts": 5,
          "average_engagement": 36.8
        },
        {
          "day": "Dimanche",
          "posts": 1,
          "average_engagement": 28.0
        }
      ]
    };
  }

  /// Données mockées pour les recommandations
  Map<String, dynamic> _getMockRecommendations() {
    return {
      "content_strategy": [
        {
          "title": "Augmentez votre fréquence de publication",
          "description": "Publiez au moins une fois par semaine pour maintenir l'engagement de votre audience.",
          "action": "Planifiez 4 publications par mois minimum"
        },
        {
          "title": "Diversifiez vos formats de contenu",
          "description": "Les vidéos génèrent en moyenne 38% plus d'engagement que les images.",
          "action": "Ajoutez des vidéos courtes à votre stratégie de contenu"
        }
      ],
      "engagement_tactics": [
        {
          "title": "Mettez en valeur vos plats signature",
          "description": "Les publications présentant des plats signature reçoivent 67% plus de likes.",
          "action": "Partagez des photos et histoires de vos plats les plus populaires"
        },
        {
          "title": "Interagissez avec vos commentaires",
          "description": "Répondre aux commentaires augmente le taux d'engagement de 17%.",
          "action": "Répondez aux commentaires dans les 24 heures"
        }
      ],
      "growth_opportunities": [
        {
          "title": "Interactions avec la communauté locale",
          "description": "Engagez-vous avec les posts mentionnant votre quartier pour augmenter votre visibilité.",
          "action": "Commentez et aimez 5 publications locales par semaine"
        },
        {
          "title": "Programme d'ambassadeurs",
          "description": "Les clients fidèles peuvent vous aider à atteindre un nouveau public.",
          "action": "Identifiez vos 10 followers les plus engagés et proposez-leur des avantages exclusifs"
        }
      ]
    };
  }
} 
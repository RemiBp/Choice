import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/api_constants.dart' as constants;
import '../screens/subscription_screen.dart';
import '../screens/subscription_level_info_screen.dart';
import './auth_service.dart'; // Import AuthService to get token

/// Service qui gère l'accès aux fonctionnalités premium basées sur le niveau d'abonnement
class PremiumFeatureService {
  // Durée du cache pour les permissions (10 minutes)
  static const Duration _cacheDuration = Duration(minutes: 10);
  
  // Cache des permissions
  final Map<String, Map<String, dynamic>> _permissionsCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  
  /// Récupère les informations d'abonnement d'un producteur
  Future<Map<String, dynamic>> getSubscriptionInfo(String producerId) async {
    try {
      final token = await AuthService.getToken(); // Get token
      final response = await http.get(
        Uri.parse('${constants.getBaseUrl()}/api/subscription/producer/$producerId/subscription'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token', // Add token header
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else {
        throw Exception('Erreur lors de la récupération des informations d\'abonnement');
      }
    } catch (e) {
      print('❌ Erreur lors de la récupération des informations d\'abonnement: $e');
      // Retourner un niveau gratuit par défaut en cas d'erreur
      return {
        'subscription': {
          'level': 'gratuit',
          'active': true,
        }
      };
    }
  }
  
  /// Vérifie si un producteur a accès à une fonctionnalité spécifique
  Future<bool> canAccessFeature(String producerId, String featureId) async {
    // Vérifier d'abord dans le cache
    if (_hasValidCache(producerId, featureId)) {
      return _getFromCache(producerId, featureId);
    }
    
    try {
      final token = await AuthService.getToken(); // Get token
      // Appel à l'API pour vérifier l'accès
      final url = Uri.parse('${constants.getBaseUrl()}/api/subscription/check-feature-access?producerId=$producerId&featureId=$featureId'); // Pass params in query
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token', // Add token header
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final bool hasAccess = data['hasAccess'] ?? false;
        
        // Stocker dans le cache
        _updateCache(producerId, featureId, hasAccess);
        
        return hasAccess;
      } else if (response.statusCode == 403) {
        // 403 = Accès refusé, pas d'abonnement approprié
        _updateCache(producerId, featureId, false);
        return false;
      } else {
        throw Exception('Erreur lors de la vérification de l\'accès à la fonctionnalité');
      }
    } catch (e) {
      print('❌ Erreur lors de la vérification de l\'accès à la fonctionnalité: $e');
      
      // En cas d'erreur réseau, vérifier le niveau d'abonnement localement
      // et faire une vérification basique
      try {
        final subscriptionInfo = await getSubscriptionInfo(producerId);
        final String level = subscriptionInfo['subscription']?['level'] ?? 'gratuit';
        
        // Mapping simple des fonctionnalités vers les niveaux minimums requis
        final featureLevelMap = {
          'advanced_analytics': 'starter',
          'audience_demographics': 'pro',
          'growth_predictions': 'pro',
          'simple_campaigns': 'pro',
          'advanced_targeting': 'legend',
          'campaign_automation': 'legend',
        };
        
        // Ordre des niveaux pour les comparaisons
        final levelOrder = ['gratuit', 'starter', 'pro', 'legend'];
        
        // Niveau minimum requis pour la fonctionnalité
        final requiredLevel = featureLevelMap[featureId] ?? 'gratuit';
        
        // Comparer les niveaux
        final currentLevelIndex = levelOrder.indexOf(level);
        final requiredLevelIndex = levelOrder.indexOf(requiredLevel);
        
        final hasAccess = currentLevelIndex >= requiredLevelIndex;
        
        // Mettre en cache
        _updateCache(producerId, featureId, hasAccess);
        
        return hasAccess;
      } catch (e) {
        print('❌ Erreur lors de la vérification locale du niveau d\'abonnement: $e');
        return false;
      }
    }
  }
  
  /// Affiche un dialogue pour inviter l'utilisateur à améliorer son abonnement
  /// Retourne true si l'utilisateur choisit de mettre à niveau
  Future<bool> showUpgradeDialog(
    BuildContext context, 
    String producerId, 
    String featureId
  ) async {
    // Déterminer le niveau requis pour cette fonctionnalité
    final requiredLevel = await _getRequiredLevelForFeature(featureId);
    
    // Obtenir l'abonnement actuel
    final subscriptionInfo = await getSubscriptionInfo(producerId);
    final currentLevel = subscriptionInfo['subscription']?['level'] ?? 'gratuit';
    
    // Si l'utilisateur a déjà le niveau requis, retourner true directement
    if (await canAccessFeature(producerId, featureId)) {
      return true;
    }
    
    // Afficher le dialogue de mise à niveau
    final shouldUpgrade = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Fonctionnalité Premium'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cette fonctionnalité nécessite un abonnement ${_getRequiredLevelName(requiredLevel)}.',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 12),
            Text(
              'Voulez-vous améliorer votre abonnement pour y accéder ?',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Plus tard'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Voir les offres'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _getLevelColor(requiredLevel),
            ),
          ),
        ],
      ),
    ) ?? false;
    
    // Si l'utilisateur veut mettre à niveau, ouvrir l'écran d'abonnement
    if (shouldUpgrade) {
      // Option 1: Afficher l'écran des détails du niveau requis
      final navigationResult = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SubscriptionLevelInfoScreen(
            producerId: producerId,
            level: requiredLevel,
          ),
        ),
      );
      
      // Après le retour, vérifier si l'utilisateur a maintenant accès
      // (en invalidant le cache pour forcer une nouvelle vérification)
      _invalidateCache(producerId, featureId);
      return await canAccessFeature(producerId, featureId);
    }
    
    return false;
  }
  
  /// Récupère la liste des fonctionnalités pour un niveau d'abonnement
  Future<List<Map<String, dynamic>>> getFeaturesForLevel(String level) async {
    try {
      final token = await AuthService.getToken(); // Get token
      final response = await http.get(
        Uri.parse('${constants.getBaseUrl()}/api/subscription/features/$level'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token', // Add token header
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> features = data['features'] ?? [];
        return features.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Erreur lors de la récupération des fonctionnalités');
      }
    } catch (e) {
      print('❌ Erreur lors de la récupération des fonctionnalités: $e');
      return [];
    }
  }
  
  /// Récupère tous les niveaux d'abonnement disponibles
  Future<List<Map<String, dynamic>>> getSubscriptionLevels() async {
    try {
      final token = await AuthService.getToken(); // Get token
      final response = await http.get(
        Uri.parse('${constants.getBaseUrl()}/api/subscription/levels'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token', // Add token header
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> levels = data['levels'] ?? [];
        return levels.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Erreur lors de la récupération des niveaux d\'abonnement');
      }
    } catch (e) {
      print('❌ Erreur lors de la récupération des niveaux d\'abonnement: $e');
      // Retourner des niveaux par défaut en cas d'erreur
      return [
        {
          'id': 'gratuit',
          'name': 'Gratuit',
          'description': 'Fonctionnalités de base pour démarrer',
          'price': {'monthly': 0, 'yearly': 0},
          'features': [],
        },
        {
          'id': 'starter',
          'name': 'Starter',
          'description': 'Pour les professionnels qui débutent',
          'price': {'monthly': 9.99, 'yearly': 99.99},
          'features': [],
        },
        {
          'id': 'pro',
          'name': 'Pro',
          'description': 'Pour les professionnels exigeants',
          'price': {'monthly': 19.99, 'yearly': 199.99},
          'features': [],
        },
        {
          'id': 'legend',
          'name': 'Legend',
          'description': 'Pour les leaders du marché',
          'price': {'monthly': 49.99, 'yearly': 499.99},
          'features': [],
        },
      ];
    }
  }
  
  /// Obtenir l'historique des abonnements d'un producteur
  Future<List<Map<String, dynamic>>> getSubscriptionHistory(String producerId) async {
    try {
      final token = await AuthService.getToken(); // Get token
      final response = await http.get(
        Uri.parse('${constants.getBaseUrl()}/api/subscription/producer/$producerId/history'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token', // Add token header
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> history = data['history'] ?? [];
        return history.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Erreur lors de la récupération de l\'historique des abonnements');
      }
    } catch (e) {
      print('❌ Erreur lors de la récupération de l\'historique des abonnements: $e');
      return [];
    }
  }
  
  /// Vérifie si une entrée de cache est valide (existe et n'a pas expiré)
  bool _hasValidCache(String producerId, String featureId) {
    final cacheKey = '$producerId:$featureId';
    
    if (!_cacheTimestamps.containsKey(cacheKey)) {
      return false;
    }
    
    final timestamp = _cacheTimestamps[cacheKey]!;
    final now = DateTime.now();
    
    return now.difference(timestamp) < _cacheDuration;
  }
  
  /// Récupère une valeur depuis le cache
  bool _getFromCache(String producerId, String featureId) {
    final cacheKey = '$producerId:$featureId';
    
    if (!_permissionsCache.containsKey(producerId)) {
      return false;
    }
    
    return _permissionsCache[producerId]?[featureId] ?? false;
  }
  
  /// Met à jour le cache avec une nouvelle valeur
  void _updateCache(String producerId, String featureId, bool hasAccess) {
    final cacheKey = '$producerId:$featureId';
    
    // Initialiser l'entrée pour ce producteur si elle n'existe pas
    _permissionsCache[producerId] ??= {};
    
    // Mettre à jour les permissions
    _permissionsCache[producerId]![featureId] = hasAccess;
    
    // Mettre à jour le timestamp
    _cacheTimestamps[cacheKey] = DateTime.now();
  }
  
  /// Invalide une entrée de cache
  void _invalidateCache(String producerId, String featureId) {
    final cacheKey = '$producerId:$featureId';
    
    if (_permissionsCache.containsKey(producerId)) {
      _permissionsCache[producerId]?.remove(featureId);
    }
    
    _cacheTimestamps.remove(cacheKey);
  }
  
  /// Détermine le niveau requis pour une fonctionnalité
  Future<String> _getRequiredLevelForFeature(String featureId) async {
    // Mapping simple des fonctionnalités vers les niveaux minimums requis
    final featureLevelMap = {
      'advanced_analytics': 'starter',
      'audience_demographics': 'pro',
      'growth_predictions': 'pro',
      'simple_campaigns': 'pro',
      'advanced_targeting': 'legend',
      'campaign_automation': 'legend',
    };
    
    return featureLevelMap[featureId] ?? 'gratuit';
  }
  
  /// Obtient le nom formaté d'un niveau d'abonnement
  String _getRequiredLevelName(String level) {
    switch (level) {
      case 'starter': return 'Starter';
      case 'pro': return 'Pro';
      case 'legend': return 'Legend';
      default: return 'Premium';
    }
  }
  
  /// Obtient la couleur associée à un niveau d'abonnement
  Color _getLevelColor(String level) {
    switch (level) {
      case 'starter': return Colors.blue;
      case 'pro': return Colors.indigo;
      case 'legend': return Colors.amber.shade800;
      default: return Colors.grey;
    }
  }
  
  /// Sauvegarde les informations d'abonnement dans les préférences locales
  /// Utile pour un accès rapide sans appel réseau
  Future<void> saveSubscriptionInfoLocally(
    String producerId, 
    Map<String, dynamic> subscriptionInfo
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'subscription_$producerId';
      final String jsonData = json.encode(subscriptionInfo);
      
      await prefs.setString(key, jsonData);
    } catch (e) {
      print('❌ Erreur lors de la sauvegarde locale des informations d\'abonnement: $e');
    }
  }
  
  /// Récupère les informations d'abonnement depuis les préférences locales
  Future<Map<String, dynamic>?> getLocalSubscriptionInfo(String producerId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'subscription_$producerId';
      
      final String? jsonData = prefs.getString(key);
      if (jsonData == null) return null;
      
      return json.decode(jsonData) as Map<String, dynamic>;
    } catch (e) {
      print('❌ Erreur lors de la récupération locale des informations d\'abonnement: $e');
      return null;
    }
  }
}

/// Widget qui crée un teaser pour une fonctionnalité premium
/// à utiliser comme constructeur d'interfaces modulaire
class PremiumFeatureTeaser extends StatelessWidget {
  final String title;
  final String description;
  final String featureId;
  final Widget child;
  final String producerId;
  final Color? color;
  final IconData icon;
  
  const PremiumFeatureTeaser({
    Key? key,
    required this.title,
    required this.description,
    required this.featureId,
    required this.child,
    required this.producerId,
    this.color,
    this.icon = Icons.workspace_premium,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    final service = PremiumFeatureService();
    
    return FutureBuilder<String>(
      future: service._getRequiredLevelForFeature(featureId),
      builder: (context, snapshot) {
        final requiredLevel = snapshot.data ?? 'pro';
        final levelColor = color ?? service._getLevelColor(requiredLevel);
        
        return Stack(
          children: [
            ClipRect(
              child: ColorFiltered(
                colorFilter: ColorFilter.mode(
                  Colors.grey.withOpacity(0.5),
                  BlendMode.saturation,
                ),
                child: child,
              ),
            ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: levelColor.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          icon,
                          color: levelColor,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Text(
                          description,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () => service.showUpgradeDialog(
                          context, 
                          producerId, 
                          featureId
                        ),
                        icon: Icon(Icons.lock_open),
                        label: Text('Débloquer'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: levelColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
} 
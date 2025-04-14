import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import 'package:provider/provider.dart';
import 'utils.dart';
import '../models/growth_analytics_models.dart';
import '../models/producer_type.dart';
import '../services/growth_analytics_service.dart';
import '../services/producer_type_service.dart';
import '../services/auth_service.dart';
import '../widgets/loading_indicator.dart';
import '../widgets/error_message.dart';
import '../widgets/trend_chart.dart';
import '../services/marketing_campaign_service.dart';
import '../services/premium_feature_service.dart';
import '../screens/subscription_screen.dart';
import '../utils/constants.dart' as constants;

class GrowthAndReachScreen extends StatefulWidget {
  final String producerId;
  final ProducerType? producerType;
  
  const GrowthAndReachScreen({
    Key? key,
    required this.producerId,
    this.producerType,
  }) : super(key: key);

  @override
  _GrowthAndReachScreenState createState() => _GrowthAndReachScreenState();
}

class _GrowthAndReachScreenState extends State<GrowthAndReachScreen> with SingleTickerProviderStateMixin {
  final GrowthAnalyticsService _analyticsService = GrowthAnalyticsService();
  final ProducerTypeService _producerTypeService = ProducerTypeService();
  final PremiumFeatureService _premiumFeatureService = PremiumFeatureService();
  late TabController _tabController;
  
  GrowthOverview? _overview;
  GrowthTrends? _trends;
  GrowthRecommendations? _recommendations;
  
  bool _isLoading = true;
  String? _error;
  String _selectedPeriod = '30'; // 30 jours par défaut
  String _currentSubscriptionLevel = 'gratuit';
  bool _checkingPremiumAccess = true;
  
  // Variables pour l'affichage du profil connecté
  String _userName = '';
  String _userPhoto = '';
  String _producerName = '';
  Map<String, dynamic>? _userProfile;
  Map<String, dynamic>? _producerData;
  late ProducerType _producerType;
  
  // Variables pour les campagnes
  bool _showCampaignCreator = false;
  String _selectedCampaignType = 'Visibilité locale';
  final List<String> _campaignTypes = [
    'Visibilité locale',
    'Boost national',
    'Promotion spéciale',
    'Événement à venir',
  ];
  final Map<String, double> _campaignPrices = {
    'Visibilité locale': 29.99,
    'Boost national': 59.99,
    'Promotion spéciale': 39.99,
    'Événement à venir': 49.99,
  };
  
  // Nouvelles variables pour le ciblage des campagnes
  final List<String> _selectedAudiences = [];
  List<Map<String, dynamic>> _availableAudiences = [];
  double _campaignBudget = 0;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isCreatingCampaign = false;
  final MarketingCampaignService _campaignService = MarketingCampaignService();
  
  // Liste des campagnes marketing
  List<Map<String, dynamic>> _campaigns = [];
  bool _loadingCampaigns = false;
  
  // Accès aux fonctionnalités premium
  Map<String, bool> _premiumFeaturesAccess = {
    'advanced_analytics': false,
    'growth_predictions': false,
    'audience_demographics': false,
    'simple_campaigns': false,
    'advanced_targeting': false,
    'campaign_automation': false,
  };
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _producerType = widget.producerType ?? ProducerType.restaurant;
    _loadSubscriptionLevel();
    _loadInitialData();
    _loadUserProfile();
    _loadProducerDetails();
    _loadAudiences();
    _loadCampaigns(); // Charger les campagnes
    _checkPremiumFeatureAccess();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  // Charger le niveau d'abonnement actuel
  Future<void> _loadSubscriptionLevel() async {
    try {
      final subscriptionData = await _premiumFeatureService.getSubscriptionInfo(widget.producerId);
      if (mounted) {
        setState(() {
          _currentSubscriptionLevel = subscriptionData['subscription']?['level'] ?? 'gratuit';
        });
      }
    } catch (e) {
      print('❌ Erreur lors du chargement du niveau d\'abonnement: $e');
    }
  }
  
  // Vérifier l'accès aux fonctionnalités premium
  Future<void> _checkPremiumFeatureAccess() async {
    if (mounted) {
      setState(() {
        _checkingPremiumAccess = true;
      });
    }
    
    try {
      // Vérifier l'accès à chaque fonctionnalité premium
      Map<String, bool> accessResults = {};
      
      for (final feature in _premiumFeaturesAccess.keys) {
        final hasAccess = await _premiumFeatureService.canAccessFeature(
          widget.producerId, 
          feature
        );
        accessResults[feature] = hasAccess;
      }
      
      if (mounted) {
        setState(() {
          _premiumFeaturesAccess = accessResults;
          _checkingPremiumAccess = false;
        });
      }
    } catch (e) {
      print('❌ Erreur lors de la vérification des accès premium: $e');
      if (mounted) {
        setState(() {
          _checkingPremiumAccess = false;
        });
      }
    }
  }
  
  // Afficher le dialogue de mise à niveau pour une fonctionnalité
  Future<void> _showUpgradePrompt(String featureId) async {
    final shouldUpgrade = await _premiumFeatureService.showUpgradeDialog(
      context, 
      widget.producerId, 
      featureId
    );
    
    if (shouldUpgrade && mounted) {
      // L'utilisateur a mis à niveau, recharger les accès
      await _checkPremiumFeatureAccess();
      await _loadSubscriptionLevel();
    }
  }
  
  Future<void> _loadInitialData() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }
    
    try {
      // Charger les données initiales (aperçu, tendances, recommandations)
      final overviewData = await _analyticsService.getOverview(
        widget.producerId, 
        period: _selectedPeriod
      );
      
      final trendsData = await _analyticsService.getTrends(
        widget.producerId,
        period: _selectedPeriod
      );
      
      final recommendationsData = await _analyticsService.getRecommendations(
        widget.producerId
      );
      
      // Convertir les données JSON en objets
      _overview = GrowthOverview.fromJson(overviewData);
      _trends = GrowthTrends.fromJson(trendsData);
      _recommendations = GrowthRecommendations.fromJson(recommendationsData);
      
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  Future<void> _loadUserProfile() async {
    try {
      final AuthService authService = Provider.of<AuthService>(context, listen: false);
      final userId = authService.userId;
      
      if (userId == null) {
        return;
      }
      
      final baseUrl = await constants.getBaseUrl();
      final url = Uri.parse('$baseUrl/api/users/$userId');
      
      final response = await http.get(
        url,
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 200 && mounted) {
        final userData = json.decode(response.body);
        setState(() {
          _userProfile = userData;
          _userName = userData['name'] ?? 'Utilisateur';
          _userPhoto = userData['photo'] ?? '';
        });
      }
    } catch (e) {
      print('❌ Erreur lors du chargement du profil: $e');
    }
  }
  
  Future<void> _loadProducerDetails() async {
    try {
      final details = await _producerTypeService.getProducerDetails(
        widget.producerId, 
        _producerType
      );
      
      if (mounted) {
        setState(() {
          _producerData = details;
          
          // Extraire le nom du producteur selon le type
          if (_producerType == ProducerType.restaurant) {
            _producerName = details['name'] ?? details['établissement'] ?? 'Restaurant';
          } else if (_producerType == ProducerType.leisureProducer) {
            _producerName = details['lieu'] ?? details['nom'] ?? 'Lieu de loisir';
          } else if (_producerType == ProducerType.wellnessProducer) {
            _producerName = details['name'] ?? details['établissement'] ?? 'Établissement bien-être';
          } else {
            _producerName = details['name'] ?? 'Établissement';
          }
        });
      }
    } catch (e) {
      print('❌ Erreur lors du chargement des détails du producteur: $e');
    }
  }
  
  List<String> _getProducerCategories() {
    if (_producerData == null) return [];
    
    List<String> categories = [];
    
    // Extraire les catégories selon le type de producteur
    if (_producerType == ProducerType.restaurant) {
      if (_producerData!['category'] != null) {
        if (_producerData!['category'] is List) {
          categories = (_producerData!['category'] as List).map((e) => e.toString()).toList();
        } else if (_producerData!['category'] is String) {
          categories = [_producerData!['category']];
        }
      } else if (_producerData!['type_cuisine'] != null) {
        if (_producerData!['type_cuisine'] is List) {
          categories = (_producerData!['type_cuisine'] as List).map((e) => e.toString()).toList();
        } else if (_producerData!['type_cuisine'] is String) {
          categories = [_producerData!['type_cuisine']];
        }
      }
    } else if (_producerType == ProducerType.leisureProducer) {
      if (_producerData!['catégorie'] != null) {
        if (_producerData!['catégorie'] is List) {
          categories = (_producerData!['catégorie'] as List).map((e) => e.toString()).toList();
        } else if (_producerData!['catégorie'] is String) {
          categories = [_producerData!['catégorie']];
        }
      } else if (_producerData!['thématique'] != null) {
        if (_producerData!['thématique'] is List) {
          categories = (_producerData!['thématique'] as List).map((e) => e.toString()).toList();
        } else if (_producerData!['thématique'] is String) {
          categories = [_producerData!['thématique']];
        }
      }
    } else if (_producerType == ProducerType.wellnessProducer) {
      if (_producerData!['category'] != null) {
        if (_producerData!['category'] is List) {
          categories = (_producerData!['category'] as List).map((e) => e.toString()).toList();
        } else if (_producerData!['category'] is String) {
          categories = [_producerData!['category']];
        }
      } else if (_producerData!['services'] != null) {
        if (_producerData!['services'] is List) {
          categories = (_producerData!['services'] as List).map((e) => e.toString()).toList();
        } else if (_producerData!['services'] is String) {
          categories = [_producerData!['services']];
        }
      }
    }
    
    // Limiter à 3 catégories maximum
    return categories.take(3).toList();
  }
  
  void _updatePeriod(String period) {
    if (_selectedPeriod != period) {
      setState(() {
        _selectedPeriod = period;
      });
      _loadInitialData();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Croissance & Audience"),
        elevation: 0,
        actions: [
          // Bouton pour ouvrir l'écran d'abonnement
          IconButton(
            icon: Icon(Icons.workspace_premium),
            tooltip: 'Abonnements Premium',
                              onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SubscriptionScreen(
                    producerId: widget.producerId,
                  ),
                ),
              ).then((_) {
                // Rafraîchir les accès au retour
                _checkPremiumFeatureAccess();
                _loadSubscriptionLevel();
              });
            },
              ),
            ],
          ),
      body: _isLoading || _checkingPremiumAccess
          ? LoadingIndicator()
          : _error != null
              ? ErrorMessage(message: _error!)
              : _buildContent(),
    );
  }
  
  Widget _buildContent() {
    return Column(
          children: [
        _buildHeader(),
        _buildSubscriptionBanner(),
        _buildPeriodSelector(),
                Expanded(
          child: TabBarView(
            controller: _tabController,
                      children: [
                        _buildOverviewTab(),
                        _buildTrendsTab(),
                        _buildRecommendationsTab(),
                    ],
                  ),
                ),
      ],
    );
  }
  
  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
        color: Theme.of(context).primaryColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
        child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                backgroundImage: _userPhoto.isNotEmpty
                    ? CachedNetworkImageProvider(_userPhoto) as ImageProvider
                    : AssetImage('assets/images/default_profile.png'),
                radius: 20,
              ),
              SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _producerName,
          style: TextStyle(
                          fontSize: 16,
            fontWeight: FontWeight.bold,
                        color: Colors.white,
          ),
        ),
        Text(
                      "Tableau de bord de croissance",
          style: TextStyle(
            fontSize: 12,
                        color: Colors.white.withOpacity(0.8),
          ),
        ),
      ],
              ),
            ),
          ],
        ),
          SizedBox(height: 16),
          TabBar(
            controller: _tabController,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white.withOpacity(0.7),
            tabs: [
              Tab(text: "Vue d'ensemble"),
              Tab(text: "Tendances"),
              Tab(text: "Conseils"),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildSubscriptionBanner() {
    // Couleur et texte selon le niveau d'abonnement
    Color bannerColor;
    String bannerText;
    IconData bannerIcon;
    
    switch (_currentSubscriptionLevel) {
      case 'gratuit':
        bannerColor = Colors.grey;
        bannerText = 'Passez à un abonnement premium pour accéder à plus de statistiques';
        bannerIcon = Icons.star_border;
        break;
      case 'starter':
        bannerColor = Colors.blue;
        bannerText = 'Abonnement Starter - Statistiques avancées débloquées';
        bannerIcon = Icons.star;
        break;
      case 'pro':
        bannerColor = Colors.indigo;
        bannerText = 'Abonnement Pro - Accès aux prédictions et campagnes';
        bannerIcon = Icons.verified;
        break;
      case 'legend':
        bannerColor = Colors.amber.shade800;
        bannerText = 'Abonnement Legend - Toutes les fonctionnalités débloquées';
        bannerIcon = Icons.workspace_premium;
        break;
      default:
        bannerColor = Colors.grey;
        bannerText = 'Améliorez votre expérience avec un abonnement premium';
        bannerIcon = Icons.star_border;
    }
    
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SubscriptionScreen(
              producerId: widget.producerId,
            ),
          ),
        ).then((_) {
          // Rafraîchir les accès au retour
          _checkPremiumFeatureAccess();
          _loadSubscriptionLevel();
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        color: bannerColor.withOpacity(0.1),
        child: Row(
                  children: [
            Icon(bannerIcon, color: bannerColor, size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                bannerText,
                        style: TextStyle(
                  color: bannerColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: bannerColor, size: 14),
                    ],
                  ),
                ),
    );
  }
  
  Widget _buildPeriodSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
                    children: [
            _buildPeriodButton('7', '7 jours'),
            SizedBox(width: 8),
            _buildPeriodButton('30', '30 jours'),
            SizedBox(width: 8),
            _buildPeriodButton('90', '3 mois'),
            SizedBox(width: 8),
            _buildPeriodButton('180', '6 mois'),
            SizedBox(width: 8),
            _buildPeriodButton('365', '1 an'),
                    ],
                  ),
                ),
    );
  }
  
  Widget _buildPeriodButton(String period, String label) {
    final isSelected = _selectedPeriod == period;
    
    return OutlinedButton(
      onPressed: () {
        setState(() {
          _selectedPeriod = period;
        });
        _loadInitialData();
      },
      style: OutlinedButton.styleFrom(
        backgroundColor: isSelected ? Theme.of(context).primaryColor : Colors.transparent,
        foregroundColor: isSelected ? Colors.white : Theme.of(context).primaryColor,
        side: BorderSide(
          color: isSelected ? Theme.of(context).primaryColor : Colors.grey.shade300,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      child: Text(label),
    );
  }
  
  Widget _buildOverviewTab() {
    if (_overview == null) {
      return Center(child: Text("Aucune donnée disponible"));
    }
    
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
          // KPIs de base (disponibles pour tous)
          _buildKpiCards(),
          SizedBox(height: 24),
          
          // Engagement (disponible pour tous)
          _buildSectionHeader("Engagement"),
          SizedBox(height: 12),
          _buildEngagementMetrics(),
          SizedBox(height: 24),
          
          // Analyse démographique (nécessite audience_demographics / niveau pro+)
          _premiumFeaturesAccess['audience_demographics'] == true
              ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    _buildSectionHeader("Démographie"),
                    SizedBox(height: 12),
                    _buildDemographics(),
          SizedBox(height: 24),
                  ],
                )
              : _buildPremiumFeatureTeaser(
                  title: 'Analyse démographique',
                  description: 'Découvrez qui sont vos clients et comment adapter votre offre',
                  featureId: 'audience_demographics',
                  color: Colors.indigo,
                  icon: Icons.people,
                  child: Container(
                    height: 200,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.withOpacity(0.3)),
                    ),
                    child: _buildDemographics(),
                  ),
                ),
          SizedBox(height: 24),
          
          // Prédictions (nécessite growth_predictions / niveau pro+)
          _premiumFeaturesAccess['growth_predictions'] == true
              ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                    _buildSectionHeader("Prédictions"),
                    SizedBox(height: 12),
                    _buildPredictions(),
                    SizedBox(height: 24),
                  ],
                )
              : _buildPremiumFeatureTeaser(
                  title: 'Prédictions de croissance',
                  description: 'Anticipez vos performances futures grâce à l\'IA',
                  featureId: 'growth_predictions',
                  color: Colors.purple,
                  icon: Icons.trending_up,
                  child: Container(
                    height: 200,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.withOpacity(0.3)),
                    ),
                    child: _buildPredictions(),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTrendsTab() {
    if (_trends == null) {
      return Center(child: Text("Aucune donnée disponible"));
    }
    
    return SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
          // Graphiques de tendances (base disponible pour tous)
          _buildSectionHeader("Évolution de la visibilité"),
          SizedBox(height: 12),
          _buildTrendCharts(),
            SizedBox(height: 24),
          
          // Analyse des concurrents (nécessite competitor_analysis / niveau pro+)
          _premiumFeaturesAccess['advanced_analytics'] == true
              ? Column(
          crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader("Analyse comparative"),
                    SizedBox(height: 12),
                    _buildCompetitorAnalysis(),
                    SizedBox(height: 24),
                  ],
                )
              : _buildPremiumFeatureTeaser(
                  title: 'Analyse comparative',
                  description: 'Comparez vos performances avec vos concurrents',
                  featureId: 'advanced_analytics',
                  color: Colors.blue,
                  icon: Icons.analytics,
                  child: Container(
              height: 200,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.withOpacity(0.3)),
                    ),
                    child: _buildCompetitorAnalysis(),
                  ),
                ),
          SizedBox(height: 24),
        ],
      ),
    );
  }
  
  Widget _buildRecommendationsTab() {
    if (_recommendations == null) {
      return Center(child: Text("Aucune recommandation disponible"));
    }
    
    return SingleChildScrollView(
        padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader("Recommandations"),
            SizedBox(height: 12),
          _buildRecommendationsList(),
          SizedBox(height: 24),
          
          // Campagnes marketing (nécessite simple_campaigns / niveau pro+)
          _buildSectionHeader("Campagnes marketing"),
          SizedBox(height: 12),
          
          _premiumFeaturesAccess['simple_campaigns'] == true
              ? _buildCampaigns()
              : _buildPremiumFeatureTeaser(
                  title: 'Campagnes marketing',
                  description: 'Créez et gérez vos campagnes marketing pour augmenter votre visibilité',
                  featureId: 'simple_campaigns',
                  color: Colors.green,
                  icon: Icons.campaign,
                                      child: Container(
                    height: 250,
                                        decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.withOpacity(0.3)),
                    ),
                    child: _buildCampaigns(),
                  ),
                ),
          SizedBox(height: 24),
        ],
      ),
    );
  }
  
  Widget _buildKpiCards() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
              'Indicateurs clés',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Text('Cette section sera bientôt disponible'),
          ],
        ),
      ),
    );
  }
  
  Widget _buildEngagementMetrics() {
      return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Métriques d\'engagement',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Text('Cette section sera bientôt disponible'),
          ],
        ),
      ),
    );
  }
  
  Widget _buildDemographics() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Démographie',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Text('Cette section sera bientôt disponible'),
          ],
        ),
      ),
    );
  }
  
  Widget _buildPredictions() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            Text(
              'Prédictions de croissance',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16),
            Text('Cette section sera bientôt disponible'),
          ],
        ),
      ),
    );
  }
  
  Widget _buildTrendCharts() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tendances',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Text('Cette section sera bientôt disponible'),
          ],
        ),
      ),
    );
  }
  
  Widget _buildCompetitorAnalysis() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
        padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
            Text(
              'Analyse de la concurrence',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Text('Cette section sera bientôt disponible'),
          ],
        ),
      ),
    );
  }
  
  Widget _buildRecommendationsList() {
                            return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                child: Padding(
        padding: const EdgeInsets.all(16.0),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
              'Recommandations',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Text('Cette section sera bientôt disponible'),
          ],
                                ),
                              ),
                            );
  }
  
  Widget _buildCampaigns() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
            Text(
              'Campagnes marketing',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            _loadingCampaigns
              ? CircularProgressIndicator()
              : _campaigns.isEmpty
                ? Text('Aucune campagne active')
                : ListView.builder(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    itemCount: _campaigns.length,
                    itemBuilder: (context, index) {
                      final campaign = _campaigns[index];
                      return ListTile(
                        title: Text(campaign['name'] ?? 'Campagne sans nom'),
                        subtitle: Text(campaign['status'] ?? 'Statut inconnu'),
                      );
                    },
                                            ),
                                          ],
                                        ),
                                      ),
    );
  }
  
  Widget _buildSectionHeader(String title) {
    return Row(
                            children: [
                                  Text(
          title,
                style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                        ),
                      ),
        SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 1,
            color: Colors.grey.withOpacity(0.3),
                                ),
                              ),
                            ],
                              );
  }
  
  // Méthode pour afficher les teasers de fonctionnalités premium
  Widget _buildPremiumFeatureTeaser({
    required String title,
    required String description,
    required String featureId,
    required IconData icon,
    Color? color,
    Widget? child,
  }) {
    return GestureDetector(
      onTap: () => _showUpgradePrompt(featureId),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
          color: Colors.grey.withOpacity(0.1),
          border: Border.all(color: Colors.grey.withOpacity(0.2)),
                            ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (color ?? Colors.blue).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color ?? Colors.blue),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                                    ),
                                  ),
                            ),
                Icon(Icons.lock, color: Colors.grey),
              ],
            ),
            SizedBox(height: 12),
        Text(
              description,
              style: TextStyle(
            fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
            SizedBox(height: 16),
            if (child != null) child,
            OutlinedButton(
              onPressed: () => _showUpgradePrompt(featureId),
              style: OutlinedButton.styleFrom(
                foregroundColor: color ?? Colors.blue,
                side: BorderSide(color: color ?? Colors.blue),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                minimumSize: Size(double.infinity, 36),
              ),
              child: Text('Débloquer cette fonctionnalité'),
            ),
          ],
        ),
      ),
    );
  }
  
  // Méthode pour charger les audiences disponibles
  Future<void> _loadAudiences() async {
    try {
      // Utiliser getTargetAudiences au lieu de getAudiences (méthode qui n'existe pas)
      final audiences = await _campaignService.getTargetAudiences(_producerType);
      
      if (mounted) {
        setState(() {
          _availableAudiences = audiences;
        });
      }
    } catch (e) {
      print('❌ Erreur lors du chargement des audiences: $e');
    }
  }

  // Méthode pour charger les campagnes marketing
  Future<void> _loadCampaigns() async {
    if (mounted) {
      setState(() {
        _loadingCampaigns = true;
      });
    }
    
    try {
      // Obtenir directement une List<Map<String, dynamic>> au lieu d'une Map
      final campaigns = await _campaignService.getCampaigns(widget.producerId);
      
      if (mounted) {
        setState(() {
          _campaigns = campaigns;
          _loadingCampaigns = false;
        });
      }
    } catch (e) {
      print('❌ Erreur lors du chargement des campagnes: $e');
      if (mounted) {
        setState(() {
          _loadingCampaigns = false;
        });
      }
    }
  }
}

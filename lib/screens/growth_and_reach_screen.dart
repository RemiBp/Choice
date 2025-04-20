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
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math' as math;

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
  DemographicsData? _demographics;
  GrowthPredictions? _predictions;
  CompetitorAnalysis? _competitorAnalysis;
  
  bool _isLoading = true;
  String? _error;
  String _selectedPeriod = '30d';
  String _currentSubscriptionLevel = 'gratuit';
  bool _checkingPremiumAccess = true;
  
  String _userName = '';
  String _userPhoto = '';
  String _producerName = '';
  Map<String, dynamic>? _userProfile;
  Map<String, dynamic>? _producerData;
  late ProducerType _producerType;
  
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
  
  final List<String> _selectedAudiences = [];
  List<Map<String, dynamic>> _availableAudiences = [];
  double _campaignBudget = 0;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isCreatingCampaign = false;
  final MarketingCampaignService _campaignService = MarketingCampaignService();
  
  List<Map<String, dynamic>> _campaigns = [];
  bool _loadingCampaigns = false;
  
  Map<String, bool> _premiumFeaturesAccess = {
    'advanced_analytics': false,
    'growth_predictions': false,
    'audience_demographics': false,
    'simple_campaigns': false,
    'advanced_targeting': false,
    'campaign_automation': false,
  };
  
  final List<String> _trendMetrics = ['followers', 'profileViews', 'engagementRate', 'conversions'];
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _producerType = widget.producerType ?? ProducerType.restaurant;
    _loadInitialData();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  Future<void> _loadInitialData() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _checkingPremiumAccess = true;
        _error = null;
      });
    }
    
    try {
      await _loadUserProfile();
      await _loadProducerDetails();
      await _loadSubscriptionLevel();
      await _checkPremiumFeatureAccess();

      final overviewFuture = _analyticsService.getOverview(widget.producerId, period: _selectedPeriod);
      final trendsFuture = _analyticsService.getTrends(widget.producerId, metrics: _trendMetrics, period: _selectedPeriod);
      final recommendationsFuture = _analyticsService.getRecommendations(widget.producerId);

      Future<DemographicsData?> demographicsFuture = _premiumFeaturesAccess['audience_demographics'] ?? false
          ? _analyticsService.getDemographics(widget.producerId, period: _selectedPeriod)
          : Future.value(null);

      Future<GrowthPredictions?> predictionsFuture = _premiumFeaturesAccess['growth_predictions'] ?? false
          ? _analyticsService.getPredictions(widget.producerId)
          : Future.value(null);

      Future<CompetitorAnalysis?> competitorAnalysisFuture = _premiumFeaturesAccess['advanced_analytics'] ?? false
          ? _analyticsService.getCompetitorAnalysis(widget.producerId, period: _selectedPeriod)
          : Future.value(null);

      Future<void> campaignsFuture = _premiumFeaturesAccess['simple_campaigns'] ?? false
          ? _loadCampaigns()
          : Future.value();
      Future<void> audiencesFuture = _premiumFeaturesAccess['advanced_targeting'] ?? false
          ? _loadAudiences()
          : Future.value();

      final results = await Future.wait([
        overviewFuture,
        trendsFuture,
        recommendationsFuture,
        demographicsFuture,
        predictionsFuture,
        competitorAnalysisFuture,
        campaignsFuture,
        audiencesFuture,
      ]);

      if (mounted) {
        setState(() {
          _overview = results[0] as GrowthOverview?;
          _trends = results[1] as GrowthTrends?;
          _recommendations = results[2] as GrowthRecommendations?;
          _demographics = results[3] as DemographicsData?;
          _predictions = results[4] as GrowthPredictions?;
          _competitorAnalysis = results[5] as CompetitorAnalysis?;

          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Erreur lors du chargement initial des données: $e');
      if (mounted) {
        setState(() {
          _error = 'Impossible de charger les données analytiques. Veuillez réessayer.';
          _isLoading = false;
          _checkingPremiumAccess = false;
        });
      }
    } finally {
       if (mounted) {
        setState(() {
           _checkingPremiumAccess = false;
        });
       }
    }
  }
  
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
      if (mounted) {
         setState(() {
             _currentSubscriptionLevel = 'gratuit';
         });
      }
    }
  }
  
  Future<void> _checkPremiumFeatureAccess() async {
    try {
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
        });
      }
    } catch (e) {
      print('❌ Erreur lors de la vérification des accès premium: $e');
    }
  }
  
  Future<void> _showUpgradePrompt(String featureId) async {
    final shouldUpgrade = await _premiumFeatureService.showUpgradeDialog(
      context,
      widget.producerId,
      featureId
    );
    
    if (shouldUpgrade && mounted) {
      _loadInitialData();
    }
  }
  
  Future<void> _loadUserProfile() async {
    try {
      final AuthService authService = Provider.of<AuthService>(context, listen: false);
      final userId = authService.userId;
      
      if (userId == null) {
        return;
      }
      
      final baseUrl = constants.getBaseUrlSync();
      final url = Uri.parse('$baseUrl/api/users/$userId');
      
      final response = await http.get(
        url,
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 200 && mounted) {
        final userData = json.decode(response.body);
        setState(() {
          _userProfile = userData;
          _userName = userData['username'] ?? 'Utilisateur';
          _userPhoto = userData['profilePicture'] ?? '';
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
          _producerName = details['businessName'] ?? details['name'] ?? details['établissement'] ?? details['lieu'] ?? 'Établissement';
        });
      }
    } catch (e) {
      print('❌ Erreur lors du chargement des détails du producteur: $e');
      if (mounted) {
        setState(() {
          _producerName = 'Établissement';
        });
      }
    }
  }
  
  List<String> _getProducerCategories() {
    if (_producerData == null) return [];
    
    List<String> categories = [];
    
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
    
    return categories.take(3).toList();
  }
  
  void _updatePeriod(String period) {
    if (_selectedPeriod != period) {
      setState(() {
        _selectedPeriod = period;
        _loadInitialData();
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    bool showLoading = _isLoading || _checkingPremiumAccess;

    return Scaffold(
      appBar: AppBar(
        title: Text("growth_reach.app_bar_title".tr()),
        elevation: 1,
        shadowColor: Colors.black.withOpacity(0.1),
        actions: [
          IconButton(
            icon: Icon(Icons.workspace_premium_outlined),
            tooltip: 'growth_reach.premium_tooltip'.tr(),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SubscriptionScreen(
                    producerId: widget.producerId,
                  ),
                ),
              ).then((_) {
                _loadInitialData();
              });
            },
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            tooltip: 'growth_reach.refresh_tooltip'.tr(),
            onPressed: _isLoading ? null : _loadInitialData,
          ),
        ],
      ),
      body: showLoading
          ? LoadingIndicator(message: _checkingPremiumAccess ? 'Vérification des accès...' : 'Chargement des données...')
          : _error != null
              ? ErrorMessage(
                   message: _error!,
                   onRetry: _loadInitialData,
                 )
              : _buildContent(),
    );
  }
  
  Widget _buildContent() {
    return RefreshIndicator(
        onRefresh: _loadInitialData,
        child: Column(
          children: [
            _buildHeader(),
            _buildSubscriptionBanner(),
            _buildPeriodSelector(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildOverviewTab(_overview),
                  _buildTrendsTab(_trends),
                  _buildRecommendationsTab(_recommendations),
                ],
              ),
            ),
          ],
        ),
    );
  }
  
  Widget _buildHeader() {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
    final onPrimaryColor = theme.colorScheme.onPrimary;

    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: BoxDecoration(
        color: primaryColor,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundImage: _userPhoto.isNotEmpty
                    ? CachedNetworkImageProvider(_userPhoto) as ImageProvider
                    : null,
                radius: 24,
                backgroundColor: Colors.white.withOpacity(0.3),
                child: _userPhoto.isEmpty ? Icon(Icons.person, color: onPrimaryColor.withOpacity(0.7)) : null,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _producerName,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: onPrimaryColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      "growth_reach.dashboard_subtitle".tr(),
                      style: TextStyle(
                        fontSize: 13,
                        color: onPrimaryColor.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _currentSubscriptionLevel.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: onPrimaryColor,
                  ),
                ),
              )
            ],
          ),
          SizedBox(height: 12),
          TabBar(
            controller: _tabController,
            indicatorColor: onPrimaryColor,
            indicatorWeight: 3,
            labelColor: onPrimaryColor,
            unselectedLabelColor: onPrimaryColor.withOpacity(0.7),
            labelStyle: TextStyle(fontWeight: FontWeight.bold),
            tabs: [
              Tab(text: "growth_reach.tab_overview".tr()),
              Tab(text: "growth_reach.tab_trends".tr()),
              Tab(text: "growth_reach.tab_recommendations".tr()),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildSubscriptionBanner() {
    if (_checkingPremiumAccess || _isLoading) {
      return const SizedBox.shrink();
    }

    Color bannerColor = Colors.grey;
    String bannerText = '';
    String buttonText = 'Gérer';
    IconData bannerIcon = Icons.help_outline;
    bool showBanner = true;

    switch (_currentSubscriptionLevel) {
      case 'gratuit':
        bannerText = 'Passer à Starter pour débloquer plus d\'insights.';
        bannerColor = Colors.blueGrey;
        buttonText = 'growth_reach.banner_upgrade_button'.tr();
        bannerIcon = Icons.lock_open_outlined;
        break;
      case 'starter':
        bannerText = 'Passer à Pro pour des analyses et prédictions avancées.';
        bannerColor = Colors.blue;
        buttonText = 'growth_reach.banner_manage_button'.tr();
        bannerIcon = Icons.star_border_purple500_outlined;
        break;
      case 'pro':
        bannerText = 'Passez à Legend pour une analyse complète et l\'automatisation.';
        bannerColor = Colors.purple;
        buttonText = 'growth_reach.banner_manage_button'.tr();
        bannerIcon = Icons.verified_outlined;
        break;
      case 'legend':
        showBanner = false;
        break;
      default:
        bannerText = 'Niveau d\'abonnement inconnu.';
        bannerColor = Colors.grey;
        buttonText = 'Gérer';
        bannerIcon = Icons.help_outline;
    }

    if (!showBanner) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: bannerColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: bannerColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(bannerIcon, color: bannerColor, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              bannerText,
              style: TextStyle(
                color: bannerColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SubscriptionScreen(
                    producerId: widget.producerId,
                  ),
                ),
              ).then((_) {
                _loadInitialData();
              });
            },
            child: Text(buttonText),
            style: OutlinedButton.styleFrom(
              foregroundColor: bannerColor,
              side: BorderSide(color: bannerColor.withOpacity(0.5)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              textStyle: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPeriodSelector() {
    final List<String> periods = ['7d', '30d', '90d', '180d', '365d'];
    final List<String> periodLabels = [
        '7 ' + 'growth_reach.days'.tr(),
        '30 ' + 'growth_reach.days'.tr(),
        '3 ' + 'growth_reach.months'.tr(),
        '6 ' + 'growth_reach.months'.tr(),
        '1 ' + 'growth_reach.year'.tr()
    ];
    final List<bool> isSelected = periods.map((p) => p == _selectedPeriod).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Center(
        child: ToggleButtons(
          isSelected: isSelected,
          onPressed: (int index) {
             if (!isSelected[index]) {
               _updatePeriod(periods[index]);
             }
          },
          borderRadius: BorderRadius.circular(8.0),
          borderColor: Theme.of(context).primaryColor.withOpacity(0.3),
          selectedBorderColor: Theme.of(context).primaryColor,
          selectedColor: Colors.white,
          fillColor: Theme.of(context).primaryColor,
          color: Theme.of(context).primaryColor,
          constraints: BoxConstraints(minHeight: 36.0),
          children: List.generate(periods.length, (index) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Text(periodLabels[index], style: TextStyle(fontSize: 13)),
            );
          }),
        ),
      ),
    );
  }
  
  Widget _buildOverviewTab(GrowthOverview? overview) {
    if (overview == null) {
      return _buildNoDataAvailable("growth_reach.no_overview_data".tr());
    }

    bool canAccessDemographics = _premiumFeaturesAccess['audience_demographics'] ?? false;
    bool canAccessPredictions = _premiumFeaturesAccess['growth_predictions'] ?? false;

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader("growth_reach.kpi_header".tr()),
          SizedBox(height: 12),
          _buildKpiGrid(overview.kpis),
          SizedBox(height: 24),

          _buildEngagementSummaryCard(overview.engagementSummary),
          SizedBox(height: 24),

          _buildSectionHeader("growth_reach.demographics_header".tr()),
          SizedBox(height: 12),
          canAccessDemographics
              ? _buildDemographicsContent(_demographics)
              : _buildPremiumFeatureTeaser(
                  title: "growth_reach.demographics_title".tr(),
                  description: "growth_reach.demographics_desc".tr(),
                  featureId: 'audience_demographics',
                  icon: Icons.people_alt_outlined,
                   color: Colors.indigo,
                   child: Container(height: 150, child: Center(child: Icon(Icons.bar_chart, size: 50, color: Colors.grey.shade400))),
                ),
          SizedBox(height: 24),

          _buildSectionHeader("growth_reach.predictions_header".tr()),
          SizedBox(height: 12),
          canAccessPredictions
              ? _buildPredictionsContent(_predictions)
              : _buildPremiumFeatureTeaser(
                  title: "growth_reach.predictions_title".tr(),
                  description: "growth_reach.predictions_desc".tr(),
                  featureId: 'growth_predictions',
                  icon: Icons.online_prediction_outlined,
                   color: Colors.purple,
                   child: Container(height: 150, child: Center(child: Icon(Icons.trending_up, size: 50, color: Colors.grey.shade400))),
                ),
        ],
      ),
    );
  }
  
  Widget _buildTrendsTab(GrowthTrends? trends) {
    if (trends == null) {
      return _buildNoDataAvailable("growth_reach.no_trends_data".tr());
    }

    bool canAccessCompetitors = _premiumFeaturesAccess['advanced_analytics'] ?? false;

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader("growth_reach.trends_header".tr()),
          SizedBox(height: 12),
          _buildTrendChartsContent(context),
          SizedBox(height: 24),

          _buildSectionHeader("growth_reach.competitors_header".tr()),
          SizedBox(height: 12),
          canAccessCompetitors
              ? _buildCompetitorAnalysisContent(context)
              : _buildPremiumFeatureTeaser(
                  title: "growth_reach.competitors_title".tr(),
                  description: "growth_reach.competitors_desc".tr(),
                  featureId: 'advanced_analytics',
                  icon: Icons.analytics_outlined,
                  color: Colors.teal,
                   child: Container(height: 150, child: Center(child: Icon(Icons.compare_arrows, size: 50, color: Colors.grey.shade400))),
                ),
          SizedBox(height: 24),
        ],
      ),
    );
  }
  
  Widget _buildRecommendationsTab(GrowthRecommendations? recommendations) {
    if (recommendations == null || recommendations.recommendations.isEmpty) {
      return _buildNoDataAvailable("growth_reach.no_recommendations_data".tr());
    }

    bool canAccessCampaigns = _premiumFeaturesAccess['simple_campaigns'] ?? false;

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader("growth_reach.recommendations_header".tr()),
          SizedBox(height: 12),
          _buildRecommendationsList(recommendations.recommendations),
          SizedBox(height: 24),

          _buildSectionHeader("growth_reach.campaigns_header".tr()),
          SizedBox(height: 12),
          canAccessCampaigns
              ? _buildCampaignsContent()
              : _buildPremiumFeatureTeaser(
                  title: "growth_reach.campaigns_title".tr(),
                  description: "growth_reach.campaigns_desc".tr(),
                  featureId: 'simple_campaigns',
                  icon: Icons.campaign_outlined,
                  color: Colors.green,
                   child: Container(height: 150, child: Center(child: Icon(Icons.volume_up_outlined, size: 50, color: Colors.grey.shade400))),
                ),
          SizedBox(height: 24),
        ],
      ),
    );
  }
  
  Widget _buildNoDataAvailable(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
           mainAxisAlignment: MainAxisAlignment.center,
           children: [
              Icon(Icons.data_usage_outlined, size: 60, color: Colors.grey.shade400),
              SizedBox(height: 16),
              Text(
                 message,
                 textAlign: TextAlign.center,
                 style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
              ),
           ],
        ),
      ),
    );
  }
  
  Widget _buildSectionHeader(String title) {
    return Text(
       title,
       style: TextStyle(
         fontSize: 20,
         fontWeight: FontWeight.bold,
          color: Theme.of(context).textTheme.titleLarge?.color?.withOpacity(0.8) ?? Colors.black87,
       ),
    );
  }
  
  String _formatNumber(double number) {
    return NumberFormat.compact().format(number);
  }
  
  String _formatPercent(double percent, {bool includeSign = false}) {
    final format = NumberFormat("##0.0'%'", "fr_FR");
    String formatted = format.format(percent / 100);
    if (includeSign && percent > 0) {
      formatted = "+$formatted";
    }
    return formatted;
  }
  
  Widget _buildKpiCard(String title, KpiValue kpi) {
    final theme = Theme.of(context);
    final bool isPositive = kpi.isPositiveChange;
    final Color changeColor = isPositive ? Colors.green.shade700 : Colors.red.shade700;
    final IconData changeIcon = isPositive ? Icons.arrow_upward : Icons.arrow_downward;

    return Card(
       elevation: 2,
       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
       child: Padding(
         padding: const EdgeInsets.all(16.0),
         child: Column(
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
             Text(
               title,
               style: TextStyle(
                  fontSize: 14,
                  color: theme.textTheme.bodySmall?.color ?? Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
             ),
             SizedBox(height: 8),
             Text(
               _formatNumber(kpi.current),
               style: TextStyle(
                 fontSize: 24,
                 fontWeight: FontWeight.bold,
                 color: theme.textTheme.titleLarge?.color ?? Colors.black,
               ),
             ),
             SizedBox(height: 8),
             Row(
                children: [
                   Icon(changeIcon, size: 16, color: changeColor),
                   SizedBox(width: 4),
                   Text(
                      _formatNumber(kpi.change.abs()),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: changeColor,
                      ),
                   ),
                   SizedBox(width: 4),
                   Text(
                     "(${_formatPercent(kpi.changePercent, includeSign: true)})",
                     style: TextStyle(
                        fontSize: 13,
                        color: changeColor.withOpacity(0.9),
                      ),
                   ),
                ],
             )
           ],
         ),
       ),
    );
  }
  
  Widget _buildKpiGrid(Map<String, KpiValue> kpis) {
    final List<MapEntry<String, String>> kpiOrder = [
       MapEntry('followers', 'growth_reach.kpi_followers'.tr()),
       MapEntry('profileViews', 'growth_reach.kpi_views'.tr()),
       MapEntry('engagementRate', 'growth_reach.kpi_engagement'.tr()),
       MapEntry('conversions', kpis['conversions']?.label ?? 'growth_reach.kpi_conversions'.tr()),
       MapEntry('reach', 'growth_reach.kpi_reach'.tr()),
       MapEntry('avgRating', 'growth_reach.kpi_rating'.tr()),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.5,
      ),
      itemCount: kpiOrder.length,
      itemBuilder: (context, index) {
        final entry = kpiOrder[index];
        final kpi = kpis[entry.key];
        if (kpi == null) {
           return Card(
             elevation: 1,
             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
             color: Colors.grey.shade100,
             child: Center(
               child: Text(
                 '${entry.value}\n(N/A)',
                 textAlign: TextAlign.center,
                 style: TextStyle(color: Colors.grey.shade500),
               ),
             ),
           );
        }
        return _buildKpiCard(entry.value, kpi);
      },
    );
  }
  
  Widget _buildTrendChartsContent(BuildContext context) {
    if (_isLoading) {
      return const Center(child: LoadingIndicator());
    }
    if (_error != null || _trends == null) {
      return ErrorMessage(message: _error ?? 'Impossible de charger les tendances.');
    }

    final trendsMap = _trends!.trends;
    if (trendsMap.isEmpty) {
      return const Center(child: Text("Aucune donnée de tendance disponible."));
    }

    double minY = 0;
    double maxY = 0;

    final firstMetricData = trendsMap.values.firstWhere((list) => list.isNotEmpty, orElse: () => []);
    if (firstMetricData.isNotEmpty) {
      minY = firstMetricData.map((e) => e.value).reduce(math.min).toDouble();
      maxY = firstMetricData.map((e) => e.value).reduce(math.max).toDouble();
    } else {
      maxY = 1;
      minY = 0;
    }
    if (maxY == minY) maxY += 1;
    double paddingY = (maxY - minY) * 0.1;
    minY = (minY - paddingY < 0 && minY >= 0) ? 0 : minY - paddingY;
    maxY += paddingY;


    return ListView(
      children: trendsMap.entries.map((entry) {
        String metricKey = entry.key;
        List<TimePoint> dataPoints = entry.value;

        List<FlSpot> spots = dataPoints.asMap().entries.map((e) {
          return FlSpot(e.key.toDouble(), e.value.value.toDouble());
        }).toList();

        double chartMinY = 0;
        double chartMaxY = 1;
        if (spots.isNotEmpty) {
           chartMinY = spots.map((spot) => spot.y).reduce(math.min);
           chartMaxY = spots.map((spot) => spot.y).reduce(math.max);
        }
        if (chartMaxY == chartMinY) chartMaxY += 1;
        double chartPaddingY = (chartMaxY - chartMinY) * 0.1;
        chartMinY = (chartMinY - chartPaddingY < 0 && chartMinY >= 0) ? 0 : chartMinY - chartPaddingY;
        chartMaxY += chartPaddingY;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'trends_title.${metricKey}'.tr(),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 250,
                child: LineChart(
                  LineChartData(
                    minY: chartMinY,
                    maxY: chartMaxY,
                    gridData: const FlGridData(show: true),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 40,
                          getTitlesWidget: (value, meta) {
                            return SideTitleWidget(
                              meta: meta,
                              space: 8.0,
                              child: Text(NumberFormat.compact().format(value)),
                            );
                          },
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          interval: spots.length > 1 ? (spots.length / 5).ceilToDouble() : 1,
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            if (index >= 0 && index < dataPoints.length) {
                                return SideTitleWidget(
                                  meta: meta,
                                  space: 8.0,
                                  child: Text('P${index + 1}'),
                                );
                            }
                            return const Text('');
                          },
                        ),
                      ),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey.shade300)),
                    lineTouchData: LineTouchData(
                         touchTooltipData: LineTouchTooltipData(
                                getTooltipColor: (touchedSpot) => Colors.blueGrey.withOpacity(0.8),
                                getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                                  return touchedBarSpots.map((barSpot) {
                                    final flSpot = barSpot;
                                    final dataIndex = flSpot.x.toInt();
                                    String bottomText = '';
                                     if (dataIndex >= 0 && dataIndex < dataPoints.length) {
                                         bottomText = dataPoints[dataIndex].date;
                                     }

                                    return LineTooltipItem(
                                      '${NumberFormat.compact().format(flSpot.y)}\n',
                                      const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                      children: [
                                         TextSpan(
                                           text: bottomText,
                                           style: TextStyle(
                                             color: Colors.white.withOpacity(0.8),
                                             fontWeight: FontWeight.normal,
                                             fontSize: 12,
                                           ),
                                         ),
                                      ],
                                    );
                                  }).toList();
                                },
                              ),
                    ),
                     lineBarsData: [
                       LineChartBarData(
                         spots: spots,
                         isCurved: true,
                         color: Theme.of(context).primaryColor,
                         barWidth: 3,
                         isStrokeCapRound: true,
                         dotData: const FlDotData(show: false),
                         belowBarData: BarAreaData(
                           show: true,
                           color: Theme.of(context).primaryColor.withOpacity(0.1),
                         ),
                       ),
                     ],
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
  
  Widget _buildEngagementSummaryCard(EngagementSummary summary) {
     return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
           padding: const EdgeInsets.all(16.0),
           child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                 Text(
                    "growth_reach.engagement_summary_header".tr(),
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                 ),
                 SizedBox(height: 16),
                 Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                       _buildSummaryItem(Icons.post_add, summary.posts, "growth_reach.engagement_posts".tr()),
                       _buildSummaryItem(Icons.favorite_border, summary.likes, "growth_reach.engagement_likes".tr()),
                       _buildSummaryItem(Icons.comment_outlined, summary.comments, "growth_reach.engagement_comments".tr()),
                    ],
                 ),
              ],
           ),
        ),
     );
  }
  
  Widget _buildSummaryItem(IconData icon, int value, String label) {
     return Column(
        children: [
           Icon(icon, size: 28, color: Theme.of(context).primaryColor),
           SizedBox(height: 4),
           Text(
              _formatNumber(value.toDouble()),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
           ),
           SizedBox(height: 2),
           Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
           ),
        ],
     );
  }
  
  Widget _buildDemographicsContent(DemographicsData? demographics) {
     if (demographics == null) {
        return _buildNoDataAvailable("growth_reach.no_demographics_data".tr());
     }

     return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
           padding: const EdgeInsets.all(16.0),
           child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                 Text(
                    "growth_reach.demographics_age_title".tr(),
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                 ),
                 SizedBox(height: 8),
                 _buildDistributionChart(demographics.ageDistribution),
                 SizedBox(height: 20),
                 Text(
                    "growth_reach.demographics_gender_title".tr(),
                     style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                 ),
                 SizedBox(height: 8),
                 _buildDistributionChart(demographics.genderDistribution),
                  SizedBox(height: 20),
                 Text(
                    "growth_reach.demographics_location_title".tr(),
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                 ),
                 SizedBox(height: 8),
                 _buildTopLocations(demographics.topLocations),
              ],
           ),
        ),
     );
  }
  
  Widget _buildDistributionChart(Map<String, double> distribution) {
     if (distribution.isEmpty) return Text("growth_reach.not_available".tr());

     final sortedEntries = distribution.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      final totalValue = distribution.values.fold(0.0, (sum, item) => sum + item);
      if (totalValue <= 0) return Text("growth_reach.not_available".tr());

      return Column(
         children: sortedEntries.map((entry) {
            double percentage = (entry.value / totalValue) * 100;
            return Padding(
               padding: const EdgeInsets.symmetric(vertical: 4.0),
               child: Row(
                  children: [
                     Expanded(
                        flex: 2,
                        child: Text(
                           entry.key,
                           style: TextStyle(fontSize: 13),
                           overflow: TextOverflow.ellipsis,
                        ),
                     ),
                     Expanded(
                        flex: 3,
                        child: LinearPercentIndicator(
                           percent: percentage / 100,
                           lineHeight: 16.0,
                            center: Text(
                               _formatPercent(percentage),
                               style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                           backgroundColor: Colors.grey.shade300,
                           progressColor: Theme.of(context).primaryColor.withOpacity(0.8),
                           barRadius: Radius.circular(8),
                        ),
                     ),
                  ],
               ),
            );
         }).toList(),
      );
  }
  
  Widget _buildTopLocations(List<Map<String, dynamic>> locations) {
      if (locations.isEmpty) return Text("growth_reach.not_available".tr());

      return Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: locations.take(5).map((loc) {
            final String name = loc['city'] ?? loc['region'] ?? loc['country'] ?? 'Inconnu';
            final double percentage = (loc['percentage'] ?? 0.0).toDouble();
            return Padding(
               padding: const EdgeInsets.symmetric(vertical: 3.0),
               child: Text(
                  "• $name (${_formatPercent(percentage)})",
                  style: TextStyle(fontSize: 14),
               ),
            );
         }).toList(),
      );
  }
  
  Widget _buildPredictionsContent(GrowthPredictions? predictions) {
     if (predictions == null || predictions.predictions.isEmpty) {
        return _buildNoDataAvailable("growth_reach.no_predictions_data".tr());
     }

     return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
           padding: const EdgeInsets.all(16.0),
           child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: predictions.predictions.entries.map((entry) {
                  String label;
                  switch(entry.key) {
                      case 'predictedFollowers': label = 'growth_reach.prediction_followers'.tr(); break;
                      case 'predictedViews': label = 'growth_reach.prediction_views'.tr(); break;
                      case 'predictedConversions': label = 'growth_reach.prediction_conversions'.tr(); break;
                      default: label = entry.key;
                  }
                 final prediction = entry.value;
                 final Color confidenceColor = prediction.confidence == 'high' ? Colors.green : (prediction.confidence == 'medium' ? Colors.orange : Colors.red);

                 return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
                       children: [
                          Expanded(
                             child: Text(
                               label,
                               style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                             ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                             children: [
                               Text(
                                  _formatNumber(prediction.value),
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                               ),
                                Row(
                                   children: [
                                     Icon(Icons.shield_outlined, size: 12, color: confidenceColor),
                                     SizedBox(width: 4),
                                     Text(
                                        'growth_reach.prediction_confidence'.tr(args: [prediction.confidence]),
                                        style: TextStyle(fontSize: 11, color: confidenceColor),
                                     ),
                                   ],
                                ),
                             ],
                          ),
                       ],
                    ),
                 );
              }).toList(),
           ),
        ),
     );
  }
  
  Widget _buildCompetitorAnalysisContent(BuildContext context) {
    if (_isLoading) {
      return const Center(child: LoadingIndicator());
    }
    if (_error != null || _competitorAnalysis == null) {
      return ErrorMessage(message: _error ?? 'Impossible de charger les analyses.', onRetry: _loadInitialData);
    }

    final analysis = _competitorAnalysis!;

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Text("growth_reach.competitor_analysis_title".tr(), style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("growth_reach.your_performance".tr(), style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                _buildCompetitorRow("Followers", analysis.yourMetrics.followers?.toDouble() ?? 0, analysis.averageCompetitorMetrics.followers?.toDouble() ?? 0),
                _buildCompetitorRow(
                   "Taux d\'engagement",
                    analysis.yourMetrics.engagementRate?.toDouble() ?? 0,
                    analysis.averageCompetitorMetrics.engagementRate?.toDouble() ?? 0,
                    isPercent: true
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text("growth_reach.competitor_top".tr(), style: Theme.of(context).textTheme.titleMedium),
        SizedBox(height: 8),
        if (analysis.topCompetitors.isEmpty)
           Text("growth_reach.competitor_no_top".tr(), style: TextStyle(color: Colors.grey)),
        ...analysis.topCompetitors.take(3).map((comp) => Padding(
           padding: const EdgeInsets.only(bottom: 8.0),
           child: Row(
              children: [
                 Expanded(child: Text(comp.name, overflow: TextOverflow.ellipsis)),
                 SizedBox(width: 8),
                 Text("(${_formatNumber(comp.followers)} followers)", style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
              ],
           ),
        )),
      ],
    );
  }
  
  Widget _buildCompetitorRow(String label, double value, double? yourValue, {bool isPercent = false}) {
    String formattedValue = isPercent ? _formatPercent(value) : _formatNumber(value);
    Widget comparisonWidget = SizedBox.shrink();

    if (yourValue != null) {
       double diff = value - yourValue;
       Color color = diff > 0 ? Colors.red.shade700 : (diff < 0 ? Colors.green.shade700 : Colors.grey);
       IconData icon = diff > 0 ? Icons.arrow_upward : (diff < 0 ? Icons.arrow_downward : Icons.remove);
       String diffText = isPercent ? _formatPercent(diff.abs(), includeSign: true) : _formatNumber(diff.abs());
       comparisonWidget = Row(
         mainAxisSize: MainAxisSize.min,
         children: [
           Text("(", style: TextStyle(fontSize: 12, color: color)),
           Icon(icon, size: 12, color: color),
           Text(diffText, style: TextStyle(fontSize: 12, color: color)),
           Text(" vs vous)", style: TextStyle(fontSize: 12, color: color)),
         ],
       );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(" • $label", style: TextStyle(fontSize: 14)),
           Row(
             children: [
                Text(formattedValue, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                SizedBox(width: 8),
                comparisonWidget,
             ],
           ),
        ],
      ),
    );
  }
  
  Widget _buildRecommendationsList(List<Recommendation> recommendations) {
     if (recommendations.isEmpty) {
        return Text("growth_reach.no_recommendations_available".tr());
     }

     final priorityOrder = {'high': 0, 'medium': 1, 'low': 2};
     recommendations.sort((a, b) =>
         (priorityOrder[a.priority] ?? 99).compareTo(priorityOrder[b.priority] ?? 99));

     return ListView.separated(
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        itemCount: recommendations.length,
        separatorBuilder: (_, __) => SizedBox(height: 12),
        itemBuilder: (context, index) {
           return _buildRecommendationCard(recommendations[index]);
        },
     );
  }
  
  Widget _buildRecommendationCard(Recommendation rec) {
     IconData icon;
     Color color;
     switch (rec.priority) {
        case 'high': icon = Icons.priority_high; color = Colors.red.shade600; break;
        case 'medium': icon = Icons.flag_outlined; color = Colors.orange.shade700; break;
        case 'low':
        default: icon = Icons.lightbulb_outline; color = Colors.blue.shade600; break;
     }

     String buttonText;
     VoidCallback? onPressedAction;

      switch (rec.action.type) {
        case 'boost_post':
          buttonText = 'growth_reach.rec_action_boost'.tr();
          onPressedAction = () { _showSnackbar('Action Bientôt disponible: Booster Post ${rec.action.postId}'); };
          break;
        case 'navigate_to_messaging':
          buttonText = 'growth_reach.rec_action_message'.tr();
          onPressedAction = () => Navigator.pushNamed(context, '/messaging');
          break;
         case 'navigate_to_profile_edit':
           buttonText = 'growth_reach.rec_action_edit_profile'.tr();
           onPressedAction = () => Navigator.pushNamed(context, '/profile/me');
           break;
        case 'create_campaign':
           buttonText = 'growth_reach.rec_action_create_campaign'.tr();
           onPressedAction = () => _showCampaignCreatorDialog();
           break;
        default:
          buttonText = 'growth_reach.rec_action_learn_more'.tr();
          onPressedAction = null;
     }

     return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
           padding: const EdgeInsets.all(16.0),
           child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                 Row(
                    children: [
                       Icon(icon, color: color, size: 20),
                       SizedBox(width: 8),
                       Expanded(
                          child: Text(
                            rec.title,
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                       ),
                    ],
                 ),
                 SizedBox(height: 8),
                 Text(
                    rec.description,
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                 ),
                 SizedBox(height: 12),
                  if (onPressedAction != null)
                     Align(
                       alignment: Alignment.centerRight,
                       child: ElevatedButton.icon(
                         icon: Icon(Icons.arrow_forward, size: 16),
                         label: Text(buttonText),
                         onPressed: onPressedAction,
                         style: ElevatedButton.styleFrom(
                           backgroundColor: color,
                           foregroundColor: Colors.white,
                           textStyle: TextStyle(fontSize: 13),
                           padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                         ),
                       ),
                     ),
              ],
           ),
        ),
     );
  }
  
  Widget _buildCampaignsContent() {
     bool canUseAdvancedTargeting = _premiumFeaturesAccess['advanced_targeting'] ?? false;

     return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
               Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                     Text(
                        "growth_reach.campaigns_my_campaigns".tr(),
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                     ),
                     ElevatedButton.icon(
                        icon: Icon(Icons.add_circle_outline, size: 18),
                        label: Text("growth_reach.campaigns_create".tr()),
                        onPressed: () {
                            if (!canUseAdvancedTargeting) {
                               // Maybe show limited options or prompt upgrade
                            }
                            _showCampaignCreatorDialog();
                        },
                        style: ElevatedButton.styleFrom(
                           padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                           textStyle: TextStyle(fontSize: 13),
                        ),
                     ),
                  ],
               ),
               SizedBox(height: 16),
               _loadingCampaigns
                  ? Center(child: Padding(padding: EdgeInsets.all(8.0), child: LoadingIndicator()))
                  : _campaigns.isEmpty
                     ? Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16.0),
                            child: Text("growth_reach.campaigns_none".tr(), style: TextStyle(color: Colors.grey)),
                          ),
                         )
                     : ListView.builder(
                         shrinkWrap: true,
                         physics: NeverScrollableScrollPhysics(),
                         itemCount: _campaigns.length,
                         itemBuilder: (context, index) {
                            final campaign = _campaigns[index];
                            return ListTile(
                               leading: Icon(_getCampaignIcon(campaign['type']), color: Theme.of(context).primaryColor),
                               title: Text(campaign['name'] ?? 'Campagne sans nom'),
                               subtitle: Text(_formatCampaignStatus(campaign['status'])),
                               trailing: Text(_formatCampaignDates(campaign['startDate'], campaign['endDate'])),
                            );
                         },
                       ),
            ],
          ),
        ),
     );
  }
  
  void _showCampaignCreatorDialog() {
     bool canUseAdvancedTargeting = _premiumFeaturesAccess['advanced_targeting'] ?? false;

     showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: RoundedRectangleBorder(
           borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) {
           return StatefulBuilder(
              builder: (BuildContext context, StateSetter setModalState) {
                String? selectedType = _campaignTypes.first;
                DateTime? startDate = DateTime.now();
                DateTime? endDate = DateTime.now().add(Duration(days: 7));
                double budget = 50.0;
                List<String> selectedAudiences = [];
                final _formKey = GlobalKey<FormState>();
                final _titleController = TextEditingController();
                final _descriptionController = TextEditingController();
                bool _isCreating = false;

                return Padding(
                   padding: EdgeInsets.only(
                       bottom: MediaQuery.of(context).viewInsets.bottom,
                       left: 16, right: 16, top: 16
                    ),
                   child: Form(
                     key: _formKey,
                     child: SingleChildScrollView(
                       child: Column(
                         mainAxisSize: MainAxisSize.min,
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: [
                           Text("growth_reach.campaign_create_title".tr(), style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                           SizedBox(height: 16),
                           TextFormField(
                              controller: _titleController,
                              decoration: InputDecoration(labelText: "growth_reach.campaign_field_title".tr(), border: OutlineInputBorder()),
                              validator: (value) => value == null || value.isEmpty ? 'Champ requis' : null,
                           ),
                           SizedBox(height: 12),
                           DropdownButtonFormField<String>(
                              value: selectedType,
                              decoration: InputDecoration(labelText: "growth_reach.campaign_field_type".tr(), border: OutlineInputBorder()),
                              items: _campaignTypes.map((String type) {
                                 return DropdownMenuItem<String>(
                                   value: type,
                                   child: Text(type),
                                 );
                              }).toList(),
                              onChanged: (value) {
                                 setModalState(() => selectedType = value);
                              },
                              validator: (value) => value == null ? 'Champ requis' : null,
                           ),
                           SizedBox(height: 12),
                           TextFormField(
                              controller: _descriptionController,
                              decoration: InputDecoration(labelText: "growth_reach.campaign_field_desc".tr(), border: OutlineInputBorder()),
                              maxLines: 3,
                           ),
                            SizedBox(height: 12),
                            Row(
                               children: [
                                  Expanded(child: Text("Début: ${DateFormat.yMd('fr_FR').format(startDate!)}")),
                                  TextButton(onPressed: () async {
                                      final picked = await showDatePicker(context: context, initialDate: startDate!, firstDate: DateTime.now(), lastDate: DateTime.now().add(Duration(days: 365)));
                                      if (picked != null) setModalState(() => startDate = picked);
                                  }, child: Text("Modifier")),
                               ],
                            ),
                            Row(
                               children: [
                                   Expanded(child: Text("Fin: ${DateFormat.yMd('fr_FR').format(endDate!)}")),
                                   TextButton(onPressed: () async {
                                       final picked = await showDatePicker(context: context, initialDate: endDate!, firstDate: startDate!, lastDate: startDate!.add(Duration(days: 90)));
                                       if (picked != null) setModalState(() => endDate = picked);
                                    }, child: Text("Modifier")),
                               ],
                            ),
                            SizedBox(height: 12),
                            Text("Budget: ${budget.toStringAsFixed(2)} €"),
                            Slider(
                               value: budget,
                               min: 10.0,
                               max: 500.0,
                               divisions: 49,
                               label: budget.toStringAsFixed(2),
                               onChanged: (value) {
                                  setModalState(() => budget = value);
                               },
                            ),
                           SizedBox(height: 12),
                            if (_availableAudiences.isNotEmpty)
                               ExpansionTile(
                                  title: Text("growth_reach.campaign_field_audience".tr()),
                                  subtitle: Text(canUseAdvancedTargeting ? "Sélectionnez votre cible" : "Niveau Pro requis"),
                                  children: [
                                     if (!canUseAdvancedTargeting)
                                        Padding(
                                           padding: const EdgeInsets.all(8.0),
                                           child: ElevatedButton(
                                              onPressed: () => _showUpgradePrompt('advanced_targeting'),
                                              child: Text("Débloquer le ciblage avancé (Pro)"),
                                           ),
                                        ),
                                     Wrap(
                                        spacing: 8.0,
                                        runSpacing: 4.0,
                                        children: _availableAudiences.map((audience) {
                                           final audienceId = audience['id'].toString();
                                           final bool isSelected = selectedAudiences.contains(audienceId);
                                           return FilterChip(
                                              label: Text(audience['name'] ?? 'Audience'),
                                              selected: isSelected,
                                              onSelected: !canUseAdvancedTargeting ? null : (selected) {
                                                 setModalState(() {
                                                    if (selected) {
                                                       selectedAudiences.add(audienceId);
                                                    } else {
                                                       selectedAudiences.remove(audienceId);
                                                    }
                                                 });
                                              },
                                              disabledColor: Colors.grey.shade300,
                                              selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
                                           );
                                        }).toList(),
                                     ),
                                  ],
                                  initiallyExpanded: canUseAdvancedTargeting,
                               ),
                            SizedBox(height: 20),
                            Center(
                               child: ElevatedButton(
                                 child: _isCreating
                                    ? Center(child: Padding(padding: EdgeInsets.all(8.0), child: LoadingIndicator()))
                                    : Text("growth_reach.campaign_create_button".tr()),
                                 onPressed: _isCreating ? null : () async {
                                   if (_formKey.currentState!.validate()) {
                                     setModalState(() => _isCreating = true);
                                     try {
                                       Map<String, dynamic> parameters = {};

                                       final newCampaign = await _campaignService.createCampaign(
                                          producerId: widget.producerId,
                                          type: selectedType ?? _campaignTypes.first,
                                          title: _titleController.text,
                                          parameters: parameters,
                                          budget: budget,
                                          startDate: startDate,
                                          endDate: endDate,
                                          targetAudience: selectedAudiences.isNotEmpty ? selectedAudiences : null,
                                          description: _descriptionController.text.isNotEmpty ? _descriptionController.text : null,
                                       );

                                       Navigator.pop(context);
                                       _showSnackbar("Campagne '${newCampaign['title']}' créée avec succès !");
                                       _loadCampaigns();

                                     } catch (e) {
                                        print('❌ Erreur création campagne: $e');
                                        Navigator.pop(context);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                           SnackBar(content: Text("Erreur lors de la création de la campagne: ${e.toString()}"), backgroundColor: Colors.red),
                                        );
                                     } finally {
                                        if (mounted) {
                                           setModalState(() => _isCreating = false);
                                        }
                                     }
                                   }
                                 },
                               ),
                             ),
                            SizedBox(height: 16),
                         ],
                       ),
                     ),
                   ),
                );
              }
           );
        },
     );
  }
  
  IconData _getCampaignIcon(String? type) {
     switch(type) {
        case 'local_visibility': return Icons.location_on_outlined;
        case 'national_boost': return Icons.public_outlined;
        case 'special_promotion': return Icons.local_offer_outlined;
        case 'upcoming_event': return Icons.event_outlined;
        default: return Icons.campaign_outlined;
     }
  }
  
  String _formatCampaignStatus(String? status) {
      switch (status) {
         case 'active': return 'Active';
         case 'pending': return 'En attente';
         case 'completed': return 'Terminée';
         case 'cancelled': return 'Annulée';
         default: return 'Inconnu';
      }
  }
  
  String _formatCampaignDates(String? start, String? end) {
      String startStr = start != null ? DateFormat.yMd('fr_FR').format(DateTime.parse(start)) : '?';
      String endStr = end != null ? DateFormat.yMd('fr_FR').format(DateTime.parse(end)) : '?';
      return "$startStr - $endStr";
  }
  
  Widget _buildPremiumFeatureTeaser({
    required String title,
    required String description,
    required String featureId,
    required IconData icon,
    Color? color,
    Widget? child,
  }) {
    return PremiumFeatureTeaser(
       title: title,
       description: description,
       featureId: featureId,
       child: child ?? Container(height: 150, color: Colors.grey.shade100),
       producerId: widget.producerId,
       color: color,
       icon: icon,
    );
  }
  
  Future<void> _loadAudiences() async {
    try {
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

  Future<void> _loadCampaigns() async {
    if (mounted) {
      setState(() {
        _loadingCampaigns = true;
      });
    }
    
    try {
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
          _campaigns = [];
          _loadingCampaigns = false;
        });
      }
    }
  }

  void _showSnackbar(String message) {
     ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), duration: Duration(seconds: 2)),
     );
  }
}

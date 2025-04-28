import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../utils.dart';
import '../models/growth_analytics_models.dart';
import '../models/producer_type.dart';
import '../services/growth_analytics_service.dart';
import '../services/producer_type_service.dart';
import '../services/auth_service.dart';
import '../widgets/loading_indicator.dart';
import '../widgets/error_message.dart';
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
  // late TabController _tabController; // No longer needed
  
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
    // _tabController = TabController(length: 3, vsync: this); // No longer needed
    _producerType = widget.producerType ?? ProducerType.restaurant;
    _loadInitialData();
  }
  
  @override
  void dispose() {
    // _tabController.dispose(); // No longer needed
    super.dispose();
  }
  
  Future<void> _loadInitialData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _checkingPremiumAccess = true;
      _error = null;
    });
    
    try {
      await _loadProducerDetails();
      
      bool premiumChecksSuccessful = true;
      try {
        await _loadSubscriptionLevel();
        await _checkPremiumFeatureAccess();
      } catch (premiumError) {
        print("⚠️ Erreur lors des vérifications premium (abonnement/accès): $premiumError");
        premiumChecksSuccessful = false;
        if (mounted) {
           setState(() {
             _premiumFeaturesAccess = {
               'advanced_analytics': false,
               'growth_predictions': false,
               'audience_demographics': false,
               'simple_campaigns': false,
               'advanced_targeting': false,
               'campaign_automation': false,
             };
             _currentSubscriptionLevel = _currentSubscriptionLevel;
           });
        }
      } finally {
         if (mounted) {
             setState(() => _checkingPremiumAccess = false);
         }
      }

      final overviewFuture = _analyticsService.getOverview(widget.producerId, producerType: _producerType, period: _selectedPeriod);
      final trendsFuture = _analyticsService.getTrends(widget.producerId, producerType: _producerType, metrics: _trendMetrics, period: _selectedPeriod);
      final recommendationsFuture = _analyticsService.getRecommendations(widget.producerId);

      Future<DemographicsData?> demographicsFuture = (_premiumFeaturesAccess['audience_demographics'] ?? false || !premiumChecksSuccessful) 
          ? _analyticsService.getDemographics(widget.producerId, producerType: _producerType, period: _selectedPeriod).catchError((e) {
              print("📊 Error fetching demographics (likely due to access/502): $e"); 
              return null;
            }) 
          : Future.value(null);

      Future<GrowthPredictions?> predictionsFuture = (_premiumFeaturesAccess['growth_predictions'] ?? false || !premiumChecksSuccessful)
          ? _analyticsService.getPredictions(widget.producerId, producerType: _producerType).catchError((e) {
              print("📈 Error fetching predictions (likely due to access/502): $e"); 
              return null;
            })
          : Future.value(null);

      Future<CompetitorAnalysis?> competitorAnalysisFuture = (_premiumFeaturesAccess['advanced_analytics'] ?? false || !premiumChecksSuccessful)
          ? _analyticsService.getCompetitorAnalysis(widget.producerId, producerType: _producerType, period: _selectedPeriod).catchError((e) {
              print("📉 Error fetching competitor analysis (likely due to access/502): $e"); 
              return null;
            })
          : Future.value(null);

      Future<void> campaignsFuture = (_premiumFeaturesAccess['simple_campaigns'] ?? false || !premiumChecksSuccessful)
          ? _loadCampaigns().catchError((e) { print("📢 Error loading campaigns: $e"); })
          : Future.value();
      Future<void> audiencesFuture = (_premiumFeaturesAccess['advanced_targeting'] ?? false || !premiumChecksSuccessful)
          ? _loadAudiences().catchError((e) { print("🎯 Error loading audiences: $e"); })
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
          
          if (_overview == null || _trends == null || _recommendations == null) {
             _error = 'Impossible de charger les données analytiques principales. Veuillez réessayer.';
           } else if (!premiumChecksSuccessful) {
           }
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Erreur majeure lors du chargement initial des données: $e');
      if (mounted) {
        setState(() {
           if (e.toString().contains("Authentication token is missing") || e.toString().contains("No token available") || e.toString().contains("Invalid token") || e.toString().contains("Unauthorized")) {
             _error = "Session invalide ou expirée. Veuillez vous reconnecter.";
           } else if (e.toString().contains('400') && e.toString().contains('Missing required query parameter: producerType')) {
             _error = 'Erreur: Type de producteur manquant pour la requête.';
           } else if (e.toString().contains('Failed host lookup') || e.toString().contains('SocketException')) {
              _error = 'Erreur de connexion réseau. Vérifiez votre connexion Internet.';
           } else {
              _error = 'Impossible de charger les données analytiques. Veuillez réessayer.\n$e';
           }
          _isLoading = false;
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
          feature,
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
      featureId,
    );
    
    if (shouldUpgrade && mounted) {
      _loadInitialData();
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
          _userPhoto = details['logoUrl'] ?? details['profilePicture'] ?? details['image'] ?? '';
          _userName = _producerName;
        });
      }
    } catch (e) {
      print('❌ Erreur lors du chargement des détails du producteur: $e');
      if (mounted) {
        setState(() {
          _producerName = 'Établissement';
          _userName = 'Établissement';
          _userPhoto = '';
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
    String loadingMessage = _checkingPremiumAccess ? 'Vérification des accès...' : 'Chargement des données...';

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
      body: _error != null
          ? ErrorMessage(
              message: _error!,
              onRetry: _loadInitialData,
            )
          : _buildContent(showLoading, loadingMessage),
    );
  }
  
  Widget _buildContent(bool isLoading, String loadingMessage) {
    return RefreshIndicator(
      onRefresh: _loadInitialData,
      child: Column(
        children: [
          _buildHeader(),
          if (!isLoading) _buildSubscriptionBanner(), // Keep banner under header
          _buildPeriodSelector(), // Keep period selector
          Expanded(
            child: isLoading
                ? Center(child: LoadingIndicator(message: loadingMessage))
                : SingleChildScrollView( // Main scroll view for all content
                    padding: EdgeInsets.all(16.0),
                    child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                          // --- Overview Section --- 
                          _buildSectionHeader("growth_reach.tab_overview".tr()),
                          SizedBox(height: 16),
                          _buildOverviewSection(_overview),
                          SizedBox(height: 32), // Space between sections
                          
                          // --- Trends Section --- 
                          _buildSectionHeader("growth_reach.tab_trends".tr()),
                          SizedBox(height: 16),
                          _buildTrendsSection(_trends),
                          SizedBox(height: 32), // Space between sections

                          // --- Recommendations Section --- 
                          _buildSectionHeader("growth_reach.tab_recommendations".tr()),
                          SizedBox(height: 16),
                          _buildRecommendationsSection(_recommendations),
                          SizedBox(height: 32), // Bottom padding
                       ],
                    ),
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

    // Reduce bottom padding as TabBar is removed
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12), 
      decoration: BoxDecoration(
        color: primaryColor,
        // Optional: Add a subtle shadow or keep it flat
         boxShadow: [
            BoxShadow(
               color: Colors.black.withOpacity(0.1),
               blurRadius: 4,
               offset: Offset(0, 2),
            )
         ]
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
          // SizedBox(height: 12), // Remove space for TabBar
          // Remove TabBar
          /* TabBar(
            controller: _tabController, 
            ...
          ), */
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
  
  Widget _buildOverviewSection(GrowthOverview? overview) {
    bool canAccessDemographics = _premiumFeaturesAccess['audience_demographics'] ?? false;
    bool canAccessPredictions = _premiumFeaturesAccess['growth_predictions'] ?? false;

    // Removed SingleChildScrollView and Padding, handled by the main scroll view now
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section moved out: _buildSectionHeader("growth_reach.kpi_header".tr()),
        // SizedBox(height: 16),
        // Use placeholder based on main isLoading flag passed to _buildContent
        (_overview != null
                ? _buildKpiGrid(_overview!.kpis)
                : _buildNoDataAvailable("growth_reach.no_overview_data".tr())),
        SizedBox(height: 24),

        if (_overview != null)
          _buildEngagementSummaryCard(_overview!.engagementSummary),
        if (_overview != null) SizedBox(height: 24),

        _buildSectionHeader("growth_reach.demographics_header".tr()),
        SizedBox(height: 16),
         (_premiumFeaturesAccess['audience_demographics'] ?? false
                ? (_demographics != null
                    ? _buildDemographicsContent(_demographics)
                    : _buildDataLoadingError("growth_reach.error_loading_demographics".tr()))
                : _buildPremiumFeatureTeaser(
                    title: "growth_reach.demographics_title".tr(),
                    description: "growth_reach.demographics_desc".tr(),
                    featureId: 'audience_demographics',
                    icon: Icons.people_alt_outlined,
                    color: Colors.indigo,
                    producerId: widget.producerId,
                    child: Container(height: 150, child: Center(child: Icon(Icons.bar_chart, size: 50, color: Colors.grey.shade400))), // Placeholder content
                  )),
        SizedBox(height: 24),

        _buildSectionHeader("growth_reach.predictions_header".tr()),
        SizedBox(height: 16),
         (_premiumFeaturesAccess['growth_predictions'] ?? false
                ? (_predictions != null
                    ? _buildPredictionsContent(_predictions)
                    : _buildDataLoadingError("growth_reach.error_loading_predictions".tr()))
                : _buildPremiumFeatureTeaser(
                    title: "growth_reach.predictions_title".tr(),
                    description: "growth_reach.predictions_desc".tr(),
                    featureId: 'growth_predictions',
                    icon: Icons.online_prediction_outlined,
                    color: Colors.purple,
                    producerId: widget.producerId,
                    child: Container(height: 150, child: Center(child: Icon(Icons.trending_up, size: 50, color: Colors.grey.shade400))), // Placeholder content
                  )),
        // No bottom SizedBox needed here, handled by main column spacing
      ],
    );
  }
  
  Widget _buildTrendsSection(GrowthTrends? trends) {
    bool hasAnalyticsAccess = _premiumFeaturesAccess['advanced_analytics'] ?? false;

    // Removed SingleChildScrollView and Padding
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section moved out: _buildSectionHeader("growth_reach.trends_header".tr()),
        // SizedBox(height: 16),
        // Use placeholder based on main isLoading flag passed to _buildContent
        (_trends != null
                ? _buildTrendChartsContent(context) // This now returns a list of cards
                : _buildNoDataAvailable("growth_reach.no_trends_data".tr())),
        SizedBox(height: 24),

        _buildSectionHeader("growth_reach.competitors_header".tr()),
        SizedBox(height: 16),
         (hasAnalyticsAccess
                ? (_competitorAnalysis != null
                    ? _buildCompetitorAnalysisContent(context)
                    : _buildDataLoadingError("growth_reach.error_loading_competitors".tr()))
                : _buildPremiumFeatureTeaser(
                    title: "growth_reach.competitors_title".tr(),
                    description: "growth_reach.competitors_desc".tr(),
                    featureId: 'advanced_analytics',
                    icon: Icons.analytics_outlined,
                    color: Colors.teal,
                    producerId: widget.producerId,
                    child: Container(height: 150, child: Center(child: Icon(Icons.compare_arrows, size: 50, color: Colors.grey.shade400))), // Placeholder content
                  )),
        // No bottom SizedBox needed here
      ],
    );
  }
  
  Widget _buildRecommendationsSection(GrowthRecommendations? recommendations) {
    bool hasCampaignAccess = _premiumFeaturesAccess['simple_campaigns'] ?? false;

    // Removed SingleChildScrollView and Padding
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section moved out: _buildSectionHeader("growth_reach.recommendations_header".tr()),
        // SizedBox(height: 16),
        // Use placeholder based on main isLoading flag
        (recommendations == null || recommendations.recommendations.isEmpty)
                ? _buildNoDataAvailable("growth_reach.no_recommendations_data".tr())
                : _buildRecommendationsList(recommendations.recommendations),
        SizedBox(height: 24),

        _buildSectionHeader("growth_reach.campaigns_header".tr()),
        SizedBox(height: 16),
         (hasCampaignAccess
                ? (_loadingCampaigns
                    ? Center(child: Padding(padding: EdgeInsets.all(16.0), child: LoadingIndicator()))
                    : _buildCampaignsContent())
                : _buildPremiumFeatureTeaser(
                    title: "growth_reach.campaigns_title".tr(),
                    description: "growth_reach.campaigns_desc".tr(),
                    featureId: 'simple_campaigns',
                    icon: Icons.campaign_outlined,
                    color: Colors.green,
                    producerId: widget.producerId,
                    child: Container(height: 150, child: Center(child: Icon(Icons.volume_up_outlined, size: 50, color: Colors.grey.shade400))), // Placeholder content
                  )),
         // No bottom SizedBox needed here
      ],
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
    return NumberFormat.compact(locale: 'fr_FR').format(number);
  }
  
  String _formatPercent(double percent, {bool includeSign = false}) {
    final format = NumberFormat("##0.0'%'", "fr_FR");
    if (percent == 0) return "0%";
    String formatted = format.format(percent.abs() / 100);
    if (includeSign && percent > 0) {
      formatted = "+$formatted";
    } else if (includeSign && percent < 0) {
      formatted = "-$formatted";
    }
    return formatted;
  }
  
  Widget _buildKpiCard(String title, KpiValue kpi) {
    return _KpiCardWidget(title: title, kpi: kpi);
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth < 600 ? 2 : 3;
        final childAspectRatio = crossAxisCount == 2 ? 1.5 : 1.8;

        return GridView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: childAspectRatio,
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
    );
  }
  
  Widget _buildTrendChartsContent(BuildContext context) {
    if (_isLoading) {
      // Use the chart placeholder while loading
      return ListView( 
        padding: EdgeInsets.zero,
        children: _trendMetrics.map((_) => Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: _buildChartPlaceholder(),
        )).toList(),
      );
    }
    if (_error != null || _trends == null) {
      return ErrorMessage(message: _error ?? 'Impossible de charger les tendances.');
    }

    final trendsMap = _trends!.trends;
    if (trendsMap.isEmpty) {
      return _buildNoDataAvailable("growth_reach.no_trends_data".tr());
    }

    // Common helper to parse and format date safely
    String _formatBottomTitle(List<TimePoint> dataPoints, int index) {
      if (index >= 0 && index < dataPoints.length) {
         try {
            final date = DateTime.parse(dataPoints[index].date);
            // Adjust format based on period? For now, use day/month
            return DateFormat('dd/MM', 'fr_FR').format(date);
         } catch (e) {
            // Fallback if date parsing fails
            return 'P${index + 1}'; 
         }
      } 
      return '';
    }
    
    final List<String> metricsToShow = _trendMetrics.where((m) => trendsMap.containsKey(m) && trendsMap[m]!.isNotEmpty).toList();

    return ListView.separated(
      padding: EdgeInsets.zero, // Padding is handled by the cards now
      itemCount: metricsToShow.length,
      separatorBuilder: (context, index) => SizedBox(height: 16),
      itemBuilder: (context, index) {
        String metricKey = metricsToShow[index];
        List<TimePoint> dataPoints = trendsMap[metricKey]!;

        List<FlSpot> spots = dataPoints.asMap().entries.map((e) {
          // Ensure y is never negative if the metric logically can't be
          double yValue = e.value.value.toDouble();
          if (['followers', 'profileViews', 'conversions'].contains(metricKey)) {
             yValue = math.max(0, yValue);
          }
          return FlSpot(e.key.toDouble(), yValue);
        }).toList();

        double chartMinY = 0;
        double chartMaxY = 1;
        if (spots.isNotEmpty) {
           chartMinY = spots.map((spot) => spot.y).reduce(math.min);
           chartMaxY = spots.map((spot) => spot.y).reduce(math.max);
           // Ensure minY is not negative for non-negative metrics
           if (['followers', 'profileViews', 'conversions'].contains(metricKey)) {
              chartMinY = math.max(0, chartMinY);
           }
        }
        // Ensure there's always some vertical space, handle case where min == max
        if (chartMaxY <= chartMinY) chartMaxY = chartMinY + 1;
        double chartPaddingY = (chartMaxY - chartMinY) * 0.15; // Increased padding
        chartMinY = (chartMinY - chartPaddingY < 0 && chartMinY >= 0) ? 0 : chartMinY - chartPaddingY;
        chartMaxY += chartPaddingY;

        final primaryColor = Theme.of(context).primaryColor;
        final lineColor = primaryColor;
        final belowBarColor = primaryColor.withOpacity(0.2); // Slightly stronger gradient
        final gridColor = Colors.grey.shade300;
        final touchTooltipBgColor = Colors.blueGrey.shade800;
        final titleStyle = Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold);
        final axisLabelStyle = Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600);

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          clipBehavior: Clip.antiAlias, // Prevent chart overflow
          child: Padding(
             padding: const EdgeInsets.fromLTRB(16, 16, 16, 12), // Adjusted padding
             child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'trends_title.${metricKey}'.tr(),
                    style: titleStyle,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 250,
                    child: LineChart(
                      LineChartData(
                        minY: chartMinY,
                        maxY: chartMaxY,
                        // More subtle grid lines
                        gridData: FlGridData(
                           show: true,
                           drawVerticalLine: true,
                           horizontalInterval: (chartMaxY - chartMinY) / 4, // Adjust interval
                           verticalInterval: spots.length > 1 ? (spots.length / 5).ceilToDouble() : 1,
                           getDrawingHorizontalLine: (value) {
                              return FlLine(
                                 color: gridColor.withOpacity(0.5),
                                 strokeWidth: 0.8,
                                 dashArray: [4, 4], // Make dashed
                              );
                           },
                           getDrawingVerticalLine: (value) {
                              return FlLine(
                                 color: gridColor.withOpacity(0.3),
                                 strokeWidth: 0.8,
                                 dashArray: [4, 4], // Make dashed
                              );
                           },
                        ),
                        titlesData: FlTitlesData(
                          // Hide top/right titles
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          // Left Axis (Y)
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 45, // Increased reserved size
                              // interval: (chartMaxY - chartMinY) / 4, // Auto interval is usually fine
                              getTitlesWidget: (value, meta) {
                                // Don't show title for min value if it's adjusted padding
                                if (value == meta.min) return Container();
                                return SideTitleWidget(
                                  meta: meta, 
                                  space: 8.0,
                                  child: Text(
                                    _formatNumber(value), // Use compact number format
                                    style: axisLabelStyle,
                                    textAlign: TextAlign.right,
                                  ),
                                );
                              },
                            ),
                            // Add Y-axis title
                            axisNameWidget: Text('Valeur', style: axisLabelStyle),
                            axisNameSize: 20,
                          ),
                          // Bottom Axis (X)
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 35, // Increased reserved size
                              interval: spots.length > 1 ? (spots.length / 5).ceilToDouble() : 1,
                              getTitlesWidget: (value, meta) {
                                final index = value.toInt();
                                // Only show labels for actual data points
                                if (index >= 0 && index < dataPoints.length) {
                                  // Show fewer labels if too crowded
                                  if (spots.length > 10 && index % 2 != 0 && index != spots.length -1) {
                                     return Container(); 
                                  }
                                  return SideTitleWidget(
                                    meta: meta,
                                    space: 8.0,
                                    child: Text(
                                      _formatBottomTitle(dataPoints, index), // Use formatted date
                                      style: axisLabelStyle,
                                    ),
                                  );
                                }
                                return Container();
                              },
                            ),
                            // Add X-axis title
                            axisNameWidget: Text('Période', style: axisLabelStyle), 
                            axisNameSize: 20,
                          ),
                        ),
                        // Hide border or make it subtle
                        borderData: FlBorderData(show: false),
                        // Enhanced Tooltip
                        lineTouchData: LineTouchData(
                          handleBuiltInTouches: true, // Enable tap, drag etc.
                          getTouchedSpotIndicator: (LineChartBarData barData, List<int> spotIndexes) {
                             return spotIndexes.map((index) {
                                return TouchedSpotIndicatorData(
                                  FlLine(color: primaryColor.withOpacity(0.5), strokeWidth: 1, dashArray: [4, 4]),
                                  FlDotData(
                                    show: true,
                                    getDotPainter: (spot, percent, barData, index) =>
                                        FlDotCirclePainter(radius: 6, color: lineColor, strokeWidth: 2, strokeColor: Colors.white),
                                  ),
                                );
                             }).toList();
                           },
                          touchTooltipData: LineTouchTooltipData(
                            tooltipRoundedRadius: 8,
                            getTooltipColor: (touchedSpot) => touchTooltipBgColor,
                            getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                              return touchedBarSpots.map((barSpot) {
                                final flSpot = barSpot;
                                final dataIndex = flSpot.x.toInt();
                                String dateText = _formatBottomTitle(dataPoints, dataIndex);
                                                                
                                return LineTooltipItem(
                                  '${_formatNumber(flSpot.y)} \n',
                                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                  children: [
                                    TextSpan(
                                      text: dateText,
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.8),
                                        fontWeight: FontWeight.normal,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                  textAlign: TextAlign.left, 
                                );
                              }).toList();
                            },
                          ),
                        ),
                        // Line Style
                        lineBarsData: [
                          LineChartBarData(
                            spots: spots,
                            isCurved: true,
                            curveSmoothness: 0.4, // Adjust smoothness
                            color: lineColor,
                            barWidth: 4, // Slightly thicker line
                            isStrokeCapRound: true,
                            // Show subtle dots on data points
                            dotData: FlDotData(
                              show: true,
                              getDotPainter: (spot, percent, barData, index) => 
                                 FlDotCirclePainter(radius: 3, color: lineColor.withOpacity(0.8), strokeWidth: 0)
                            ),
                            // Enhanced gradient below line
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                colors: [
                                   belowBarColor.withOpacity(0.5), 
                                   belowBarColor.withOpacity(0.0),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                          ),
                        ],
                      ),
                      // Add duration for animation on data change (optional)
                      // swapAnimationDuration: Duration(milliseconds: 250),
                    ),
                  ),
                ],
             ),
          ),
        );
      },
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                       Flexible(child: _buildSummaryItem(Icons.post_add, summary.posts, "growth_reach.engagement_posts".tr())),
                       Flexible(child: _buildSummaryItem(Icons.favorite_border, summary.likes, "growth_reach.engagement_likes".tr())),
                       Flexible(child: _buildSummaryItem(Icons.comment_outlined, summary.comments, "growth_reach.engagement_comments".tr())),
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
              textAlign: TextAlign.center,
           ),
        ],
     );
  }
  
  Widget _buildDemographicsContent(DemographicsData? demographics) {
     if (demographics == null) {
        return _buildNoDataAvailable("growth_reach.no_demographics_data".tr());
     }
     
     final theme = Theme.of(context);
     final List<Color> pieChartColors = [ // Define a color palette
       theme.primaryColor,
       Colors.teal.shade300,
       Colors.blue.shade300,
       Colors.purple.shade300,
       Colors.orange.shade300,
       Colors.pink.shade200,
       Colors.amber.shade400,
     ];

     // Prepare data for pie charts
     final ageData = _preparePieData(demographics.ageDistribution, pieChartColors);
     final genderData = _preparePieData(demographics.genderDistribution, pieChartColors);

     return Card(
        elevation: 1.5, // Consistent elevation
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), // Consistent rounding
        clipBehavior: Clip.antiAlias,
        child: Padding(
           padding: const EdgeInsets.all(16.0),
           child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                 // Age Distribution - Row with Chart and Legend
                 _buildSectionHeader("growth_reach.demographics_age_title".tr()),
                 SizedBox(height: 16),
                 (ageData.isEmpty)
                    ? Text("growth_reach.not_available".tr(), style: TextStyle(color: Colors.grey))
                    : Row(
                       children: [
                          Expanded(
                             flex: 2,
                             child: SizedBox(
                                height: 150,
                                child: PieChart(
                                   PieChartData(
                                      sections: ageData,
                                      centerSpaceRadius: 40, // Make it a donut chart
                                      sectionsSpace: 2,
                                      pieTouchData: PieTouchData(enabled: false), // Disable touch for simplicity
                                      borderData: FlBorderData(show: false),
                                   ),
                                   swapAnimationDuration: Duration(milliseconds: 150), // Optional if data updates
                                   swapAnimationCurve: Curves.linear,
                                ),
                             ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                             flex: 3,
                             child: _buildLegend(demographics.ageDistribution, pieChartColors),
                          ),
                       ],
                    ),
                 SizedBox(height: 24),
                 
                 // Gender Distribution - Row with Chart and Legend
                 _buildSectionHeader("growth_reach.demographics_gender_title".tr()),
                 SizedBox(height: 16),
                 (genderData.isEmpty)
                    ? Text("growth_reach.not_available".tr(), style: TextStyle(color: Colors.grey))
                    : Row(
                       children: [
                          Expanded(
                             flex: 2,
                             child: SizedBox(
                                height: 120, // Smaller chart for gender
                                child: PieChart(
                                   PieChartData(
                                      sections: genderData,
                                      centerSpaceRadius: 30,
                                      sectionsSpace: 2,
                                      pieTouchData: PieTouchData(enabled: false),
                                      borderData: FlBorderData(show: false),
                                   ),
                                ),
                             ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                             flex: 3,
                             child: _buildLegend(demographics.genderDistribution, pieChartColors),
                          ),
                       ],
                    ),
                 SizedBox(height: 24),
                 
                 // Top Locations
                 _buildSectionHeader("growth_reach.demographics_location_title".tr()),
                 SizedBox(height: 16),
                 _buildTopLocations(demographics.topLocations),
              ],
           ),
        ),
     );
  }
  
  // Helper to prepare PieChartSectionData
  List<PieChartSectionData> _preparePieData(Map<String, double> distribution, List<Color> colors) {
     if (distribution.isEmpty) return [];

     final totalValue = distribution.values.fold(0.0, (sum, item) => sum + item);
     if (totalValue <= 0) return [];

     final sortedEntries = distribution.entries.toList()
       ..sort((a, b) => b.value.compareTo(a.value)); // Sort for consistent color assignment

     return sortedEntries.asMap().entries.map((entry) {
        int index = entry.key;
        String key = entry.value.key;
        double value = entry.value.value;
        double percentage = (value / totalValue) * 100;
        final color = colors[index % colors.length]; // Cycle through colors

        return PieChartSectionData(
           value: value, 
           title: '${percentage.toStringAsFixed(0)}%', // Show percentage on slice
           radius: 40, // Adjust radius
           color: color,
           titleStyle: TextStyle(
              fontSize: 10, 
              fontWeight: FontWeight.bold, 
              color: Colors.white, // Or calculate contrast color
              shadows: [Shadow(color: Colors.black.withOpacity(0.5), blurRadius: 2)]
           ),
           // Optional: Add border or other effects
        );
     }).toList();
  }

  // Helper to build legend
  Widget _buildLegend(Map<String, double> distribution, List<Color> colors) {
     if (distribution.isEmpty) return SizedBox.shrink();
     
     final totalValue = distribution.values.fold(0.0, (sum, item) => sum + item);
     if (totalValue <= 0) return SizedBox.shrink();
     
     final sortedEntries = distribution.entries.toList()
       ..sort((a, b) => b.value.compareTo(a.value));

     return Column(
       crossAxisAlignment: CrossAxisAlignment.start,
       mainAxisSize: MainAxisSize.min, // Take minimum space needed
       children: sortedEntries.asMap().entries.map((entry) {
         int index = entry.key;
         String key = entry.value.key;
         double value = entry.value.value;
         double percentage = (value / totalValue) * 100;
         final color = colors[index % colors.length];

         return Padding(
           padding: const EdgeInsets.symmetric(vertical: 3.0),
           child: Row(
             children: [
               Container(
                 width: 10, height: 10,
                 decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                 ),
               ),
               SizedBox(width: 8),
               Flexible(
                 child: Text(
                   '$key (${percentage.toStringAsFixed(1)}%)', 
                   style: TextStyle(fontSize: 12),
                   overflow: TextOverflow.ellipsis,
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

      // Using a Column instead of ListView for simplicity within the Card
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: locations.take(5).map((loc) { // Limit to top 5
           final name = loc['city'] ?? loc['region'] ?? loc['country'] ?? 'Inconnu';
           final percentage = (loc['percentage'] ?? 0.0).toDouble();
           return Padding(
             padding: const EdgeInsets.symmetric(vertical: 4.0),
             child: Row(
               children: [
                 Icon(Icons.location_pin, size: 16, color: Colors.grey.shade600),
                 SizedBox(width: 8),
                 Expanded(
                   child: Text(
                     "$name (${_formatPercent(percentage)})",
                     style: TextStyle(fontSize: 14),
                   ),
                 ),
               ],
             ),
           );
         }).toList(),
      );
  }
  
  Widget _buildPredictionsContent(GrowthPredictions? predictions) {
     if (predictions == null || predictions.predictions.isEmpty) {
        return _buildNoDataAvailable("growth_reach.no_predictions_data".tr());
     }
     
     final theme = Theme.of(context);

     return Card(
        elevation: 1.5, // Consistent elevation
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), // Consistent rounding
        clipBehavior: Clip.antiAlias,
        child: Padding(
           padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0), // Adjust padding
           child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: predictions.predictions.entries.map((entry) {
                  String label;
                  IconData predIcon;
                  switch(entry.key) {
                      case 'predictedFollowers': 
                         label = 'growth_reach.prediction_followers'.tr(); 
                         predIcon = Icons.people_alt_outlined;
                         break;
                      case 'predictedViews': 
                         label = 'growth_reach.prediction_views'.tr(); 
                         predIcon = Icons.visibility_outlined;
                         break;
                      case 'predictedConversions': 
                         label = 'growth_reach.prediction_conversions'.tr(); 
                         predIcon = Icons.monetization_on_outlined;
                         break;
                      default: 
                         label = entry.key; 
                         predIcon = Icons.analytics_outlined;
                  }
                 final prediction = entry.value;
                 
                 // Confidence Visualization
                 double confidenceValue = 0.0;
                 Color confidenceColor = Colors.grey;
                 String confidenceText = 'growth_reach.prediction_confidence_low'.tr();
                 switch (prediction.confidence) {
                    case 'high': 
                       confidenceValue = 1.0; 
                       confidenceColor = Colors.green.shade600;
                       confidenceText = 'growth_reach.prediction_confidence_high'.tr();
                       break;
                    case 'medium': 
                       confidenceValue = 0.6; 
                       confidenceColor = Colors.orange.shade600;
                       confidenceText = 'growth_reach.prediction_confidence_medium'.tr();
                       break;
                    case 'low':
                    default: 
                       confidenceValue = 0.25; 
                       confidenceColor = Colors.red.shade600;
                       confidenceText = 'growth_reach.prediction_confidence_low'.tr();
                       break;
                 }

                 return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12.0), // More vertical space
                    child: Row(
                       crossAxisAlignment: CrossAxisAlignment.center, // Center items vertically
                       children: [
                          Icon(predIcon, size: 20, color: theme.primaryColor.withOpacity(0.8)),
                          SizedBox(width: 12),
                          Expanded(
                             child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                   Text(
                                      label,
                                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                                   ),
                                   SizedBox(height: 2),
                                   Text(
                                      _formatNumber(prediction.value),
                                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: theme.primaryColor),
                                   ),
                                ],
                             ),
                          ),
                          SizedBox(width: 12),
                          // Confidence Indicator
                          Column(
                             crossAxisAlignment: CrossAxisAlignment.end,
                             children: [
                                Container(
                                   width: 60, // Fixed width for the indicator bar
                                   child: LinearPercentIndicator(
                                      percent: confidenceValue,
                                      lineHeight: 6.0,
                                      backgroundColor: Colors.grey.shade300,
                                      progressColor: confidenceColor,
                                      barRadius: Radius.circular(3),
                                      padding: EdgeInsets.zero,
                                   ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                   confidenceText,
                                   style: theme.textTheme.bodySmall?.copyWith(fontSize: 10, color: confidenceColor),
                                   textAlign: TextAlign.end,
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
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
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
                _buildCompetitorRow(
                  "Followers", 
                  analysis.averageCompetitorMetrics.followers?.toDouble() ?? 0,
                  analysis.yourMetrics.followers?.toDouble() ?? 0
                ),
                _buildCompetitorRow(
                   "Taux d'engagement",
                    analysis.averageCompetitorMetrics.engagementRate?.toDouble() ?? 0,
                    analysis.yourMetrics.engagementRate?.toDouble() ?? 0,
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
                 Expanded(
                    child: Text(comp.name, overflow: TextOverflow.ellipsis)
                 ),
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
       IconData icon = diff > 0 ? Icons.arrow_downward : (diff < 0 ? Icons.arrow_upward : Icons.remove);
       String diffText = isPercent ? _formatPercent(diff.abs(), includeSign: diff != 0) : _formatNumber(diff.abs()); 
       comparisonWidget = Row(
         mainAxisSize: MainAxisSize.min,
         children: [
           Text(" (", style: TextStyle(fontSize: 12, color: color)),
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
          Expanded(
            flex: 3,
            child: Text(" • $label", style: TextStyle(fontSize: 14), overflow: TextOverflow.ellipsis)
          ),
           Expanded(
             flex: 4,
             child: Row(
               mainAxisAlignment: MainAxisAlignment.end,
               children: [
                  Text(formattedValue, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  SizedBox(width: 4),
                  Flexible(child: comparisonWidget),
               ],
             ),
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
     String priorityText;
     switch (rec.priority) {
        case 'high': 
           icon = Icons.priority_high; 
           color = Colors.red.shade600; 
           priorityText = "growth_reach.priority_high".tr();
           break;
        case 'medium': 
           icon = Icons.flag_outlined; 
           color = Colors.orange.shade700; 
           priorityText = "growth_reach.priority_medium".tr();
           break;
        case 'low':
        default: 
           icon = Icons.lightbulb_outline; 
           color = Colors.blue.shade600; 
           priorityText = "growth_reach.priority_low".tr();
           break;
     }

     String buttonText;
     IconData buttonIcon;
     VoidCallback? onPressedAction;

      switch (rec.action.type) {
        case 'boost_post':
          buttonText = 'growth_reach.rec_action_boost'.tr();
          buttonIcon = Icons.rocket_launch_outlined;
          onPressedAction = () { _showSnackbar('Action Bientôt disponible: Booster Post ${rec.action.postId}'); };
          break;
        case 'navigate_to_messaging':
          buttonText = 'growth_reach.rec_action_message'.tr();
          buttonIcon = Icons.send_outlined;
          onPressedAction = () => Navigator.pushNamed(context, '/messaging');
          break;
         case 'navigate_to_profile_edit':
           buttonText = 'growth_reach.rec_action_edit_profile'.tr();
           buttonIcon = Icons.edit_outlined;
           onPressedAction = () => Navigator.pushNamed(context, '/profile/me');
           break;
        case 'create_campaign':
           buttonText = 'growth_reach.rec_action_create_campaign'.tr();
           buttonIcon = Icons.campaign_outlined;
           onPressedAction = () => _showCampaignCreatorDialog();
           break;
        default:
          buttonText = 'growth_reach.rec_action_learn_more'.tr();
          buttonIcon = Icons.info_outline;
          onPressedAction = null; // Or open a help link?
     }

     final theme = Theme.of(context);

     return Card(
        elevation: 1.5, // Slightly reduced elevation
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), // Consistent rounding
        margin: EdgeInsets.zero, // Margin handled by ListView.separated
        clipBehavior: Clip.antiAlias, // Clip content
        child: ListTile(
          contentPadding: EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
          // Leading icon with colored background
          leading: CircleAvatar(
             radius: 20,
             backgroundColor: color.withOpacity(0.15),
             child: Icon(icon, color: color, size: 22),
          ),
          // Title of the recommendation
          title: Text(
             rec.title,
             style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
             maxLines: 2,
             overflow: TextOverflow.ellipsis,
          ),
          // Description below the title
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
               rec.description,
               style: theme.textTheme.bodySmall?.copyWith(color: theme.textTheme.bodySmall?.color?.withOpacity(0.7)),
               maxLines: 3,
               overflow: TextOverflow.ellipsis,
            ),
          ),
          // Trailing action button (if available)
          trailing: onPressedAction == null ? null : 
             Tooltip(
               message: buttonText, // Show full text on hover/long press
               child: IconButton(
                  icon: Icon(buttonIcon, color: color, size: 24),
                  onPressed: onPressedAction,
                  visualDensity: VisualDensity.compact, // Reduce padding around icon
                  splashRadius: 24, // Control splash size
               ), 
             ),
          isThreeLine: true, // Allow subtitle to take more space
          dense: false, // Adjust vertical density if needed
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
                     Expanded(
                       child: Text(
                          "growth_reach.campaigns_my_campaigns".tr(),
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                               title: Text(campaign['name'] ?? 'Campagne sans nom', overflow: TextOverflow.ellipsis),
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
    required Widget child,
    required String producerId,
    Color? color,
    IconData? icon,
  }) {
    return PremiumFeatureTeaser(
       title: title,
       description: description,
       featureId: featureId,
       child: child,
       producerId: producerId,
       color: color,
       icon: icon ?? Icons.lock_outline,
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

  Widget _buildDataLoadingError(String message) {
     return Card(
        elevation: 1,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.orange.shade200)
        ),
        color: Colors.orange.shade50,
        child: Padding(
           padding: const EdgeInsets.all(16.0),
           child: Row(
             children: [
               Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 20),
               SizedBox(width: 12),
               Expanded(
                 child: Text(
                   message, 
                   style: TextStyle(color: Colors.orange.shade900, fontWeight: FontWeight.w500),
                 ),
               ),
             ],
           ),
        ),
     );
  }

  Widget _buildShimmer({required Widget child}) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: child,
    );
  }

  Widget _buildKpiPlaceholder() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(width: 80, height: 14, color: Colors.white),
            SizedBox(height: 8),
            Container(width: 60, height: 24, color: Colors.white),
            SizedBox(height: 8),
            Row(
              children: [
                Container(width: 16, height: 16, color: Colors.white),
                SizedBox(width: 4),
                Container(width: 40, height: 14, color: Colors.white),
                SizedBox(width: 4),
                Container(width: 50, height: 13, color: Colors.white),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildChartPlaceholder() {
    return _buildShimmer(
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          height: 250,
          padding: EdgeInsets.all(16),
          child: Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               Container(width: 150, height: 20, color: Colors.white),
               SizedBox(height: 16),
               Expanded(
                 child: Container(color: Colors.white),
               ),
             ],
          ),
        ),
      ),
    );
  }

  Widget _buildGenericPlaceholder({double height = 150}) {
     return _buildShimmer(
       child: Card(
         elevation: 1,
         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
         child: Container(
           height: height,
           width: double.infinity,
           color: Colors.white,
         ),
       ),
     );
  }

  Widget _buildRecommendationsPlaceholder() {
     return _buildShimmer(
       child: ListView.separated(
         shrinkWrap: true,
         physics: NeverScrollableScrollPhysics(),
         itemCount: 3,
         separatorBuilder: (_, __) => SizedBox(height: 12),
         itemBuilder: (context, index) {
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
                        Container(width: 20, height: 20, color: Colors.white),
                        SizedBox(width: 8),
                        Container(width: MediaQuery.of(context).size.width * 0.5, height: 16, color: Colors.white),
                      ],
                    ),
                    SizedBox(height: 8),
                    Container(width: double.infinity, height: 14, color: Colors.white),
                    SizedBox(height: 6),
                    Container(width: MediaQuery.of(context).size.width * 0.7, height: 14, color: Colors.white),
                    SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Container(width: 100, height: 30, color: Colors.white),
                    ),
                  ],
                ),
              ),
            );
         },
       ),
     );
  }
}

class _KpiCardWidget extends StatelessWidget {
  final String title;
  final KpiValue kpi;

  const _KpiCardWidget({required this.title, required this.kpi});

  // Format number in compact form
  String _formatNumber(double number) {
    return NumberFormat.compact(locale: 'fr_FR').format(number);
  }
  
  // Format percent with optional sign
  String _formatPercent(double percent, {bool includeSign = false}) {
    final format = NumberFormat("##0.0'%'", "fr_FR");
    if (percent == 0) return "0%";
    String formatted = format.format(percent.abs() / 100);
    if (includeSign && percent > 0) {
      formatted = "+$formatted";
    } else if (includeSign && percent < 0) {
      formatted = "-$formatted";
    }
    return formatted;
  }

  // Placeholder for a simple sparkline chart
  Widget _buildSparkline(BuildContext context, bool isPositive) {
    // TODO: Replace with actual sparkline implementation if data is available
    final Color lineColor = isPositive ? Colors.green.shade300 : Colors.red.shade300;
    return Container(
      height: 20, // Adjust height as needed
      child: CustomPaint(
        painter: _SparklinePainter(isPositive: isPositive, color: lineColor),
        size: Size(double.infinity, 20),
      ),
      margin: const EdgeInsets.only(bottom: 6.0),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Use slightly less saturated colors for better contrast/modern feel
    final bool isPositive = kpi.changePercent >= 0; // Consider 0% as neutral/positive visually
    final Color changeColor = isPositive ? Colors.green.shade700 : Colors.red.shade700;
    final IconData changeIcon = isPositive ? Icons.arrow_upward : Icons.arrow_downward;

    return Card(
      elevation: 2,
      // Slightly more rounded corners
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      // Add subtle gradient or background color? (Optional)
      // color: theme.cardColor.withOpacity(0.95),
      clipBehavior: Clip.antiAlias, // Ensure content respects border radius
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        // Use IntrinsicHeight to make the column expand vertically if needed
        child: IntrinsicHeight(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title - slightly smaller, less prominent color
              Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.textTheme.bodySmall?.color ?? Colors.grey.shade700,
                ),
                 maxLines: 1,
                 overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 8),
              // Main Value - larger, bolder
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  _formatNumber(kpi.current),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.textTheme.titleLarge?.color ?? Colors.black,
                  ),
                   maxLines: 1,
                ),
              ),
              // Spacer to push the trend info to the bottom
              Spacer(),
              // Placeholder for the Sparkline
              _buildSparkline(context, isPositive),
              // Trend Info Row
              Row(
                children: [
                  // Only show icon if there's a non-zero change
                  if (kpi.changePercent != 0)
                     Icon(changeIcon, size: 16, color: changeColor)
                  else // Placeholder for alignment when no icon
                     SizedBox(width: 16),
                  SizedBox(width: 4),
                  // Change Value (Absolute)
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        // Only show absolute change if non-zero
                        kpi.changePercent != 0 ? _formatNumber(kpi.change.abs()) : '-',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: changeColor,
                        ),
                        maxLines: 1,
                      ),
                    ),
                  ),
                  SizedBox(width: 6),
                  // Change Percentage
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        // Format percentage, include sign only if non-zero
                        "(${_formatPercent(kpi.changePercent, includeSign: kpi.changePercent != 0)})",
                        style: TextStyle(
                          fontSize: 13,
                          color: changeColor.withOpacity(0.9),
                        ),
                        maxLines: 1,
                      ),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}

// Simple Custom Painter for the Sparkline Placeholder
class _SparklinePainter extends CustomPainter {
  final bool isPositive;
  final Color color;

  _SparklinePainter({required this.isPositive, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final path = Path();
    // Simple V shape for downward trend, or inverse V for upward
    if (isPositive) {
      path.moveTo(0, size.height * 0.7);
      path.lineTo(size.width * 0.3, size.height * 0.2);
      path.lineTo(size.width * 0.6, size.height * 0.5);
      path.lineTo(size.width, size.height * 0.1);
    } else {
      path.moveTo(0, size.height * 0.3);
      path.lineTo(size.width * 0.3, size.height * 0.8);
      path.lineTo(size.width * 0.6, size.height * 0.5);
      path.lineTo(size.width, size.height * 0.9);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

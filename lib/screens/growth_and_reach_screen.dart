import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import 'utils.dart';
import '../models/growth_analytics_models.dart';
import '../services/growth_analytics_service.dart';
import '../widgets/loading_indicator.dart';
import '../widgets/error_message.dart';
import '../widgets/trend_chart.dart';

class GrowthAndReachScreen extends StatefulWidget {
  final String producerId;
  
  const GrowthAndReachScreen({
    Key? key,
    required this.producerId,
  }) : super(key: key);

  @override
  _GrowthAndReachScreenState createState() => _GrowthAndReachScreenState();
}

class _GrowthAndReachScreenState extends State<GrowthAndReachScreen> with SingleTickerProviderStateMixin {
  final GrowthAnalyticsService _analyticsService = GrowthAnalyticsService();
  late TabController _tabController;
  
  GrowthOverview? _overview;
  GrowthTrends? _trends;
  GrowthRecommendations? _recommendations;
  
  bool _isLoading = true;
  String? _error;
  String _selectedPeriod = '30'; // 30 jours par défaut
  
  // Nouvelles variables pour l'affichage du profil connecté
  String _userName = '';
  String _userPhoto = '';
  Map<String, dynamic>? _userProfile;
  
  // Variables pour les campagnes
  bool _showCampaignCreator = false;
  String _selectedCampaignType = 'Visibilité locale';
  final List<String> _campaignTypes = [
    'Visibilité locale',
    'Boost national',
    'Promotion spéciale',
    'Événement à venir'
  ];
  final Map<String, double> _campaignPrices = {
    'Visibilité locale': 29.99,
    'Boost national': 59.99,
    'Promotion spéciale': 39.99,
    'Événement à venir': 49.99
  };
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadInitialData();
    _loadUserProfile();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
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
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _loadUserProfile() async {
    try {
      final baseUrl = getBaseUrl();
      final url = Uri.parse('$baseUrl/api/users/me');
      
      final response = await http.get(
        url,
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 200) {
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
        title: const Text('Croissance & Portée'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Aperçu'),
            Tab(text: 'Tendances'),
            Tab(text: 'Recommandations'),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.calendar_today),
            tooltip: 'Période d\'analyse',
            onSelected: _updatePeriod,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: '7',
                child: Text('7 jours'),
              ),
              const PopupMenuItem(
                value: '30',
                child: Text('30 jours'),
              ),
              const PopupMenuItem(
                value: '90',
                child: Text('90 jours'),
              ),
              const PopupMenuItem(
                value: '365',
                child: Text('365 jours'),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Erreur: $_error'))
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOverviewTab(),
                    _buildTrendsTab(),
                    _buildRecommendationsTab(),
                  ],
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          setState(() {
            _showCampaignCreator = true;
          });
          _showCampaignDialog();
        },
        icon: const Icon(Icons.campaign),
        label: const Text('Nouvelle campagne'),
        backgroundColor: Colors.deepPurple,
      ),
    );
  }
  
  Widget _buildOverviewTab() {
    if (_overview == null) {
      return const Center(child: Text('Aucune donnée disponible'));
    }
    
    // Récupérer les données d'aperçu
    final producer = _overview!.producer;
    final engagement = _overview!.engagement;
    final followers = _overview!.followers;
    final reach = _overview!.reach;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête du producteur avec le profil connecté
          _buildConnectedProducerHeader(),
          const SizedBox(height: 24),
          
          // Statistiques principales
          _buildStatCards(engagement, followers, reach),
          const SizedBox(height: 24),
          
          // Activité récente
          _buildRecentActivitySection(),
          const SizedBox(height: 24),
          
          // Démographie des followers
          _buildDemographicsSection(),
          const SizedBox(height: 24),
          
          // Concurrents
          _buildCompetitorsSection(),
        ],
      ),
    );
  }
  
  Widget _buildConnectedProducerHeader() {
    final theme = Theme.of(context);
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundImage: _userPhoto.isNotEmpty 
                      ? NetworkImage(_userPhoto) 
                      : const AssetImage('assets/images/default_profile.png') as ImageProvider,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _userName,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Restaurant Le Gourmet',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          Chip(
                            label: const Text('Bistro'),
                            backgroundColor: Colors.amber.withOpacity(0.2),
                          ),
                          Chip(
                            label: const Text('Français'),
                            backgroundColor: Colors.blue.withOpacity(0.2),
                          ),
                          Chip(
                            label: const Text('Gastronomique'),
                            backgroundColor: Colors.green.withOpacity(0.2),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildQuickStat('Visibilité', '83%', Icons.visibility, Colors.blue),
                _buildQuickStat('Engagement', '25.3', Icons.thumb_up, Colors.green),
                _buildQuickStat('Conversion', '4.8%', Icons.trending_up, Colors.orange),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildQuickStat(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
  
  Widget _buildRecentActivitySection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Activité Récente',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildActivityItem(
              icon: Icons.person_add,
              title: 'Nouveaux abonnés',
              value: '+12',
              change: '+10.7%',
              isPositive: true,
            ),
            const Divider(),
            _buildActivityItem(
              icon: Icons.remove_red_eye,
              title: 'Vues du profil',
              value: '342',
              change: '+5.2%',
              isPositive: true,
            ),
            const Divider(),
            _buildActivityItem(
              icon: Icons.comment,
              title: 'Commentaires',
              value: '87',
              change: '-2.3%',
              isPositive: false,
            ),
            const Divider(),
            _buildActivityItem(
              icon: Icons.share,
              title: 'Partages',
              value: '26',
              change: '+12.4%',
              isPositive: true,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildActivityItem({
    required IconData icon,
    required String title,
    required String value,
    required String change,
    required bool isPositive,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.deepPurple.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.deepPurple),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 16),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            change,
            style: TextStyle(
              color: isPositive ? Colors.green : Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatCards(
    EngagementStats engagement, 
    FollowersStats followers,
    ReachStats reach
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Performance générale',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        SizedBox(height: 8),
        
        // Ligne 1: Engagement
        Card(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Engagement',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _statItem(
                      Icons.post_add, 
                      '${engagement.posts}', 
                      'Publications'
                    ),
                    _statItem(
                      Icons.thumb_up, 
                      '${engagement.likes}', 
                      'J\'aime'
                    ),
                    _statItem(
                      Icons.comment, 
                      '${engagement.comments}', 
                      'Commentaires'
                    ),
                    _statItem(
                      Icons.share, 
                      '${engagement.shares}', 
                      'Partages'
                    ),
                  ],
                ),
                Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Engagement moyen par post: ',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    Text(
                      '${engagement.averagePerPost.toStringAsFixed(1)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 8),
        
        // Ligne 2: Followers et Portée
        Row(
          children: [
            // Followers
            Expanded(
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Abonnés',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 16),
                      _statItem(
                        Icons.people, 
                        '${followers.total}', 
                        'Total',
                        big: true,
                      ),
                      SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _statItem(
                            Icons.person_add, 
                            '+${followers.new_}', 
                            'Nouveaux'
                          ),
                          Text(
                            '${followers.growthRate.toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontWeight: FontWeight.bold, 
                              color: Colors.green
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // Portée
            Expanded(
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Portée',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 8),
                      _statItem(
                        Icons.tag, 
                        '${reach.mentions}', 
                        'Mentions'
                      ),
                      SizedBox(height: 4),
                      _statItem(
                        Icons.favorite_border, 
                        '${reach.interestedUsers}', 
                        'Intéressés'
                      ),
                      SizedBox(height: 4),
                      _statItem(
                        Icons.check_circle_outline, 
                        '${reach.choiceUsers}', 
                        'Choices'
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  Widget _statItem(IconData icon, String value, String label, {bool big = false}) {
    return Column(
      children: [
        Icon(icon, color: Colors.blue.shade700, size: big ? 36 : 20),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: big ? 24 : 16,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: big ? 14 : 12,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }
  
  Widget _buildDemographicsSection() {
    if (_overview == null) return SizedBox();
    
    final demographics = _overview!.demographics;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Démographie des abonnés',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        SizedBox(height: 8),
        
        // Démographie - Cartes Âge et Genre sur la même ligne
        Row(
          children: [
            // Distribution par âge
            Expanded(
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Âge',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      ...demographics.age.distribution.entries
                          .toList()
                          .map((entry) => _buildPercentageBar(
                            entry.key, 
                            entry.value,
                            Colors.blue.shade700,
                          )).toList(),
                    ],
                  ),
                ),
              ),
            ),
            
            // Distribution par genre
            Expanded(
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Genre',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      ...demographics.gender.distribution.entries
                          .toList()
                          .map((entry) => _buildPercentageBar(
                            entry.key, 
                            entry.value,
                            Colors.purple.shade700,
                          )).toList(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        
        SizedBox(height: 8),
        
        // Distribution par localisation
        Card(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Localisation',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                ...demographics.location.distribution.entries
                    .toList()
                    .map((entry) => _buildPercentageBar(
                      entry.key, 
                      entry.value,
                      Colors.green.shade700,
                    )).toList(),
              ],
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildPercentageBar(String label, double percentage, Color barColor) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label),
              Text('${percentage.toStringAsFixed(1)}%'),
            ],
          ),
          SizedBox(height: 4),
          LinearProgressIndicator(
            value: percentage / 100,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
          ),
        ],
      ),
    );
  }
  
  Widget _buildCompetitorsSection() {
    if (_overview == null || _overview!.competitors.isEmpty) {
      return SizedBox();
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Concurrents dans votre zone',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        SizedBox(height: 8),
        
        ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: _overview!.competitors.length,
          itemBuilder: (context, index) {
            final competitor = _overview!.competitors[index];
            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundImage: NetworkImage(competitor.photo),
                ),
                title: Text(competitor.name),
                subtitle: Row(
                  children: [
                    Icon(Icons.star, size: 16, color: Colors.amber),
                    SizedBox(width: 4),
                    Text(competitor.rating.toString()),
                    SizedBox(width: 16),
                    Icon(Icons.people, size: 16, color: Colors.blue),
                    SizedBox(width: 4),
                    Text(competitor.followers.toString()),
                  ],
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${competitor.recentPosts}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'posts récents',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
  
  Widget _buildTrendsTab() {
    if (_trends == null) {
      return Center(child: Text('Aucune donnée disponible'));
    }
    
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Graphiques des tendances
          Text(
            'Tendances d\'engagement',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          SizedBox(height: 16),
          
          // Graphique des likes
          TrendChart(
            data: _trends!.engagement,
            title: 'Évolution des j\'aime',
            lineColor: Colors.pink.shade400,
            metric: 'likes',
          ),
          SizedBox(height: 16),
          
          // Graphique des commentaires
          TrendChart(
            data: _trends!.engagement,
            title: 'Évolution des commentaires',
            lineColor: Colors.amber.shade700,
            metric: 'comments',
          ),
          SizedBox(height: 16),
          
          // Graphique des partages
          TrendChart(
            data: _trends!.engagement,
            title: 'Évolution des partages',
            lineColor: Colors.green.shade700,
            metric: 'shares',
          ),
          SizedBox(height: 24),
          
          // Publications les plus performantes
          Text(
            'Publications les plus performantes',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          SizedBox(height: 8),
          ..._trends!.topPosts.map((post) => _buildTopPostCard(post)).toList(),
          SizedBox(height: 24),
          
          // Heures optimales de publication
          Text(
            'Heures optimales de publication',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          SizedBox(height: 8),
          _buildOptimalTimesChart(),
          SizedBox(height: 24),
          
          // Distribution hebdomadaire
          Text(
            'Distribution hebdomadaire',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          SizedBox(height: 8),
          _buildWeeklyDistributionChart(),
        ],
      ),
    );
  }
  
  Widget _buildTopPostCard(TopPost post) {
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image du post si disponible
          if (post.media != null)
            ClipRRect(
              borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
              child: Image.network(
                post.media!,
                width: double.infinity,
                height: 160,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: double.infinity,
                    height: 160,
                    color: Colors.grey.shade200,
                    child: Icon(Icons.image_not_supported, color: Colors.grey),
                  );
                },
              ),
            ),
            
          Padding(
            padding: EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      formatDate(post.postedAt),
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade700,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Score: ${post.score}',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  post.content,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _engagementStat(
                      Icons.thumb_up,
                      post.engagement.likes.toString(),
                    ),
                    _engagementStat(
                      Icons.comment,
                      post.engagement.comments.toString(),
                    ),
                    _engagementStat(
                      Icons.share,
                      post.engagement.shares.toString(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _engagementStat(IconData icon, String count) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade700),
        SizedBox(width: 4),
        Text(count),
      ],
    );
  }
  
  Widget _buildOptimalTimesChart() {
    if (_trends == null || _trends!.peakTimes.isEmpty) {
      return Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: Text('Aucune donnée disponible')),
        ),
      );
    }
    
    // Trier par ordre d'heure
    final sortedPeakTimes = List<PeakTime>.from(_trends!.peakTimes)
      ..sort((a, b) => a.hour.compareTo(b.hour));
    
    // Trouver l'engagement maximum pour l'échelle
    final maxEngagement = _trends!.peakTimes
        .map((e) => e.averageEngagement)
        .reduce((a, b) => a > b ? a : b);
    
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Basé sur votre historique de publication',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
            ),
            SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: Row(
                children: [
                  // Axe Y (engagement)
                  Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${maxEngagement.toStringAsFixed(0)}', style: TextStyle(fontSize: 10)),
                      Text('${(maxEngagement / 2).toStringAsFixed(0)}', style: TextStyle(fontSize: 10)),
                      Text('0', style: TextStyle(fontSize: 10)),
                    ],
                  ),
                  SizedBox(width: 8),
                  // Graphique à barres
                  Expanded(
                    child: CustomPaint(
                      size: Size.infinite,
                      painter: HourlyBarChartPainter(
                        data: sortedPeakTimes,
                        maxValue: maxEngagement,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 8),
            // Légende pour l'axe X (heures)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('0h', style: TextStyle(fontSize: 10)),
                Text('6h', style: TextStyle(fontSize: 10)),
                Text('12h', style: TextStyle(fontSize: 10)),
                Text('18h', style: TextStyle(fontSize: 10)),
                Text('24h', style: TextStyle(fontSize: 10)),
              ],
            ),
            SizedBox(height: 16),
            // Afficher les meilleures heures
            Text(
              'Meilleures heures pour publier:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _trends!.peakTimes
                  .take(3)
                  .map((time) => Chip(
                    backgroundColor: Colors.blue.shade100,
                    label: Text(
                      '${time.hour}h (${time.averageEngagement.toStringAsFixed(1)} engagements)',
                      style: TextStyle(fontSize: 12),
                    ),
                  ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildWeeklyDistributionChart() {
    if (_trends == null || _trends!.weeklyDistribution.isEmpty) {
      return Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: Text('Aucune donnée disponible')),
        ),
      );
    }
    
    // Ordonner les jours
    const orderMap = {
      'Lundi': 0,
      'Mardi': 1,
      'Mercredi': 2,
      'Jeudi': 3,
      'Vendredi': 4,
      'Samedi': 5,
      'Dimanche': 6,
    };
    
    final sortedData = List<WeekdayDistribution>.from(_trends!.weeklyDistribution)
      ..sort((a, b) => orderMap[a.day]!.compareTo(orderMap[b.day]!));
    
    // Trouver l'engagement maximum pour l'échelle
    final maxEngagement = _trends!.weeklyDistribution
        .map((e) => e.averageEngagement)
        .reduce((a, b) => a > b ? a : b);
    
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Performance par jour de la semaine',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: CustomPaint(
                size: Size.infinite,
                painter: WeeklyBarChartPainter(
                  data: sortedData,
                  maxValue: maxEngagement,
                ),
              ),
            ),
            SizedBox(height: 16),
            // Meilleur jour
            Text(
              'Meilleur jour pour publier:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            sortedData.isNotEmpty
                ? Chip(
                    backgroundColor: Colors.green.shade100,
                    label: Text(
                      '${sortedData.reduce((a, b) => a.averageEngagement > b.averageEngagement ? a : b).day} '
                      '(${sortedData.reduce((a, b) => a.averageEngagement > b.averageEngagement ? a : b).averageEngagement.toStringAsFixed(1)} engagements)',
                      style: TextStyle(fontSize: 12),
                    ),
                  )
                : Text('Données insuffisantes'),
          ],
        ),
      ),
    );
  }
  
  Widget _buildRecommendationsTab() {
    if (_recommendations == null) {
      return Center(child: Text('Aucune donnée disponible'));
    }
    
    // Vérifier si les listes de recommandations sont vides
    bool hasNoRecommendations = _recommendations!.contentStrategy.isEmpty && 
                               _recommendations!.engagementTactics.isEmpty && 
                               _recommendations!.growthOpportunities.isEmpty;
                               
    if (hasNoRecommendations) {
      return Center(child: Text('Aucune recommandation disponible'));
    }
    
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildRecommendationSection(
            'Stratégie de contenu',
            'Améliorez votre stratégie de contenu pour maximiser l\'engagement',
            _recommendations!.contentStrategy,
            Colors.blue.shade700,
          ),
          SizedBox(height: 16),
          _buildRecommendationSection(
            'Tactiques d\'engagement',
            'Augmentez l\'engagement de votre audience avec ces approches',
            _recommendations!.engagementTactics,
            Colors.purple.shade700,
          ),
          SizedBox(height: 16),
          _buildRecommendationSection(
            'Opportunités de croissance',
            'Exploitez ces opportunités pour développer votre présence',
            _recommendations!.growthOpportunities,
            Colors.green.shade700,
          ),
        ],
      ),
    );
  }
  
  Widget _buildRecommendationSection(String title, String description, List<Recommendation> recommendations, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        SizedBox(height: 8),
        Text(description),
        SizedBox(height: 8),
        ...recommendations.map((recommendation) => _buildRecommendationCard(recommendation)).toList(),
      ],
    );
  }
  
  Widget _buildRecommendationCard(Recommendation recommendation) {
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              recommendation.title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 8),
            Text(recommendation.description),
            SizedBox(height: 12),
            // Afficher l'action suggérée dans un conteneur stylisé
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.arrow_forward, color: Colors.blue, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      recommendation.action,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  void _showCampaignDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              builder: (context, scrollController) {
                return Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: SingleChildScrollView(
                    controller: scrollController,
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Nouvelle Campagne',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Type de campagne',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Liste des types de campagne
                          ...List.generate(_campaignTypes.length, (index) {
                            final type = _campaignTypes[index];
                            final isSelected = _selectedCampaignType == type;
                            final price = _campaignPrices[type] ?? 0.0;
                            
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: isSelected ? Colors.deepPurple : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    _selectedCampaignType = type;
                                  });
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      Radio<String>(
                                        value: type,
                                        groupValue: _selectedCampaignType,
                                        onChanged: (value) {
                                          setState(() {
                                            _selectedCampaignType = value!;
                                          });
                                        },
                                        activeColor: Colors.deepPurple,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              type,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              _getCampaignDescription(type),
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        '${price.toStringAsFixed(2)} €',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                          const SizedBox(height: 24),
                          // Estimation des résultats
                          Card(
                            margin: const EdgeInsets.only(bottom: 24),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            color: Colors.blue.withOpacity(0.1),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Résultats estimés',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  _buildEstimationRow(
                                    'Portée', 
                                    _getEstimatedReach(_selectedCampaignType),
                                    Icons.visibility
                                  ),
                                  const SizedBox(height: 8),
                                  _buildEstimationRow(
                                    'Interactions', 
                                    _getEstimatedInteractions(_selectedCampaignType),
                                    Icons.thumb_up
                                  ),
                                  const SizedBox(height: 8),
                                  _buildEstimationRow(
                                    'Conversion', 
                                    _getEstimatedConversion(_selectedCampaignType),
                                    Icons.shopping_cart
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Bouton de lancement
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.pop(context);
                                _showCampaignSuccess();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.deepPurple,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Lancer la campagne',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
  
  Widget _buildEstimationRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.blue),
        const SizedBox(width: 8),
        Text(
          '$label :',
          style: const TextStyle(
            fontSize: 14,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
  
  String _getCampaignDescription(String type) {
    switch (type) {
      case 'Visibilité locale':
        return 'Augmentez votre visibilité auprès des utilisateurs à proximité de votre établissement';
      case 'Boost national':
        return 'Élargissez votre portée à l\'échelle nationale pour attirer une nouvelle clientèle';
      case 'Promotion spéciale':
        return 'Mettez en avant vos offres et promotions exceptionnelles';
      case 'Événement à venir':
        return 'Faites la promotion de vos événements à venir pour maximiser la participation';
      default:
        return '';
    }
  }
  
  String _getEstimatedReach(String type) {
    switch (type) {
      case 'Visibilité locale':
        return '2 500 - 3 000 utilisateurs';
      case 'Boost national':
        return '8 000 - 10 000 utilisateurs';
      case 'Promotion spéciale':
        return '4 000 - 5 000 utilisateurs';
      case 'Événement à venir':
        return '5 000 - 6 000 utilisateurs';
      default:
        return '0 utilisateurs';
    }
  }
  
  String _getEstimatedInteractions(String type) {
    switch (type) {
      case 'Visibilité locale':
        return '300 - 450 interactions';
      case 'Boost national':
        return '800 - 1 200 interactions';
      case 'Promotion spéciale':
        return '500 - 700 interactions';
      case 'Événement à venir':
        return '600 - 800 interactions';
      default:
        return '0 interactions';
    }
  }
  
  String _getEstimatedConversion(String type) {
    switch (type) {
      case 'Visibilité locale':
        return '30 - 50 visites';
      case 'Boost national':
        return '70 - 100 visites';
      case 'Promotion spéciale':
        return '50 - 70 visites';
      case 'Événement à venir':
        return '60 - 80 réservations';
      default:
        return '0 visites';
    }
  }
  
  void _showCampaignSuccess() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Campagne lancée avec succès !'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'Voir',
          textColor: Colors.white,
          onPressed: () {
            // Naviguer vers les détails de la campagne
          },
        ),
      ),
    );
  }
}

class HourlyBarChartPainter extends CustomPainter {
  final List<PeakTime> data;
  final double maxValue;
  
  HourlyBarChartPainter({
    required this.data,
    required this.maxValue,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    // Dessiner la grille
    final gridPaint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 1;
    
    // Lignes horizontales
    canvas.drawLine(Offset(0, 0), Offset(size.width, 0), gridPaint);
    canvas.drawLine(Offset(0, size.height / 2), Offset(size.width, size.height / 2), gridPaint);
    canvas.drawLine(Offset(0, size.height), Offset(size.width, size.height), gridPaint);
    
    // Lignes verticales
    for (int i = 0; i <= 4; i++) {
      final x = i * size.width / 4;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    
    // Barres d'heures
    final barWidth = size.width / 24;
    
    for (final timePoint in data) {
      final hour = timePoint.hour;
      final x = hour * size.width / 24;
      final barHeight = (timePoint.averageEngagement / maxValue) * size.height;
      
      final barPaint = Paint()
        ..color = Colors.blue.shade700
        ..style = PaintingStyle.fill;
      
      canvas.drawRect(
        Rect.fromLTWH(x, size.height - barHeight, barWidth, barHeight),
        barPaint,
      );
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class WeeklyBarChartPainter extends CustomPainter {
  final List<WeekdayDistribution> data;
  final double maxValue;
  
  WeeklyBarChartPainter({
    required this.data,
    required this.maxValue,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    // Dessiner la grille
    final gridPaint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 1;
    
    // Lignes horizontales
    canvas.drawLine(Offset(0, 0), Offset(size.width, 0), gridPaint);
    canvas.drawLine(Offset(0, size.height / 2), Offset(size.width, size.height / 2), gridPaint);
    canvas.drawLine(Offset(0, size.height), Offset(size.width, size.height), gridPaint);
    
    if (data.isEmpty) return;
    
    final barWidth = size.width / data.length * 0.7;
    final spacing = size.width / data.length * 0.3;
    
    for (int i = 0; i < data.length; i++) {
      final day = data[i];
      final x = i * size.width / data.length + spacing / 2;
      final barHeight = (day.averageEngagement / maxValue) * size.height;
      
      // Déterminer la couleur en fonction du jour
      Color barColor;
      if (day.day == 'Samedi' || day.day == 'Dimanche') {
        barColor = Colors.green.shade700;
      } else {
        barColor = Colors.blue.shade700;
      }
      
      final barPaint = Paint()
        ..color = barColor
        ..style = PaintingStyle.fill;
      
      // Dessiner la barre
      canvas.drawRect(
        Rect.fromLTWH(x, size.height - barHeight, barWidth, barHeight),
        barPaint,
      );
      
      // Ajouter le label du jour
      TextPainter textPainter = TextPainter(
        text: TextSpan(
          text: day.day.substring(0, 3),
          style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x + barWidth / 2 - textPainter.width / 2, size.height + 5),
      );
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
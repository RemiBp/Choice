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
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadInitialData();
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
        title: Text('Croissance & Portée'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Aperçu'),
            Tab(text: 'Tendances'),
            Tab(text: 'Recommandations'),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.calendar_today),
            tooltip: 'Période d\'analyse',
            onSelected: _updatePeriod,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: '7',
                child: Text('7 jours'),
              ),
              PopupMenuItem(
                value: '30',
                child: Text('30 jours'),
              ),
              PopupMenuItem(
                value: '90',
                child: Text('90 jours'),
              ),
              PopupMenuItem(
                value: '365',
                child: Text('365 jours'),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: LoadingIndicator())
          : _error != null
              ? ErrorMessage(message: _error!)
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOverviewTab(),
                    _buildTrendsTab(),
                    _buildRecommendationsTab(),
                  ],
                ),
    );
  }
  
  Widget _buildOverviewTab() {
    if (_overview == null) {
      return Center(child: Text('Aucune donnée disponible'));
    }
    
    // Récupérer les données d'aperçu
    final producer = _overview!.producer;
    final engagement = _overview!.engagement;
    final followers = _overview!.followers;
    final reach = _overview!.reach;
    
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête du producteur
          _buildProducerHeader(producer),
          SizedBox(height: 24),
          
          // Statistiques principales
          _buildStatCards(engagement, followers, reach),
          SizedBox(height: 24),
          
          // Démographie des followers
          _buildDemographicsSection(),
          SizedBox(height: 24),
          
          // Concurrents
          _buildCompetitorsSection(),
        ],
      ),
    );
  }
  
  Widget _buildProducerHeader(Producer producer) {
    final theme = Theme.of(context);
    
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Row(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundImage: NetworkImage(producer.photo),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    producer.name,
                    style: theme.textTheme.titleLarge,
                  ),
                  SizedBox(height: 4),
                  Wrap(
                    spacing: 4,
                    children: producer.category.map((cat) => Chip(
                      label: Text(cat, style: TextStyle(fontSize: 12)),
                      backgroundColor: producer.type == 'restaurant' 
                          ? Colors.orange.shade100 
                          : Colors.purple.shade100,
                    )).toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
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
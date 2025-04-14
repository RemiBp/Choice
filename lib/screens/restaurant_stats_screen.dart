import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../utils/constants.dart' as constants;

class RestaurantStatsScreen extends StatefulWidget {
  final String producerId;

  const RestaurantStatsScreen({Key? key, required this.producerId}) : super(key: key);

  @override
  State<RestaurantStatsScreen> createState() => _RestaurantStatsScreenState();
}

class _RestaurantStatsScreenState extends State<RestaurantStatsScreen>
    with SingleTickerProviderStateMixin {
  
  late TabController _tabController;
  String _selectedPeriod = 'week';
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  
  // Données des statistiques
  Map<String, dynamic> _generalStats = {};
  Map<String, dynamic> _menuStats = {};
  Map<String, dynamic> _engagementStats = {};
  List<dynamic> _dailyStats = [];
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _fetchAllStats();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  // Récupérer toutes les statistiques nécessaires
  Future<void> _fetchAllStats() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    
    try {
      await Future.wait([
        _fetchGeneralStats(),
        _fetchMenuStats(),
        _fetchEngagementStats(),
        _fetchDailyStats(),
      ]);
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'Erreur lors du chargement des données: $e';
      });
      print('❌ Erreur lors du chargement des statistiques: $e');
    }
  }
  
  // Récupérer les statistiques générales
  Future<void> _fetchGeneralStats() async {
    try {
      final url = Uri.parse('${constants.getBaseUrl()}/api/stats/restaurant/${widget.producerId}?period=$_selectedPeriod');
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _generalStats = data['stats'] ?? {};
        });
      } else {
        throw Exception('Erreur API: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Erreur lors du chargement des statistiques générales: $e');
      throw e;
    }
  }
  
  // Récupérer les statistiques du menu
  Future<void> _fetchMenuStats() async {
    try {
      final url = Uri.parse('${constants.getBaseUrl()}/api/stats/restaurant/${widget.producerId}/menu');
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _menuStats = data['menuStats'] ?? {};
        });
      } else {
        throw Exception('Erreur API: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Erreur lors du chargement des statistiques du menu: $e');
      throw e;
    }
  }
  
  // Récupérer les statistiques d'engagement
  Future<void> _fetchEngagementStats() async {
    try {
      final url = Uri.parse('${constants.getBaseUrl()}/api/stats/restaurant/${widget.producerId}/engagement');
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _engagementStats = data['engagement'] ?? {};
        });
      } else {
        throw Exception('Erreur API: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Erreur lors du chargement des statistiques d\'engagement: $e');
      throw e;
    }
  }
  
  // Récupérer les statistiques quotidiennes
  Future<void> _fetchDailyStats() async {
    try {
      final url = Uri.parse('${constants.getBaseUrl()}/api/stats/restaurant/${widget.producerId}/daily');
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _dailyStats = data['dailyStats'] ?? [];
        });
      } else {
        throw Exception('Erreur API: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Erreur lors du chargement des statistiques quotidiennes: $e');
      throw e;
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistiques du Restaurant', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.orangeAccent,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Général'),
            Tab(text: 'Menu'),
            Tab(text: 'Engagement'),
            Tab(text: 'Graphiques'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Rafraîchir',
            onPressed: _fetchAllStats,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.orangeAccent))
          : _hasError
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 60, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('Erreur: $_errorMessage', style: const TextStyle(fontSize: 16)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent),
                        onPressed: _fetchAllStats,
                        child: const Text('Réessayer'),
                      ),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildGeneralStatsTab(),
                    _buildMenuStatsTab(),
                    _buildEngagementStatsTab(),
                    _buildGraphsTab(),
                  ],
                ),
    );
  }
  
  // Onglet des statistiques générales
  Widget _buildGeneralStatsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPeriodSelector(),
          const SizedBox(height: 24),
          _buildGeneralStatsOverview(),
        ],
      ),
    );
  }
  
  // Sélecteur de période
  Widget _buildPeriodSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildPeriodButton('Jour', 'day'),
          _buildPeriodButton('Semaine', 'week'),
          _buildPeriodButton('Mois', 'month'),
        ],
      ),
    );
  }
  
  // Bouton de période
  Widget _buildPeriodButton(String label, String value) {
    final isSelected = _selectedPeriod == value;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPeriod = value;
        });
        _fetchGeneralStats();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.orangeAccent : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
  
  // Statistiques générales
  Widget _buildGeneralStatsOverview() {
    final visitors = _generalStats['visitors'] ?? 0;
    final revenue = _generalStats['revenue'] ?? 0;
    final ordersCount = _generalStats['ordersCount'] ?? 0;
    final averageOrderValue = _generalStats['averageOrderValue'] ?? 0;
    final newCustomers = _generalStats['newCustomers'] ?? 0;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Vue d\'ensemble',
          style: TextStyle(
            fontSize: 20, 
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        
        // Première ligne: visiteurs et revenus
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                icon: Icons.people,
                title: 'Visiteurs',
                value: '$visitors',
                color: Colors.blue,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                icon: Icons.euro,
                title: 'Revenus',
                value: '${revenue.toStringAsFixed(0)} €',
                color: Colors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // Deuxième ligne: commandes et valeur moyenne
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                icon: Icons.shopping_cart,
                title: 'Commandes',
                value: '$ordersCount',
                color: Colors.purple,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                icon: Icons.receipt,
                title: 'Valeur moyenne',
                value: '${averageOrderValue.toStringAsFixed(0)} €',
                color: Colors.amber,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // Troisième ligne: nouveaux clients
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                icon: Icons.person_add,
                title: 'Nouveaux clients',
                value: '$newCustomers',
                color: Colors.teal,
              ),
            ),
            const Expanded(child: SizedBox()),
          ],
        ),
      ],
    );
  }
  
  // Carte de statistique
  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const Spacer(),
              Icon(
                Icons.arrow_upward,
                color: Colors.green,
                size: 16,
              ),
              Text(
                '8%',
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
  
  // Onglet des statistiques du menu
  Widget _buildMenuStatsTab() {
    final topSellingItems = _menuStats['topSellingItems'] ?? [];
    final leastSellingItems = _menuStats['leastSellingItems'] ?? [];
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMenuSection(
            title: 'Plats les plus vendus',
            items: topSellingItems,
            icon: Icons.trending_up,
            color: Colors.green,
          ),
          const SizedBox(height: 24),
          _buildMenuSection(
            title: 'Plats les moins vendus',
            items: leastSellingItems,
            icon: Icons.trending_down,
            color: Colors.red,
          ),
        ],
      ),
    );
  }
  
  // Section du menu (plats les plus/moins vendus)
  Widget _buildMenuSection({
    required String title,
    required List<dynamic> items,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...items.map((item) => _buildMenuItem(item)).toList(),
      ],
    );
  }
  
  // Élément de menu
  Widget _buildMenuItem(dynamic item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['name'] ?? 'Nom inconnu',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${item['quantity'] ?? 0} vendus',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${item['revenue'] ?? 0} €',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
        ],
      ),
    );
  }
  
  // Onglet des statistiques d'engagement
  Widget _buildEngagementStatsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Engagement des clients',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          _buildEngagementCard(
            title: 'Vues du profil',
            value: '${_engagementStats['profileViews'] ?? 0}',
            icon: Icons.visibility,
            color: Colors.blue,
          ),
          _buildEngagementCard(
            title: 'Vues du menu',
            value: '${_engagementStats['menuViews'] ?? 0}',
            icon: Icons.restaurant_menu,
            color: Colors.orange,
          ),
          _buildEngagementCard(
            title: 'Clics sur la carte',
            value: '${_engagementStats['mapClicks'] ?? 0}',
            icon: Icons.map,
            color: Colors.green,
          ),
          _buildEngagementCard(
            title: 'Clics sur le site web',
            value: '${_engagementStats['websiteClicks'] ?? 0}',
            icon: Icons.language,
            color: Colors.purple,
          ),
          _buildEngagementCard(
            title: 'Appels téléphoniques',
            value: '${_engagementStats['phoneCallsCount'] ?? 0}',
            icon: Icons.call,
            color: Colors.red,
          ),
        ],
      ),
    );
  }
  
  // Carte d'engagement
  Widget _buildEngagementCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_upward,
            color: Colors.green,
            size: 20,
          ),
          Text(
            '5%',
            style: TextStyle(
              color: Colors.green,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
  
  // Onglet des graphiques
  Widget _buildGraphsTab() {
    if (_dailyStats.isEmpty) {
      return const Center(
        child: Text(
          'Aucune donnée disponible pour les graphiques',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildRevenueChart(),
          const SizedBox(height: 24),
          _buildVisitorsChart(),
        ],
      ),
    );
  }
  
  // Graphique des revenus
  Widget _buildRevenueChart() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Revenus quotidiens',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          height: 250,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (value) {
                  return FlLine(
                    color: Colors.grey[200]!,
                    strokeWidth: 1,
                  );
                },
              ),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    getTitlesWidget: (value, meta) {
                      if (value.toInt() >= 0 && value.toInt() < _dailyStats.length) {
                        if (value.toInt() % 5 == 0) {
                          final date = DateTime.parse(_dailyStats[value.toInt()]['date']);
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              DateFormat('dd/MM').format(date),
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 10,
                              ),
                            ),
                          );
                        }
                      }
                      return const SizedBox();
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        '${value.toInt()} €',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 10,
                        ),
                      );
                    },
                    reservedSize: 40,
                  ),
                ),
                rightTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: List.generate(_dailyStats.length, (index) {
                    return FlSpot(
                      index.toDouble(),
                      (_dailyStats[index]['revenue'] ?? 0).toDouble(),
                    );
                  }),
                  isCurved: true,
                  color: Colors.green,
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    color: Colors.green.withOpacity(0.1),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
  
  // Graphique des visiteurs
  Widget _buildVisitorsChart() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Visiteurs quotidiens',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          height: 250,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: BarChart(
            BarChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (value) {
                  return FlLine(
                    color: Colors.grey[200]!,
                    strokeWidth: 1,
                  );
                },
              ),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    getTitlesWidget: (value, meta) {
                      if (value.toInt() >= 0 && value.toInt() < _dailyStats.length) {
                        if (value.toInt() % 5 == 0) {
                          final date = DateTime.parse(_dailyStats[value.toInt()]['date']);
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              DateFormat('dd/MM').format(date),
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 10,
                              ),
                            ),
                          );
                        }
                      }
                      return const SizedBox();
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        value.toInt().toString(),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 10,
                        ),
                      );
                    },
                    reservedSize: 30,
                  ),
                ),
                rightTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              borderData: FlBorderData(show: false),
              barGroups: List.generate(_dailyStats.length, (index) {
                return BarChartGroupData(
                  x: index,
                  barRods: [
                    BarChartRodData(
                      toY: (_dailyStats[index]['visitors'] ?? 0).toDouble(),
                      width: 8,
                      color: Colors.blue,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(3),
                        topRight: Radius.circular(3),
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        ),
      ],
    );
  }
} 
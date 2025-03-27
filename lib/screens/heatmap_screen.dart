import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_flutter_platform_interface/src/types/heatmap.dart' show WeightedLatLng;
import '../utils/custom_heatmap.dart' hide WeightedLatLng;
import 'package:cached_network_image/cached_network_image.dart';
import 'utils.dart';
import '../models/user_hotspot.dart' as models;
import '../models/faker_data.dart';

class HeatmapScreen extends StatefulWidget {
  final String userId;

  const HeatmapScreen({Key? key, required this.userId}) : super(key: key);

  @override
  _HeatmapScreenState createState() => _HeatmapScreenState();
}

class _HeatmapScreenState extends State<HeatmapScreen> {
  late GoogleMapController _mapController;
  bool _isLoading = true;
  bool _showLegend = false;
  String _selectedTimeFilter = 'Semaine';
  String _selectedDayFilter = 'Tous';
  
  // Data for heatmap and markers
  List<models.UserHotspot> _hotspots = [];
  List<models.UserHotspot> _filteredHotspots = [];
  Map<MarkerId, Marker> _markers = {};
  
  // Default location (Paris)
  final CameraPosition _initialCameraPosition = const CameraPosition(
    target: LatLng(48.8566, 2.3522),
    zoom: 13,
  );
  
  // Statistics by zone
  Map<String, Map<String, dynamic>> _zoneStats = {};
  
  // Selected zone (when user taps on a hotspot)
  String? _selectedZoneId;
  
  // Insights about zones
  List<Map<String, dynamic>> _zoneInsights = [];
  
  @override
  void initState() {
    super.initState();
    _loadData();
  }
  
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Get producer location first
      final locationData = await _fetchProducerLocation();
      
      // Then load hotspots around that location
      final hotspots = await _fetchHotspots(
        locationData['latitude'] ?? 48.8566,
        locationData['longitude'] ?? 2.3522,
      );
      
      // Process and set data
      setState(() {
        _hotspots = hotspots;
        _filteredHotspots = List.from(hotspots);
        
        // Create markers for each hotspot
        _markers = {};
        for (var hotspot in hotspots) {
          final markerId = MarkerId(hotspot.id);
          
          _markers[markerId] = Marker(
            markerId: markerId,
            position: LatLng(hotspot.latitude, hotspot.longitude),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              _getMarkerHue(hotspot.intensity),
            ),
            infoWindow: InfoWindow(
              title: hotspot.zoneName,
              snippet: '${hotspot.visitorCount} visiteurs',
            ),
            onTap: () => _selectZone(hotspot.id),
          );
        }
        
        // Generate zone stats
        _generateZoneStats();
        
        // Load insights
        _loadZoneInsights();
        
        _isLoading = false;
      });
      
      // Center map on producer location
      if (_mapController != null) {
        _mapController.animateCamera(
          CameraUpdate.newLatLng(
            LatLng(
              locationData['latitude'] ?? 48.8566,
              locationData['longitude'] ?? 2.3522,
            ),
          ),
        );
      }
    } catch (e) {
      print('❌ Error loading heatmap data: $e');
      setState(() {
        _isLoading = false;
      });
      
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors du chargement des données: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  Future<Map<String, dynamic>> _fetchProducerLocation() async {
    try {
      final url = Uri.parse('${getBaseUrl()}/api/producers/${widget.userId}/location');
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        print('❌ Error fetching producer location: ${response.body}');
        return {
          'latitude': 48.8566,
          'longitude': 2.3522,
        };
      }
    } catch (e) {
      print('❌ Error fetching producer location: $e');
      return {
        'latitude': 48.8566,
        'longitude': 2.3522,
      };
    }
  }
  
  Future<List<models.UserHotspot>> _fetchHotspots(double latitude, double longitude) async {
    try {
      final url = Uri.parse('${getBaseUrl()}/api/location-history/hotspots').replace(
        queryParameters: {
          'latitude': latitude.toString(),
          'longitude': longitude.toString(),
          'radius': '2000', // 2km par défaut
        },
      );
      
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((item) => models.UserHotspot.fromJson(item)).toList();
      } else {
        print('❌ Erreur lors de la récupération des hotspots: ${response.statusCode}');
        
        // Utiliser des données fictives en cas d'erreur
        print('ℹ️ Utilisation de données simulées pour la carte de chaleur');
        return FakerData.generateFakeHotspots(
          LatLng(latitude, longitude), 
          15, // 15 hotspots
          maxRadius: 2000
        );
      }
    } catch (e) {
      print('❌ Exception lors de la récupération des hotspots: $e');
      
      // Utiliser des données fictives en cas d'erreur
      print('ℹ️ Utilisation de données simulées pour la carte de chaleur');
      return FakerData.generateFakeHotspots(
        LatLng(latitude, longitude), 
        15, // 15 hotspots
        maxRadius: 2000
      );
    }
  }
  
  void _applyFilters() {
    setState(() {
      // Filter hotspots by time and day
      _filteredHotspots = _hotspots.where((hotspot) {
        // Apply time filter
        if (_selectedTimeFilter != 'Tous') {
          final timeDistribution = hotspot.timeDistribution;
          
          if (_selectedTimeFilter == 'Matin' && 
              (timeDistribution['morning'] ?? 0) < 0.2) {
            return false;
          } else if (_selectedTimeFilter == 'Après-midi' && 
                   (timeDistribution['afternoon'] ?? 0) < 0.2) {
            return false;
          } else if (_selectedTimeFilter == 'Soir' && 
                   (timeDistribution['evening'] ?? 0) < 0.2) {
            return false;
          }
        }
        
        // Apply day filter
        if (_selectedDayFilter != 'Tous') {
          final dayDistribution = hotspot.dayDistribution;
          String dayKey = _selectedDayFilter.toLowerCase();
          
          // Handle English day keys in the data
          if (dayKey == 'lundi') dayKey = 'monday';
          else if (dayKey == 'mardi') dayKey = 'tuesday';
          else if (dayKey == 'mercredi') dayKey = 'wednesday';
          else if (dayKey == 'jeudi') dayKey = 'thursday';
          else if (dayKey == 'vendredi') dayKey = 'friday';
          else if (dayKey == 'samedi') dayKey = 'saturday';
          else if (dayKey == 'dimanche') dayKey = 'sunday';
          
          if ((dayDistribution[dayKey] ?? 0) < 0.1) {
            return false;
          }
        }
        
        return true;
      }).toList();
      
      // Update markers
      _markers = {};
      for (var hotspot in _filteredHotspots) {
        final markerId = MarkerId(hotspot.id);
        
        _markers[markerId] = Marker(
          markerId: markerId,
          position: LatLng(hotspot.latitude, hotspot.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            _getMarkerHue(hotspot.intensity),
          ),
          infoWindow: InfoWindow(
            title: hotspot.zoneName,
            snippet: '${hotspot.visitorCount} visiteurs',
          ),
          onTap: () => _selectZone(hotspot.id),
        );
      }
      
      // Regenerate zone stats
      _generateZoneStats();
    });
  }
  
  void _selectZone(String zoneId) {
    setState(() {
      _selectedZoneId = zoneId;
    });
    
    // Show bottom sheet with zone details
    _showZoneDetailsSheet();
  }
  
  void _showZoneDetailsSheet() {
    final selectedHotspot = _hotspots.firstWhere(
      (hotspot) => hotspot.id == _selectedZoneId,
      orElse: () => _hotspots.first,
    );
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (_, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: 10, bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      const Icon(Icons.place, color: Colors.deepPurple),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          selectedHotspot.zoneName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                Divider(color: Colors.grey[300]),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(20),
                    children: [
                      // Visitor stats
                      _buildStatCard(
                        icon: Icons.people,
                        title: 'Affluence',
                        value: '${selectedHotspot.visitorCount}',
                        subtitle: 'visiteurs sur la période',
                        color: Colors.blue,
                      ),
                      const SizedBox(height: 16),
                      
                      // Time distribution
                      const Text(
                        'Distribution par heure',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        height: 160,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: _buildTimeDistributionChart(selectedHotspot.timeDistribution),
                      ),
                      const SizedBox(height: 20),
                      
                      // Day distribution
                      const Text(
                        'Distribution par jour',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        height: 170,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: _buildDayDistributionChart(selectedHotspot.dayDistribution),
                      ),
                      const SizedBox(height: 20),
                      
                      // Action recommendations for this zone
                      _buildActionRecommendations(selectedHotspot),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildTimeDistributionChart(Map<String, double> timeDistribution) {
    final morningValue = (timeDistribution['morning'] ?? 0) * 100;
    final afternoonValue = (timeDistribution['afternoon'] ?? 0) * 100;
    final eveningValue = (timeDistribution['evening'] ?? 0) * 100;
    
    return Column(
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Morning bar
              _buildTimeBar('Matin', morningValue, Colors.orange),
              
              // Afternoon bar
              _buildTimeBar('Après-midi', afternoonValue, Colors.blue),
              
              // Evening bar
              _buildTimeBar('Soir', eveningValue, Colors.purple),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Matin: ${morningValue.toInt()}%',
              style: const TextStyle(fontSize: 12),
            ),
            Text(
              'Après-midi: ${afternoonValue.toInt()}%',
              style: const TextStyle(fontSize: 12),
            ),
            Text(
              'Soir: ${eveningValue.toInt()}%',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }
  
  Widget _buildTimeBar(String label, double value, Color color) {
    final height = (value / 100) * 80; // Max height 80
    
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: 40,
          height: height,
          decoration: BoxDecoration(
            color: color,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(6),
              topRight: Radius.circular(6),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }
  
  Widget _buildDayDistributionChart(Map<String, double> dayDistribution) {
    final List<MapEntry<String, double>> entries = dayDistribution.entries.toList();
    
    // Convert English day keys to French
    final Map<String, String> dayTranslation = {
      'monday': 'Lun',
      'tuesday': 'Mar',
      'wednesday': 'Mer',
      'thursday': 'Jeu',
      'friday': 'Ven',
      'saturday': 'Sam',
      'sunday': 'Dim',
    };
    
    // Sort entries by day of week
    final List<String> dayOrder = [
      'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'
    ];
    entries.sort((a, b) => dayOrder.indexOf(a.key).compareTo(dayOrder.indexOf(b.key)));
    
    return Column(
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: entries.map((entry) {
              final value = entry.value * 100;
              final dayAbbr = dayTranslation[entry.key] ?? entry.key;
              
              return _buildDayBar(dayAbbr, value, Colors.teal);
            }).toList(),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: entries.map((entry) {
            final value = entry.value * 100;
            final dayAbbr = dayTranslation[entry.key] ?? entry.key;
            
            return Text(
              '$dayAbbr: ${value.toInt()}%',
              style: const TextStyle(fontSize: 10),
            );
          }).toList(),
        ),
      ],
    );
  }
  
  Widget _buildDayBar(String label, double value, Color color) {
    final height = (value / 100) * 100; // Max height 100
    
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: 20,
          height: height,
          decoration: BoxDecoration(
            color: color,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(4),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 10),
        ),
      ],
    );
  }
  
  Widget _buildActionRecommendations(models.UserHotspot hotspot) {
    // Generate action recommendations based on hotspot data
    List<Map<String, dynamic>> recommendations = [];
    
    // Recommendation based on time distribution
    final timeDistribution = hotspot.timeDistribution;
    final bestTime = _getBestTimeSlot(timeDistribution);
    
    if (bestTime.isNotEmpty) {
      recommendations.add({
        'title': 'Optimisez vos horaires',
        'description': 'La zone est plus active en période de $bestTime. '
                       'Adaptez vos horaires d\'ouverture et promotions en conséquence.',
        'icon': Icons.access_time,
        'color': Colors.blue,
      });
    }
    
    // Recommendation based on day distribution
    final dayDistribution = hotspot.dayDistribution;
    final bestDay = _getBestDay(dayDistribution);
    
    if (bestDay.isNotEmpty) {
      recommendations.add({
        'title': 'Jour de forte affluence',
        'description': 'Le $bestDay est le jour avec le plus de passage. '
                       'Proposez des offres spéciales ce jour-là pour maximiser votre impact.',
        'icon': Icons.event,
        'color': Colors.green,
      });
    }
    
    // Location-based recommendation
    if (hotspot.intensity > 0.7) {
      recommendations.add({
        'title': 'Zone à fort potentiel',
        'description': 'Cette zone attire beaucoup de visiteurs. '
                      'Envisagez des actions promotionnelles ciblées ou une présence physique.',
        'icon': Icons.trending_up,
        'color': Colors.purple,
      });
    }
    
    // Build recommendation widgets
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Actions recommandées',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        ...recommendations.map((recommendation) {
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: (recommendation['color'] as Color).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: (recommendation['color'] as Color).withOpacity(0.3),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  recommendation['icon'] as IconData,
                  color: recommendation['color'] as Color,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        recommendation['title'] as String,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        recommendation['description'] as String,
                        style: const TextStyle(height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }
  
  String _getBestTimeSlot(Map<String, double> timeDistribution) {
    double maxValue = 0;
    String bestTime = '';
    
    timeDistribution.forEach((key, value) {
      if (value > maxValue) {
        maxValue = value;
        bestTime = key;
      }
    });
    
    switch (bestTime) {
      case 'morning':
        return 'matinée';
      case 'afternoon':
        return 'après-midi';
      case 'evening':
        return 'soirée';
      default:
        return '';
    }
  }
  
  String _getBestDay(Map<String, double> dayDistribution) {
    double maxValue = 0;
    String bestDay = '';
    
    dayDistribution.forEach((key, value) {
      if (value > maxValue) {
        maxValue = value;
        bestDay = key;
      }
    });
    
    switch (bestDay) {
      case 'monday':
        return 'Lundi';
      case 'tuesday':
        return 'Mardi';
      case 'wednesday':
        return 'Mercredi';
      case 'thursday':
        return 'Jeudi';
      case 'friday':
        return 'Vendredi';
      case 'saturday':
        return 'Samedi';
      case 'sunday':
        return 'Dimanche';
      default:
        return '';
    }
  }
  
  void _generateZoneStats() {
    // Generate statistics for each zone
    _zoneStats = {};
    
    for (var hotspot in _filteredHotspots) {
      final id = hotspot.id;
      final visitorCount = hotspot.visitorCount;
      final intensity = hotspot.intensity;
      
      // Find peak times
      final timeDistribution = hotspot.timeDistribution;
      final bestTime = _getBestTimeSlot(timeDistribution);
      
      // Find best days
      final dayDistribution = hotspot.dayDistribution;
      final bestDay = _getBestDay(dayDistribution);
      
      _zoneStats[id] = {
        'visitorCount': visitorCount,
        'intensity': intensity,
        'bestTime': bestTime,
        'bestDay': bestDay,
      };
    }
  }
  
  Future<void> _loadZoneInsights() async {
    // This would call an AI-powered API endpoint for detailed insights
    // For now, we'll create some sample insights
    _zoneInsights = [
      {
        'title': 'Suggestions pour le quartier',
        'insights': [
          'La concurrence est forte dans cette zone, différenciez-vous avec des offres uniques.',
          'Les heures de pointe sont entre 12h et 14h en semaine, proposez des services rapides.',
          'Trafic piéton élevé le weekend, idéal pour des promotions de rue.',
        ],
      },
      {
        'title': 'Tendances de consommation',
        'insights': [
          'La clientèle locale préfère les options santé et végétariennes.',
          'Forte demande pour des options à emporter de qualité.',
          'Les familles avec enfants sont nombreuses le mercredi après-midi.',
        ],
      },
      {
        'title': 'Opportunités à saisir',
        'insights': [
          'Partenariat possible avec les bureaux à proximité pour livraisons groupées.',
          'Forte demande non satisfaite pour des options de petit-déjeuner tôt le matin.',
          'Les événements culturels à proximité génèrent des pics d\'affluence, préparez-vous!',
        ],
      },
    ];
  }
  
  double _getMarkerHue(double intensity) {
    // Convert intensity (0-1) to hue (0-360, but BitmapDescriptor uses 0-360)
    // Low intensity: red (0)
    // Medium intensity: yellow (60)
    // High intensity: green (120)
    return 120 * intensity;
  }
  
  List<WeightedLatLng> _getHeatmapPoints() {
    return _filteredHotspots.map((hotspot) {
      // Créer une instance de WeightedLatLng de google_maps_flutter_platform_interface
      return WeightedLatLng(
        LatLng(hotspot.latitude, hotspot.longitude),
        weight: hotspot.intensity,
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Heatmap & Audience Explorer'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Rafraîchir',
          ),
          IconButton(
            icon: Icon(_showLegend ? Icons.info_outline : Icons.info),
            onPressed: () {
              setState(() {
                _showLegend = !_showLegend;
              });
            },
            tooltip: 'Légende',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Map with heatmap
          GoogleMap(
            initialCameraPosition: _initialCameraPosition,
            onMapCreated: (controller) {
              _mapController = controller;
            },
            markers: Set<Marker>.of(_markers.values),
            myLocationButtonEnabled: true,
            myLocationEnabled: true,
            mapType: MapType.normal,
            buildingsEnabled: true,
            compassEnabled: true,
            trafficEnabled: false,
          ),
          
          // Heatmap overlay using flutter_heatmap_map
          Positioned.fill(
            child: IgnorePointer(
              child: HeatMapWidget(
                heatMapDataList: _getHeatmapPoints(),
                mapController: _mapController,
                radius: 30,
                gradient: HeatMapGradient(
                  colors: const [
                    Colors.transparent,
                    Color.fromARGB(100, 255, 0, 0),
                    Color.fromARGB(150, 255, 160, 0),
                    Color.fromARGB(200, 255, 255, 0),
                  ],
                  startPoints: const [0.0, 0.25, 0.5, 0.75],
                ),
              ),
            ),
          ),
          
          // Filter controls
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Filtres',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        // Time filter dropdown
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            decoration: const InputDecoration(
                              labelText: 'Heure',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            value: _selectedTimeFilter,
                            items: const [
                              DropdownMenuItem(value: 'Tous', child: Text('Toute la journée')),
                              DropdownMenuItem(value: 'Matin', child: Text('Matin')),
                              DropdownMenuItem(value: 'Après-midi', child: Text('Après-midi')),
                              DropdownMenuItem(value: 'Soir', child: Text('Soir')),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _selectedTimeFilter = value ?? 'Tous';
                              });
                              _applyFilters();
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Day filter dropdown
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            decoration: const InputDecoration(
                              labelText: 'Jour',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            value: _selectedDayFilter,
                            items: const [
                              DropdownMenuItem(value: 'Tous', child: Text('Tous les jours')),
                              DropdownMenuItem(value: 'Lundi', child: Text('Lundi')),
                              DropdownMenuItem(value: 'Mardi', child: Text('Mardi')),
                              DropdownMenuItem(value: 'Mercredi', child: Text('Mercredi')),
                              DropdownMenuItem(value: 'Jeudi', child: Text('Jeudi')),
                              DropdownMenuItem(value: 'Vendredi', child: Text('Vendredi')),
                              DropdownMenuItem(value: 'Samedi', child: Text('Samedi')),
                              DropdownMenuItem(value: 'Dimanche', child: Text('Dimanche')),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _selectedDayFilter = value ?? 'Tous';
                              });
                              _applyFilters();
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Legend overlay (when enabled)
          if (_showLegend)
            Positioned(
              top: 140,
              right: 16,
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.info_outline, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Légende',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildLegendItem(
                        color: Colors.red,
                        label: 'Faible affluence',
                      ),
                      _buildLegendItem(
                        color: Colors.yellow,
                        label: 'Affluence moyenne',
                      ),
                      _buildLegendItem(
                        color: Colors.green,
                        label: 'Forte affluence',
                      ),
                      const Divider(),
                      const Text(
                        'Cliquez sur les marqueurs\npour plus de détails',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          
          // Bottom stats panel
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Card(
              margin: EdgeInsets.zero,
              elevation: 8,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle indicator
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    // Heading
                    const Row(
                      children: [
                        Icon(Icons.analytics_outlined, size: 20, color: Colors.deepPurple),
                        SizedBox(width: 8),
                        Text(
                          'Statistiques des zones',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Zone stats
                    SizedBox(
                      height: 120,
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: _filteredHotspots.length,
                              itemBuilder: (context, index) {
                                final hotspot = _filteredHotspots[index];
                                final stats = _zoneStats[hotspot.id];
                                
                                if (stats == null) return const SizedBox.shrink();
                                
                                return GestureDetector(
                                  onTap: () => _selectZone(hotspot.id),
                                  child: Container(
                                    width: 160,
                                    margin: const EdgeInsets.only(right: 12),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.deepPurple.withOpacity(0.3),
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.05),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          hotspot.zoneName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            const Icon(Icons.people, size: 14, color: Colors.blue),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${stats['visitorCount']} visiteurs',
                                              style: const TextStyle(fontSize: 12),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            const Icon(Icons.access_time, size: 14, color: Colors.orange),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Pic: ${stats['bestTime']}',
                                              style: const TextStyle(fontSize: 12),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            const Icon(Icons.event, size: 14, color: Colors.green),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Jour: ${stats['bestDay']}',
                                              style: const TextStyle(fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                    
                    // AI insights section
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.lightbulb_outline, size: 14, color: Colors.amber),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Insights IA',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 150,
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: _zoneInsights.length,
                              itemBuilder: (context, index) {
                                final insight = _zoneInsights[index];
                                
                                return Container(
                                  width: 280,
                                  margin: const EdgeInsets.only(right: 12),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.amber.withOpacity(0.3),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        insight['title'] as String,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: Colors.amber[800],
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Expanded(
                                        child: ListView.builder(
                                          physics: const NeverScrollableScrollPhysics(),
                                          itemCount: (insight['insights'] as List).length,
                                          itemBuilder: (context, insightIndex) {
                                            final insightText = insight['insights'][insightIndex] as String;
                                            
                                            return Padding(
                                              padding: const EdgeInsets.only(bottom: 4),
                                              child: Row(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  const Text('• ', style: TextStyle(fontSize: 12)),
                                                  Expanded(
                                                    child: Text(
                                                      insightText,
                                                      style: const TextStyle(fontSize: 12),
                                                      maxLines: 2,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Loading indicator
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildLegendItem({required Color color, required String label}) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
  
  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
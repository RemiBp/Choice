import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:google_maps_cluster_manager/google_maps_cluster_manager.dart' as cluster_manager;
import '../utils/custom_heatmap.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'utils.dart';
import '../models/user_hotspot.dart' as models;
import '../models/faker_data.dart';
import '../utils/constants.dart' as constants;
import 'dart:ui' as ui;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/services.dart';
import '../services/secure_storage_service.dart';
import 'package:timeago/timeago.dart' as timeago;

void initializeTimeago() {
  try {
    timeago.setLocaleMessages('fr', timeago.FrMessages());
    timeago.setLocaleMessages('en', timeago.EnMessages());
    print("🕰️ Timeago locales initialized.");
  } catch (e) {
    print("🕰️ Error initializing timeago locales: $e");
  }
}

class Place with cluster_manager.ClusterItem {
  final String id;
  final String name;
  @override
  final LatLng location;
  final bool isZone;
  final int? visitorCount;
  final DateTime? liveTimestamp;

  Place({
    required this.id,
    required this.name,
    required this.location,
    this.isZone = false,
    this.visitorCount,
    this.liveTimestamp,
  });

  Marker toMarker({VoidCallback? onTap}) => Marker(
    markerId: MarkerId(id),
    position: location,
    icon: isZone
        ? BitmapDescriptor.defaultMarker
        : BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
    infoWindow: InfoWindow(
      title: name,
      snippet: isZone
          ? '$visitorCount visiteurs'
          : (liveTimestamp != null ? 'Vu à ${DateFormat.Hms().format(liveTimestamp!)}' : '')
    ),
    onTap: onTap,
    zIndex: isZone ? 0.0 : 1.0,
  );
}

class LiveUserData {
  final String userId;
  final LatLng location;
  final DateTime timestamp;

  LiveUserData({required this.userId, required this.location, required this.timestamp});
}

class NearbySearchEvent {
  final String id = UniqueKey().toString();
  final String userId;
  final String query;
  final LatLng location;
  final DateTime timestamp;

  NearbySearchEvent({required this.userId, required this.query, required this.location, required this.timestamp});
}

class PublicUserProfile {
  final String id;
  final String name;
  final String? profilePicture;
  final String? bio;
  final List<String> likedTags;

  PublicUserProfile({
    required this.id,
    required this.name,
    this.profilePicture,
    this.bio,
    this.likedTags = const [],
  });

  factory PublicUserProfile.fromJson(Map<String, dynamic> json) {
    return PublicUserProfile(
      id: json['id'] as String? ?? 'unknown_id', // Handle potential null ID
      name: json['name'] as String? ?? 'Utilisateur',
      profilePicture: json['profilePicture'] as String?,
      bio: json['bio'] as String?,
      likedTags: List<String>.from(json['liked_tags'] ?? []),
    );
  }
}

class ActiveUser {
  final String userId;
  final String name;
  final String? profilePicture;
  final LatLng location;
  final DateTime lastSeen;
  final double? distance;

  ActiveUser({
    required this.userId,
    required this.name,
    this.profilePicture,
    required this.location,
    required this.lastSeen,
    this.distance,
  });

  factory ActiveUser.fromJson(Map<String, dynamic> json) {
    LatLng? loc;
    if (json['location'] != null) {
        if (json['location']['type'] == 'Point' && json['location']['coordinates'] is List && json['location']['coordinates'].length == 2) {
            loc = LatLng(json['location']['coordinates'][1], json['location']['coordinates'][0]);
        } else if (json['location'] is Map && json['location']['latitude'] != null && json['location']['longitude'] != null) {
             // Added check for Map type here
             loc = LatLng(json['location']['latitude'], json['location']['longitude']);
        }
    }
    loc ??= const LatLng(0, 0);

    return ActiveUser(
      userId: json['userId'] as String? ?? 'unknown_user', // Handle potential null ID
      name: json['name'] as String? ?? 'Utilisateur Actif',
      profilePicture: json['profilePicture'] as String?,
      location: loc,
      lastSeen: DateTime.tryParse(json['lastSeen'] as String? ?? '') ?? DateTime.now(), // Safer parsing
      distance: (json['distance'] as num?)?.toDouble(),
    );
  }
}

class HeatmapScreen extends StatefulWidget {
  final String userId;
  final String? producerName;

  const HeatmapScreen({Key? key, required this.userId, this.producerName}) : super(key: key);

  @override
  _HeatmapScreenState createState() => _HeatmapScreenState();
}

class _HeatmapScreenState extends State<HeatmapScreen> {
  GoogleMapController? _mapController;
  GoogleMapController? _googleMapController;
  bool _isLoading = true;
  bool _showLegend = false;
  String _selectedTimeFilter = 'Tous';
  String _selectedDayFilter = 'Tous';
  
  List<models.UserHotspot> _hotspots = [];
  List<models.UserHotspot> _filteredHotspots = [];
  Map<MarkerId, Marker> _markers = {};
  
  IO.Socket? _socket;
  
  late cluster_manager.ClusterManager _clusterManager;
  Set<Marker> _clusterMarkers = {};
  List<Place> _places = [];
  
  final List<NearbySearchEvent> _nearbySearchEvents = [];
  final Duration _searchEventTimeout = const Duration(minutes: 5);
  
  List<ActiveUser> _activeUsers = [];
  Timer? _activeUserPollTimer;
  final Duration _activeUserPollInterval = const Duration(seconds: 45);
  bool _isFetchingActiveUsers = false;
  
  final CameraPosition _initialCameraPosition = const CameraPosition(
    target: LatLng(48.8566, 2.3522),
    zoom: 13,
  );
  
  Map<String, Map<String, dynamic>> _zoneStats = {};
  String? _selectedZoneId;
  List<Map<String, dynamic>> _zoneInsights = [];
  
  final List<String> _timeFilterOptions = ['Tous', 'Matin', 'Après-midi', 'Soir'];
  final List<String> _dayFilterOptions = ['Tous', 'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];
  
  final _customPushTitleController = TextEditingController();
  final _customPushBodyController = TextEditingController();
  final _customDiscountController = TextEditingController(text: '30');
  final _customDurationController = TextEditingController(text: '1');
  
  PublicUserProfile? _fetchedUserProfile;
  bool _isFetchingProfile = false;
  bool _isLoadingInsights = false;
  
  @override
  void initState() {
    super.initState();
    initializeTimeago();
    _clusterManager = _initClusterManager();
    _loadData();
    _initSocket();
    Timer.periodic(const Duration(minutes: 1), (_) => _cleanupSearchEvents());
    _startActiveUserPolling();
  }
  
  @override
  void dispose() {
    _socket?.disconnect();
    _socket?.dispose();
    _activeUserPollTimer?.cancel();
    _customPushTitleController.dispose();
    _customPushBodyController.dispose();
    _customDiscountController.dispose();
    _customDurationController.dispose();
    _googleMapController?.dispose();
    super.dispose();
  }
  
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final locationData = await _fetchProducerLocation();
      
      final hotspots = await _fetchHotspots(
        locationData['latitude'] ?? 48.8566,
        locationData['longitude'] ?? 2.3522,
      );
      
      setState(() {
        _hotspots = hotspots;
        _filteredHotspots = List.from(hotspots);
        
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
        
        _generateZoneStats();
        
        _loadZoneInsights();
        
        _isLoading = false;
      });
      
      if (_mapController != null) {
        _mapController!.animateCamera(
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
      final url = Uri.parse('${constants.getBaseUrl()}/api/producers/${widget.userId}/location');
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
    final url = Uri.parse('${constants.getBaseUrl()}/api/location-history/hotspots').replace(
      queryParameters: {
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'radius': '2000',
      },
    );
    
    final response = await http.get(url);
    
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data
          .map((item) => models.UserHotspot.fromJson(item))
          .where((hotspot) => hotspot.latitude != 0 && hotspot.longitude != 0)
          .toList();
    } else {
      print('❌ Erreur lors de la récupération des hotspots: ${response.statusCode} ${response.body}');
      return [];
    }
  }
  
  void _applyFilters() {
    setState(() {
      _filteredHotspots = _hotspots.where((hotspot) {
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
        
        if (_selectedDayFilter != 'Tous') {
          final dayDistribution = hotspot.dayDistribution;
          String dayKey = _selectedDayFilter.toLowerCase();
          
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
      
      _generateZoneStats();
    });
  }
  
  void _selectZone(String zoneId) {
    setState(() {
      _selectedZoneId = zoneId;
    });
    
    _showZoneDetailsSheet();
  }
  
  void _showZoneDetailsSheet() {
    final selectedHotspot = _hotspots.firstWhere(
      (hotspot) => hotspot.id == _selectedZoneId,
      orElse: () => models.UserHotspot(id: 'error', zoneName: 'Erreur', latitude: 0, longitude: 0, visitorCount: 0, intensity: 0, timeDistribution: {}, dayDistribution: {})
    );
    
    if (selectedHotspot.id == 'error') {
        print("Error: Could not find selected hotspot details.");
        return;
    }

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
                      _buildStatCard(
                        icon: Icons.people,
                        title: 'Affluence',
                        value: '${selectedHotspot.visitorCount}',
                        subtitle: 'visiteurs sur la période',
                        color: Colors.blue,
                      ),
                      const SizedBox(height: 16),
                      
                      const Text('Distribution par heure', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      Container(
                        height: 180,
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: _buildTimeDistributionFlChart(selectedHotspot.timeDistribution),
                      ),
                      const SizedBox(height: 20),
                      
                      const Text('Distribution par jour', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      Container(
                        height: 200,
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: _buildDayDistributionFlChart(selectedHotspot.dayDistribution),
                      ),
                      const SizedBox(height: 20),
                      
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
  
  Widget _buildTimeDistributionFlChart(Map<String, double> timeDistribution) {
    final morningValue = (timeDistribution['morning'] ?? 0.0);
    final afternoonValue = (timeDistribution['afternoon'] ?? 0.0);
    final eveningValue = (timeDistribution['evening'] ?? 0.0);
    final total = morningValue + afternoonValue + eveningValue;
    final double safeTotal = total == 0 ? 1.0 : total;

    const Color morningColor = Colors.orangeAccent;
    const Color afternoonColor = Colors.lightBlueAccent;
    const Color eveningColor = Colors.purpleAccent;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: 1.0,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (group) => Colors.blueGrey.withOpacity(0.8),
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              String label;
              switch (group.x.toInt()) {
                case 0: label = 'Matin'; break;
                case 1: label = 'Après-midi'; break;
                case 2: label = 'Soir'; break;
                default: label = '';
              }
              return BarTooltipItem(
                '$label\n',
                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                children: <TextSpan>[
                  TextSpan(
                    text: (rod.toY * 100).toStringAsFixed(0) + '%',
                    style: const TextStyle(color: Colors.yellow, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ],
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                String text = '';
                switch (value.toInt()) {
                  case 0: text = 'Matin'; break;
                  case 1: text = 'Après-midi'; break;
                  case 2: text = 'Soir'; break;
                }
                return Padding(
                   padding: const EdgeInsets.only(top: 4.0),
                   child: Text(text, style: const TextStyle(fontSize: 12))
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: 0.2,
              getTitlesWidget: (value, meta) {
                if (value == 0 || value == 1.0) return Container();
                return Text('${(value * 100).toInt()}%', style: const TextStyle(fontSize: 10));
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        barGroups: [
          BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: morningValue / safeTotal, color: morningColor, width: 22)]),
          BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: afternoonValue / safeTotal, color: afternoonColor, width: 22)]),
          BarChartGroupData(x: 2, barRods: [BarChartRodData(toY: eveningValue / safeTotal, color: eveningColor, width: 22)]),
        ],
        gridData: const FlGridData(show: false),
      ),
    );
  }

  Widget _buildDayDistributionFlChart(Map<String, double> dayDistribution) {
    final List<String> dayKeys = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
    final Map<String, String> dayTranslation = {
      'monday': 'Lun', 'tuesday': 'Mar', 'wednesday': 'Mer', 'thursday': 'Jeu', 'friday': 'Ven', 'saturday': 'Sam', 'sunday': 'Dim'
    };
    double maxValue = dayDistribution.values.fold(0.0, (max, v) => v > max ? v : max);
    if (maxValue == 0) maxValue = 1.0;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxValue * 1.1,
        barTouchData: BarTouchData(
          enabled: true,
           touchTooltipData: BarTouchTooltipData(
             getTooltipColor: (group) => Colors.blueGrey.withOpacity(0.8),
             getTooltipItem: (group, groupIndex, rod, rodIndex) {
              String day = dayTranslation[dayKeys[groupIndex]] ?? '';
              String valueText = (rod.toY).toStringAsFixed(1); 
              return BarTooltipItem(
                '$day\n', 
                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                children: <TextSpan>[
                  TextSpan(
                    text: valueText,
                    style: const TextStyle(color: Colors.yellow, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ],
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                 if (value.toInt() >= dayKeys.length) return Container(); // Avoid index out of bounds
                 final dayKey = dayKeys[value.toInt()];
                return Padding(
                   padding: const EdgeInsets.only(top: 4.0),
                   child: Text(dayTranslation[dayKey] ?? '', style: const TextStyle(fontSize: 11))
                );
              },
            ),
          ),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(dayKeys.length, (index) {
          final dayKey = dayKeys[index];
          final value = dayDistribution[dayKey] ?? 0.0;
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: value,
                color: Colors.primaries[index % Colors.primaries.length].withOpacity(0.8),
                width: 18,
                borderRadius: BorderRadius.circular(4),
              )
            ],
          );
        }),
        gridData: const FlGridData(show: false),
      ),
    );
  }

  Widget _buildActionRecommendations(models.UserHotspot hotspot) {
    List<Map<String, dynamic>> recommendations = [];
    
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
    
    if (hotspot.intensity > 0.7) {
      recommendations.add({
        'title': 'Zone à fort potentiel',
        'description': 'Cette zone attire beaucoup de visiteurs. '
                      'Envisagez des actions promotionnelles ciblées ou une présence physique.',
        'icon': Icons.trending_up,
        'color': Colors.purple,
      });
    }
    
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
    _zoneStats = {};
    
    for (var hotspot in _filteredHotspots) {
      final id = hotspot.id;
      final visitorCount = hotspot.visitorCount;
      final intensity = hotspot.intensity;
      
      final timeDistribution = hotspot.timeDistribution;
      final bestTime = _getBestTimeSlot(timeDistribution);
      
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
    return 120 * intensity;
  }
  
  List<WeightedLatLng> _getHeatmapPoints() {
    return _filteredHotspots.map((hotspot) {
      final intensity = (hotspot.intensity ?? 0.0).clamp(0.0, 1.0);
      return WeightedLatLng(LatLng(hotspot.latitude, hotspot.longitude), weight: intensity);
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
          GoogleMap(
            initialCameraPosition: _initialCameraPosition,
            onMapCreated: (controller) {
              setState(() {
                _mapController = controller;
                _googleMapController = controller;
              });
            },
            markers: Set<Marker>.of(_markers.values),
            myLocationButtonEnabled: true,
            myLocationEnabled: true,
            mapType: MapType.normal,
            buildingsEnabled: true,
            compassEnabled: true,
            trafficEnabled: false,
            circles: _createHeatmapCircles(),
          ),
          
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
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
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

  Set<Circle> _createHeatmapCircles() {
    if (_filteredHotspots.isEmpty) {
      return {};
    }

    Set<Circle> circles = {};
    for (var hotspot in _filteredHotspots) {
      final color = _getColorForIntensity(hotspot.intensity);
      
      circles.add(
        Circle(
          circleId: CircleId('heatmap_${hotspot.id}'),
          center: LatLng(hotspot.latitude, hotspot.longitude),
          radius: 50 + (hotspot.intensity * 100),
          fillColor: color.withOpacity(0.7),
          strokeWidth: 0,
        ),
      );
    }
    
    return circles;
  }
  
  Color _getColorForIntensity(double intensity) {
    if (intensity < 0.3) {
      return Colors.blue;
    } else if (intensity < 0.6) {
      return Colors.yellow;
    } else {
      return Colors.red;
    }
  }

  void _updatePlacesList() {
    List<Place> newPlaces = [];

    for (var hotspot in _filteredHotspots) {
      newPlaces.add(Place(
        id: hotspot.id,
        name: hotspot.zoneName,
        location: LatLng(hotspot.latitude, hotspot.longitude),
        isZone: true,
        visitorCount: hotspot.visitorCount,
      ));
    }

    for (var activeUser in _activeUsers) {
       newPlaces.add(Place(
        id: 'active_${activeUser.userId}',
        name: activeUser.name,
        location: activeUser.location,
        isZone: false,
        liveTimestamp: activeUser.lastSeen,
      ));
    }

    setState(() {
       _places = newPlaces;
       _clusterManager.setItems(_places);
    });
  }

  void _initSocket() {
    // Implementation of _initSocket method
  }

  void _handleUserNearby() {
    // Implementation of _handleUserNearby method
  }

  void _handleUserSearchNearby() {
    // Implementation of _handleUserSearchNearby method
  }

  void _parseLocation() {
    // Implementation of _parseLocation method
  }

  void _scheduleLiveUserRemoval() {
    // Implementation of _scheduleLiveUserRemoval method
  }

  void _startActiveUserPolling() {
    // Implementation of _startActiveUserPolling method
  }

  void _cleanupSearchEvents() {
    final now = DateTime.now();
    setState(() {
      _nearbySearchEvents.removeWhere((event) => now.difference(event.timestamp) > _searchEventTimeout);
    });
  }

  void _onSendPushPressed() {
    // Implementation of _onSendPushPressed method
  }

  void _showSendPushDialog() {
    // Implementation of _showSendPushDialog method
  }

  Future<void> _fetchPublicUserInfo(String targetUserId) async {
    // Implementation of _fetchPublicUserInfo method
  }

  void _updateMarkers(Set<Marker> markers) {
    if (!mounted) return;
    setState(() {
      _clusterMarkers = markers;
    });
  }

  Future<Marker> _markerBuilder(cluster_manager.Cluster<Place> cluster) async {
    final markerIdStr = cluster.location.toString(); 
    return Marker(
      markerId: MarkerId(markerIdStr),
      position: cluster.location,
      onTap: () {
        print('---- Tapped Cluster: ${markerIdStr}, Multiple: ${cluster.isMultiple}');
        print(cluster.items);
        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(cluster.location, 15)); 
        
        if (!cluster.isMultiple) {
           final place = cluster.items.first;
           if (place.isZone) {
             _selectZone(place.id); 
           } else {
             print("Tapped on single live user marker: ${place.name}");
             _fetchPublicUserInfo(place.id.replaceFirst('active_', '')); 
           }
        }
      },
      icon: await _getMarkerBitmap(cluster.isMultiple ? 125 : 75, 
          text: cluster.isMultiple ? cluster.count.toString() : null),
    );
  }

  Future<BitmapDescriptor> _getMarkerBitmap(int size, {String? text}) async {
    if (size <= 0) {
      print("Error: Invalid size for marker bitmap ($size).");
      return BitmapDescriptor.defaultMarker; 
    }

    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    final Paint paint1 = Paint()..color = Colors.deepPurple;
    final Paint paint2 = Paint()..color = Colors.white;

    canvas.drawCircle(Offset(size / 2, size / 2), size / 2.0, paint1);
    canvas.drawCircle(Offset(size / 2, size / 2), size / 2.2, paint2);
    canvas.drawCircle(Offset(size / 2, size / 2), size / 2.8, paint1);

    if (text != null) {
      TextPainter painter = TextPainter(textDirection: ui.TextDirection.ltr);
      painter.text = TextSpan(
        text: text,
        style: TextStyle(
            fontSize: size / 3,
            color: Colors.white,
            fontWeight: FontWeight.normal),
      );
      painter.layout();
      painter.paint(
        canvas,
        Offset(size / 2 - painter.width / 2, size / 2 - painter.height / 2),
      );
    }

    final img = await pictureRecorder.endRecording().toImage(size, size);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);

    if (data == null) {
      print("Error: Failed to get byte data from image for marker.");
      return BitmapDescriptor.defaultMarker;
    }

    return BitmapDescriptor.fromBytes(data.buffer.asUint8List());
  }

  Widget _buildNearbySearchFeed() {
    if (_nearbySearchEvents.isEmpty) {
      return const Center(
          child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                  'Aucune recherche récente détectée à proximité.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey)
              )
          )
      );
    }
    return ListView.builder(
      itemCount: _nearbySearchEvents.length,
      itemBuilder: (context, index) {
        final event = _nearbySearchEvents[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: ListTile(
            leading: const Icon(Icons.search, color: Colors.blueAccent),
            title: Text('"${event.query}"', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(
              'Il y a ${timeago.format(event.timestamp, locale: 'fr')}',
              style: const TextStyle(fontSize: 11)
            ),
            trailing: TextButton(
              child: const Text('Voir', style: TextStyle(color: Colors.blueAccent)),
              onPressed: () {
                _fetchPublicUserInfo(event.userId);
              },
            ),
          ),
        );
      },
    );
  }

  cluster_manager.ClusterManager _initClusterManager() {
    return cluster_manager.ClusterManager<Place>(
      _places,
      _updateMarkers,
      markerBuilder: _markerBuilder,
      levels: const [1, 4.25, 6.75, 8.25, 11.5, 14.5, 16.0, 16.5, 20.0],
      extraPercent: 0.2,
      stopClusteringZoom: 17.0,
    );
  }
}


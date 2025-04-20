import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/user_hotspot.dart';
import '../models/geo_action.dart';
import '../services/heatmap_service.dart';
import '../utils/constants.dart' as constants;

/// Écran de heatmap amélioré pour les producteurs
class EnhancedHeatmapScreen extends StatefulWidget {
  final String producerId;
  final CameraPosition? initialPosition;

  const EnhancedHeatmapScreen({
    Key? key,
    required this.producerId,
    this.initialPosition,
  }) : super(key: key);

  @override
  _EnhancedHeatmapScreenState createState() => _EnhancedHeatmapScreenState();
}

class _EnhancedHeatmapScreenState extends State<EnhancedHeatmapScreen> {
  // Services
  final HeatmapService _heatmapService = HeatmapService();
  
  // Contrôleurs
  GoogleMapController? _mapController;
  final TextEditingController _messageController = TextEditingController();
  
  // État de la carte
  bool _isLoading = true;
  bool _isLocalView = false; // Vue locale (500m) ou globale
  String _selectedTimeFilter = 'Tous';
  String _selectedDayFilter = 'Tous';
  double _zoomLevel = 14.0;
  
  // Données de carte
  List<UserHotspot> _hotspots = [];
  List<UserHotspot> _filteredHotspots = [];
  Map<MarkerId, Marker> _markers = {};
  Set<Circle> _circles = {};
  
  // Position par défaut (Paris)
  CameraPosition _initialCameraPosition = const CameraPosition(
    target: LatLng(48.8566, 2.3522),
    zoom: 14,
  );
  
  // Zone sélectionnée
  UserHotspot? _selectedHotspot;
  bool _showActionPanel = false;
  
  // Historique des actions
  List<GeoAction> _recentActions = [];
  
  @override
  void initState() {
    super.initState();
    
    // Définir la position initiale si fournie
    if (widget.initialPosition != null) {
      _initialCameraPosition = widget.initialPosition!;
    }
    
    // Charger les données
    _loadData();
    _loadRecentActions();
  }
  
  @override
  void dispose() {
    _mapController?.dispose();
    _messageController.dispose();
    super.dispose();
  }
  
  /// Charge les données de hotspots
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Récupérer la position du producteur
      final locationData = await _fetchProducerLocation();
      final latitude = locationData['latitude'] ?? 48.8566;
      final longitude = locationData['longitude'] ?? 2.3522;
      
      // Charger les hotspots autour de cette position
      final hotspots = await _heatmapService.getHotspots(
        latitude: latitude,
        longitude: longitude,
        radius: _isLocalView ? 500 : 2000,
      );
      
      setState(() {
        _hotspots = hotspots;
        _filteredHotspots = List.from(hotspots);
        _updateMarkersAndCircles();
        _isLoading = false;
      });
      
      // Centrer la carte sur la position du producteur
      if (_mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng(latitude, longitude),
            _isLocalView ? 15.5 : 14.0,
          ),
        );
      }
    } catch (e) {
      print('❌ Erreur lors du chargement des données: $e');
      setState(() {
        _isLoading = false;
      });
      
      _showErrorSnackbar('Erreur lors du chargement des données');
    }
  }
  
  /// Charge l'historique des actions récentes
  Future<void> _loadRecentActions() async {
    try {
      final actions = await _heatmapService.getProducerActions(widget.producerId);
      
      setState(() {
        _recentActions = actions;
      });
    } catch (e) {
      print('❌ Erreur lors du chargement des actions: $e');
    }
  }
  
  /// Récupère la position du producteur
  Future<Map<String, dynamic>> _fetchProducerLocation() async {
    try {
      final url = Uri.parse('${constants.getBaseUrl()}/api/producers/${widget.producerId}/location');
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        print('❌ Erreur lors de la récupération de la position: ${response.body}');
        return {
          'latitude': 48.8566,
          'longitude': 2.3522,
        };
      }
    } catch (e) {
      print('❌ Erreur lors de la récupération de la position: $e');
      return {
        'latitude': 48.8566,
        'longitude': 2.3522,
      };
    }
  }
  
  /// Met à jour les marqueurs et cercles de la carte
  void _updateMarkersAndCircles() {
    // Marqueurs pour chaque hotspot
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
        onTap: () => _selectHotspot(hotspot),
      );
    }
    
    // Cercles pour la heatmap
    _circles = _createHeatmapCircles();
  }
  
  /// Crée les cercles de la heatmap
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
          radius: 50 + (hotspot.intensity * 100), // Rayon variable selon l'intensité
          fillColor: color.withOpacity(0.7),
          strokeWidth: 0,
        ),
      );
    }
    
    return circles;
  }
  
  /// Sélectionne un hotspot
  void _selectHotspot(UserHotspot hotspot) {
    setState(() {
      _selectedHotspot = hotspot;
      _showActionPanel = true;
    });
    
    // Centrer la carte sur le hotspot sélectionné
    _mapController?.animateCamera(
      CameraUpdate.newLatLng(LatLng(hotspot.latitude, hotspot.longitude)),
    );
  }
  
  /// Applique les filtres de jour et d'heure
  void _applyFilters() {
    setState(() {
      // Filtrer les hotspots
      _filteredHotspots = _hotspots.where((hotspot) {
        // Filtre par heure
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
        
        // Filtre par jour
        if (_selectedDayFilter != 'Tous') {
          final dayDistribution = hotspot.dayDistribution;
          String dayKey = _selectedDayFilter.toLowerCase();
          
          // Convertir les jours français en anglais
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
      
      // Mettre à jour les marqueurs et cercles
      _updateMarkersAndCircles();
      
      // Réinitialiser la sélection
      _selectedHotspot = null;
      _showActionPanel = false;
    });
  }
  
  /// Bascule entre la vue locale et globale
  void _toggleViewMode() {
    setState(() {
      _isLocalView = !_isLocalView;
      _zoomLevel = _isLocalView ? 15.5 : 14.0;
    });
    
    // Recharger les données avec le nouveau rayon
    _loadData();
  }
  
  /// Envoie une notification aux utilisateurs dans la zone
  Future<void> _sendZoneAction() async {
    if (_selectedHotspot == null || _messageController.text.isEmpty) {
      _showErrorSnackbar('Veuillez sélectionner une zone et entrer un message');
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final request = GeoActionRequest(
        producerId: widget.producerId,
        zoneId: _selectedHotspot!.id,
        message: _messageController.text,
        radius: _isLocalView ? 500 : 1000,
      );
      
      final result = await _heatmapService.sendZoneNotification(request);
      
      setState(() {
        _isLoading = false;
        _showActionPanel = false;
        _messageController.clear();
      });
      
      // Afficher un message de succès
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Action envoyée à ${result['targetedUsers']} utilisateurs'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Recharger les actions récentes
      _loadRecentActions();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      _showErrorSnackbar('Erreur lors de l\'envoi de l\'action');
    }
  }
  
  /// Affiche un message d'erreur
  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
  
  /// Détermine la teinte du marqueur en fonction de l'intensité
  double _getMarkerHue(double intensity) {
    // Convertir intensité (0-1) en teinte (0-360)
    // Faible intensité: rouge (0)
    // Intensité moyenne: jaune (60)
    // Forte intensité: vert (120)
    return 120 * intensity;
  }
  
  /// Détermine la couleur en fonction de l'intensité
  Color _getColorForIntensity(double intensity) {
    if (intensity < 0.3) {
      return Colors.blue;
    } else if (intensity < 0.6) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Heatmap & Actions'),
        actions: [
          // Toggle vue locale/globale
          IconButton(
            icon: Icon(_isLocalView ? Icons.zoom_out : Icons.zoom_in),
            tooltip: _isLocalView ? 'Vue globale' : 'Vue locale (500m)',
            onPressed: _toggleViewMode,
          ),
          // Bouton de rafraîchissement
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Rafraîchir',
          ),
        ],
      ),
      body: Stack(
        children: [
          // 1. CARTE
          GoogleMap(
            initialCameraPosition: _initialCameraPosition,
            onMapCreated: (controller) {
              setState(() {
                _mapController = controller;
              });
            },
            markers: Set<Marker>.of(_markers.values),
            myLocationButtonEnabled: true,
            myLocationEnabled: true,
            mapType: MapType.normal,
            buildingsEnabled: true,
            compassEnabled: true,
            trafficEnabled: false,
            circles: _circles,
            onTap: (_) {
              // Cacher le panneau d'action au tap sur la carte
              setState(() {
                _showActionPanel = false;
              });
            },
          ),
          
          // 2. FILTRES
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
                    Row(
                      children: [
                        Icon(_isLocalView 
                          ? Icons.location_searching 
                          : Icons.map,
                          color: Colors.deepPurple,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isLocalView 
                            ? 'Vue locale (500m)' 
                            : 'Vue globale',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.filter_alt, size: 16),
                          label: const Text('Filtres'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.deepPurple,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                            minimumSize: const Size(0, 36),
                          ),
                          onPressed: () => _showFilterBottomSheet(context),
                        ),
                      ],
                    ),
                    if (_selectedTimeFilter != 'Tous' || _selectedDayFilter != 'Tous')
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Wrap(
                          spacing: 8,
                          children: [
                            if (_selectedTimeFilter != 'Tous')
                              Chip(
                                label: Text(_selectedTimeFilter),
                                backgroundColor: Colors.deepPurple.withOpacity(0.1),
                                deleteIcon: const Icon(Icons.close, size: 16),
                                onDeleted: () {
                                  setState(() {
                                    _selectedTimeFilter = 'Tous';
                                  });
                                  _applyFilters();
                                },
                              ),
                            if (_selectedDayFilter != 'Tous')
                              Chip(
                                label: Text(_selectedDayFilter),
                                backgroundColor: Colors.deepPurple.withOpacity(0.1),
                                deleteIcon: const Icon(Icons.close, size: 16),
                                onDeleted: () {
                                  setState(() {
                                    _selectedDayFilter = 'Tous';
                                  });
                                  _applyFilters();
                                },
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          
          // 3. PANNEAU D'ACTION POUR LA ZONE SÉLECTIONNÉE
          if (_showActionPanel && _selectedHotspot != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 96,
              child: Card(
                elevation: 6,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Titre de la zone
                      Row(
                        children: [
                          Icon(Icons.place, color: _getColorForIntensity(_selectedHotspot!.intensity)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _selectedHotspot!.zoneName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            splashRadius: 24,
                            onPressed: () {
                              setState(() {
                                _showActionPanel = false;
                              });
                            },
                          ),
                        ],
                      ),
                      const Divider(),
                      
                      // Statistiques clés
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatItem(
                            icon: Icons.people,
                            value: '${_selectedHotspot!.visitorCount}',
                            label: 'visiteurs',
                            color: Colors.blue,
                          ),
                          _buildStatItem(
                            icon: Icons.local_fire_department,
                            value: '${(_selectedHotspot!.intensity * 100).toInt()}%',
                            label: 'intensité',
                            color: _getColorForIntensity(_selectedHotspot!.intensity),
                          ),
                          _buildStatItem(
                            icon: Icons.access_time,
                            value: _getBestTimeSlot(_selectedHotspot!.timeDistribution),
                            label: 'pic',
                            color: Colors.orange,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // Action principale - Envoyer notification
                      TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: 'Message à envoyer à cette zone...',
                          filled: true,
                          fillColor: Colors.grey[100],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.all(12),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.send),
                            onPressed: _sendZoneAction,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // Bouton d'action principal
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.notifications_active),
                          label: Text('Envoyer à ${_selectedHotspot!.visitorCount} personnes'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _sendZoneAction,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          
          // 4. PANNEAU INFÉRIEUR - SUGGESTIONS ET HISTORIQUE
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
                    // Indicateur
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    
                    // Historique des actions
                    Row(
                      children: [
                        Icon(Icons.history, color: Colors.deepPurple, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'Vos dernières actions',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    SizedBox(
                      height: 80,
                      child: _recentActions.isEmpty
                        ? const Center(
                            child: Text('Aucune action récente'),
                          )
                        : ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _recentActions.length,
                            itemBuilder: (context, index) {
                              final action = _recentActions[index];
                              return Container(
                                width: 220,
                                margin: const EdgeInsets.only(right: 12),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: action.color.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: action.color.withOpacity(0.3),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(action.icon, size: 16, color: action.color),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            action.zoneName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      action.message,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 12),
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
          
          // 5. INDICATEUR DE CHARGEMENT
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
  
  /// Affiche la feuille de filtres
  void _showFilterBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filtres',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            
            // Filtre par heure
            const Text(
              'Heure de la journée',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              children: [
                'Tous',
                'Matin',
                'Après-midi',
                'Soir',
              ].map((time) => ChoiceChip(
                label: Text(time),
                selected: _selectedTimeFilter == time,
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _selectedTimeFilter = time;
                    });
                    Navigator.pop(context);
                    _applyFilters();
                  }
                },
              )).toList(),
            ),
            const SizedBox(height: 20),
            
            // Filtre par jour
            const Text(
              'Jour de la semaine',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              children: [
                'Tous',
                'Lundi',
                'Mardi',
                'Mercredi',
                'Jeudi',
                'Vendredi',
                'Samedi',
                'Dimanche',
              ].map((day) => ChoiceChip(
                label: Text(day),
                selected: _selectedDayFilter == day,
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _selectedDayFilter = day;
                    });
                    Navigator.pop(context);
                    _applyFilters();
                  }
                },
              )).toList(),
            ),
            const SizedBox(height: 20),
            
            // Bouton d'application
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _applyFilters();
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Appliquer'),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  /// Construit un élément de statistique
  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
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
  
  /// Retourne le créneau horaire avec la plus grande affluence
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
        return 'Matin';
      case 'afternoon':
        return 'Après-midi';
      case 'evening':
        return 'Soir';
      default:
        return '';
    }
  }
} 
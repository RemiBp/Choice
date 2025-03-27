import 'dart:async';
import 'dart:math' as math;
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../services/location_service.dart';
import '../services/api_service.dart';
import '../models/producer.dart';
import '../providers/theme_provider.dart';
import '../widgets/filters/filter_panel.dart';
import '../widgets/filters/filter_section.dart';
import '../widgets/filters/filter_toggle_card.dart';
import '../widgets/filters/filter_chip_group.dart';
import '../widgets/filters/filter_chip.dart';
import '../widgets/filters/floating_filter_button.dart';
import '../widgets/filters/custom_filter_chip.dart' as custom;
import 'utils.dart';
import 'producer_screen.dart';

class MapScreen extends StatefulWidget {
  final String? userId;
  final String? initialCategory;
  final LatLng? initialPosition;

  const MapScreen({Key? key, this.userId, this.initialCategory, this.initialPosition}) : super(key: key);

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // Contrôleurs
  GoogleMapController? _mapController;
  
  // Position initiale (Paris par défaut)
  LatLng _initialPosition = const LatLng(48.8566, 2.3522);
  
  // Markers et clusters
  final Set<Marker> _markers = {};
  final Map<String, dynamic> _producerData = {};
  
  // Services
  final ApiService _apiService = ApiService();
  final LocationService _locationService = LocationService();
  final Location _location = Location();
  LocationData? _currentPosition;
  
  // États
  bool _isLoading = false;
  bool _mapInitialized = false;
  bool _filterPanelVisible = false;
  
  // Filtres
  List<String> _selectedCategories = [];
  List<String> _selectedInterests = [];
  bool _showFriendsOnly = false;
  double _maxDistance = 5.0; // km
  double _minRating = 0.0;
  
  @override
  void initState() {
    super.initState();
    
    // Utiliser la position initiale si elle est fournie
    if (widget.initialPosition != null) {
      _initialPosition = widget.initialPosition!;
    }
    
    _initLocation();
    
    if (widget.initialCategory != null) {
      _selectedCategories = [widget.initialCategory!];
    }
  }
  
  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
  
  Future<void> _initLocation() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      await _checkLocationPermission();
      final position = await _locationService.getCurrentPosition();
      
      if (position != null) {
        setState(() {
          _currentPosition = LocationData.fromMap({
            'latitude': position.latitude,
            'longitude': position.longitude,
          });
        });
        
        if (_mapController != null) {
          _mapController!.animateCamera(
            CameraUpdate.newLatLng(
              LatLng(position.latitude, position.longitude)
            )
          );
        }
        
        _loadProducers();
      } else {
        _loadProducers();
      }
    } catch (e) {
      print('❌ Erreur de géolocalisation: $e');
      _loadProducers();
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _checkLocationPermission() async {
    bool serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) {
        return;
      }
    }
    
    PermissionStatus permission = await _location.hasPermission();
    if (permission == PermissionStatus.denied) {
      permission = await _location.requestPermission();
      if (permission == PermissionStatus.denied) {
        return;
      }
    }
  }
  
  Future<void> _loadProducers() async {
    setState(() {
      _isLoading = true;
      _markers.clear();
      _producerData.clear();
    });
    
    try {
      final double latitude = _currentPosition?.latitude ?? _initialPosition.latitude;
      final double longitude = _currentPosition?.longitude ?? _initialPosition.longitude;
      
      // Charger les producteurs à proximité
      final producers = await _apiService.getNearbyProducers(
        latitude,
        longitude,
        radius: _maxDistance * 1000,
      );
      
      // Créer les marqueurs pour chaque producteur
      for (final producer in producers) {
        // Filtrer selon les catégories sélectionnées
        if (_selectedCategories.isNotEmpty && 
            producer['category'] != null &&
            !_selectedCategories.contains(producer['category'])) {
          continue;
        }
        
        // Filtrer selon les intérêts sélectionnés
        if (_selectedInterests.isNotEmpty) {
          final List producerInterests = producer['tags'] ?? [];
          bool hasMatchingInterest = false;
          
          for (final interest in _selectedInterests) {
            if (producerInterests.contains(interest)) {
              hasMatchingInterest = true;
              break;
            }
          }
          
          if (!hasMatchingInterest) continue;
        }
        
        // Filtrer selon l'option "amis uniquement"
        if (_showFriendsOnly && !(producer['is_from_friend'] ?? false)) {
          continue;
        }
        
        // Filtrer selon la note minimale
        final double rating = (producer['rating'] ?? 0).toDouble();
        if (rating < _minRating) continue;
        
        // Extraire les coordonnées
        final coordinates = producer['gps_coordinates']?['coordinates'];
        if (coordinates == null || coordinates.length < 2) continue;
        
        final double lng = coordinates[0].toDouble();
        final double lat = coordinates[1].toDouble();
        
        final String id = producer['_id'] ?? 'unknown_${math.Random().nextInt(10000)}';
        
        // Stocker les données du producteur
        _producerData[id] = producer;
        
        // Créer le marqueur
        final Marker marker = Marker(
          markerId: MarkerId(id),
          position: LatLng(lat, lng),
          infoWindow: InfoWindow(
            title: producer['name'] ?? 'Sans nom',
            snippet: producer['category'] ?? 'Sans catégorie',
          ),
          onTap: () {
            _showProducerDetails(id);
          },
        );
        
        setState(() {
          _markers.add(marker);
        });
      }
    } catch (e) {
      print('❌ Erreur lors du chargement des producteurs: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors du chargement des données: $e'))
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  void _showProducerDetails(String producerId) {
    final producer = _producerData[producerId];
    if (producer == null) return;
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProducerScreen(
          producerId: producerId,
        ),
      ),
    );
  }
  
  void _toggleFilterPanel() {
    setState(() {
      _filterPanelVisible = !_filterPanelVisible;
    });
  }
  
  void _applyFilters() {
    _loadProducers();
    setState(() {
      _filterPanelVisible = false;
    });
  }
  
  void _resetFilters() {
    setState(() {
      _selectedCategories = [];
      _selectedInterests = [];
      _showFriendsOnly = false;
      _maxDistance = 5.0;
      _minRating = 0.0;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Découvrir'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _initLocation,
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Carte Google Maps
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _initialPosition,
              zoom: 14,
            ),
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapType: MapType.normal,
            onMapCreated: (controller) {
              _mapController = controller;
              setState(() {
                _mapInitialized = true;
              });
              
              // Si position disponible, centrer la carte
              if (_currentPosition != null) {
                controller.animateCamera(
                  CameraUpdate.newLatLng(
                    LatLng(
                      _currentPosition!.latitude!,
                      _currentPosition!.longitude!,
                    ),
                  ),
                );
              }
            },
          ),
          
          // Indicateur de chargement
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
            
          // Bouton de filtre
          Positioned(
            top: 16,
            right: 16,
            child: FloatingActionButton(
              mini: true,
              onPressed: _toggleFilterPanel,
              tooltip: 'Filtrer',
              child: Icon(Icons.filter_list),
            ),
          ),
          
          // Panneau de filtres
          if (_filterPanelVisible)
            Container(
              color: Colors.black54,
              child: Center(
                child: Card(
                  margin: EdgeInsets.all(16),
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Filtres', style: Theme.of(context).textTheme.titleLarge),
                        SizedBox(height: 16),
                        // Catégories
                        Text('Catégories', style: Theme.of(context).textTheme.titleMedium),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            'Restaurant', 'Café', 'Bar', 'Boulangerie', 'Épicerie', 'Marché'
                          ].map((category) => Chip(
                            label: Text(category),
                            backgroundColor: _selectedCategories.contains(category)
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.surfaceVariant,
                            labelStyle: TextStyle(
                              color: _selectedCategories.contains(category)
                                  ? Theme.of(context).colorScheme.onPrimary
                                  : Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                            onDeleted: _selectedCategories.contains(category)
                                ? () {
                                    setState(() {
                                      _selectedCategories.remove(category);
                                    });
                                  }
                                : null,
                            deleteIcon: _selectedCategories.contains(category)
                                ? Icon(Icons.cancel, size: 18)
                                : null,
                          )).toList(),
                        ),
                        SizedBox(height: 16),
                        // Boutons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _filterPanelVisible = false;
                                });
                              },
                              child: Text('Annuler'),
                            ),
                            ElevatedButton(
                              onPressed: _applyFilters,
                              child: Text('Appliquer'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
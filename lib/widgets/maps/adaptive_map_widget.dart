import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:flutter_map/flutter_map.dart' hide Marker;
import 'package:flutter_map/flutter_map.dart' as fmap;
import 'package:latlong2/latlong.dart' as latLng;
import '../../screens/utils.dart';

/// Widget qui adapte automatiquement la carte selon la plateforme (mobile ou web)
/// Fournit une interface unifiée pour les deux implémentations
class AdaptiveMapWidget extends StatefulWidget {
  final gmaps.LatLng initialPosition;
  final double initialZoom;
  final Set<gmaps.Marker> markers;
  final Function(gmaps.GoogleMapController)? onMapCreated;
  final Function(gmaps.LatLng)? onTap;
  final Widget? filterPanel; // Panel de filtres à afficher

  const AdaptiveMapWidget({
    Key? key,
    required this.initialPosition,
    this.initialZoom = 15.0,
    this.markers = const {},
    this.onMapCreated,
    this.onTap,
    this.filterPanel,
  }) : super(key: key);

  @override
  State<AdaptiveMapWidget> createState() => _AdaptiveMapWidgetState();
}

class _AdaptiveMapWidgetState extends State<AdaptiveMapWidget> {
  bool _isFilterPanelExpanded = false;
  gmaps.GoogleMapController? _mapController;
  
  // Exposer l'état du panneau pour les tests et le débogage
  bool get isFilterPanelExpanded => _isFilterPanelExpanded;
  
  // Méthode pour ouvrir/fermer le panneau de filtres de l'extérieur
  void toggleFilterPanel() {
    setState(() {
      _isFilterPanelExpanded = !_isFilterPanelExpanded;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    // Récupérer la largeur de l'écran pour la responsivité
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    return Stack(
      children: [
        // Carte adaptative selon la plateforme
        kIsWeb ? _buildWebMap() : _buildMobileMap(),
        
        // Panel de filtres avec animation améliorée
        if (widget.filterPanel != null)
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            transform: Matrix4.translationValues(
              _isFilterPanelExpanded ? 0 : -300.0, 
              0, 
              0
            ),
            width: 300,
            height: screenHeight,
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(2, 0),
                ),
              ],
            ),
            child: SafeArea(
              child: Column(
                children: [
                  // Titre du panneau
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    color: Theme.of(context).primaryColor,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Filtres',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () {
                            setState(() {
                              _isFilterPanelExpanded = false;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  // Contenu du panneau
                  Expanded(
                    child: SingleChildScrollView(
                      child: widget.filterPanel!,
                    ),
                  ),
                ],
              ),
            ),
          ),
        
        // Bouton pour ouvrir le panel de filtres (plus visible)
        if (widget.filterPanel != null && !_isFilterPanelExpanded)
          Positioned(
            top: 16,
            left: 10,
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(30),
              color: Theme.of(context).primaryColor,
              child: InkWell(
                borderRadius: BorderRadius.circular(30),
                onTap: () {
                  setState(() {
                    _isFilterPanelExpanded = true;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: const [
                      Icon(Icons.tune, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        'Filtres',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        
        // Contrôles de navigation de la carte
        Positioned(
          right: 16,
          bottom: 100,
          child: Column(
            children: [
              // Bouton de zoom +
              FloatingActionButton(
                mini: true,
                heroTag: "zoomIn",
                backgroundColor: Colors.white,
                child: const Icon(Icons.add, color: Colors.black87),
                onPressed: () {
                  _zoomIn();
                },
              ),
              const SizedBox(height: 8),
              // Bouton de zoom -
              FloatingActionButton(
                mini: true,
                heroTag: "zoomOut",
                backgroundColor: Colors.white,
                child: const Icon(Icons.remove, color: Colors.black87),
                onPressed: () {
                  _zoomOut();
                },
              ),
              const SizedBox(height: 8),
              // Bouton de localisation
              FloatingActionButton(
                mini: true,
                heroTag: "myLocation",
                backgroundColor: Colors.white,
                child: const Icon(Icons.my_location, color: Colors.blue),
                onPressed: () {
                  _resetMapPosition();
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Construction de la carte pour les plateformes mobiles avec contrôles améliorés
  Widget _buildMobileMap() {
    return gmaps.GoogleMap(
      initialCameraPosition: gmaps.CameraPosition(
        target: widget.initialPosition,
        zoom: widget.initialZoom,
      ),
      markers: _optimizeMarkers(widget.markers),
      onMapCreated: (controller) {
        _mapController = controller;
        if (widget.onMapCreated != null) {
          widget.onMapCreated!(controller);
        }
      },
      onTap: (position) {
        if (widget.onTap != null) {
          widget.onTap!(position);
        }
      },
      myLocationEnabled: true,
      myLocationButtonEnabled: false, // Nous utilisons notre propre bouton
      mapToolbarEnabled: true, // Activer la barre d'outils pour meilleure navigation
      zoomControlsEnabled: true, // Activer les contrôles de zoom natifs
      compassEnabled: true,
      zoomGesturesEnabled: true, // Activer les gestes de zoom
      rotateGesturesEnabled: true, // Activer la rotation
      scrollGesturesEnabled: true, // Activer le défilement
      tiltGesturesEnabled: true, // Activer l'inclinaison
    );
  }

  /// Construction de la carte pour le web avec flutter_map
  /// Flutter Map est plus performant sur le web que GoogleMaps Flutter
  Widget _buildWebMap() {
    final markers = _convertToFlutterMapMarkers(widget.markers);
    
    return fmap.FlutterMap(
      options: fmap.MapOptions(
        center: latLng.LatLng(
          widget.initialPosition.latitude, 
          widget.initialPosition.longitude
        ),
        zoom: widget.initialZoom,
        onTap: (tapPosition, point) {
          if (widget.onTap != null) {
            widget.onTap!(gmaps.LatLng(point.latitude, point.longitude));
          }
          // Fermer le panel de filtres si l'utilisateur tape sur la carte
          if (_isFilterPanelExpanded) {
            setState(() {
              _isFilterPanelExpanded = false;
            });
          }
        }
      ),
      children: [
        fmap.TileLayer(
          urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
          subdomains: const ['a', 'b', 'c'],
        ),
        // Clustering des marqueurs pour une meilleure performance
        MarkerClusterLayerWidget(
          options: MarkerClusterLayerOptions(
            maxClusterRadius: 45,
            size: const Size(40, 40),
            // La propriété fitBoundsOptions a été supprimée dans la nouvelle version
            markers: markers,
            builder: (context, markers) {
              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: Theme.of(context).primaryColor,
                ),
                child: Center(
                  child: Text(
                    markers.length.toString(),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Optimise les marqueurs pour Google Maps
  Set<gmaps.Marker> _optimizeMarkers(Set<gmaps.Marker> markers) {
    // On pourrait implémenter ici une logique de clustering pour Google Maps
    // ou limiter le nombre de marqueurs affichés simultanément
    // si la liste devient trop grande
    
    if (markers.length > 100) {
      // Limiter à 100 marqueurs pour les performances ou
      // implémenter un algorithme de clustering
      return markers.take(100).toSet();
    }
    
    return markers;
  }

  /// Convertit les marqueurs Google Maps en marqueurs Flutter Map
  List<fmap.Marker> _convertToFlutterMapMarkers(Set<gmaps.Marker> googleMarkers) {
    // Cette fonction n'est utilisée que pour le web
    if (!kIsWeb) return [];
    
    // Convertir chaque marqueur Google Maps en marqueur Flutter Map
    List<fmap.Marker> flutterMapMarkers = [];
    
    for (final marker in googleMarkers) {
      flutterMapMarkers.add(
        fmap.Marker(
          point: latLng.LatLng(
            marker.position.latitude,
            marker.position.longitude
          ),
          child: const Icon(
            Icons.location_on,
            color: Colors.red,
          ),
          width: 30.0,
          height: 30.0,
        ),
      );
    }
    
    // Note: Cette implémentation est basique et devrait être étendue
    // selon vos besoins réels (info windows, couleurs, etc.)
    
    return flutterMapMarkers;
  }

  /// Zoom in sur la carte
  void _zoomIn() {
    if (_mapController != null) {
      _mapController!.animateCamera(
        gmaps.CameraUpdate.zoomIn(),
      );
    }
  }

  /// Zoom out sur la carte
  void _zoomOut() {
    if (_mapController != null) {
      _mapController!.animateCamera(
        gmaps.CameraUpdate.zoomOut(),
      );
    }
  }

  /// Réinitialise la position de la carte à la position initiale
  void _resetMapPosition() {
    if (_mapController != null) {
      _mapController!.animateCamera(
        gmaps.CameraUpdate.newLatLngZoom(
          widget.initialPosition,
          widget.initialZoom,
        ),
      );
    }
  }
}
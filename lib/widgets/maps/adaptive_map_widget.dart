import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:flutter_map/flutter_map.dart' hide Marker;
import 'package:flutter_map/flutter_map.dart' as fmap;
import 'package:latlong2/latlong.dart' as latLng;
import '../../utils/constants.dart' as constants;
import 'map_utils.dart';

/// Widget qui adapte automatiquement la carte selon la plateforme (mobile ou web)
/// Fournit une interface unifiée pour les deux implémentations
class AdaptiveMapWidget extends StatefulWidget {
  final gmaps.LatLng initialPosition;
  final double initialZoom;
  final Set<gmaps.Marker> markers;
  final Function(gmaps.GoogleMapController)? onMapCreated;
  final Function(gmaps.LatLng)? onTap;
  final Widget? filterPanel; // Panel de filtres à afficher
  final Function(gmaps.CameraPosition)? onCameraMove;
  final bool zoomControlsEnabled;

  const AdaptiveMapWidget({
    Key? key,
    required this.initialPosition,
    this.initialZoom = 15.0,
    this.markers = const {},
    this.onMapCreated,
    this.onTap,
    this.filterPanel,
    this.onCameraMove,
    this.zoomControlsEnabled = false,
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
      ],
    );
  }

  /// Construction de la carte pour les plateformes mobiles sans aucun contrôle
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
      myLocationEnabled: false,
      myLocationButtonEnabled: false,
      mapToolbarEnabled: false,
      zoomControlsEnabled: widget.zoomControlsEnabled,
      compassEnabled: false,
      zoomGesturesEnabled: true,
      rotateGesturesEnabled: true,
      scrollGesturesEnabled: true,
      tiltGesturesEnabled: true,
      onCameraMove: widget.onCameraMove,
    );
  }

  // Contrôleur pour la carte web (flutter_map)
  fmap.MapController? _webMapController;

  @override
  void initState() {
    super.initState();
    // Initialiser le contrôleur pour la carte web
    if (kIsWeb) {
      _webMapController = fmap.MapController();
    }
  }

  @override
  void dispose() {
    _webMapController = null;
    super.dispose();
  }

  /// Construction de la carte pour le web avec flutter_map sans contrôles
  Widget _buildWebMap() {
    final markers = _convertToFlutterMapMarkers(widget.markers);
    
    return Stack(
      children: [
        fmap.FlutterMap(
          mapController: _webMapController,
          options: fmap.MapOptions(
            initialCenter: latLng.LatLng(
              widget.initialPosition.latitude, 
              widget.initialPosition.longitude
            ),
            initialZoom: widget.initialZoom,
            onTap: (tapPosition, point) {
              if (widget.onTap != null) {
                widget.onTap!(gmaps.LatLng(point.latitude, point.longitude));
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
        ),
        
        // Attributions OpenStreetMap (obligatoires pour respecter la licence)
        Positioned(
          left: 10,
          bottom: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.7),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              "© OpenStreetMap contributors",
              style: TextStyle(fontSize: 10, color: Colors.black54),
            ),
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

  /// Convertit les marqueurs Google Maps en marqueurs Flutter Map avec support amélioré
  List<fmap.Marker> _convertToFlutterMapMarkers(Set<gmaps.Marker> googleMarkers) {
    // Cette fonction n'est utilisée que pour le web
    if (!kIsWeb) return [];
    
    // Convertir chaque marqueur Google Maps en marqueur Flutter Map
    List<fmap.Marker> flutterMapMarkers = [];
    
    for (final marker in googleMarkers) {
      // Essayer d'extraire la couleur de l'icône personnalisée ou utiliser une couleur par défaut
      Color markerColor = Colors.red;
      
      // Vérifier si le marqueur a une hue personnalisée (utilisée dans map_screen.dart)
      if (marker.icon != null && marker.icon == gmaps.BitmapDescriptor.defaultMarkerWithHue(gmaps.BitmapDescriptor.hueGreen)) {
        markerColor = Colors.green;
      } else if (marker.icon != null && marker.icon == gmaps.BitmapDescriptor.defaultMarkerWithHue(gmaps.BitmapDescriptor.hueYellow)) {
        markerColor = Colors.yellow;
      } else if (marker.icon != null && marker.icon == gmaps.BitmapDescriptor.defaultMarkerWithHue(gmaps.BitmapDescriptor.hueAzure)) {
        markerColor = Colors.blue;
      } else if (marker.icon != null && marker.icon == gmaps.BitmapDescriptor.defaultMarkerWithHue(gmaps.BitmapDescriptor.hueViolet)) {
        markerColor = Colors.purple;
      } else if (marker.icon != null && marker.icon == gmaps.BitmapDescriptor.defaultMarkerWithHue(gmaps.BitmapDescriptor.hueOrange)) {
        markerColor = Colors.orange;
      }
      
      // Créer un marqueur spécifique au web qui simule l'apparence de Google Maps
      final newMarker = fmap.Marker(
        point: latLng.LatLng(
          marker.position.latitude,
          marker.position.longitude
        ),
        child: GestureDetector(
          onTap: () {
            // Simuler l'événement onTap du marqueur original
            if (marker.onTap != null) {
              marker.onTap!();
            }
          },
          child: Column(
            children: [
              // Icône personnalisée ressemblant au marqueur Google Maps
              Container(
                height: 30,
                width: 30,
                decoration: BoxDecoration(
                  color: markerColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      spreadRadius: 1,
                      blurRadius: 3,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                // Si une infoWindow est disponible, afficher en tooltip
                child: marker.infoWindow.title != null 
                  ? Tooltip(
                      message: marker.infoWindow.title ?? "",
                      child: const Icon(Icons.location_on, color: Colors.white, size: 18),
                    )
                  : const Icon(Icons.location_on, color: Colors.white, size: 18),
              ),
            ],
          ),
        ),
        width: 30.0,
        height: 40.0,
      );
      
      flutterMapMarkers.add(newMarker);
    }
    
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
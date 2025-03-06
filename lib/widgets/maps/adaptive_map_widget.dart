import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:flutter_map/flutter_map.dart' hide Marker;
import 'package:flutter_map/flutter_map.dart' as fmap;
import 'package:latlong2/latlong.dart' as latLng;
import '../../screens/utils.dart';
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

  /// Construction de la carte pour le web avec flutter_map
  /// Flutter Map est plus performant sur le web que GoogleMaps Flutter
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
        ),
        
        // Ajout de contrôles personnalisés pour le web similaires à Google Maps
        Positioned(
          right: 16,
          bottom: 100,
          child: Column(
            children: [
              // Bouton de zoom +
              FloatingActionButton(
                mini: true,
                heroTag: "webZoomIn",
                backgroundColor: Colors.white,
                child: const Icon(Icons.add, color: Colors.black87),
                onPressed: () {
                  if (_webMapController != null) {
                    // Obtenir le zoom et la position actuels
                    final mapCamera = _webMapController!.camera;
                    final currentZoom = mapCamera.zoom;
                    _webMapController!.move(
                      mapCamera.center,
                      currentZoom + 1
                    );
                  }
                },
              ),
              const SizedBox(height: 8),
              // Bouton de zoom -
              FloatingActionButton(
                mini: true,
                heroTag: "webZoomOut",
                backgroundColor: Colors.white,
                child: const Icon(Icons.remove, color: Colors.black87),
                onPressed: () {
                  if (_webMapController != null) {
                    // Obtenir le zoom et la position actuels
                    final mapCamera = _webMapController!.camera;
                    final currentZoom = mapCamera.zoom;
                    _webMapController!.move(
                      mapCamera.center,
                      currentZoom - 1
                    );
                  }
                },
              ),
              const SizedBox(height: 8),
              // Bouton de localisation
              FloatingActionButton(
                mini: true,
                heroTag: "webMyLocation",
                backgroundColor: Colors.white,
                child: const Icon(Icons.my_location, color: Colors.blue),
                onPressed: () {
                  if (_webMapController != null) {
                    _webMapController!.move(
                      latLng.LatLng(
                        widget.initialPosition.latitude,
                        widget.initialPosition.longitude
                      ),
                      widget.initialZoom
                    );
                  }
                },
              ),
            ],
          ),
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
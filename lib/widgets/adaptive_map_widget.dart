import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;

/// Widget de carte adaptative qui uniformise l'interface pour toutes les cartes
/// de l'application.
class AdaptiveMapWidget extends StatelessWidget {
  /// Position initiale de la carte
  final gmaps.LatLng initialPosition;
  
  /// Liste des marqueurs à afficher sur la carte
  final Set<gmaps.Marker> markers;
  
  /// Callback appelé lorsque la carte est créée
  final Function(gmaps.GoogleMapController) onMapCreated;
  
  /// Callback appelé lorsque la caméra se déplace
  final Function(gmaps.CameraPosition)? onCameraMove;
  
  /// Indique si le bouton de localisation doit être affiché
  final bool myLocationButtonEnabled;
  
  /// Indique si la position de l'utilisateur doit être affichée
  final bool myLocationEnabled;
  
  /// Niveau de zoom initial
  final double initialZoom;

  /// Constructeur
  const AdaptiveMapWidget({
    Key? key,
    required this.initialPosition,
    required this.markers,
    required this.onMapCreated,
    this.onCameraMove,
    this.myLocationButtonEnabled = false,
    this.myLocationEnabled = true,
    this.initialZoom = 14.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return gmaps.GoogleMap(
      initialCameraPosition: gmaps.CameraPosition(
        target: initialPosition,
        zoom: initialZoom,
      ),
      onMapCreated: onMapCreated,
      markers: markers,
      myLocationEnabled: myLocationEnabled,
      myLocationButtonEnabled: myLocationButtonEnabled,
      zoomControlsEnabled: false,
      compassEnabled: true,
      mapToolbarEnabled: false,
      onCameraMove: onCameraMove,
      mapType: gmaps.MapType.normal,
    );
  }
} 
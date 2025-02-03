import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/distance_service.dart';

class DistanceScreen extends StatefulWidget {
  @override
  _DistanceScreenState createState() => _DistanceScreenState();
}

class _DistanceScreenState extends State<DistanceScreen> {
  final DistanceService _distanceService = DistanceService();

  double _originLat = 48.8566; // Coordonnées par défaut (Paris)
  double _originLng = 2.3522;
  double _destinationLat = 48.8584; // Coordonnées par défaut (Tour Eiffel)
  double _destinationLng = 2.2945;

  String? _distance;
  String? _duration;

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Vérifier si le service de localisation est activé
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _distance = 'Le service de localisation est désactivé.';
      });
      return;
    }

    // Vérifier les permissions
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          _distance = 'Permission de localisation refusée.';
        });
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() {
        _distance = 'Permission de localisation définitivement refusée.';
      });
      return;
    }

    // Obtenir la position actuelle
    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    setState(() {
      _originLat = position.latitude;
      _originLng = position.longitude;
      _distance = 'Localisation actuelle mise à jour.';
    });
  }

  void _calculateDistance() async {
    final result = await _distanceService.calculateDistance(
      originLat: _originLat,
      originLng: _originLng,
      destinationLat: _destinationLat,
      destinationLng: _destinationLng,
    );

    if (result != null) {
      setState(() {
        _distance = result['distance'];
        _duration = result['duration'];
      });
    } else {
      setState(() {
        _distance = 'Erreur lors du calcul';
        _duration = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Calcul de Distance')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              decoration: InputDecoration(labelText: 'Latitude d\'origine'),
              keyboardType: TextInputType.number,
              onChanged: (value) => _originLat = double.tryParse(value) ?? _originLat,
            ),
            TextField(
              decoration: InputDecoration(labelText: 'Longitude d\'origine'),
              keyboardType: TextInputType.number,
              onChanged: (value) => _originLng = double.tryParse(value) ?? _originLng,
            ),
            TextField(
              decoration: InputDecoration(labelText: 'Latitude de destination'),
              keyboardType: TextInputType.number,
              onChanged: (value) => _destinationLat = double.tryParse(value) ?? _destinationLat,
            ),
            TextField(
              decoration: InputDecoration(labelText: 'Longitude de destination'),
              keyboardType: TextInputType.number,
              onChanged: (value) => _destinationLng = double.tryParse(value) ?? _destinationLng,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _calculateDistance,
              child: Text('Calculer la Distance'),
            ),
            ElevatedButton(
              onPressed: _getCurrentLocation,
              child: Text('Utiliser ma position actuelle'),
            ),
            if (_distance != null)
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Text('Distance : $_distance\nDurée : $_duration'),
              ),
          ],
        ),
      ),
    );
  }
}

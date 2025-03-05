import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'dart:html' as html show window;
import '../services/distance_service.dart';

class DistanceScreen extends StatefulWidget {
  const DistanceScreen({Key? key}) : super(key: key);

  @override
  _DistanceScreenState createState() => _DistanceScreenState();
}

class _DistanceScreenState extends State<DistanceScreen> {
  final DistanceService _distanceService = DistanceService();
  bool _isLoading = false;

  // Paris par défaut
  double _originLat = 48.8566;
  double _originLng = 2.3522;
  double _destinationLat = 48.8584;
  double _destinationLng = 2.2945;

  String? _distance;
  String? _duration;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    setState(() => _isLoading = true);
    try {
      final position = await _determinePosition();
      setState(() {
        _originLat = position.latitude;
        _originLng = position.longitude;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        // Garder Paris comme position par défaut
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<Position> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Les services de localisation sont désactivés.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Les permissions de localisation ont été refusées.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Les permissions de localisation sont définitivement refusées.');
    }

    return await Geolocator.getCurrentPosition();
  }

  Future<void> _getCurrentLocation() async {
    if (kIsWeb) {
      // Gérer la localisation sur Web
      try {
        html.window.navigator.geolocation.getCurrentPosition().then((pos) {
          setState(() {
            _originLat = pos.coords!.latitude!;
            _originLng = pos.coords!.longitude!;
            _distance = 'Localisation actuelle mise à jour.';
          });
        }).catchError((error) {
          setState(() {
            _distance = 'Erreur de localisation sur Web';
          });
        });
      } catch (e) {
        setState(() {
          _distance = 'Localisation non supportée sur Web';
        });
      }
    } else {
      // Gérer la localisation sur Android/iOS
      bool serviceEnabled;
      LocationPermission permission;

      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _distance = 'Le service de localisation est désactivé.';
        });
        return;
      }

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

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _originLat = position.latitude;
        _originLng = position.longitude;
        _distance = 'Localisation actuelle mise à jour.';
      });
    }
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
      appBar: AppBar(title: const Text('Calcul de Distance')),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                if (_error != null)
                  Card(
                    color: Colors.red[100],
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(_error!, style: TextStyle(color: Colors.red[900])),
                    ),
                  ),
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

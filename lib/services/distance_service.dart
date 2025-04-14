import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../services/location_service.dart';

class DistanceService {
  final String _baseUrl = getBaseUrl();  // Utiliser la fonction de constants.dart

  /// Calcule la distance entre deux points (origine et destination) en appelant l'API backend
  Future<Map<String, dynamic>?> calculateDistance({
    required double originLat,
    required double originLng,
    required double destinationLat,
    required double destinationLng,
    String mode = 'walking', // "driving", "bicycling", etc.
  }) async {
    final url = Uri.parse('$_baseUrl/api/distance');
    
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'origin': {'lat': originLat, 'lng': originLng},
          'destination': {'lat': destinationLat, 'lng': destinationLng},
          'mode': mode,
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        print('❌ Erreur API (${response.statusCode}): ${response.body}');
        return null;
      }
    } catch (error) {
      print('❌ Erreur lors de l\'appel HTTP : $error');
      print('URL tentée : $url');
      return null;
    }
  }
}

class DistanceScreen extends StatefulWidget {
  @override
  _DistanceScreenState createState() => _DistanceScreenState();
}

class _DistanceScreenState extends State<DistanceScreen> {
  final LocationService _locationService = LocationService();
  bool _isLoading = false;
  
  // Remplacer les coordonnées statiques par des nullable
  double? _originLat;
  double? _originLng;
  double? _destinationLat;
  double? _destinationLng;

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    setState(() => _isLoading = true);
    try {
      // Position par défaut (Paris) en cas d'échec
      final position = await _locationService.getCurrentPosition();

      setState(() {
        _originLat = position?.latitude ?? 48.8566;
        _originLng = position?.longitude ?? 2.3522;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Erreur de géolocalisation: $e');
      setState(() {
        _originLat = 48.8566; // Paris par défaut
        _originLng = 2.3522;
        _isLoading = false;
      });
    }
  }

  // Afficher la distance entre l'origine et la destination
  String getDistance() {
    if (_originLat == null || _originLng == null || 
        _destinationLat == null || _destinationLng == null) {
      return "Veuillez sélectionner une destination";
    }
    
    final distance = _locationService.calculateDistance(
      _originLat!, 
      _originLng!, 
      _destinationLat!, 
      _destinationLng!
    );
    
    if (distance < 1000) {
      return "${distance.toStringAsFixed(0)} m";
    } else {
      return "${(distance / 1000).toStringAsFixed(1)} km";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Distance Calculator'),
      ),
      body: Center(
        child: _isLoading 
          ? const CircularProgressIndicator()
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Votre position: ${_originLat?.toStringAsFixed(4) ?? "N/A"}, ${_originLng?.toStringAsFixed(4) ?? "N/A"}',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    // Simuler la sélection d'une destination (à 1km au nord)
                    setState(() {
                      _destinationLat = (_originLat ?? 48.8566) + 0.009;
                      _destinationLng = _originLng ?? 2.3522;
                    });
                  },
                  child: const Text('Sélectionner une destination'),
                ),
                const SizedBox(height: 20),
                if (_destinationLat != null)
                  Text(
                    'Destination: ${_destinationLat?.toStringAsFixed(4) ?? "N/A"}, ${_destinationLng?.toStringAsFixed(4) ?? "N/A"}',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                const SizedBox(height: 20),
                if (_destinationLat != null)
                  Text(
                    'Distance: ${getDistance()}',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
              ],
            ),
      ),
    );
  }
}

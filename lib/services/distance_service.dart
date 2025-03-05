import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';

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

class _DistanceScreenState extends State<DistanceScreen> {
  final DistanceService _distanceService = DistanceService();
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
      Position? position;
      
      if (kIsWeb) {
        position = await _getWebLocation();
      } else {
        position = await _getNativeLocation();
      }

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

  Future<Position?> _getNativeLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Services de localisation désactivés');
    }

    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      final newPermission = await Geolocator.requestPermission();
      if (newPermission == LocationPermission.denied) {
        throw Exception('Permission refusée');
      }
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  Future<Position?> _getWebLocation() async {
    try {
      final completer = Completer<Position?>();
      html.window.navigator.geolocation.getCurrentPosition((pos) {
        completer.complete(Position(
          latitude: pos.coords!.latitude!,
          longitude: pos.coords!.longitude!,
          timestamp: DateTime.now(),
          accuracy: pos.coords!.accuracy!,
          altitude: pos.coords!.altitude ?? 0,
          heading: pos.coords!.heading ?? 0,
          speed: pos.coords!.speed ?? 0,
          speedAccuracy: 0,
        ));
      }, (error) {
        completer.completeError(error);
      });
      return await completer.future;
    } catch (e) {
      throw Exception('Erreur de géolocalisation web: $e');
    }
  }
}

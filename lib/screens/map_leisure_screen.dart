import 'dart:isolate';
import 'dart:async';
import 'dart:math' show sin, cos, sqrt, atan2, pi;
import 'package:flutter/foundation.dart' show kIsWeb, compute;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'producerLeisure_screen.dart';
import 'eventLeisure_screen.dart';
import 'utils.dart';
import '../widgets/maps/adaptive_map_widget.dart';
import 'map_screen.dart'; // Importer la carte des restaurants
import 'map_friends.dart'; // Importer l'écran MapFriendsScreen

class MapLeisureScreen extends StatefulWidget {
  const MapLeisureScreen({Key? key}) : super(key: key);

  @override
  State<MapLeisureScreen> createState() => _MapLeisureScreenState();
}

class _MapLeisureScreenState extends State<MapLeisureScreen> {
  LatLng _initialPosition = const LatLng(0, 0); // Position par défaut
  GoogleMapController? _mapController;
  LocationData? _currentPosition; // Position GPS actuelle
  bool _isUsingLiveLocation = false; // État de la localisation en direct
  Timer? _locationUpdateTimer; // Timer pour la mise à jour périodique de la position

  Set<Marker> _markers = {};
  bool _isLoading = false;
  bool _isMapReady = false;
  bool _isComputingMarkers = false;
  bool _hasShownFilterHint = false; // Pour savoir si l'utilisateur a déjà vu l'indicateur
  bool _shouldShowMarkers = true; // Contrôle l'affichage des marqueurs - activé par défaut
  final ReceivePort _receivePort = ReceivePort();
  String? _lastTappedMarkerId; // Pour gérer le double-tap sur les marqueurs
  
  // Propriétés pour les filtres
  double _selectedRadius = 5000;
  String? _selectedProducerCategory;
  String? _selectedEventCategory;
  List<String> _selectedEmotions = [];
  double _minMiseEnScene = 0;
  double _minJeuActeurs = 0;
  double _minScenario = 0;
  double _minPrice = 0;
  double _maxPrice = 1000;
  
  // Propriété pour les icônes de marqueurs
  Map<String, BitmapDescriptor> _markerIcons = {};
  
  // Liste des aspects sélectionnés pour le filtrage dynamique
  List<String> _selectedAspects = [];

  // Aide pour obtenir la catégorie standardisée à partir d'une catégorie brute
  String _getStandardCategory(String rawCategory) {
    if (rawCategory.isEmpty) return CATEGORY_MAPPING["default"]!;
    
    // Convertir en minuscules pour une correspondance insensible à la casse
    String lowerCategory = rawCategory.toLowerCase();
    
    // Vérifier dans le mapping
    for (var entry in CATEGORY_MAPPING.entries) {
      if (lowerCategory.contains(entry.key)) {
        return entry.value;
      }
    }
    
    // Si aucune correspondance, renvoyer la catégorie par défaut
    return CATEGORY_MAPPING["default"]!;
  }
  
  // Récupérer les détails (aspects, émotions) pour une catégorie
  Map<String, dynamic> _getCategoryDetails(String category) {
    // Standardiser d'abord la catégorie
    String standardCategory = _getStandardCategory(category);
    
    // Extraire le terme principal (avant le » si présent)
    String mainCategory = standardCategory.split('»').first.trim();
    
    // Chercher dans les mappings détaillés
    if (CATEGORY_MAPPINGS_DETAILED.containsKey(mainCategory)) {
      return CATEGORY_MAPPINGS_DETAILED[mainCategory]!;
    }
    
    // Chercher des correspondances partielles
    for (var entry in CATEGORY_MAPPINGS_DETAILED.entries) {
      if (mainCategory.contains(entry.key) || entry.key.contains(mainCategory)) {
        return entry.value;
      }
    }
    
    // Si aucune correspondance, retourner la catégorie par défaut
    return CATEGORY_MAPPINGS_DETAILED["Default"]!;
  }
  
  // Calculer un score de correspondance pour une entité basé sur les filtres sélectionnés
  double _calculateEntityScore(Map<String, dynamic> entity, bool isProducer) {
    double score = 0.5; // Score de base moyen
    int criteriaCount = 0;
    
    // Si aucun filtre n'est sélectionné, on maintient le score moyen
    if (_selectedProducerCategory == null && 
        _selectedEventCategory == null && 
        _selectedEmotions.isEmpty &&
        _minMiseEnScene == 0 &&
        _minJeuActeurs == 0 &&
        _minScenario == 0 &&
        _minPrice == 0 &&
        _maxPrice == 1000) {
      return score;
    }
    
    // Vérifier la correspondance de catégorie pour les producteurs
    if (isProducer && _selectedProducerCategory != null) {
      String category = entity['catégorie']?.toString().toLowerCase() ?? '';
      if (category.contains(_selectedProducerCategory!.toLowerCase())) {
        score += 0.2;
        criteriaCount++;
      }
    }
    
    // Vérifier la correspondance de catégorie pour les événements
    if (!isProducer && _selectedEventCategory != null) {
      String category = entity['catégorie']?.toString().toLowerCase() ?? '';
      if (category.contains(_selectedEventCategory!.toLowerCase())) {
        score += 0.2;
        criteriaCount++;
      }
    }
    
    // Vérifier la correspondance des émotions pour les événements
    if (!isProducer && _selectedEmotions.isNotEmpty) {
      if (entity['emotions'] != null && entity['emotions'] is List) {
        List<dynamic> entityEmotions = entity['emotions'];
        int matchCount = 0;
        
        for (String selectedEmotion in _selectedEmotions) {
          if (entityEmotions.any((e) => e.toString().toLowerCase().contains(selectedEmotion.toLowerCase()))) {
            matchCount++;
          }
        }
        
        if (matchCount > 0) {
          score += (matchCount / _selectedEmotions.length) * 0.3;
          criteriaCount++;
        }
      }
    }
    
    // Vérifier les notes spécifiques (mise en scène, jeu d'acteurs, etc.)
    if (!isProducer) {
      // Mise en scène
      if (_minMiseEnScene > 0 && entity['notes_détaillées']?['mise_en_scène'] != null) {
        double entityScore = (entity['notes_détaillées']['mise_en_scène'] is num) 
                           ? (entity['notes_détaillées']['mise_en_scène'] as num).toDouble() 
                           : 0.0;
        if (entityScore >= _minMiseEnScene) {
          score += ((entityScore - _minMiseEnScene) / (10.0 - _minMiseEnScene)) * 0.15;
          criteriaCount++;
        }
      }
      
      // Jeu d'acteurs
      if (_minJeuActeurs > 0 && entity['notes_détaillées']?['jeu_acteurs'] != null) {
        double entityScore = (entity['notes_détaillées']['jeu_acteurs'] is num) 
                           ? (entity['notes_détaillées']['jeu_acteurs'] as num).toDouble() 
                           : 0.0;
        if (entityScore >= _minJeuActeurs) {
          score += ((entityScore - _minJeuActeurs) / (10.0 - _minJeuActeurs)) * 0.15;
          criteriaCount++;
        }
      }
      
      // Texte/Scénario
      if (_minScenario > 0 && entity['notes_détaillées']?['texte'] != null) {
        double entityScore = (entity['notes_détaillées']['texte'] is num) 
                           ? (entity['notes_détaillées']['texte'] as num).toDouble() 
                           : 0.0;
        if (entityScore >= _minScenario) {
          score += ((entityScore - _minScenario) / (10.0 - _minScenario)) * 0.15;
          criteriaCount++;
        }
      }
      
      // Prix
      if (_minPrice > 0 || _maxPrice < 1000) {
        double price = (entity['prix_reduit'] is num) 
                      ? (entity['prix_reduit'] as num).toDouble() 
                      : (entity['prix'] is num) 
                          ? (entity['prix'] as num).toDouble() 
                          : 0.0;
        
        if (price >= _minPrice && price <= _maxPrice) {
          // Meilleur score si le prix est proche du minimum
          double priceScore = 1.0 - ((price - _minPrice) / (_maxPrice - _minPrice));
          score += priceScore * 0.2;
          criteriaCount++;
        }
      }
    }
    
    // Considérer la note générale si disponible
    if (entity['note'] != null) {
      double rating = (entity['note'] is num) ? (entity['note'] as num).toDouble() : 0.0;
      // Bonus de score pour les entités bien notées
      score += (rating / 10.0) * 0.15;
      criteriaCount++;
    }
    
    // Si aucun critère n'a été appliqué, garder le score moyen
    if (criteriaCount == 0) {
      return score;
    }
    
    // Normaliser le score final entre 0 et 1
    return (score / (1.0 + (criteriaCount * 0.1))).clamp(0.0, 1.0);
  }

  // Obtenir la couleur BitmapDescriptor.hue pour une catégorie donnée
  // Maintenant peut aussi utiliser le score pour une cohérence visuelle avec Map des Restaurants
  double _getCategoryHue(String category, [double? score, Map<String, dynamic>? entity, bool? isProducer]) {
    // Si on a un score, on l'utilise pour la couleur
    if (score != null) {
      return _getColorBasedOnScore(score);
    }
    
    // Sinon on utilise la catégorie (mode rétrocompatible)
    category = category.toLowerCase();
    
    // Attribution directe des couleurs par catégorie selon CATEGORY_MAPPING
    if (category.contains('théâtre') || category.contains('theatre')) {
      return BitmapDescriptor.hueRed;
    } else if (category.contains('musiqu') || category.contains('concert')) {
      return BitmapDescriptor.hueAzure;
    } else if (category.contains('ciném') || category.contains('cinema')) {
      return BitmapDescriptor.hueOrange;
    } else if (category.contains('danse') || category.contains('spectacle')) {
      return BitmapDescriptor.hueGreen;
    } else if (category.contains('exposition')) {
      return BitmapDescriptor.hueYellow;
    } else if (category.contains('festival')) {
      return BitmapDescriptor.hueMagenta;
    } else if (category.contains('conférence')) {
      return BitmapDescriptor.hueCyan;
    } else {
      // Utiliser la partie principale du CATEGORY_MAPPING
      for (var entry in CATEGORY_MAPPING.entries) {
        if (category.contains(entry.key)) {
          String mappedCategory = entry.value.toLowerCase();
          if (mappedCategory.contains('théâtre')) {
            return BitmapDescriptor.hueRed;
          } else if (mappedCategory.contains('musique')) {
            return BitmapDescriptor.hueAzure;
          } else if (mappedCategory.contains('cinéma')) {
            return BitmapDescriptor.hueOrange;
          } else if (mappedCategory.contains('spectacles')) {
            return BitmapDescriptor.hueGreen;
          } else if (mappedCategory.contains('exposition')) {
            return BitmapDescriptor.hueYellow;
          } else if (mappedCategory == 'festival') {
            return BitmapDescriptor.hueMagenta;
          } else if (mappedCategory == 'concert') {
            return BitmapDescriptor.hueRose;
          } else if (mappedCategory == 'conférence') {
            return BitmapDescriptor.hueCyan;
          }
        }
      }
    }
    
    // Si aucune correspondance, utiliser une couleur par défaut autre que violet
    return BitmapDescriptor.hueBlue;
  }

  // Contrôle du panneau de filtres
  bool _isFilterPanelVisible = false;
  bool _isPanelAnimating = false; // Pour éviter les clics multiples pendant l'animation

  // CATEGORY_MAPPING selon l'instruction du projet
  final Map<String, String> CATEGORY_MAPPING = {
    "default": "Autre",
    "deep": "Musique » Électronique",
    "techno": "Musique » Électronique",
    "house": "Musique » Électronique",
    "hip hop": "Musique » Hip-Hop",
    "rap": "Musique » Hip-Hop",
    "rock": "Musique » Rock",
    "indie": "Musique » Indie",
    "pop": "Musique » Pop",
    "jazz": "Musique » Jazz",
    "soul": "Musique » Soul",
    "funk": "Musique » Funk",
    "dj set": "Musique » DJ Set",
    "club": "Musique » Club",
    "festival": "Festival",
    "concert": "Concert",
    "live": "Concert",
    "comédie": "Théâtre » Comédie",
    "spectacle": "Spectacles",
    "danse": "Spectacles » Danse",
    "exposition": "Exposition",
    "conférence": "Conférence",
    "stand-up": "Spectacles » One-man-show",
    "one-man-show": "Spectacles » One-man-show",
    "théâtre": "Théâtre",
    "cinéma": "Cinéma",
    "projection": "Cinéma",
  };

  // Liste des catégories principales pour la carte
  final List<String> MAIN_CATEGORIES = [
    "Théâtre",
    "Musique",
    "Spectacles",
    "Cinéma",
    "Exposition",
    "Festival",
    "Concert",
    "Conférence"
  ];
  
  // Mappings détaillés pour l'analyse AI par catégorie
  final Map<String, Map<String, dynamic>> CATEGORY_MAPPINGS_DETAILED = {
    "Théâtre": {
      "aspects": ["mise en scène", "jeu des acteurs", "texte", "scénographie"],
      "emotions": ["intense", "émouvant", "captivant", "enrichissant", "profond"]
    },
    "Théâtre contemporain": {
      "aspects": ["mise en scène", "jeu des acteurs", "texte", "originalité", "message"],
      "emotions": ["provocant", "dérangeant", "stimulant", "actuel", "profond"]
    },
    "Comédie": {
      "aspects": ["humour", "jeu des acteurs", "rythme", "dialogue"],
      "emotions": ["drôle", "amusant", "divertissant", "léger", "enjoué"]
    },
    "Spectacle musical": {
      "aspects": ["performance musicale", "mise en scène", "chant", "chorégraphie"],
      "emotions": ["entraînant", "mélodieux", "festif", "rythmé", "touchant"]
    },
    "One-man-show": {
      "aspects": ["humour", "présence scénique", "texte", "interaction"],
      "emotions": ["drôle", "mordant", "spontané", "énergique", "incisif"]
    },
    "Concert": {
      "aspects": ["performance", "répertoire", "son", "ambiance"],
      "emotions": ["électrisant", "envoûtant", "festif", "énergique", "intense"]
    },
    "Musique électronique": {
      "aspects": ["dj", "ambiance", "son", "rythme"],
      "emotions": ["festif", "énergique", "immersif", "exaltant", "hypnotique"]
    },
    "Danse": {
      "aspects": ["chorégraphie", "technique", "expressivité", "musique"],
      "emotions": ["gracieux", "puissant", "fluide", "émouvant", "esthétique"]
    },
    "Cirque": {
      "aspects": ["performance", "mise en scène", "acrobaties", "créativité"],
      "emotions": ["impressionnant", "magique", "époustouflant", "spectaculaire", "poétique"]
    },
    "Default": {  // Catégorie par défaut si non reconnue
      "aspects": ["qualité générale", "intérêt", "originalité"],
      "emotions": ["agréable", "intéressant", "divertissant", "satisfaisant"]
    }
  };

  // Mapping pour la traduction des dates
  final Map<String, String> JOURS_FR_EN = {
    "lundi": "Monday", "mardi": "Tuesday", "mercredi": "Wednesday",
    "jeudi": "Thursday", "vendredi": "Friday", "samedi": "Saturday", "dimanche": "Sunday"
  };
  
  final Map<String, String> MOIS_FR_EN = {
    "janvier": "January", "février": "February", "mars": "March", "avril": "April",
    "mai": "May", "juin": "June", "juillet": "July", "août": "August",
    "septembre": "September", "octobre": "October", "novembre": "November", "décembre": "December"
  };
  
  final Map<String, String> MOIS_ABBR_FR = {
    "janv.": "janvier", "févr.": "février", "mars": "mars", "avr.": "avril",
    "mai": "mai", "juin": "juin", "juil.": "juillet", "août": "août",
    "sept.": "septembre", "oct.": "octobre", "nov.": "novembre", "déc.": "décembre"
  };

  // Helper function to convert degrees to radians (moved outside of _calculateDistance)
  double _degreesToRadians(double degrees) {
    return degrees * pi / 180;
  }

  /// Calculate distance between two coordinates using Haversine formula
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000; // meters
    
    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLon = _degreesToRadians(lon2 - lon1);
    
    final double a = 
      sin(dLat / 2) * sin(dLat / 2) +
      cos(_degreesToRadians(lat1)) * cos(_degreesToRadians(lat2)) * 
      sin(dLon / 2) * sin(dLon / 2);
    
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    
    return earthRadius * c;
  }

  @override
  void initState() {
    super.initState();
    _loadMarkerIcons();
    
    // Vérifier les permissions de localisation au démarrage
    _checkLocationPermission();
    
    // Initialiser l'écouteur pour les calculs d'arrière-plan
    _receivePort.listen((data) {
      if (data is List<dynamic> && data.isNotEmpty) {
        // Traiter les données de marqueurs envoyées par l'isolate
        if (data[0] == 'markerData') {
          print("✅ Réception des données pour ${(data[1] as List).length} marqueurs");
          // Convertir les données de marqueurs en objets Marker réels
          Set<Marker> newMarkers = _createMarkersFromData(data[1]);
          
          setState(() {
            _markers = newMarkers;
            _isComputingMarkers = false;
            
            // Pour le débogage - afficher un message si des marqueurs sont chargés
            print("✅ ${_markers.length} marqueurs chargés et prêts à être affichés");
            
            // S'assurer que la carte est ajustée pour montrer tous les marqueurs
            if (_markers.isNotEmpty && _mapController != null && mounted) {
              _fitMarkersOnMap();
            }
          });
        } 
        // Pour la compatibilité avec l'ancien format de données
        else if (data[0] == 'markers') {
          setState(() {
            _markers = Set<Marker>.from(data[1]);
            _isComputingMarkers = false;
            print("✅ ${_markers.length} marqueurs chargés directement");
            
            // S'assurer que la carte est ajustée pour montrer tous les marqueurs
            if (_markers.isNotEmpty && _mapController != null && mounted) {
              _fitMarkersOnMap();
            }
          });
        }
      }
    });
    
    // Charger automatiquement les données après un court délai
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _fetchNearbyProducers(_initialPosition.latitude, _initialPosition.longitude);
      }
    });
  }
  
  // Instance du service de localisation
  final Location _location = Location();
  
  /// Vérifier et demander les permissions de localisation
  Future<void> _checkLocationPermission() async {
    try {
      bool serviceEnabled = await _location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await _location.requestService();
        if (!serviceEnabled) {
          // Le service de localisation est désactivé, utiliser Paris par défaut
          _showSnackBar("Service de localisation désactivé. Utilisation de la position par défaut.");
          return;
        }
      }
      
      PermissionStatus permissionStatus = await _location.hasPermission();
      if (permissionStatus == PermissionStatus.denied) {
        permissionStatus = await _location.requestPermission();
        if (permissionStatus == PermissionStatus.denied) {
          // Permission refusée, mais on peut continuer avec Paris comme position par défaut
          _showSnackBar("Permissions de localisation refusées. Utilisation de la position par défaut.");
          return;
        }
      }
      
      if (permissionStatus == PermissionStatus.deniedForever) {
        // L'utilisateur a refusé définitivement, proposer d'ouvrir les paramètres
        _showSnackBar("Permissions de localisation définitivement refusées. Utilisez les paramètres pour les activer.");
        return;
      }
      
      // Si on arrive ici, on a les permissions
      _getCurrentLocation();
    } catch (e) {
      print("❌ Erreur lors de la vérification des permissions: $e");
    }
  }
  
  /// Obtenir la position actuelle avec gestion adaptée pour iOS et Android
  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Configurer la précision de la localisation
      await _location.changeSettings(accuracy: LocationAccuracy.high);
      
      // Obtenir la position actuelle
      LocationData position = await _location.getLocation();
      
      // Vérifier que les coordonnées ne sont pas nulles
      if (position.latitude == null || position.longitude == null) {
        _showSnackBar("Impossible d'obtenir des coordonnées valides. Veuillez réessayer.");
        setState(() {
          _isLoading = false;
          _isUsingLiveLocation = false;
        });
        return;
      }
      
      setState(() {
        _currentPosition = position;
        _initialPosition = LatLng(position.latitude!, position.longitude!);
        _isUsingLiveLocation = true;
      });
      
      if (_mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(_initialPosition, 14.0),
        );
      }
      
      // Charger les producteurs proches de la position actuelle
      _fetchNearbyProducers(position.latitude!, position.longitude!);
      _showSnackBar("Position GPS obtenue. Recherche des lieux à proximité.");
      
      // Configurer les mises à jour de position périodiques si activées
      _setupLocationTracking();
      
      // Informer l'utilisateur que le suivi en direct est activé
      _showSnackBar("Localisation en direct activée. La carte s'adaptera à vos déplacements.");
    } catch (e) {
      print("❌ Erreur lors de l'obtention de la position: $e");
      _showSnackBar("Impossible d'obtenir votre position. Vérifiez que le GPS est activé.");
      setState(() {
        _isUsingLiveLocation = false;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  /// Configure les mises à jour périodiques de la position
  void _setupLocationTracking() {
    // Annuler l'ancien timer s'il existe
    _locationUpdateTimer?.cancel();
    
    if (_isUsingLiveLocation) {
      // Créer un nouveau timer pour mettre à jour la position toutes les 30 secondes
      _locationUpdateTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
        if (!mounted || !_isUsingLiveLocation) {
          timer.cancel();
          return;
        }
        
        try {
          LocationData position = await _location.getLocation();
          
          // Vérifier que les coordonnées ne sont pas nulles
          if (_currentPosition != null && position.latitude != null && position.longitude != null) {
            // S'assurer que les positions actuelles ont des coordonnées valides
            if (_currentPosition!.latitude != null && _currentPosition!.longitude != null) {
              double distance = _calculateDistance(
                _currentPosition!.latitude!, _currentPosition!.longitude!,
                position.latitude!, position.longitude!
              );
              
              if (distance > 50) { // Seulement si déplacé de plus de 50 mètres
                setState(() {
                  _currentPosition = position;
                  _initialPosition = LatLng(position.latitude!, position.longitude!);
                });
                
                if (_mapController != null) {
                  _mapController!.animateCamera(
                    CameraUpdate.newLatLng(_initialPosition),
                  );
                }
                
                // Recharger les lieux à proximité de la nouvelle position
                _fetchNearbyProducers(position.latitude!, position.longitude!);
                print("📍 Position mise à jour: ${position.latitude}, ${position.longitude}");
              }
            }
          }
        } catch (e) {
          print("❌ Erreur lors de la mise à jour périodique de la position: $e");
        }
      });
      
      print("✅ Suivi de localisation en direct activé");
    }
  }
  
  /// Convertir les données de marqueurs reçues de l'isolate en objets Marker réels
  Set<Marker> _createMarkersFromData(List<dynamic> markersData) {
    Set<Marker> markers = {};
    
    // Index pour créer un z-index unique pour chaque marqueur
    int markerIndex = 0;
    
    for (var markerData in markersData) {
      try {
        final String id = markerData['id'];
        // Récupérer les coordonnées originales
        double lat = markerData['lat'];
        double lon = markerData['lon'];
        final String name = markerData['name'];
        final double hue = markerData['hue'];
        final String category = markerData['category'];
        final bool isProducer = markerData['isProducer'];
        final String entityJson = markerData['entityJson'];
        
        // Ajouter un décalage microscopique aléatoire aux coordonnées uniquement pour éviter une superposition parfaite
        // Utiliser un décalage ultra-minimal pour préserver l'emplacement géographique exact
        final double microOffsetFactor = 0.000001; // ~0.1 mètre de décalage maximum
        final math.Random random = math.Random(markerIndex); // Random déterministe basé sur l'index
        
        // Appliquer un décalage minuscule unique à chaque marqueur qui maintient les coordonnées quasi-exactes
        lat += random.nextDouble() * microOffsetFactor * 2 - microOffsetFactor;
        lon += random.nextDouble() * microOffsetFactor * 2 - microOffsetFactor;
        
        // Log détaillé pour débogage
        print("  🔍 Position exacte (micro-décalage): [${lat.toStringAsFixed(8)}, ${lon.toStringAsFixed(8)}]");
        
        // Reconstruire l'entité à partir de son JSON
        Map<String, dynamic> entity = json.decode(entityJson);
        
        // Calculer un score de pertinence pour cette entité basé sur les filtres sélectionnés
        double entityScore = _calculateEntityScore(entity, isProducer);
        print("  📊 Score calculé pour ${name}: ${entityScore.toStringAsFixed(2)}");
        
        // Utiliser le score pour la couleur du marqueur plutôt que la catégorie
        // pour une meilleure visualisation de la pertinence
        double markerHue = _getColorBasedOnScore(entityScore);
        
        // Créer l'icône du marqueur avec la teinte basée sur le score
        BitmapDescriptor markerIcon = BitmapDescriptor.defaultMarkerWithHue(markerHue);
        
        // Z-index unique et croissant pour chaque marqueur - utiliser une plage plus large
        final double zIndex = 100.0 + (markerIndex * 0.1); // z-index 100.0, 100.1, 100.2, etc.
        
        // Créer le marqueur avec tous les paramètres nécessaires pour garantir visibilité et interaction
        Marker marker = Marker(
          markerId: MarkerId(id),
          position: LatLng(lat, lon),
          icon: markerIcon,
          visible: true,
          flat: false, // Désactiver flat pour meilleure visibilité
          alpha: 1.0, // Complètement opaque
          zIndex: zIndex, // Z-index unique et croissant
          anchor: const Offset(0.5, 0.7), // Ancrage plus haut pour que le marqueur apparaisse plus élevé sur la carte
          consumeTapEvents: true, // Assure que les taps sont bien capturés
          onTap: () {
            // Afficher les détails directement sans passer par infoWindow
            _showEntityQuickView(context, entity, isProducer, id);
            
            // Gérer le double-tap pour navigation directe
            if (_lastTappedMarkerId == id) {
              // Double tap détecté - naviguer vers la page détaillée
              if (isProducer) {
                _navigateToProducerDetails(entity);
              } else {
                _navigateToEventDetails(id);
              }
              _lastTappedMarkerId = null;
            } else {
              // Premier tap - enregistrer l'ID
              setState(() {
                _lastTappedMarkerId = id;
              });
              
              // Annuler après un délai si pas de second tap
              Future.delayed(const Duration(seconds: 3), () {
                if (mounted && _lastTappedMarkerId == id) {
                  setState(() {
                    _lastTappedMarkerId = null;
                  });
                }
              });
            }
          },
          infoWindow: InfoWindow(
            title: name,
            snippet: _buildInfoSnippet(entity, isProducer),
          ),
        );
        
        markers.add(marker);
        print("✅ Marqueur créé et visible pour: $name avec catégorie: $category, z-index: $zIndex");
        // Ajouter des informations supplémentaires pour débogage
        int nbEvents = 0;
        if (entity['evenements'] != null && entity['evenements'] is List) {
          nbEvents = entity['evenements'].length;
        } else if (entity['nombre_evenements'] != null) {
          nbEvents = entity['nombre_evenements'];
        }

        if (nbEvents > 0) {
          print("   📅 Nombre d'événements: $nbEvents");
        }
        
        // Incrémenter l'index pour le prochain marqueur
        markerIndex++;
      } catch (e) {
        print("❌ Erreur lors de la création du marqueur à partir des données: $e");
      }
    }
    
    return markers;
  }
  
  /// Construit le texte informatif pour l'infoWindow du marqueur
  String _buildInfoSnippet(Map<String, dynamic> entity, bool isProducer) {
    String snippet = '';
    
    // Pour les producteurs, afficher la description + nombre d'événements
    if (isProducer) {
      // Description courte
      if (entity['description'] != null) {
        snippet = entity['description'].toString().substring(
          0, math.min(40, entity['description'].toString().length)
        );
        if (entity['description'].toString().length > 40) snippet += '...';
      } else {
        snippet = 'Lieu de loisir';
      }
      
      // Ajouter le nombre d'événements si disponible
      int nbEvents = 0;
      if (entity['evenements'] != null && entity['evenements'] is List) {
        nbEvents = entity['evenements'].length;
      } else if (entity['nombre_evenements'] != null) {
        nbEvents = entity['nombre_evenements'];
      }
      
      if (nbEvents > 0) {
        snippet += ' • $nbEvents événement${nbEvents > 1 ? 's' : ''}';
      }
      
      // Ajouter note si disponible
      if (entity['note'] != null) {
        snippet += ' • ${entity['note'].toStringAsFixed(1)}★';
      }
    } 
    // Pour les événements, afficher catégorie + émotions
    else {
      // Catégorie
      if (entity['catégorie'] != null) {
        snippet = entity['catégorie'].toString();
      } else {
        snippet = 'Événement';
      }
      
      // Prix si disponible
      if (entity['prix_reduit'] != null) {
        snippet += ' • ${entity['prix_reduit']}€';
      }
      
      // Note si disponible
      if (entity['note'] != null) {
        snippet += ' • ${entity['note'].toStringAsFixed(1)}★';
      }
    }
    
    return snippet;
  }
  
  @override
  void dispose() {
    _receivePort.close();
    _mapController?.dispose();
    _locationUpdateTimer?.cancel(); // Annuler le timer pour éviter les fuites de mémoire
    super.dispose();
  }

  /// Charger les icônes personnalisées pour les différentes catégories de marqueurs
  Future<void> _loadMarkerIcons() async {
    try {
      // Précharger les icônes pour chaque catégorie pour éviter les délais lors de l'affichage
      _markerIcons = {
        'default': BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
        'théâtre': BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        'musique': BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        'cinéma': BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        'danse': BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        'exposition': BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow),
        'musée': BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
        'festival': BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueMagenta),
        'match': BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      };
      
      print("✅ Icônes de marqueurs chargées pour toutes les catégories");
    } catch (e) {
      print("❌ Erreur lors du chargement des icônes de marqueurs: $e");
      // Fallback à l'icône par défaut si une erreur se produit
      _markerIcons = {'default': BitmapDescriptor.defaultMarker};
    }
  }
  
  /// Calculer une couleur de marqueur en fonction du score
  double _getColorBasedOnScore(double score) {
    // Utiliser un dégradé de couleurs plus visible avec des valeurs qui garantissent l'opacité:
    // 0.0 (faible) = Rouge (0) 
    // 0.5 (moyen) = Jaune (60)
    // 1.0 (excellent) = Vert (120)
    
    // Garantir que le score est entre 0 et 1
    score = score.clamp(0.0, 1.0);
    
    // Convertir le score en une valeur de teinte entre 0 (rouge) et 120 (vert)
    return (score * 120).clamp(0.0, 120.0);
  }
  
  /// Obtenir une icône de marqueur basée sur le score et la catégorie
  BitmapDescriptor _getMarkerIcon(double score, String category) {
    // Normaliser la catégorie pour la recherche
    category = category.toLowerCase();
    
    // Trouver la catégorie correspondante dans notre cache
    String iconKey = 'default';
    
    if (category.contains('théâtre') || category.contains('theatre')) {
      iconKey = 'théâtre';
    } else if (category.contains('musiqu') || category.contains('concert')) {
      iconKey = 'musique';
    } else if (category.contains('ciném') || category.contains('cinema')) {
      iconKey = 'cinéma';
    } else if (category.contains('danse')) {
      iconKey = 'danse';
    } else if (category.contains('expo')) {
      iconKey = 'exposition';
    } else if (category.contains('musée') || category.contains('musee')) {
      iconKey = 'musée';
    } else if (category.contains('festival')) {
      iconKey = 'festival';
    }
    
    // Si le score est très élevé (>0.8), utiliser l'icône "match" pour montrer la haute correspondance
    if (score > 0.8) {
      return _markerIcons['match'] ?? _markerIcons['default'] ?? BitmapDescriptor.defaultMarker;
    }
    
    // Sinon utiliser l'icône basée sur la catégorie
    return _markerIcons[iconKey] ?? _markerIcons['default'] ?? BitmapDescriptor.defaultMarker;
  }

  /// Convertir un type de venue en emoji
  String _getEmojiForCategory(String category) {
    category = category.toLowerCase();
    if (category.contains('théâtre') || category.contains('theatre')) {
      return '🎭';
    } else if (category.contains('musique') || category.contains('concert')) {
      return '🎵';
    } else if (category.contains('danse')) {
      return '💃';
    } else if (category.contains('ciném') || category.contains('cinema')) {
      return '🎬';
    } else if (category.contains('art') || category.contains('exposition')) {
      return '🎨';
    } else if (category.contains('musée') || category.contains('musee')) {
      return '🏛️';
    } else if (category.contains('spectacle')) {
      return '🎪';
    } else {
      return '🎟️';
    }
  }

  /// Convertir une émotion en emoji
  String _getEmojiForEmotion(String emotion) {
    emotion = emotion.toLowerCase();
    if (emotion.contains('drôle') || emotion.contains('humoristique')) {
      return '😂';
    } else if (emotion.contains('émouvant') || emotion.contains('touchant')) {
      return '😢';
    } else if (emotion.contains('haletant') || emotion.contains('suspense')) {
      return '😮';
    } else if (emotion.contains('intense')) {
      return '😲';
    } else if (emotion.contains('poignant')) {
      return '💔';
    } else if (emotion.contains('réfléchi') || emotion.contains('reflexion')) {
      return '🤔';
    } else if (emotion.contains('joyeux') || emotion.contains('heureux')) {
      return '😊';
    } else {
      return '✨';
    }
  }
  
  /// Traitement des marqueurs en arrière-plan
  void _processMarkers(List<dynamic> entities, bool isProducers) {
    if (_isComputingMarkers) return;
    _isComputingMarkers = true;
    
    print("🔍 Traitement de ${entities.length} entités (type: ${isProducers ? 'producteurs' : 'événements'})");
    
    // Vérification rapide des coordonnées pour débugger
    int validCoordinatesCount = 0;
    for (var entity in entities) {
      if (entity['location'] != null && 
          entity['location']['coordinates'] != null && 
          entity['location']['coordinates'].length >= 2) {
        validCoordinatesCount++;
      }
    }
    print("✅ Nombre d'entités avec coordonnées valides: $validCoordinatesCount sur ${entities.length}");
    
    if (kIsWeb) {
      // En Web, créer les marqueurs directement
      Set<Marker> newMarkers = _createMarkers(entities, isProducers);
      setState(() {
        _markers = newMarkers;
        _isComputingMarkers = false;
        
        // Pour le débogage - afficher un message si des marqueurs sont chargés
        print("✅ ${_markers.length} marqueurs chargés et prêts à être affichés sur le web");
        
        // S'assurer que la carte est ajustée pour montrer tous les marqueurs
        if (_markers.isNotEmpty && _mapController != null) {
          _fitMarkersOnMap();
        }
      });
    } else {
      // Sur mobile, utiliser le traitement en arrière-plan
      compute(_createMarkersInBackground, {
        'entities': entities,
        'isProducers': isProducers,
        'port': _receivePort.sendPort,
      });
    }
  }
  
  /// Créer les marqueurs directement (pour le web)
  Set<Marker> _createMarkers(List<dynamic> entities, bool isProducers) {
    Set<Marker> markers = {};
    
    // Debug: afficher les 3 premières entités pour vérification
    if (entities.isNotEmpty) {
      print("🔍 Echantillon des entites:");
      for (int i = 0; i < math.min(3, entities.length); i++) {
        print("- Entite ${i+1}: ${entities[i]['lieu'] ?? entities[i]['intitulé'] ?? 'Sans nom'}");
        if (entities[i]['location'] != null && entities[i]['location']['coordinates'] != null) {
          print("  Coords: ${entities[i]['location']['coordinates']}");
        }
      }
    }
    
    // Utiliser un compteur pour z-index unique
    double zIndexCounter = 100.0;
    
    // Calculer un score de pertinence pour chaque entité
    for (var entity in entities) {
      try {
        // Vérification que location et coordinates existent et sont valides
        if (entity['location'] == null || entity['location']['coordinates'] == null) {
          print('❌ Coordonnées manquantes pour une entité');
          continue;
        }
        
        final List? coordinates = entity['location']['coordinates'];
        
        // Vérifier que coordinates est une liste avec au moins 2 éléments
        if (coordinates == null || coordinates.length < 2 || entity['_id'] == null) {
          print('❌ Coordonnées incomplètes ou ID manquant');
          continue;
        }
        
        // Vérifier que les coordonnées sont numériques
        if (coordinates[0] == null || coordinates[1] == null || 
            !(coordinates[0] is num) || !(coordinates[1] is num)) {
          print('❌ Coordonnées invalides: valeurs non numériques');
          continue;
        }
        
        // Convertir en double de manière sécurisée
        double lon = coordinates[0].toDouble();
        double lat = coordinates[1].toDouble();
        
        // Vérifier que les coordonnées sont dans les limites valides
        if (lat < -90 || lat > 90 || lon < -180 || lon > 180) {
          print('❌ Coordonnées invalides: hors limites (lat: $lat, lon: $lon)');
          continue;
        }
        
        // Ajouter un décalage microscopique aux coordonnées - juste pour prévenir la superposition parfaite
        final int entityIndex = entities.indexOf(entity);
        final double offsetFactor = 0.000001; // ~0.1 mètre de décalage maximum (microscopique)
        final math.Random random = math.Random(entityIndex); // Random prévisible basé sur l'index
        
        // Appliquer un décalage infime qui maintient les coordonnées géographiques quasi-exactes
        lat += random.nextDouble() * offsetFactor * 2 - offsetFactor;
        lon += random.nextDouble() * offsetFactor * 2 - offsetFactor;
        
        // Log détaillé pour le débogage
        print("  🔍 Position exacte (micro-décalage): [${lat.toStringAsFixed(8)}, ${lon.toStringAsFixed(8)}]");
        
        final String id = entity['_id'];
        final String name = isProducers
            ? entity['lieu'] ?? 'Sans nom'
            : entity['intitulé'] ?? 'Événement sans nom';
            
        // Récupérer la catégorie de l'entité pour couleur thématique
        String entityCategory = '';
        if (isProducers) {
          entityCategory = entity['catégorie']?.toString().toLowerCase() ?? '';
        } else {
          entityCategory = entity['catégorie']?.toString().toLowerCase() ?? '';
        }
        
        // Calculer un score de pertinence pour cette entité basé sur les filtres sélectionnés
        double entityScore = _calculateEntityScore(entity, isProducers);
        
        // Assigner une couleur basée sur le score pour un repérage plus intuitif
        double markerHue = _getColorBasedOnScore(entityScore);
        
        // Z-index unique et croissant pour chaque marqueur (incréments plus petits)
        final double zIndex = 100.0 + (zIndexCounter * 0.1);
        zIndexCounter++;
        
        // Créer l'icône du marqueur avec la couleur basée sur la catégorie
        BitmapDescriptor markerIcon = BitmapDescriptor.defaultMarkerWithHue(markerHue);
        
        // Log pour confirmer création du marqueur
        print("✅ Marqueur créé pour: $name avec catégorie: $entityCategory (hue: $markerHue, z-index: $zIndex)");
        
        // Créer le marqueur avec tous les paramètres nécessaires pour garantir visibilité et interaction
        Marker marker = Marker(
          markerId: MarkerId(id),
          position: LatLng(lat, lon),
          icon: markerIcon,
          visible: true,
          flat: false, // Désactiver flat pour meilleure visibilité 3D
          alpha: 1.0, // Complètement opaque
          zIndex: zIndex, // Z-index unique croissant
          anchor: const Offset(0.5, 0.7), // Ancrage plus haut pour que le marqueur apparaisse plus élevé sur la carte
          consumeTapEvents: true, // Assure que les taps sont bien capturés
          infoWindow: InfoWindow(
            title: name,
            snippet: _buildInfoSnippet(entity, isProducers),
          ),
          onTap: () {
            // Afficher les détails directement sans passer par infoWindow
            _showEntityQuickView(context, entity, isProducers, id);
            
            // Gérer le double-tap pour navigation directe
            if (_lastTappedMarkerId == id) {
              // Double tap détecté - naviguer vers la page détaillée
              if (isProducers) {
                _navigateToProducerDetails(entity);
              } else {
                _navigateToEventDetails(id);
              }
              _lastTappedMarkerId = null;
            } else {
              // Premier tap - enregistrer l'ID
              setState(() {
                _lastTappedMarkerId = id;
              });
              
              // Annuler après un délai si pas de second tap
              Future.delayed(const Duration(seconds: 3), () {
                if (mounted && _lastTappedMarkerId == id) {
                  setState(() {
                    _lastTappedMarkerId = null;
                  });
                }
              });
            }
          },
        );
        
        markers.add(marker);
      } catch (e) {
        print("❌ Erreur lors de la création du marqueur: $e");
      }
    }
    
    return markers;
  }
  
  /// Afficher une vue rapide des détails de l'entité
  void _showEntityQuickView(BuildContext context, Map<String, dynamic> entity, bool isProducer, String id) {
    // Obtenir l'image du lieu si disponible avec une image de repli fiable
    final String imageUrl = entity['photo'] ?? 
                           entity['image'] ?? 
                           (isProducer 
                             ? 'https://images.unsplash.com/photo-1561089489-f13d5e730d72?w=500&q=80'
                             : 'https://images.unsplash.com/photo-1540575467063-178a50c2df87?w=500&q=80');
    
    // Couleur thématique selon le type
    final Color themeColor = isProducer ? Colors.purple : Colors.orange;
    
    // Récupérer les données à afficher comme émojis
    String categoryEmoji = "";
    if (entity['catégorie'] != null) {
      categoryEmoji = _getEmojiForCategory(entity['catégorie'].toString());
    }
    
    // Récupérer les événements ou émotions pour les convertir en émojis
    List<String> emotionEmojis = [];
    
    // Rechercher les émotions dans différentes structures possibles
    if (entity['notes_globales']?['emotions'] != null && entity['notes_globales']['emotions'] is List) {
      emotionEmojis = (entity['notes_globales']['emotions'] as List)
          .map((e) => _getEmojiForEmotion(e.toString()))
          .toList();
    } else if (entity['emotions'] != null && entity['emotions'] is List) {
      emotionEmojis = (entity['emotions'] as List)
          .map((e) => _getEmojiForEmotion(e.toString()))
          .toList();
    }
    
    // Extraire les intérêts pour affichage
    List<String> interestEmojis = [];
    if (entity['interests'] != null && entity['interests'] is List) {
      interestEmojis = (entity['interests'] as List)
          .take(5) // Limiter à 5 intérêts maximum
          .map((i) {
            // Convertir les intérêts en emoji selon le nom
            String interest = i.toString().toLowerCase();
            if (interest.contains('food') || interest.contains('cuisine') || interest.contains('restaurant')) {
              return '🍽️';
            } else if (interest.contains('art') || interest.contains('culture')) {
              return '🎨';
            } else if (interest.contains('sport') || interest.contains('activ')) {
              return '🏃';
            } else if (interest.contains('music') || interest.contains('musiqu')) {
              return '🎵';
            } else if (interest.contains('nature') || interest.contains('eco')) {
              return '🌿';
            } else {
              return '✨';
            }
          })
          .toList();
    }
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias, // Pour que l'image ne déborde pas
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          width: 320,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Image d'en-tête avec nom et note superposés
              Stack(
                children: [
                  // Image d'en-tête
                  Container(
                    height: 150,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: NetworkImage(imageUrl),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  // Dégradé pour améliorer la lisibilité du texte
                  Container(
                    height: 150,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.1),
                          Colors.black.withOpacity(0.7),
                        ],
                      ),
                    ),
                  ),
                  // Nom et note du lieu
                  Positioned(
                    bottom: 10,
                    left: 15,
                    right: 15,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            isProducer ? entity['lieu'] ?? "Lieu de loisir" : entity['intitulé'] ?? "Événement",
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 22,
                              shadows: [
                                Shadow(
                                  color: Colors.black,
                                  offset: Offset(0, 1),
                                  blurRadius: 3,
                                ),
                              ],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (entity['note'] != null || entity['rating'] != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.amber,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  "${(entity['note'] ?? entity['rating']).toStringAsFixed(1)}",
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const Icon(Icons.star, size: 16, color: Colors.black),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Bouton fermer
                  Positioned(
                    top: 10,
                    right: 10,
                    child: InkWell(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                  // Type de contenu (Producteur ou Événement) avec emoji
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: themeColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            categoryEmoji,
                            style: const TextStyle(fontSize: 14),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isProducer ? "Lieu" : "Événement",
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              
              // Corps avec les détails essentiels
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Adresse ou lieu
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.location_on, size: 18, color: Colors.grey),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            entity['adresse'] ?? entity['lieu'] ?? "Adresse non disponible",
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    // Catégorie avec puce stylisée et emoji
                    if (entity['catégorie'] != null) ...[
                      Wrap(
                        spacing: 6,
                        children: [
                          Chip(
                            avatar: Text(
                              categoryEmoji,
                              style: const TextStyle(fontSize: 14),
                            ),
                            label: Text(entity['catégorie'].toString()),
                            labelStyle: const TextStyle(fontSize: 12, color: Colors.white),
                            backgroundColor: themeColor,
                            padding: const EdgeInsets.all(0),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                    
                    // Émotions et intérêts avec émojis - avec un design amélioré
                    if (emotionEmojis.isNotEmpty || interestEmojis.isNotEmpty) ...[
                      // En-tête avec un badge de correspondance si c'est un bon match
                      Row(
                        children: [
                          const Text(
                            "Ambiance & Intérêts :",
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const Spacer(),
                          if (_selectedEmotions.isNotEmpty && emotionEmojis.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.green, width: 1),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.check_circle, color: Colors.green, size: 12),
                                  SizedBox(width: 4),
                                  Text(
                                    "Match",
                                    style: TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      
                      // Affichage amélioré des émojis avec libellé
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            ...emotionEmojis.map((emoji) => 
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.purple.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        emoji,
                                        style: const TextStyle(fontSize: 24),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            ),
                            ...interestEmojis.map((emoji) => 
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        emoji,
                                        style: const TextStyle(fontSize: 24),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    
                    // Intérêts des amis - SECTION AMÉLIORÉE AVEC STYLE VISUEL
                    if (entity['followers'] != null || entity['friend_interests'] != null || entity['followers_count'] != null) ...[
                      Row(
                        children: [
                          const Text(
                            "Intérêts des amis :",
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const Spacer(),
                          // Badge pour indiquer le nombre total
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.purple,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              "${entity['followers_count'] ?? entity['followers']?.length ?? '0'} amis",
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.purple.withOpacity(0.1), Colors.blue.withOpacity(0.05)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.purple.withOpacity(0.3)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // Avatars des amis en chevauchement stylisé
                            Row(
                              children: [
                                // Photo principale du lieu
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    image: DecorationImage(
                                      image: NetworkImage(imageUrl),
                                      fit: BoxFit.cover,
                                    ),
                                    border: Border.all(color: Colors.white, width: 3),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Avatars fictifs des amis en chevauchement
                                Expanded(
                                  child: Stack(
                                    children: List.generate(
                                      math.min(4, entity['friend_interests']?.length ?? 3),
                                      (index) => Positioned(
                                        left: index * 28.0, // Chevauchement
                                        child: Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Colors.white,
                                            image: DecorationImage(
                                              image: NetworkImage(
                                                // Images d'avatars fictifs
                                                "https://picsum.photos/200?random=${index + 10}"
                                              ),
                                              fit: BoxFit.cover,
                                            ),
                                            border: Border.all(color: Colors.white, width: 2),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(0.1),
                                                blurRadius: 3,
                                                offset: const Offset(0, 1),
                                              ),
                                            ],
                                          ),
                                          // Badge d'intérêt sur l'avatar
                                          child: Stack(
                                            children: [
                                              Positioned(
                                                right: 0,
                                                bottom: 0,
                                                child: Container(
                                                  padding: const EdgeInsets.all(2),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white,
                                                    shape: BoxShape.circle,
                                                    border: Border.all(color: Colors.purple, width: 1),
                                                  ),
                                                  child: Text(
                                                    emotionEmojis.isNotEmpty && index < emotionEmojis.length
                                                        ? emotionEmojis[index]
                                                        : isProducer ? '🎭' : '👍',
                                                    style: const TextStyle(fontSize: 10),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                // Indication du nombre d'amis supplémentaires
                                if ((entity['followers_count'] ?? entity['followers']?.length ?? 0) > 4)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      "+${(entity['followers_count'] ?? entity['followers']?.length ?? 0) - 4}",
                                      style: TextStyle(
                                        color: Colors.grey.shade700,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Statistiques d'intérêts avec affichage amélioré
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildInterestStat(
                                  categoryEmoji,
                                  "Catégorie",
                                  entity['catégorie']?.toString() ?? (isProducer ? "Lieu" : "Événement"),
                                ),
                                _buildInterestStat(
                                  interestEmojis.isNotEmpty ? interestEmojis[0] : "✨",
                                  "Ambiance",
                                  emotionEmojis.isNotEmpty ? "Positive" : "Variée",
                                ),
                                _buildInterestStat(
                                  "👥",
                                  "Popularité",
                                  "${entity['followers_count'] ?? entity['followers']?.length ?? '?'} amis",
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    
                    // Description
                    if (entity['description'] != null) ...[
                      const Text(
                        "Description :",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        entity['description'].toString(),
                        style: const TextStyle(fontSize: 14),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 12),
                    ],
                    
                    // Prix si disponible
                    if (entity['prix_reduit'] != null || entity['ancien_prix'] != null) ...[
                      Row(
                        children: [
                          const Icon(Icons.local_offer, size: 18, color: Colors.green),
                          const SizedBox(width: 8),
                          Text(
                            "Prix : ${entity['prix_reduit'] ?? ''} ${entity['ancien_prix'] != null ? '(au lieu de ${entity['ancien_prix']})' : ''}",
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                    
                    // Bouton pour voir plus de détails
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        icon: isProducer 
                          ? const Icon(Icons.theater_comedy) 
                          : const Icon(Icons.event),
                        label: const Text('VOIR LE PROFIL COMPLET',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: themeColor,
                          foregroundColor: Colors.white,
                          elevation: 3,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(context); // Fermer la boîte de dialogue
                          if (isProducer) {
                            _navigateToProducerDetails(entity);
                          } else {
                            _navigateToEventDetails(id);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  /// Fonction statique pour préparer les données des marqueurs en arrière-plan
  /// Plutôt que de créer des objets Marker directement, nous allons envoyer des données
  /// structurées qui seront ensuite utilisées pour créer les marqueurs dans le thread principal
  static void _createMarkersInBackground(Map<String, dynamic> params) {
    final List<dynamic> entities = params['entities'];
    final bool isProducers = params['isProducers'];
    final SendPort sendPort = params['port'];
    
    // Créer une liste pour stocker les données simplifiées des marqueurs
    List<Map<String, dynamic>> markerDataList = [];
    
    print("🏗️ Préparation des données pour ${entities.length} entités en arrière-plan");
    
    for (var entity in entities) {
      try {
        // Vérification que location et coordinates existent et sont valides
        if (entity['location'] == null || entity['location']['coordinates'] == null) {
          continue;
        }
        
        final List? coordinates = entity['location']['coordinates'];
        
        // Vérifier que coordinates est une liste avec au moins 2 éléments
        if (coordinates == null || coordinates.length < 2 || entity['_id'] == null) {
          continue;
        }
        
        // Vérifier que les coordonnées sont numériques
        if (coordinates[0] == null || coordinates[1] == null || 
            !(coordinates[0] is num) || !(coordinates[1] is num)) {
          continue;
        }
        
        // Convertir en double de manière sécurisée
        final double lon = coordinates[0].toDouble();
        final double lat = coordinates[1].toDouble();
        
        // Vérifier que les coordonnées sont dans les limites valides
        if (lat < -90 || lat > 90 || lon < -180 || lon > 180) {
          continue;
        }
        
        final String id = entity['_id'];
        final String name = isProducers
            ? entity['lieu'] ?? 'Sans nom'
            : entity['intitulé'] ?? 'Événement sans nom';
        
        // Définir la couleur en fonction de la catégorie
        double markerHue = BitmapDescriptor.hueViolet; // Couleur par défaut
        
        // Attribution des couleurs par catégorie
        String category = '';
        if (isProducers) {
          category = entity['catégorie']?.toString().toLowerCase() ?? '';
        } else {
          category = entity['catégorie']?.toString().toLowerCase() ?? '';
        }
        
        if (category.contains('théâtre') || category.contains('theatre')) {
          markerHue = BitmapDescriptor.hueRed;
        } else if (category.contains('musiqu') || category.contains('concert')) {
          markerHue = BitmapDescriptor.hueAzure;
        } else if (category.contains('ciném') || category.contains('cinema')) {
          markerHue = BitmapDescriptor.hueOrange;
        } else if (category.contains('danse')) {
          markerHue = BitmapDescriptor.hueGreen;
        } else if (category.contains('expo')) {
          markerHue = BitmapDescriptor.hueYellow;
        } else if (category.contains('musée') || category.contains('musee')) {
          markerHue = BitmapDescriptor.hueCyan;
        } else if (category.contains('festival')) {
          markerHue = BitmapDescriptor.hueMagenta;
        }
        
        // Sérialiser l'entité pour pouvoir la reconstruire dans le thread principal
        String entityJson = json.encode(entity);
        
        // Créer un objet de données pour ce marqueur
        Map<String, dynamic> markerData = {
          'id': id,
          'lat': lat,
          'lon': lon,
          'name': name,
          'hue': markerHue,
          'category': category,
          'isProducer': isProducers,
          'entityJson': entityJson,
        };
        
        // Ajouter les données à la liste
        markerDataList.add(markerData);
        
        // Log pour confirmer création des données du marqueur
        print("✅ Données préparées pour marqueur: $name (catégorie: $category)");
      } catch (e) {
        print("❌ Erreur lors de la création des données d'un marqueur en arrière-plan: $e");
      }
    }
    
    print("✅ ${markerDataList.length} marqueurs préparés en arrière-plan, envoi au thread principal");
    
    // Envoyer les données des marqueurs au thread principal
    sendPort.send(['markerData', markerDataList]);
  }
  
  /// Appliquer les filtres de producteurs
  void _applyProducerFilters() {
    setState(() {
      _markers.clear(); // Vider les marqueurs existants avant d'en ajouter de nouveaux
      _shouldShowMarkers = true; // S'assurer que les marqueurs seront visibles
    });
    _fetchNearbyProducers(_initialPosition.latitude, _initialPosition.longitude);
    _showSnackBar("Recherche des producteurs mise à jour.");
  }

  /// Appliquer les filtres d'événements
  void _applyEventFilters() {
    _fetchEvents();
    _showSnackBar("Recherche des événements mise à jour.");
  }

  /// Récupérer les producteurs proches
  Future<void> _fetchNearbyProducers(double latitude, double longitude) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final queryParameters = {
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'radius': _selectedRadius.toString(),
        if (_selectedProducerCategory != null) 'category': _selectedProducerCategory,
      };

      // Extraire le domaine et le protocole de l'URL complète
      final baseUrl = getBaseUrl();
      Uri uri;
      
      if (baseUrl.startsWith('http://')) {
        // Si c'est http://
        final domain = baseUrl.replaceFirst('http://', '');
        uri = Uri.http(domain, '/api/leisureProducers/nearby', queryParameters);
      } else if (baseUrl.startsWith('https://')) {
        // Si c'est https://
        final domain = baseUrl.replaceFirst('https://', '');
        uri = Uri.https(domain, '/api/leisureProducers/nearby', queryParameters);
      } else {
        // Utiliser Uri.parse comme solution de secours
        uri = Uri.parse('$baseUrl/api/leisureProducers/nearby').replace(queryParameters: queryParameters);
      }
      
      print("🔍 Requête envoyée : $uri");

      // Ajouter un timeout pour la requête
      final response = await http.get(uri).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          print('⏱️ Timeout lors de la requête vers $uri');
          throw TimeoutException("La requête a pris trop de temps.");
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> producers = json.decode(response.body);
        print("✅ Nombre de producteurs reçus: ${producers.length}");

        if (producers.isEmpty) {
          _showSnackBar("Aucun lieu trouvé dans cette zone. Essayez d'augmenter le rayon ou de changer de filtres.");
          setState(() {
            _isLoading = false;
          });
          return;
        }

        _processMarkers(producers, true);
      } else {
        print("❌ Erreur API (${response.statusCode}): ${response.body}");
        _showSnackBar("Erreur lors de la récupération des producteurs (${response.statusCode}).");
      }
    } catch (e) {
      print("❌ Exception lors de la requête: $e");
      _showSnackBar("Erreur réseau: $e. Veuillez vérifier votre connexion.");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  /// Adapter la carte pour afficher tous les marqueurs
  void _fitMarkersOnMap() {
    if (_markers.isEmpty || _mapController == null) return;
    
    try {
      // Calculer les limites pour inclure tous les marqueurs
      double minLat = 90;
      double maxLat = -90;
      double minLng = 180;
      double maxLng = -180;
      
      for (final marker in _markers) {
        if (marker.position.latitude < minLat) minLat = marker.position.latitude;
        if (marker.position.latitude > maxLat) maxLat = marker.position.latitude;
        if (marker.position.longitude < minLng) minLng = marker.position.longitude;
        if (marker.position.longitude > maxLng) maxLng = marker.position.longitude;
      }
      
      // Ajouter une marge autour des limites
      final latPadding = (maxLat - minLat) * 0.2;
      final lngPadding = (maxLng - minLng) * 0.2;
      
      final bounds = LatLngBounds(
        southwest: LatLng(minLat - latPadding, minLng - lngPadding),
        northeast: LatLng(maxLat + latPadding, maxLng + lngPadding),
      );
      
      // Animer la caméra pour inclure tous les marqueurs
      _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
      print("✅ Carte ajustée pour afficher tous les marqueurs");
    } catch (e) {
      print("❌ Erreur lors de l'ajustement de la carte: $e");
      // En cas d'erreur, revenir à la position initiale avec un zoom raisonnable
      _mapController!.animateCamera(CameraUpdate.newLatLngZoom(_initialPosition, 12));
    }
  }

  /// Récupérer les événements proches selon les critères
  Future<void> _fetchEvents() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final queryParameters = {
        if (_selectedEventCategory != null) 'category': _selectedEventCategory,
        if (_minMiseEnScene > 0) 'miseEnScene': _minMiseEnScene.toString(),
        if (_minJeuActeurs > 0) 'jeuActeurs': _minJeuActeurs.toString(),
        if (_minScenario > 0) 'scenario': _minScenario.toString(),
        if (_selectedEmotions.isNotEmpty) 'emotions': _selectedEmotions.join(','),
        'minPrice': _minPrice.toString(),
        'maxPrice': _maxPrice.toString(),
      };

      // Extraire le domaine et le protocole de l'URL complète
      final baseUrl = getBaseUrl();
      Uri uri;
      
      if (baseUrl.startsWith('http://')) {
        // Si c'est http://
        final domain = baseUrl.replaceFirst('http://', '');
        uri = Uri.http(domain, '/api/events/advanced-search', queryParameters);
      } else if (baseUrl.startsWith('https://')) {
        // Si c'est https://
        final domain = baseUrl.replaceFirst('https://', '');
        uri = Uri.https(domain, '/api/events/advanced-search', queryParameters);
      } else {
        // Utiliser Uri.parse comme solution de secours
        uri = Uri.parse('$baseUrl/api/events/advanced-search').replace(queryParameters: queryParameters);
      }
      
      print("🔍 Requête événements envoyée : $uri");

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final List<dynamic> events = json.decode(response.body);
        _processMarkers(events, false);
      } else {
        _showSnackBar("Erreur lors de la récupération des événements.");
      }
    } catch (e) {
      _showSnackBar("Erreur réseau. Veuillez vérifier votre connexion.");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Afficher une boîte de dialogue pour sélectionner un événement parmi plusieurs
  void _showEventSelectionDialog(List<dynamic> events) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Sélectionnez un événement"),
          content: SizedBox(
            width: double.infinity,
            height: 300,
            child: ListView.builder(
              itemCount: events.length,
              itemBuilder: (context, index) {
                final event = events[index];
                return ListTile(
                  title: Text(event['intitulé']),
                  subtitle: Text('Catégorie : ${event['catégorie']}'),
                  onTap: () {
                    Navigator.pop(context);
                    _navigateToEventDetails(event['_id']);
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  /// Navigation vers les détails du producteur
  void _navigateToProducerDetails(Map<String, dynamic> producer) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProducerLeisureScreen(producerData: producer),
      ),
    );
  }

  /// Navigation vers les détails de l'événement
  void _navigateToEventDetails(String eventId) async {
    // Extraire le domaine et le protocole de l'URL complète
    final baseUrl = getBaseUrl();
    Uri url;
    
    if (baseUrl.startsWith('http://')) {
      // Si c'est http://
      final domain = baseUrl.replaceFirst('http://', '');
      url = Uri.http(domain, '/api/events/$eventId');
    } else if (baseUrl.startsWith('https://')) {
      // Si c'est https://
      final domain = baseUrl.replaceFirst('https://', '');
      url = Uri.https(domain, '/api/events/$eventId');
    } else {
      // Utiliser Uri.parse comme solution de secours
      url = Uri.parse('$baseUrl/api/events/$eventId');
    }
    
    print("🔍 Requête détails événement : $url");

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final eventData = json.decode(response.body);

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EventLeisureScreen(eventData: eventData),
          ),
        );
      } else {
        _showSnackBar("Erreur lors de la récupération des détails de l'événement.");
      }
    } catch (e) {
      _showSnackBar("Erreur réseau. Veuillez vérifier votre connexion.");
    }
  }

  /// Afficher une barre d'alerte
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
  
  /// Affiche une bulle d'aide pour guider l'utilisateur vers le panneau de filtres
  void _showFilterHintTooltip() {
    // Vérifier si le panneau de filtres est déjà visible
    if (!_isFilterPanelVisible && !_hasShownFilterHint) {
      // Afficher temporairement la bulle d'aide puis la masquer après quelques secondes
      setState(() {
        // La bulle s'affiche grâce au widget Positioned dans le build
      });
      
      // Masquer après un délai (l'animation se fait dans le widget)
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) {
          setState(() {
            // Marquer que l'aide a été vue
            _hasShownFilterHint = true;
          });
        }
      });
    }
  }
  
  /// Applique un style personnalisé à la carte pour une meilleure lisibilité
  Future<void> _setMapStyle(GoogleMapController controller) async {
    // Style inspiré de "Retro" de Google avec ajustements pour rendre les POIs plus visibles
    const String mapStyle = '''
    [
      {
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#f5f5f5"
          }
        ]
      },
      {
        "elementType": "labels.icon",
        "stylers": [
          {
            "visibility": "on"
          }
        ]
      },
      {
        "elementType": "labels.text.fill",
        "stylers": [
          {
            "color": "#616161"
          }
        ]
      },
      {
        "elementType": "labels.text.stroke",
        "stylers": [
          {
            "color": "#f5f5f5"
          }
        ]
      },
      {
        "featureType": "administrative.land_parcel",
        "stylers": [
          {
            "visibility": "off"
          }
        ]
      },
      {
        "featureType": "administrative.land_parcel",
        "elementType": "labels.text.fill",
        "stylers": [
          {
            "color": "#bdbdbd"
          }
        ]
      },
      {
        "featureType": "poi",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#eeeeee"
          }
        ]
      },
      {
        "featureType": "poi",
        "elementType": "labels.text.fill",
        "stylers": [
          {
            "color": "#757575"
          }
        ]
      },
      {
        "featureType": "poi.attraction",
        "elementType": "geometry.fill",
        "stylers": [
          {
            "color": "#f9ebff"
          }
        ]
      },
      {
        "featureType": "poi.park",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#e5e5e5"
          }
        ]
      },
      {
        "featureType": "poi.park",
        "elementType": "labels.text.fill",
        "stylers": [
          {
            "color": "#9e9e9e"
          }
        ]
      },
      {
        "featureType": "road",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#ffffff"
          }
        ]
      },
      {
        "featureType": "road",
        "elementType": "geometry.fill",
        "stylers": [
          {
            "color": "#f1f1f1"
          }
        ]
      },
      {
        "featureType": "road.arterial",
        "elementType": "geometry.fill",
        "stylers": [
          {
            "color": "#ffffff"
          }
        ]
      },
      {
        "featureType": "road.arterial",
        "elementType": "labels.text.fill",
        "stylers": [
          {
            "color": "#757575"
          }
        ]
      },
      {
        "featureType": "road.highway",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#dadada"
          }
        ]
      },
      {
        "featureType": "road.highway",
        "elementType": "labels.text.fill",
        "stylers": [
          {
            "color": "#616161"
          }
        ]
      },
      {
        "featureType": "road.local",
        "elementType": "labels.text.fill",
        "stylers": [
          {
            "color": "#9e9e9e"
          }
        ]
      },
      {
        "featureType": "transit.line",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#e5e5e5"
          }
        ]
      },
      {
        "featureType": "transit.station",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#eeeeee"
          }
        ]
      },
      {
        "featureType": "water",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#c9c9c9"
          }
        ]
      },
      {
        "featureType": "water",
        "elementType": "geometry.fill",
        "stylers": [
          {
            "color": "#d8e9f3"
          }
        ]
      },
      {
        "featureType": "water",
        "elementType": "labels.text.fill",
        "stylers": [
          {
            "color": "#9e9e9e"
          }
        ]
      }
    ]
    ''';

    try {
      await controller.setMapStyle(mapStyle);
    } catch (e) {
      print("❌ Erreur lors de l'application du style de carte: $e");
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PopScope(
        canPop: false,
        child: Stack(
          children: [
            AdaptiveMapWidget(
              initialPosition: _initialPosition,
              initialZoom: 12.0,
              markers: _markers,
              onMapCreated: (GoogleMapController controller) {
                _mapController = controller;
                setState(() {
                  _isMapReady = true;
                });
                _setMapStyle(controller);
                if (_markers.isEmpty && _shouldShowMarkers) {
                  _fetchNearbyProducers(_initialPosition.latitude, _initialPosition.longitude);
                }
              },
            ),
            if (_isLoading)
              Container(
                color: Colors.black.withOpacity(0.3),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.purple),
                        ),
                        SizedBox(height: 16),
                        Text(
                          "Chargement des lieux...",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          "Élevé",
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.orange,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          "Moyen",
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.red,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          "Faible",
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  /// Création d'un bouton stylisé pour les options de carte
  Widget _buildMapOptionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    bool isSelected = false,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? color : Colors.grey.shade100,
        foregroundColor: isSelected ? Colors.white : color,
        elevation: isSelected ? 3 : 1,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isSelected ? color : Colors.transparent,
            width: 1,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 28),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
  
  /// Définir une palette de couleurs selon le type de catégorie
  Color _getCategoryColor(String category) {
    category = category.toLowerCase();
    if (category.contains('théâtre') || category.contains('theatre')) {
      return Colors.redAccent;
    } else if (category.contains('musique') || category.contains('concert')) {
      return Colors.blueAccent;
    } else if (category.contains('danse')) {
      return Colors.greenAccent;
    } else if (category.contains('ciném') || category.contains('cinema')) {
      return Colors.orangeAccent;
    } else if (category.contains('art') || category.contains('exposition')) {
      return Colors.purpleAccent;
    } else {
      return Colors.deepPurple;
    }
  }

  /// Affiche un dialogue d'aide pour expliquer l'utilisation des filtres
  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Aide - Utilisation des filtres"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text("Comment utiliser les filtres:"),
            SizedBox(height: 8),
            Text("• Cliquez sur le bouton 🔍 en haut à gauche pour afficher le panneau de critères"),
            SizedBox(height: 4),
            Text("• Le premier onglet permet de filtrer par type de lieux (théâtre, musique, etc.)"),
            SizedBox(height: 4),
            Text("• Le deuxième onglet permet de filtrer par type d'événements"),
            SizedBox(height: 4),
            Text("• Sélectionnez vos critères puis cliquez sur 'Appliquer'"),
            SizedBox(height: 4),
            Text("• Les lieux correspondants apparaîtront sur la carte"),
            SizedBox(height: 8),
            Text("• Cliquez sur un marqueur pour voir les détails du lieu ou de l'événement"),
            SizedBox(height: 4),
            Text("• Double-cliquez sur un marqueur pour accéder directement à sa page détaillée"),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Compris"),
          ),
        ],
      ),
    );
  }

  /// Dialogue de filtres rapides
  void _showQuickFilterDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Filtres rapides"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.theater_comedy, color: Colors.purple),
              title: const Text("Théâtre"),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _selectedProducerCategory = "Théâtre";
                });
                _applyProducerFilters();
              },
            ),
            ListTile(
              leading: const Icon(Icons.music_note, color: Colors.blue),
              title: const Text("Musique"),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _selectedProducerCategory = "Musique";
                });
                _applyProducerFilters();
              },
            ),
            ListTile(
              leading: const Icon(Icons.movie, color: Colors.red),
              title: const Text("Cinéma"),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _selectedProducerCategory = "Cinéma";
                });
                _applyProducerFilters();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Fermer"),
          ),
        ],
      ),
    );
  }
  
  /// Helper method to count active filters for notification badge
  int _getActiveFiltersCount() {
    int count = 0;
    if (_selectedProducerCategory != null) count++;
    if (_selectedEventCategory != null) count++;
    if (_selectedEmotions.isNotEmpty) count++;
    if (_minMiseEnScene > 0 || _minJeuActeurs > 0 || _minScenario > 0) count++;
    if (_minPrice > 0 || _maxPrice < 1000) count++;
    return count;
  }

  /// Widget helper to build legend items
  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildFilterPanel() {
    // Obtenir la hauteur d'écran pour définir une taille maximale
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(2, 2),
          ),
        ],
      ),
      margin: const EdgeInsets.only(right: 10),
      width: screenWidth * 0.85, // Limiter la largeur à 85% de l'écran
      child: DefaultTabController(
        length: 2,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // En-tête avec onglets et bouton fermer - style amélioré
            Container(
              decoration: const BoxDecoration(
                color: Colors.purple,
                borderRadius: BorderRadius.only(topRight: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  // Bouton fermer à gauche avec style amélioré
                  Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () {
                        setState(() {
                          _isFilterPanelVisible = false;
                        });
                      },
                      tooltip: "Fermer les filtres",
                    ),
                  ),
                  // Titre des filtres avec icône
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.filter_list, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text(
                          "Critères",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Bouton réinitialiser à droite avec style amélioré
                  Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: TextButton.icon(
                      icon: const Icon(Icons.refresh, color: Colors.white, size: 16),
                      label: const Text(
                        "Réinitialiser",
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                      onPressed: () {
                        setState(() {
                          _selectedProducerCategory = null;
                          _selectedEventCategory = null;
                          _minMiseEnScene = 0;
                          _minJeuActeurs = 0;
                          _minScenario = 0;
                          _selectedEmotions.clear();
                          _minPrice = 0;
                          _maxPrice = 1000;
                          _selectedRadius = 5000;
                        });
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        minimumSize: Size.zero,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Onglets avec style amélioré
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
              ),
              child: TabBar(
                labelColor: Colors.purple,
                unselectedLabelColor: Colors.grey.shade600,
                indicatorColor: Colors.purple,
                indicatorWeight: 3,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                tabs: const [
                  Tab(
                    icon: Icon(Icons.business, size: 20),
                    text: "Producteurs",
                  ),
                  Tab(
                    icon: Icon(Icons.event, size: 20),
                    text: "Événements",
                  ),
                ],
              ),
            ),
            // Contenu des onglets avec hauteur contrainte
            SizedBox(
              height: screenHeight * 0.5, // Hauteur fixe qui correspond à 50% de l'écran
              child: TabBarView(
                children: [
                  _buildProducerFilters(),
                  _buildEventFilters(),
                ],
              ),
            ),
            // Bouton Appliquer avec style amélioré
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(bottomRight: Radius.circular(20)),
              ),
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.search),
                label: const Text('RECHERCHER', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 3,
                ),
                onPressed: () {
                  _applyProducerFilters();
                  // Fermer automatiquement le panneau après application
                  setState(() {
                    _isFilterPanelVisible = false;
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProducerFilters() {
    // Liste complète des catégories de lieux de loisirs
    final List<String> venueCategories = [
      'Théâtre', 'Musique', 'Cinéma', 'Danse', 'Musée', 
      'Galerie d\'art', 'Parc d\'attractions', 'Escape Game',
      'Bar à jeux', 'Salle de concert', 'Opéra', 'Cirque'
    ];
    
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.theater_comedy, size: 18, color: Colors.purple),
              const SizedBox(width: 8),
              const Text(
                "Catégorie lieu",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Utiliser un ListView.builder avec hauteur fixe pour rendre la liste défilante
          SizedBox(
            height: 120, // Hauteur fixe pour permettre le défilement
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: venueCategories.map((category) {
                      // Récupérer l'emoji correspondant à la catégorie
                      String emoji = _getEmojiForCategory(category);
                      return FilterChip(
                        avatar: Text(emoji, style: const TextStyle(fontSize: 14)),
                        label: Text(category),
                        selected: _selectedProducerCategory == category,
                        selectedColor: _getCategoryColor(category).withOpacity(0.2),
                        onSelected: (selected) {
                          setState(() {
                            _selectedProducerCategory = selected ? category : null;
                          });
                        },
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          const Text(
            "Rayon de recherche",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Column(
            children: [
              Slider(
                value: _selectedRadius,
                min: 1000,
                max: 50000,
                divisions: 49,
                label: "${(_selectedRadius/1000).toStringAsFixed(1)} km",
                onChanged: (value) {
                  setState(() {
                    _selectedRadius = value;
                  });
                },
              ),
              Text(
                "Distance : ${(_selectedRadius/1000).toStringAsFixed(1)} km", 
                style: const TextStyle(fontStyle: FontStyle.italic)
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          ElevatedButton.icon(
            onPressed: () {
              _applyProducerFilters();
              // Fermer automatiquement le panneau après application
              setState(() {
                _isFilterPanelVisible = false;
              });
            },
            icon: const Icon(Icons.search),
            label: const Text('Rechercher des lieux'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventFilters() {
    // Liste détaillée des émotions possibles
    final List<Map<String, dynamic>> emotions = [
      {'label': 'Drôle', 'value': 'drôle', 'emoji': '😂'},
      {'label': 'Émouvant', 'value': 'émouvant', 'emoji': '😢'},
      {'label': 'Haletant', 'value': 'haletant', 'emoji': '😮'},
      {'label': 'Intense', 'value': 'intense', 'emoji': '😲'},
      {'label': 'Poignant', 'value': 'poignant', 'emoji': '💔'},
      {'label': 'Réfléchi', 'value': 'réfléchi', 'emoji': '🤔'},
      {'label': 'Joyeux', 'value': 'joyeux', 'emoji': '😊'},
      {'label': 'Surprenant', 'value': 'surprenant', 'emoji': '😯'},
      {'label': 'Inspirant', 'value': 'inspirant', 'emoji': '✨'},
      {'label': 'Relaxant', 'value': 'relaxant', 'emoji': '😌'},
    ];
    
    // Catégories d'événements plus complètes
    final List<Map<String, dynamic>> eventCategories = [
      {'label': 'Théâtre', 'value': 'Théâtre', 'emoji': '🎭'},
      {'label': 'Comédie', 'value': 'Comédie', 'emoji': '😁'},
      {'label': 'Drame', 'value': 'Drame', 'emoji': '😔'},
      {'label': 'Musique', 'value': 'Musique', 'emoji': '🎵'},
      {'label': 'Concert', 'value': 'Concert', 'emoji': '🎸'},
      {'label': 'Danse', 'value': 'Danse', 'emoji': '💃'},
      {'label': 'Exposition', 'value': 'Exposition', 'emoji': '🎨'},
      {'label': 'Festival', 'value': 'Festival', 'emoji': '🎪'},
      {'label': 'Cinéma', 'value': 'Cinéma', 'emoji': '🎬'},
    ];
    
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Catégorie d'événement",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          // Rendre les catégories défilantes pour éviter la surcharge visuelle
          SizedBox(
            height: 120,
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: eventCategories.map((category) {
                      return FilterChip(
                        avatar: Text(category['emoji']),
                        label: Text(category['label']),
                        selected: _selectedEventCategory == category['value'],
                        selectedColor: _getCategoryColor(category['value']).withOpacity(0.2),
                        onSelected: (selected) {
                          setState(() {
                            _selectedEventCategory = selected ? category['value'] : null;
                          });
                        },
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Notes minimales pour l'événement - dynamique selon la catégorie sélectionnée
          _selectedEventCategory != null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Obtenir les aspects spécifiques à la catégorie
                Builder(builder: (context) {
                  final categoryDetails = _getCategoryDetails(_selectedEventCategory!);
                  final List<String> aspects = List<String>.from(categoryDetails['aspects'] ?? []);
                  
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Texte d'information avec catégorie
                      Text(
                        "Critères spécifiques : $_selectedEventCategory",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Sélectionnez vos critères d'importance pour cette catégorie :",
                        style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: Colors.grey.shade700),
                      ),
                      const SizedBox(height: 12),
                      
                      // Carte pour les sliders d'aspects spécifiques
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: aspects.isEmpty
                              ? const Center(
                                  child: Text(
                                    "Aucun critère spécifique disponible pour cette catégorie",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontStyle: FontStyle.italic),
                                  ),
                                )
                              : Column(
                                  children: [
                                    // Construire dynamiquement les sliders selon les aspects de la catégorie
                                    for (int i = 0; i < aspects.length; i++) ...[
                                      _buildRatingSlider(
                                        aspects[i].substring(0, 1).toUpperCase() + aspects[i].substring(1), // Première lettre en majuscule
                                        _selectedAspects.contains(aspects[i]) ? _minMiseEnScene : 0, // Utiliser une valeur par défaut si aspect sélectionné
                                        (value) {
                                          setState(() {
                                            if (value > 0) {
                                              if (!_selectedAspects.contains(aspects[i])) {
                                                _selectedAspects.add(aspects[i]);
                                              }
                                              
                                              // Stocker la valeur dans la variable appropriée selon l'aspect
                                              if (aspects[i].contains("mise en scène")) {
                                                _minMiseEnScene = value;
                                              } else if (aspects[i].contains("jeu des acteurs")) {
                                                _minJeuActeurs = value;
                                              } else if (aspects[i].contains("texte") || aspects[i].contains("scénario")) {
                                                _minScenario = value;
                                              }
                                            } else {
                                              _selectedAspects.remove(aspects[i]);
                                            }
                                          });
                                        },
                                      ),
                                      if (i < aspects.length - 1) const Divider(),
                                    ],
                                  ],
                                ),
                        ),
                      ),
                    ],
                  );
                }),
              ],
            )
          : Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.purple.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  const Icon(Icons.info_outline, color: Colors.purple, size: 24),
                  const SizedBox(height: 8),
                  const Text(
                    "Sélectionnez une catégorie pour voir les critères spécifiques",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Exemple : Théâtre → mise en scène, jeu des acteurs, etc.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          
          // Émotions recherchées - avec émojis
          const Text(
            "Émotions recherchées",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          // Rendre les émotions défilantes pour ne pas surcharger l'interface
          SizedBox(
            height: 120,
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: emotions.map((emotion) => FilterChip(
                      avatar: Text(emotion['emoji']),
                      label: Text(emotion['label']),
                      selected: _selectedEmotions.contains(emotion['value']),
                      selectedColor: Colors.purple.withOpacity(0.2),
                      checkmarkColor: Colors.purple,
                      onSelected: (isSelected) {
                        setState(() {
                          if (isSelected) {
                            _selectedEmotions.add(emotion['value']);
                          } else {
                            _selectedEmotions.remove(emotion['value']);
                          }
                        });
                      },
                    )).toList(),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Prix avec affichage plus clair
          const Text(
            "Gamme de prix (€)",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Column(
            children: [
              RangeSlider(
                values: RangeValues(_minPrice, _maxPrice),
                min: 0,
                max: 1000,
                divisions: 100,
                labels: RangeLabels(
                  "${_minPrice.round()}€", 
                  "${_maxPrice.round()}€",
                ),
                onChanged: (values) {
                  setState(() {
                    _minPrice = values.start;
                    _maxPrice = values.end;
                  });
                },
                activeColor: Colors.orange,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Min: ${_minPrice.round()}€"),
                  Text("Max: ${_maxPrice.round()}€"),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          ElevatedButton.icon(
            onPressed: () {
              _applyEventFilters();
              // Fermer automatiquement le panneau après application
              setState(() {
                _isFilterPanelVisible = false;
              });
            },
            icon: const Icon(Icons.search),
            label: const Text('Rechercher des événements'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  /// Widget pour afficher une statistique d'intérêt avec émoji et valeur
  Widget _buildInterestStat(String emoji, String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.purple.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Text(
            emoji,
            style: const TextStyle(fontSize: 18),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ],
    );
  }
  
  /// Widget amélioré pour les sliders de notation avec retour visuel plus clair
  Widget _buildRatingSlider(String label, double value, Function(double) onChanged) {
    // Définir une couleur basée sur la valeur pour un retour visuel
    Color sliderColor = value < 3 ? Colors.grey :
                        value < 6 ? Colors.blue :
                        value < 8 ? Colors.orange : Colors.green;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: value > 0 ? sliderColor.withOpacity(0.2) : Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: value > 0 ? sliderColor : Colors.grey.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Text(
                value > 0 ? value.toStringAsFixed(1) : "Non spécifié",
                style: TextStyle(
                  color: value > 0 ? sliderColor : Colors.grey,
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        Slider(
          value: value,
          min: 0,
          max: 10,
          divisions: 10,
          label: value.toStringAsFixed(1),
          activeColor: sliderColor,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
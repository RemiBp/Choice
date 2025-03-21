import 'dart:isolate';
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb, compute;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
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

class MapLeisureScreen extends StatefulWidget {
  const MapLeisureScreen({Key? key}) : super(key: key);

  @override
  State<MapLeisureScreen> createState() => _MapLeisureScreenState();
}

class _MapLeisureScreenState extends State<MapLeisureScreen> {
  final LatLng _initialPosition = const LatLng(48.8566, 2.3522); // Paris
  GoogleMapController? _mapController;

  Set<Marker> _markers = {};
  bool _isLoading = false;
  bool _isMapReady = false;
  bool _isComputingMarkers = false;
  bool _hasShownFilterHint = false; // Pour savoir si l'utilisateur a déjà vu l'indicateur
  bool _shouldShowMarkers = true; // Contrôle l'affichage des marqueurs - activé par défaut
  final ReceivePort _receivePort = ReceivePort();
  String? _lastTappedMarkerId; // Pour gérer le double-tap sur les marqueurs

  // Filtres
  double _selectedRadius = 5000; // Rayon (5 km par défaut)
  String? _selectedProducerCategory;
  String? _selectedEventCategory;
  double _minMiseEnScene = 0;
  double _minJeuActeurs = 0;
  double _minScenario = 0;
  List<String> _selectedEmotions = [];
  double _minPrice = 0;
  double _maxPrice = 1000;
  Map<String, BitmapDescriptor> _markerIcons = {}; // Cache d'icônes pour différentes catégories

  // Contrôle du panneau de filtres
  bool _isFilterPanelVisible = false;
  bool _isPanelAnimating = false; // Pour éviter les clics multiples pendant l'animation

  @override
  void initState() {
    super.initState();
    _loadMarkerIcons();
    
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
        
        // Ajouter un léger décalage aux coordonnées pour éviter la superposition parfaite
        final double offsetFactor = 0.0001; // ~10 mètres de décalage maximum
        final math.Random random = math.Random(markerIndex); // Random déterministe basé sur l'index
        
        // Appliquer un petit décalage unique à chaque marqueur
        lat += random.nextDouble() * offsetFactor * 2 - offsetFactor;
        lon += random.nextDouble() * offsetFactor * 2 - offsetFactor;
        
        // Reconstruire l'entité à partir de son JSON
        Map<String, dynamic> entity = json.decode(entityJson);
        
        // Utiliser des hues différentes selon l'index pour créer des marqueurs visuellement distincts
        double markerHue = (markerIndex % 7) * 45.0; // 0, 45, 90, 135, 180, 225, 270
        if (markerIndex == 0) markerHue = BitmapDescriptor.hueRed; // Premier marqueur toujours rouge
        
        // Créer l'icône du marqueur avec la teinte calculée
        BitmapDescriptor markerIcon = BitmapDescriptor.defaultMarkerWithHue(markerHue);
        
        // Z-index unique et croissant pour chaque marqueur - utiliser une plage plus large
        final double zIndex = 100.0 + (markerIndex * 2.0); // z-index 100.0, 102.0, 104.0, etc.
        
        // Appliquer un décalage beaucoup plus prononcé pour éviter un chevauchement parfait
        final double offsetFactor = 0.0005; // ~50 mètres de décalage
        lat += math.cos(markerIndex * 0.3) * offsetFactor; // Décalage circulaire
        lon += math.sin(markerIndex * 0.3) * offsetFactor;
        
        // Créer le marqueur avec tous les paramètres nécessaires pour garantir visibilité et interaction
        Marker marker = Marker(
          markerId: MarkerId(id),
          position: LatLng(lat, lon),
          icon: markerIcon,
          visible: true,
          flat: markerIndex % 2 == 0, // Alterner entre flat true/false pour diversifier le rendu
          alpha: 1.0, // Complètement opaque
          zIndex: zIndex, // Z-index unique et beaucoup plus élevé
          anchor: const Offset(0.5, 1.0), // Ancrage standard pour les marqueurs Google
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
            snippet: isProducer 
                ? entity['description']?.toString().substring(0, math.min(50, (entity['description']?.toString().length ?? 0))) ?? 'Pas de description'
                : entity['catégorie'] ?? 'Pas de catégorie',
          ),
        );
        
        markers.add(marker);
        print("✅ Marqueur créé et visible pour: $name avec catégorie: $category, z-index: $zIndex");
        
        // Incrémenter l'index pour le prochain marqueur
        markerIndex++;
      } catch (e) {
        print("❌ Erreur lors de la création du marqueur à partir des données: $e");
      }
    }
    
    return markers;
  }
  
  @override
  void dispose() {
    _receivePort.close();
    _mapController?.dispose();
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
    
    // Utiliser un compteur pour z-index unique, commencer à un nombre élevé pour garantir la visibilité
    double zIndexCounter = 1000.0;
    
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
        
        // Ajouter un léger décalage aléatoire aux coordonnées pour éviter la superposition
        // On utilise l'index de l'entité pour créer un décalage déterministe mais unique
        final int entityIndex = entities.indexOf(entity);
        final double offsetFactor = 0.0001; // ~10 mètres de décalage maximum
        final math.Random random = math.Random(entityIndex); // Random prévisible basé sur l'index
        
        // Appliquer un décalage différent pour chaque marqueur
        lat += random.nextDouble() * offsetFactor * 2 - offsetFactor;
        lon += random.nextDouble() * offsetFactor * 2 - offsetFactor;
        
        final String id = entity['_id'];
        final String name = isProducers
            ? entity['lieu'] ?? 'Sans nom'
            : entity['intitulé'] ?? 'Événement sans nom';
        
        print('✅ Création du marqueur pour: $name [lat=$lat, lon=$lon] avec décalage');
        
        // Utiliser une couleur basée sur l'index de l'entité pour diversifier visuellement les marqueurs
        double markerHue;
        if (entityIndex % 8 == 0) markerHue = BitmapDescriptor.hueRed;
        else if (entityIndex % 8 == 1) markerHue = BitmapDescriptor.hueOrange; 
        else if (entityIndex % 8 == 2) markerHue = BitmapDescriptor.hueYellow;
        else if (entityIndex % 8 == 3) markerHue = BitmapDescriptor.hueGreen;
        else if (entityIndex % 8 == 4) markerHue = BitmapDescriptor.hueCyan;
        else if (entityIndex % 8 == 5) markerHue = BitmapDescriptor.hueAzure;
        else if (entityIndex % 8 == 6) markerHue = BitmapDescriptor.hueBlue;
        else markerHue = BitmapDescriptor.hueViolet;
        
        // Augmenter le décalage des coordonnées pour éviter la superposition parfaite
        final double offsetFactor = 0.0005; // ~50 mètres de décalage maximum
        lat += math.cos(entityIndex * 0.3) * offsetFactor; // Motif circulaire pour la distribution
        lon += math.sin(entityIndex * 0.3) * offsetFactor; // Variation sinusoïdale pour éviter l'alignement
        
        // Z-index beaucoup plus élevé et espacé pour garantir séparation visuelle
        final double zIndex = 100.0 + (entityIndex * 2.0); // z-index 100.0, 102.0, 104.0, etc.
        
        // Créer l'icône du marqueur avec la couleur calculée
        BitmapDescriptor markerIcon = BitmapDescriptor.defaultMarkerWithHue(markerHue);
        
        // Log pour confirmer création du marqueur avec informations détaillées
        print("✅ Marqueur créé pour: $name avec catégorie: $category (index: $entityIndex, hue: $markerHue, z-index: $zIndex)");
        
        // Créer le marqueur avec tous les paramètres nécessaires pour garantir visibilité et séparation
        Marker marker = Marker(
          markerId: MarkerId(id),
          position: LatLng(lat, lon),
          icon: markerIcon,
          visible: true,
          flat: entityIndex % 2 == 0, // Alterner entre flat true/false pour éviter superposition visuelle
          alpha: 1.0, // Complètement opaque
          zIndex: zIndex, // Z-index unique beaucoup plus élevé
          anchor: const Offset(0.5, 1.0), // Ancrage standard pour les marqueurs Google
          consumeTapEvents: true, // Assure que les taps sont bien capturés
          infoWindow: InfoWindow(
            title: name,
            snippet: isProducers 
                ? entity['description']?.toString().substring(0, math.min(50, (entity['description']?.toString().length ?? 0))) ?? 'Pas de description'
                : entity['catégorie'] ?? 'Pas de catégorie',
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
      appBar: AppBar(
        title: const Text('Carte des Loisirs'),
        centerTitle: true,
        actions: [
          // Bouton de filtres rapides
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Filtres rapides',
            onPressed: () => _showQuickFilterDialog(context),
          ),
          // Bouton d'aide
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'Aide',
            onPressed: () => _showHelpDialog(context),
          ),
          // Bouton stylisé pour basculer vers la carte des restaurants
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.restaurant),
                  SizedBox(width: 4),
                  Text(
                    "Restos",
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              tooltip: 'Carte des restaurants',
              onPressed: () {
                // Animation de transition
                Navigator.of(context).push(
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) => const MapScreen(),
                    transitionsBuilder: (context, animation, secondaryAnimation, child) {
                      var begin = const Offset(1.0, 0.0);
                      var end = Offset.zero;
                      var curve = Curves.easeInOut;
                      var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                      return SlideTransition(
                        position: animation.drive(tween),
                        child: child,
                      );
                    },
                    transitionDuration: const Duration(milliseconds: 400),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      body: PopScope(
        // Empêche de fermer l'application en appuyant sur retour
        canPop: false,
        child: Stack(
          children: [
            // Carte avec animation du panneau de critères
            Stack(
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
                    
                    // Appliquer un style personnalisé à la carte
                    _setMapStyle(controller);
                    
                    // Afficher un guide visuel pour les critères après un court délai
                    Future.delayed(const Duration(seconds: 1), () {
                      if (mounted) {
                        _showFilterHintTooltip();
                      }
                    });
                    
                    // Charger les marqueurs si ce n'est pas déjà fait
                    if (_markers.isEmpty && _shouldShowMarkers) {
                      _fetchNearbyProducers(_initialPosition.latitude, _initialPosition.longitude);
                    }
                  },
                  onTap: (position) {
                    // Fermer le panneau de filtres si ouvert et permettre le déplacement
                    if (_isFilterPanelVisible && !_isPanelAnimating) {
                      setState(() {
                        _isPanelAnimating = true;
                        
                        // Animation de fermeture douce
                        Future.delayed(const Duration(milliseconds: 300), () {
                          if (mounted) {
                            setState(() {
                              _isFilterPanelVisible = false;
                              _isPanelAnimating = false;
                            });
                          }
                        });
                      });
                    }
                    
                    // Permettre le déplacement sur la carte en tapant
                    if (_mapController != null) {
                      _mapController!.animateCamera(
                        CameraUpdate.newLatLng(position),
                      );
                    }
                  },
                ),
                
                // Panneau de filtres avec animation améliorée
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutQuint,
                  left: _isFilterPanelVisible ? 0 : -MediaQuery.of(context).size.width,
                  top: 0,
                  bottom: 0,
                  width: MediaQuery.of(context).size.width * 0.85,
                  child: _isFilterPanelVisible || _isPanelAnimating 
                    ? _buildFilterPanel() 
                    : const SizedBox.shrink(),
                ),
              ],
            ),
            
            // Indicateur de chargement amélioré
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
              
            // Bulle informative indiquant où trouver les critères - seulement si pas encore vue
            if (!_hasShownFilterHint)
              Positioned(
                top: 80,
                left: 60,
                child: AnimatedOpacity(
                  opacity: _isFilterPanelVisible ? 0.0 : 1.0,
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.arrow_back, color: Colors.white, size: 16),
                        SizedBox(width: 6),
                        Text(
                          "Cliquez ici pour les critères",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            
            // Bouton pour afficher les lieux si pas encore chargés ou si une erreur s'est produite
            if (_markers.isEmpty && !_isLoading && _isMapReady)
              Positioned(
                bottom: 80,
                left: 0,
                right: 0,
                child: Center(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text("Actualiser les lieux"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                      elevation: 4,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    onPressed: () {
                      // Toujours activer l'affichage des marqueurs
                      setState(() {
                        _shouldShowMarkers = true;
                      });
                      _fetchNearbyProducers(_initialPosition.latitude, _initialPosition.longitude);
                    },
                  ),
                ),
              ),
              
            // Message de diagnostic si aucun marqueur n'est affiché après chargement
            if (_markers.isEmpty && !_isLoading && _shouldShowMarkers)
              Positioned(
                top: 150,
                left: 20,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.orange.shade800),
                          const SizedBox(width: 8),
                          const Text(
                            "Aucun lieu trouvé",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Essayez d'augmenter le rayon de recherche ou de modifier les filtres pour voir plus de résultats.",
                        style: TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _selectedRadius = 10000; // Augmenter le rayon à 10km
                              });
                              _fetchNearbyProducers(_initialPosition.latitude, _initialPosition.longitude);
                            },
                            child: const Text("AUGMENTER LE RAYON"),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            
            // Légende des couleurs - redessinée avec un style moderne
            Positioned(
              top: 80,
              right: 16,
              child: AnimatedOpacity(
                opacity: _markers.isEmpty ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 500),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // En-tête avec badge moderne
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.purple.shade400, Colors.purple.shade700],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              "Correspondance",
                              style: TextStyle(
                                fontWeight: FontWeight.bold, 
                                fontSize: 12,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              // Afficher un petit popup d'information sur la correspondance
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Les couleurs indiquent le niveau de correspondance avec vos critères"),
                                  duration: Duration(seconds: 3),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.info_outline, size: 16, color: Colors.grey.shade700),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Items de légende avec design amélioré
                      _buildLegendItem(Colors.green, "Élevé"),
                      const SizedBox(height: 4),
                      _buildLegendItem(Colors.orange, "Moyen"),
                      const SizedBox(height: 4),
                      _buildLegendItem(Colors.red, "Faible"),
                    ],
                  ),
                ),
              ),
            ),
            
              // Bouton flottant pour les critères avec badge de notification et animation
              Positioned(
                top: 16,
                left: 16,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  transform: Matrix4.translationValues(
                    _isFilterPanelVisible ? 20 : 0, 
                    0, 
                    0
                  ),
                  child: FloatingActionButton(
                    mini: true,
                    backgroundColor: _isFilterPanelVisible 
                      ? Colors.purple.withOpacity(0.8) 
                      : Colors.white,
                    foregroundColor: _isFilterPanelVisible 
                      ? Colors.white 
                      : Colors.purple,
                    elevation: _isFilterPanelVisible ? 0 : 4,
                    heroTag: "filterBtn",
                    child: Stack(
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: _isFilterPanelVisible
                            ? const Icon(Icons.arrow_back, key: ValueKey('back'))
                            : const Icon(Icons.filter_list, key: ValueKey('filter')),
                        ),
                        if (!_isFilterPanelVisible && (_selectedProducerCategory != null || _selectedEventCategory != null || _selectedEmotions.isNotEmpty))
                          Positioned(
                            right: 0,
                            top: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.purple,
                              ),
                              child: Text(
                                _getActiveFiltersCount().toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    onPressed: () {
                      if (!_isPanelAnimating) {
                        setState(() {
                          _isPanelAnimating = true;
                          _isFilterPanelVisible = !_isFilterPanelVisible;
                          
                          // Remettre le flag d'animation à false après un délai 
                          // pour éviter les clics multiples pendant l'animation
                          Future.delayed(const Duration(milliseconds: 300), () {
                            if (mounted) {
                              setState(() {
                                _isPanelAnimating = false;
                              });
                            }
                          });
                        });
                      }
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
      
      // Boutons d'action flottants - redessinés et groupés avec clarification
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
            // Bouton pour rafraîchir les données avec étiquette
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ],
              ),
              child: FloatingActionButton.extended(
                heroTag: "refreshLeisureBtn",
                backgroundColor: Colors.deepPurple, // Couleur distincte
                foregroundColor: Colors.white,
                icon: const Icon(Icons.refresh),
                label: const Text("Recharger", style: TextStyle(fontSize: 12)),
                onPressed: () {
                  setState(() {
                    _markers.clear(); // Vider les marqueurs existants avant d'en ajouter de nouveaux
                    _shouldShowMarkers = true; // S'assurer que les marqueurs seront visibles
                  });
                  _fetchNearbyProducers(_initialPosition.latitude, _initialPosition.longitude);
                  _showSnackBar("Chargement des lieux en cours...");
                },
              ),
            ),
          // Bouton pour la position actuelle
          Container(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                )
              ],
            ),
            child: FloatingActionButton(
              backgroundColor: Colors.white,
              foregroundColor: Colors.purple,
              heroTag: "locateLeisureBtn",
              child: const Icon(Icons.my_location),
              onPressed: () {
                if (_mapController != null) {
                  _mapController!.animateCamera(
                    CameraUpdate.newLatLngZoom(_initialPosition, 12.0),
                  );
                }
              },
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
          const Text(
            "Catégorie lieu",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
          
          // Notes minimales pour l'événement - en utilisant des sliders plus stylisés
          const Text(
            "Notes minimales",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  _buildRatingSlider("Mise en scène", _minMiseEnScene, (value) {
                    setState(() => _minMiseEnScene = value);
                  }),
                  const Divider(),
                  _buildRatingSlider("Jeu d'acteurs", _minJeuActeurs, (value) {
                    setState(() => _minJeuActeurs = value);
                  }),
                  const Divider(),
                  _buildRatingSlider("Scénario", _minScenario, (value) {
                    setState(() => _minScenario = value);
                  }),
                ],
              ),
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
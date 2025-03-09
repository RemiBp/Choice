import 'dart:isolate';
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb, compute;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'producerLeisure_screen.dart';
import 'eventLeisure_screen.dart';
import 'utils.dart';
import '../widgets/maps/adaptive_map_widget.dart';
import 'map_screen.dart'; // Importer la carte des restaurants

class MapLeisureScreen extends StatefulWidget {
  const MapLeisureScreen({Key? key}) : super(key: key);

  @override
  _MapLeisureScreenState createState() => _MapLeisureScreenState();
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
  BitmapDescriptor? _customMarkerIcon;

  @override
  void initState() {
    super.initState();
    _loadCustomMarkerIcon();
    
    // Initialiser l'écouteur pour les calculs d'arrière-plan
    _receivePort.listen((data) {
      if (data is List<dynamic> && data.isNotEmpty && data[0] == 'markers') {
        setState(() {
          _markers = Set<Marker>.from(data[1]);
          _isComputingMarkers = false;
        });
      }
    });
    
    // Charger automatiquement les données après un court délai
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _fetchNearbyProducers(_initialPosition.latitude, _initialPosition.longitude);
      }
    });
  }
  
  @override
  void dispose() {
    _receivePort.close();
    _mapController?.dispose();
    super.dispose();
  }

  /// Charger une icône personnalisée pour les marqueurs
  Future<void> _loadCustomMarkerIcon() async {
    // Utiliser des marqueurs colorés par catégorie pour une meilleure distinction visuelle
    _customMarkerIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet);
    print("✅ Icône de marqueur personnalisée chargée avec teinte violette par défaut");
  }
  
  /// Calculer une couleur de marqueur en fonction du score
  double _getColorBasedOnScore(double score) {
    // Utiliser un dégradé de couleurs plus visible:
    // 0.0 (faible) = Rouge (0)
    // 0.5 (moyen) = Jaune (60)
    // 1.0 (excellent) = Vert (120)
    return (score * 120).clamp(0.0, 120.0);
  }
  
  /// Traitement des marqueurs en arrière-plan
  void _processMarkers(List<dynamic> entities, bool isProducers) {
    if (_isComputingMarkers) return;
    _isComputingMarkers = true;
    
    if (kIsWeb) {
      // En Web, créer les marqueurs directement
      Set<Marker> newMarkers = _createMarkers(entities, isProducers);
      setState(() {
        _markers = newMarkers;
        _isComputingMarkers = false;
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
        final double lon = coordinates[0].toDouble();
        final double lat = coordinates[1].toDouble();
        
        // Vérifier que les coordonnées sont dans les limites valides
        if (lat < -90 || lat > 90 || lon < -180 || lon > 180) {
          print('❌ Coordonnées invalides: hors limites (lat: $lat, lon: $lon)');
          continue;
        }
        
        final String id = entity['_id'];
        final String name = isProducers
            ? entity['lieu'] ?? 'Sans nom'
            : entity['intitulé'] ?? 'Événement sans nom';
        
        // Assigner un score de pertinence basé sur les filtres (simpliste pour l'instant)
        double score = 0.5; // score par défaut moyen
        
        if (isProducers) {
          // Score pour les producteurs de loisirs
          if (_selectedProducerCategory != null && 
              entity['catégorie'] == _selectedProducerCategory) {
            score += 0.3;
          }
          
          // Ajouter d'autres critères pour améliorer le score
          final double rating = entity['rating'] != null ? 
              (entity['rating'] / 5.0).clamp(0.0, 1.0) : 0.5;
          score = (score + rating) / 2;
        } else {
          // Score pour les événements
          if (_selectedEventCategory != null && 
              entity['catégorie'] == _selectedEventCategory) {
            score += 0.3;
          }
          
          if (_selectedEmotions.isNotEmpty && entity['emotions'] != null) {
            final List<dynamic> eventEmotions = entity['emotions'];
            int matchCount = 0;
            for (var emotion in _selectedEmotions) {
              if (eventEmotions.contains(emotion)) {
                matchCount++;
              }
            }
            if (matchCount > 0) {
              score += 0.2 * (matchCount / _selectedEmotions.length);
            }
          }
        }
        
        // Définir la couleur en fonction de la catégorie
        double markerHue = BitmapDescriptor.hueViolet; // Couleur par défaut
        
        // Attribution des couleurs par catégorie
        String category = isProducers 
            ? entity['catégorie']?.toString().toLowerCase() ?? ''
            : entity['catégorie']?.toString().toLowerCase() ?? '';
            
        if (category.contains('théâtre') || category.contains('theatre')) {
          markerHue = BitmapDescriptor.hueRed;
        } else if (category.contains('musiqu') || category.contains('concert')) {
          markerHue = BitmapDescriptor.hueAzure;
        } else if (category.contains('ciném') || category.contains('cinema')) {
          markerHue = BitmapDescriptor.hueOrange;
        } else if (category.contains('danse')) {
          markerHue = BitmapDescriptor.hueGreen;
        }
        
        BitmapDescriptor markerIcon = BitmapDescriptor.defaultMarkerWithHue(markerHue);
        
        // Log pour confirmer création du marqueur avec couleur par catégorie
        print("✅ Marqueur créé pour: $name avec catégorie: $category (teinte: $markerHue)");
        
        // Créer un marqueur avec visibilité et z-index explicites
        Marker marker = Marker(
          markerId: MarkerId(id),
          position: LatLng(lat, lon),
          icon: markerIcon, // Utiliser un marqueur coloré par catégorie
          visible: true, // Explicitement marquer comme visible
          zIndex: 10.0, // S'assurer que le marqueur est au-dessus des autres éléments
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
                        if (entity['rating'] != null)
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
                                  "${entity['rating'].toStringAsFixed(1)}",
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
                  // Type de contenu (Producteur ou Événement)
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: themeColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isProducer ? "Lieu" : "Événement",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
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
                    
                    // Catégorie avec puce stylisée
                    if (entity['catégorie'] != null) ...[
                      Wrap(
                        spacing: 6,
                        children: [
                          Chip(
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
  
  /// Fonction statique pour créer les marqueurs en arrière-plan
  static void _createMarkersInBackground(Map<String, dynamic> params) {
    final List<dynamic> entities = params['entities'];
    final bool isProducers = params['isProducers'];
    final SendPort sendPort = params['port'];
    
    Set<Marker> markers = {};
    
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
        }
        
        BitmapDescriptor markerIcon = BitmapDescriptor.defaultMarkerWithHue(markerHue);
        
        // Log pour confirmer création du marqueur avec couleur par catégorie
        print("✅ Marqueur créé pour arrière-plan avec catégorie: $category (teinte: $markerHue)");
        
        Marker marker = Marker(
          markerId: MarkerId(id),
          position: LatLng(lat, lon),
          icon: markerIcon,
          visible: true, // Explicitement marquer comme visible
          zIndex: 10.0, // S'assurer que le marqueur est au-dessus des autres éléments
          infoWindow: InfoWindow(
            title: isProducers
                ? entity['lieu'] ?? 'Sans nom'
                : entity['intitulé'] ?? 'Événement sans nom',
            snippet: isProducers 
                ? entity['description'] ?? 'Pas de description'
                : entity['catégorie'] ?? 'Pas de catégorie',
          ),
        );
        
        markers.add(marker);
      } catch (e) {
        // Ignorer les erreurs silencieusement en arrière-plan
      }
    }
    
    sendPort.send(['markers', markers]);
  }

  /// Appliquer les filtres de producteurs
  void _applyProducerFilters() {
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

        Set<Marker> newMarkers = {};
        int validMarkersCount = 0;
        
        for (var producer in producers) {
          try {
            // Vérification que location et coordinates existent et sont valides
            if (producer['location'] == null || producer['location']['coordinates'] == null) {
              print('❌ Coordonnées manquantes pour un producteur: ${producer['_id']}');
              continue;
            }
            
            final List? coordinates = producer['location']['coordinates'];
            
            // Vérifier que coordinates est une liste avec au moins 2 éléments
            if (coordinates == null || coordinates.length < 2 || producer['_id'] == null) {
              print('❌ Coordonnées incomplètes ou ID manquant: ${producer['_id']}');
              continue;
            }
            
            // Vérifier que les coordonnées sont numériques
            if (coordinates[0] == null || coordinates[1] == null || 
                !(coordinates[0] is num) || !(coordinates[1] is num)) {
              print('❌ Coordonnées invalides (non numériques): ${producer['_id']}');
              continue;
            }
            
            // Convertir en double de manière sécurisée
            final double lon = coordinates[0].toDouble();
            final double lat = coordinates[1].toDouble();
            
            // Vérification moins stricte des limites (certaines coordonnées peuvent être légèrement hors limites)
            if (lat < -90 || lat > 90 || lon < -180 || lon > 180) {
              print('⚠️ Coordonnées hors limites standards mais on continue: (lat: $lat, lon: $lon)');
              // On continue quand même car certaines coordonnées peuvent être légèrement hors limites
            }
            
            // Vérification si le lieu a un nom
            final String name = producer['lieu'] ?? 'Lieu sans nom';
            print("✅ Ajout du marqueur: $name (lat: $lat, lon: $lon)");
            
            // Définir la couleur en fonction de la catégorie
            double markerHue = BitmapDescriptor.hueViolet; // Couleur par défaut
            
            // Attribution des couleurs par catégorie
            String category = producer['catégorie']?.toString().toLowerCase() ?? '';
            if (category.contains('théâtre') || category.contains('theatre')) {
              markerHue = BitmapDescriptor.hueRed;
            } else if (category.contains('musiqu') || category.contains('concert')) {
              markerHue = BitmapDescriptor.hueAzure;
            } else if (category.contains('ciném') || category.contains('cinema')) {
              markerHue = BitmapDescriptor.hueOrange;
            } else if (category.contains('danse')) {
              markerHue = BitmapDescriptor.hueGreen;
            }
            
            BitmapDescriptor markerIcon = BitmapDescriptor.defaultMarkerWithHue(markerHue);
            
            // Log pour confirmer création du marqueur avec couleur par catégorie
            print("✅ Marqueur créé pour: $name avec catégorie: $category (teinte: $markerHue)");
            
            newMarkers.add(Marker(
              markerId: MarkerId(producer['_id']),
              position: LatLng(lat, lon),
              icon: markerIcon,
              visible: true, // Explicitement marquer comme visible
              zIndex: 10.0, // S'assurer que le marqueur est au-dessus des autres éléments
              onTap: () {
                // Afficher une carte de détail au-dessus du marqueur
                _showEntityQuickView(context, producer, true, producer['_id']);
                
                // Gérer le double-tap pour navigation directe
                if (_lastTappedMarkerId == producer['_id']) {
                  // Double tap détecté - naviguer vers la page détaillée
                  _navigateToProducerDetails(producer);
                  setState(() {
                    _lastTappedMarkerId = null;
                  });
                } else {
                  // Premier tap - enregistrer l'ID
                  setState(() {
                    _lastTappedMarkerId = producer['_id'];
                  });
                  
                  // Annuler après un délai si pas de second tap
                  Future.delayed(const Duration(seconds: 3), () {
                    if (mounted && _lastTappedMarkerId == producer['_id']) {
                      setState(() {
                        _lastTappedMarkerId = null;
                      });
                    }
                  });
                }
              },
            ));
            validMarkersCount++;
          } catch (e) {
            print("❌ Erreur lors de la création du marqueur: $e");
          }
        }
        
        print("✅ Nombre de marqueurs valides créés: $validMarkersCount");
        
        setState(() {
          _markers = newMarkers;
        });
        
        // Si des marqueurs ont été créés mais ne sont pas visibles sur la carte,
        // ajuster le niveau de zoom pour les voir tous
        if (validMarkersCount > 0 && _mapController != null) {
          _fitMarkersOnMap();
        }
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

        // Gestion des multiples événements au même endroit
        Map<LatLng, List<dynamic>> eventsGroupedByLocation = {};

        for (var event in events) {
          final coordinates = LatLng(event['location']['coordinates'][1], event['location']['coordinates'][0]);
          if (!eventsGroupedByLocation.containsKey(coordinates)) {
            eventsGroupedByLocation[coordinates] = [];
          }
          eventsGroupedByLocation[coordinates]!.add(event);
        }

        setState(() {
          _markers = eventsGroupedByLocation.entries.map((entry) {
            final LatLng position = entry.key;
            final List<dynamic> groupedEvents = entry.value;

            // Définir la couleur en fonction de la catégorie
            double markerHue = BitmapDescriptor.hueViolet; // Couleur par défaut
            
            // Récupérer la catégorie du premier événement du groupe
            String category = groupedEvents.first['catégorie']?.toString().toLowerCase() ?? '';
            
            // Attribution des couleurs par catégorie
            if (category.contains('théâtre') || category.contains('theatre')) {
              markerHue = BitmapDescriptor.hueRed;
            } else if (category.contains('musiqu') || category.contains('concert')) {
              markerHue = BitmapDescriptor.hueAzure;
            } else if (category.contains('ciném') || category.contains('cinema')) {
              markerHue = BitmapDescriptor.hueOrange;
            } else if (category.contains('danse')) {
              markerHue = BitmapDescriptor.hueGreen;
            }
            
            BitmapDescriptor markerIcon = BitmapDescriptor.defaultMarkerWithHue(markerHue);
            
            // Log pour confirmer création du marqueur avec couleur par catégorie
            print("✅ Marqueur créé pour événement: ${groupedEvents.first['intitulé']} avec catégorie: $category (teinte: $markerHue)");
            
            return Marker(
              markerId: MarkerId(groupedEvents.first['_id']),
              position: position,
              icon: markerIcon,
              visible: true, // Explicitement marquer comme visible
              zIndex: 10.0, // S'assurer que le marqueur est au-dessus des autres éléments
              onTap: () {
                // Afficher la vue rapide multi-événements
                if (groupedEvents.length == 1) {
                  _showEntityQuickView(context, groupedEvents.first, false, groupedEvents.first['_id']);
                  
                  // Gestion double-tap pour un seul événement
                  if (_lastTappedMarkerId == groupedEvents.first['_id']) {
                    _navigateToEventDetails(groupedEvents.first['_id']);
                    setState(() {
                      _lastTappedMarkerId = null;
                    });
                  } else {
                    setState(() {
                      _lastTappedMarkerId = groupedEvents.first['_id'];
                    });
                    Future.delayed(const Duration(seconds: 3), () {
                      if (mounted && _lastTappedMarkerId == groupedEvents.first['_id']) {
                        setState(() {
                          _lastTappedMarkerId = null;
                        });
                      }
                    });
                  }
                } else {
                  // Plusieurs événements au même endroit, montrer la liste
                  _showEventSelectionDialog(groupedEvents);
                }
              },
            );
          }).toSet();
        });
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

  // Indicateur de visibilité du panneau de filtres
  bool _isFilterPanelVisible = false;
  
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
  
  /// Met à jour la visibilité du panneau de filtres (appelé depuis AdaptiveMapWidget)
  void updateFilterPanelVisibility(bool isVisible) {
    setState(() {
      _isFilterPanelVisible = isVisible;
      
      // Si le panneau s'affiche, marquer qu'on a montré l'aide
      if (isVisible) {
        _hasShownFilterHint = true;
      }
    });
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
          // Bouton pour basculer vers la carte des restaurants
          IconButton(
            icon: const Icon(Icons.restaurant),
            tooltip: 'Carte des restaurants',
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const MapScreen()),
              );
            },
          ),
        ],
      ),
      body: PopScope(
        // Empêche de fermer l'application en appuyant sur retour
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
                setState(() {
                  if (_isFilterPanelVisible) {
                    _isFilterPanelVisible = false;
                  }
                });
                
                // Permettre le déplacement sur la carte en tapant
                if (_mapController != null) {
                  _mapController!.animateCamera(
                    CameraUpdate.newLatLng(position),
                  );
                }
              },
              filterPanel: _buildFilterPanel(), // Panneau de filtres latéral
            ),
            
            // Indicateur de chargement
            if (_isLoading)
              Container(
                color: Colors.black.withOpacity(0.3),
                child: const Center(
                  child: CircularProgressIndicator(),
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
                      children: [
                        const Icon(Icons.arrow_back, color: Colors.white, size: 16),
                        const SizedBox(width: 6),
                        const Text(
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
            
            // Légende des couleurs - repositionnée pour ne pas gêner les boutons de zoom
            Positioned(
              top: 80,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // En-tête avec titre et bouton
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Correspondance",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        InkWell(
                          onTap: () {
                            // Masquer la légende (à implémenter)
                          },
                          child: const Icon(Icons.info_outline, size: 16),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          width: 16,
                          height: 16,
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text("Élevé", style: TextStyle(fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          width: 16,
                          height: 16,
                          decoration: const BoxDecoration(
                            color: Colors.yellow,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text("Moyen", style: TextStyle(fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          width: 16,
                          height: 16,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text("Faible", style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      
      // Pas de barre de navigation en bas pour éviter le bandeau blanc
      // Boutons d'action flottants
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Bouton pour rafraîchir les données
          FloatingActionButton(
            mini: true,
            heroTag: "refreshLeisureBtn",
            child: const Icon(Icons.refresh),
            onPressed: () {
              _fetchNearbyProducers(_initialPosition.latitude, _initialPosition.longitude);
            },
          ),
          const SizedBox(height: 8),
          // Bouton pour la position actuelle
          FloatingActionButton(
            mini: true,
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
        ],
      ),
    );
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
  
  /// Construction du panneau de filtres avec onglets
  Widget _buildFilterPanel() {
    // Obtenir la hauteur d'écran pour définir une taille maximale
    final screenHeight = MediaQuery.of(context).size.height;
    
    return DefaultTabController(
      length: 2,
      child: Column(
        mainAxisSize: MainAxisSize.min, // Important: limiter la taille de la colonne
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // En-tête avec bouton fermer
          Container(
            color: Colors.purple,
            child: Row(
              children: [
                // Bouton fermer à gauche
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () {
                    setState(() {
                      _isFilterPanelVisible = false;
                    });
                  },
                ),
                // Titre des filtres
                const Expanded(
                  child: Center(
                    child: Text(
                      "Filtres",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
                // Bouton réinitialiser à droite
                TextButton.icon(
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
                ),
              ],
            ),
          ),
          // Onglets
          const TabBar(
            labelColor: Colors.purple,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.purple,
            tabs: [
              Tab(text: "Producteurs", icon: Icon(Icons.business)),
              Tab(text: "Événements", icon: Icon(Icons.event)),
            ],
          ),
          // Contenu des onglets avec hauteur contrainte
          SizedBox(
            height: screenHeight * 0.5, // Hauteur fixe qui correspond à 50% de l'écran
            child: TabBarView(
              children: [
                SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: _buildProducerFilters(),
                  ),
                ),
                SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: _buildEventFilters(),
                  ),
                ),
              ],
            ),
          ),
          // Bouton Appliquer
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.search),
              label: const Text('APPLIQUER LES FILTRES', style: TextStyle(fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                _applyProducerFilters();
                // Fermer le panneau après l'application des filtres
                setState(() {
                  _isFilterPanelVisible = false;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProducerFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Catégorie producteur",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ['Théâtre', 'Musique', 'Cinéma'].map((category) {
            return FilterChip(
              label: Text(category),
              selected: _selectedProducerCategory == category,
              onSelected: (selected) {
                setState(() {
                  _selectedProducerCategory = selected ? category : null;
                });
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        
        const Text(
          "Rayon de recherche",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        Slider(
          value: _selectedRadius,
          min: 1000,
          max: 50000,
          divisions: 49,
          label: "${_selectedRadius.round()} m",
          onChanged: (value) {
            setState(() {
              _selectedRadius = value;
            });
          },
        ),
        const SizedBox(height: 16),
        
        ElevatedButton.icon(
          onPressed: _applyProducerFilters,
          icon: const Icon(Icons.search),
          label: const Text('Rechercher des producteurs'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildEventFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Catégorie d'événement",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ['Théâtre', 'Musique', 'Danse'].map((category) {
            return FilterChip(
              label: Text(category),
              selected: _selectedEventCategory == category,
              onSelected: (selected) {
                setState(() {
                  _selectedEventCategory = selected ? category : null;
                });
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        
        // Notes minimales pour l'événement
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
        
        // Émotions recherchées
        const Text(
          "Émotions recherchées",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ['drôle', 'émouvant', 'haletant', 'intense', 'poignant', 'réfléchi', 'joyeux']
              .map((emotion) => FilterChip(
                    label: Text(emotion),
                    selected: _selectedEmotions.contains(emotion),
                    selectedColor: Colors.blue.withOpacity(0.7),
                    checkmarkColor: Colors.white,
                    onSelected: (isSelected) {
                      setState(() {
                        if (isSelected) {
                          _selectedEmotions.add(emotion);
                        } else {
                          _selectedEmotions.remove(emotion);
                        }
                      });
                    },
                  ))
              .toList(),
        ),
        const SizedBox(height: 16),
        
        // Prix
        const Text(
          "Gamme de prix (€)",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
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
        ),
        const SizedBox(height: 16),
        
        ElevatedButton.icon(
          onPressed: _applyEventFilters,
          icon: const Icon(Icons.search),
          label: const Text('Rechercher des événements'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          ),
        ),
      ],
    );
  }
  
  /// Widget pour les sliders de notation
  Widget _buildRatingSlider(String label, double value, Function(double) onChanged) {
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(label),
        ),
        Expanded(
          child: Slider(
            value: value,
            min: 0,
            max: 10,
            divisions: 10,
            label: value.toStringAsFixed(1),
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 40,
          child: Text(
            value > 0 ? value.toStringAsFixed(1) : "-",
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}
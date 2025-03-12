import 'dart:math'; // Nécessaire pour sin, cos, sqrt, atan2
import 'dart:typed_data'; // Pour Uint8List et ByteData
import 'dart:ui' as ui; // Pour Picture et ImageByteFormat
import 'dart:isolate'; // Pour traitement en arrière-plan
import 'dart:async'; // Pour les Completer
import 'package:flutter/foundation.dart' show kIsWeb, compute; // Pour la détection web et traitement parallèle
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'producer_screen.dart'; // Importer l'écran ProducerScreen
import 'package:flutter/services.dart'; // Nécessaire pour rootBundle
import 'utils.dart';
import '../widgets/maps/adaptive_map_widget.dart'; // Widget carte adaptatif
import 'map_leisure_screen.dart'; // Importer l'écran MapLeisureScreen

// Ajout de la classe MapScreen
class MapScreen extends StatefulWidget {
  const MapScreen({Key? key}) : super(key: key);

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with AutomaticKeepAliveClientMixin {
  // Déclarations des variables d'état globales
  Set<Marker> _markers = {}; // Contiendra les marqueurs affichés sur la carte
  bool _isLoading = false; // Pour indiquer si les données sont en cours de chargement
  bool _isMapReady = false; // Pour vérifier si la carte est prête
  final LatLng _initialPosition = const LatLng(48.8566, 2.3522); // Paris
  GoogleMapController? _mapController;
  String? _lastTappedMarkerId; // Stocke l'ID du dernier marqueur cliqué
  bool _isComputingMarkers = false; // Pour éviter les calculs simultanés
  bool _isFilterPanelVisible = false; // Pour contrôler la visibilité du panneau de filtres
  bool _hasShownFilterHint = false; // Pour savoir si l'utilisateur a déjà vu l'indicateur
  bool _shouldShowMarkers = false; // Contrôle l'affichage des marqueurs
  final ReceivePort _receivePort = ReceivePort(); // Pour communication avec isolate

  // Filtres Items
  String? _searchKeyword;
  double? _minCalories;
  double? _maxCalories;
  double? _maxCarbonFootprint;
  List<String> _selectedNutriScores = [];

  // Filtres Restaurants
  double? _minRating;
  double? _minServiceRating;
  double? _minLocationRating;
  double? _minPortionRating;
  double? _minAmbianceRating;
  String? _openingHours; // Format attendu : "Monday:10:00–14:00"
  TimeOfDay? _selectedTime; // Ajout de _selectedTime ici
  List<String> _selectedCategories = []; // Types de restaurants
  List<String> _selectedDishTypes = []; // Types de plats
  String? _choice; // Nouveau filtre
  int? _minFavorites; // Nouveau filtre
  double? _minPrice; // Nouveau filtre
  double? _maxPrice; // Nouveau filtre
  double? _minItemRating; // Nouveau filtre
  double? _maxItemRating; // Nouveau filtre

  // Rayon de recherche
  double _selectedRadius = 1500;
  
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    
    // Initialiser l'écouteur pour les calculs d'arrière-plan
    _receivePort.listen((data) {
      if (data is List<dynamic> && data.isNotEmpty && data[0] == 'markers') {
        setState(() {
          _markers = Set<Marker>.from(data[1]);
          _isComputingMarkers = false;
        });
      }
    });
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Ne pas charger les producteurs automatiquement
    // Attendre que l'utilisateur décide de le faire
    if (_isMapReady && _shouldShowMarkers && _markers.isEmpty) {
      // Utiliser Future.delayed pour s'assurer que le contexte est prêt
      Future.delayed(Duration.zero, () {
        if (mounted) {
          _fetchNearbyProducers(_initialPosition.latitude, _initialPosition.longitude);
        }
      });
    }
  }
  
  @override
  void dispose() {
    _receivePort.close();
    _mapController?.dispose();
    super.dispose();
  }

  double _convertColorToHue(Color color) {
    // Convertit une couleur RGB en teinte (hue)
    final int r = color.red;
    final int g = color.green;
    final int b = color.blue;

    double max = [r, g, b].reduce((a, b) => a > b ? a : b).toDouble();
    double min = [r, g, b].reduce((a, b) => a < b ? a : b).toDouble();

    double hue = 0.0;
    if (max == min) {
      hue = 0.0;
    } else if (max == r) {
      hue = (60 * ((g - b) / (max - min)) + 360) % 360;
    } else if (max == g) {
      hue = (60 * ((b - r) / (max - min)) + 120) % 360;
    } else if (max == b) {
      hue = (60 * ((r - g) / (max - min)) + 240) % 360;
    }

    return hue; // Retourne la teinte entre 0 et 360
  }


  /// Charger et créer les marqueurs avec traitement en arrière-plan
  void _setMarkerColorsByRank(List<Map<String, dynamic>> rankedProducers) async {
    print("🔍 Début de la création des marqueurs avec classement.");

    if (rankedProducers.isEmpty) {
      print("⚠️ Aucun producteur à afficher.");
      return;
    }
    
    // Eviter de lancer plusieurs calculs en parallèle
    if (_isComputingMarkers) return;
    _isComputingMarkers = true;
    
    // En Web, nous calculons directement dans le thread UI pour éviter des problèmes de compatibilité
    if (kIsWeb) {
      Set<Marker> newMarkers = await _createMarkersInUI(rankedProducers);
      setState(() {
        _markers = newMarkers;
        _isComputingMarkers = false;
      });
    } else {
      // Utilisation de compute pour le traitement en arrière-plan (mobile)
      compute(_createMarkersInBackground, {
        'producers': rankedProducers,
        'port': _receivePort.sendPort,
        'lastTappedMarkerId': _lastTappedMarkerId,
      });
    }
  }
  
  /// Créer les marqueurs directement dans l'UI (pour Web)
  Future<Set<Marker>> _createMarkersInUI(List<Map<String, dynamic>> producers) async {
    Set<Marker> markers = {};
    int totalProducers = producers.length;
    
    for (int i = 0; i < producers.length; i++) {
      final producer = producers[i];
      
      try {
        final List<dynamic>? coordinates = producer['gps_coordinates']?['coordinates'];
        final String? producerId = producer['_id'];
        final String producerName = producer['name'] ?? "Nom inconnu";
        
        if (coordinates == null || coordinates.length < 2 || producerId == null) {
          continue;
        }
        
        // Vérifier que les coordonnées sont numériques
        if (coordinates[0] == null || coordinates[1] == null || 
            !(coordinates[0] is num) || !(coordinates[1] is num)) {
          print('❌ Coordonnées invalides pour "${producerName}": valeurs non numériques');
          continue;
        }
        
        // Convertir en double de manière sécurisée
        final double lon = coordinates[0].toDouble();
        final double lat = coordinates[1].toDouble();
        
        // Vérifier que les coordonnées sont dans les limites valides
        if (lat < -90 || lat > 90 || lon < -180 || lon > 180) {
          print('❌ Coordonnées invalides pour "${producerName}": hors limites (lat: $lat, lon: $lon)');
          continue;
        }
        
        // Récupérer le score pour la couleur (score entre 0 et 1)
        double score = producer['score'] ?? 0.0;
        double markerHue = _getColorBasedOnScore(score);
        
        // Créer un marqueur plus visible et interactif
        final BitmapDescriptor customIcon = await _createCustomMarkerBitmap(
          producerName, 
          producer['rating']?.toDouble() ?? 0.0,
          markerHue
        );
        
        Marker marker = Marker(
          markerId: MarkerId(producerId),
          position: LatLng(lat, lon),
          icon: customIcon,
          alpha: 1.0, // Assurer une opacité complète
          zIndex: 2.0, // Mettre au-dessus des autres éléments
          consumeTapEvents: true, // Capture les taps correctement
          onTap: () {
            // Afficher une carte de détail au-dessus du marqueur
            _showProducerQuickView(context, producer);
            
            // Enregistrer l'ID pour un éventuel double-tap
            if (_lastTappedMarkerId == producerId) {
              _navigateToProducerDetails(producerId);
              _lastTappedMarkerId = null;
            } else {
              setState(() {
                _lastTappedMarkerId = producerId;
              });
              
              // Annuler le dernier identifiant après un délai
              Future.delayed(const Duration(seconds: 3), () {
                if (mounted && _lastTappedMarkerId == producerId) {
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
        print("❌ Erreur lors de la création du marqueur : $e");
      }
    }
    
    return markers;
  }
  
  /// Fonction statique pour créer les marqueurs en arrière-plan (pour mobile)
  static void _createMarkersInBackground(Map<String, dynamic> params) {
    final List<Map<String, dynamic>> producers = params['producers'];
    final SendPort sendPort = params['port'];
    final String? lastTappedMarkerId = params['lastTappedMarkerId'];
    
    Set<Marker> markers = {};
    
    if (producers.isEmpty) {
      sendPort.send(['markers', markers]);
      return;
    }
    
    int totalProducers = producers.length;
    
    for (int i = 0; i < producers.length; i++) {
      final producer = producers[i];
      
      try {
        final List<dynamic>? coordinates = producer['gps_coordinates']?['coordinates'];
        final String? producerId = producer['_id'];
        final String producerName = producer['name'] ?? "Nom inconnu";
        
        if (coordinates == null || coordinates.length < 2 || producerId == null) {
          continue;
        }
        
        // Vérifier que les coordonnées sont numériques
        if (coordinates[0] == null || coordinates[1] == null || 
            !(coordinates[0] is num) || !(coordinates[1] is num)) {
          // En arrière-plan, on ignore silencieusement les erreurs
          continue;
        }
        
        // Convertir en double de manière sécurisée
        final double lon = coordinates[0].toDouble();
        final double lat = coordinates[1].toDouble();
        
        // Vérifier que les coordonnées sont dans les limites valides
        if (lat < -90 || lat > 90 || lon < -180 || lon > 180) {
          // En arrière-plan, on ignore silencieusement les erreurs
          continue;
        }
        
        // Utiliser directement la teinte (fonction statique nécessaire)
        double normalizedRank = (i / totalProducers).clamp(0.0, 1.0);
        double markerHue = 120 * (1.0 - normalizedRank);
        
        Marker marker = Marker(
          markerId: MarkerId(producerId),
          position: LatLng(lat, lon),
          icon: BitmapDescriptor.defaultMarkerWithHue(markerHue),
          infoWindow: InfoWindow(
            title: producerName,
            snippet: "Note : ${producer['rating']?.toStringAsFixed(1) ?? 'N/A'}",
          ),
        );
        
        markers.add(marker);
        
      } catch (e) {
        // Les erreurs sont ignorées silencieusement en arrière-plan
      }
    }
    
    sendPort.send(['markers', markers]);
  }


  /// Calculer une couleur de marqueur en fonction du score
  double _getColorBasedOnScore(double score) {
    // Utiliser un dégradé de couleurs plus visible:
    // 0.0 (faible) = Rouge (0)
    // 0.5 (moyen) = Jaune (60)
    // 1.0 (excellent) = Vert (120)
    return (score * 120).clamp(0.0, 120.0);
  }
  
  /// Convertir une catégorie de restaurant en emoji
  String _getEmojiForCategory(String category) {
    category = category.toLowerCase();
    if (category.contains('italien') || category.contains('pizza')) {
      return '🍕';
    } else if (category.contains('français') || category.contains('francais')) {
      return '🥖';
    } else if (category.contains('japonais') || category.contains('sushi')) {
      return '🍣';
    } else if (category.contains('indien')) {
      return '🍛';
    } else if (category.contains('mexicain')) {
      return '🌮';
    } else if (category.contains('chinois')) {
      return '🥡';
    } else if (category.contains('thai') || category.contains('thaï')) {
      return '🍜';
    } else if (category.contains('burger') || category.contains('américain')) {
      return '🍔';
    } else if (category.contains('vegan') || category.contains('végé')) {
      return '🥗';
    } else if (category.contains('fast') || category.contains('rapide')) {
      return '🍟';
    } else if (category.contains('café') || category.contains('cafe')) {
      return '☕';
    } else if (category.contains('bar')) {
      return '🍺';
    } else if (category.contains('dessert') || category.contains('patisserie')) {
      return '🍰';
    } else {
      return '🍽️';
    }
  }
  
  /// Créer une image bitmap personnalisée pour le marqueur
  Future<BitmapDescriptor> _createCustomMarkerBitmap(String name, double rating, double hue) async {
    // Utiliser le marqueur par défaut avec la teinte appropriée
    return BitmapDescriptor.defaultMarkerWithHue(hue);
  }
  
  /// Afficher une carte de détail rapide au-dessus du marqueur
  void _showProducerQuickView(BuildContext context, Map<String, dynamic> producer) {
    // Obtenir l'image du restaurant avec une image de secours de qualité
    final String imageUrl = producer['photo'] ?? 
                           producer['image'] ?? 
                           'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=500&q=80';
    
    // Couleur thématique
    final Color themeColor = Colors.deepOrange;
    
    // Récupérer les catégories et les convertir en émojis
    List<String> categoryEmojis = [];
    if (producer['category'] != null && producer['category'] is List) {
      categoryEmojis = (producer['category'] as List)
          .map((cat) => _getEmojiForCategory(cat.toString()))
          .toList();
    }
    
    // Récupérer les types de plats et les convertir en émojis
    List<String> dishTypeEmojis = [];
    if (producer['dish_types'] != null && producer['dish_types'] is List) {
      dishTypeEmojis = (producer['dish_types'] as List)
          .take(5) // Limiter à 5 max
          .map((type) {
            String dishType = type.toString().toLowerCase();
            if (dishType.contains('viande')) return '🥩';
            if (dishType.contains('poisson')) return '🐟';
            if (dishType.contains('végé')) return '🥦';
            if (dishType.contains('pâtes') || dishType.contains('pasta')) return '🍝';
            if (dishType.contains('riz') || dishType.contains('rice')) return '🍚';
            if (dishType.contains('soupe')) return '🍲';
            if (dishType.contains('salad')) return '🥗';
            if (dishType.contains('dessert')) return '🍰';
            return '🍴';
          })
          .toList();
    }
    
    // Extraire les caractéristiques nutritionnelles
    List<String> nutritionEmojis = [];
    if (producer['nutriscores'] != null) {
      if (producer['nutriscores']['A'] != null) nutritionEmojis.add('🥗');
      if (producer['nutriscores']['B'] != null) nutritionEmojis.add('🥦');
    }
    if (producer['low_carbon'] == true) nutritionEmojis.add('🌱');
    if (producer['bio'] == true) nutritionEmojis.add('🌿');
    
    // Afficher la boîte de dialogue améliorée
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
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
                  // Nom et note du restaurant
                  Positioned(
                    bottom: 10,
                    left: 15,
                    right: 15,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            producer['name'] ?? "Restaurant",
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
                                "${producer['rating']?.toStringAsFixed(1) ?? 'N/A'}",
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
                  // Badge catégorie principale
                  if (categoryEmojis.isNotEmpty)
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
                        children: [
                          Text(
                            categoryEmojis.first,
                            style: const TextStyle(fontSize: 14),
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            "Restaurant",
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
                ],
              ),
              
              // Corps avec détails et émojis
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Adresse
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.location_on, size: 18, color: Colors.grey),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            producer['address'] ?? "Adresse non disponible",
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    // Catégories avec émojis
                    if (producer['category'] != null && producer['category'] is List && producer['category'].isNotEmpty) ...[
                      const Text(
                        "Type de cuisine :",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: List.generate(
                            producer['category']?.length ?? 0,
                            (index) {
                              final category = (producer['category'] as List)[index].toString();
                              final emoji = categoryEmojis[index < categoryEmojis.length ? index : 0];
                              
                              return Container(
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: themeColor.withOpacity(0.8),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(emoji, style: const TextStyle(fontSize: 16)),
                                    const SizedBox(width: 4),
                                    Text(
                                      category,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    
                    // Badge de correspondance si score élevé
                    if (producer['score'] != null && producer['score'] > 0.7) ...[
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
                            Icon(Icons.check_circle, color: Colors.green, size: 16),
                            SizedBox(width: 4),
                            Text(
                              "Match avec vos critères",
                              style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    
                    // Spécificités avec émojis
                    if (dishTypeEmojis.isNotEmpty || nutritionEmojis.isNotEmpty) ...[
                      const Text(
                        "Spécificités :",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            // Plats signature
                            ...dishTypeEmojis.map((emoji) => 
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        emoji,
                                        style: const TextStyle(fontSize: 24),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // Spécificités nutritionnelles
                            ...nutritionEmojis.map((emoji) => 
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withOpacity(0.1),
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
                    
                    // Notes détaillées
                    if (producer['notes_globales'] != null) ...[
                      const Text(
                        "Notes détaillées :",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildRatingItem("Service", producer['notes_globales']?['service'] ?? 0.0),
                          _buildRatingItem("Lieu", producer['notes_globales']?['lieu'] ?? 0.0),
                          _buildRatingItem("Portions", producer['notes_globales']?['portions'] ?? 0.0),
                          _buildRatingItem("Ambiance", producer['notes_globales']?['ambiance'] ?? 0.0),
                        ],
                      ),
                    ],
                    
                    const SizedBox(height: 16),
                    
                    // Bouton pour voir plus de détails
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.restaurant_menu),
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
                          _navigateToProducerDetails(producer['_id']);
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
  
  // Construire un widget d'étoiles de notation avec couleur par note
  Widget _buildRatingItem(String label, double rating) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: _getRatingColor(rating),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                rating.toStringAsFixed(1),
                style: TextStyle(
                  fontWeight: FontWeight.bold, 
                  fontSize: 12,
                  color: rating > 7.0 ? Colors.white : Colors.black87,
                ),
              ),
              Icon(
                Icons.star, 
                size: 12, 
                color: rating > 7.0 ? Colors.white : Colors.amber,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Obtenir une couleur en fonction de la note
  Color _getRatingColor(double rating) {
    if (rating >= 8.0) {
      return Colors.green;
    } else if (rating >= 6.0) {
      return Colors.lightGreen;
    } else if (rating >= 4.0) {
      return Colors.amber;
    } else if (rating >= 2.0) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  /// Récupérer les producteurs proches avec les filtres
  Future<void> _fetchNearbyProducers(double latitude, double longitude) async {
    setState(() {
      _isLoading = true; // Activer l'indicateur de chargement
    });

    try {
      // Construction des paramètres de requête
      final queryParameters = {
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'radius': _selectedRadius.toString(),
        if (_searchKeyword != null && _searchKeyword!.isNotEmpty) 'itemName': _searchKeyword,
        if (_minCalories != null) 'minCalories': _minCalories.toString(),
        if (_maxCalories != null) 'maxCalories': _maxCalories.toString(),
        if (_maxCarbonFootprint != null) 'maxCarbonFootprint': _maxCarbonFootprint.toString(),
        if (_selectedNutriScores.isNotEmpty) 'nutriScores': _selectedNutriScores.join(","),
        if (_minRating != null) 'minRating': _minRating.toString(),
        if (_minServiceRating != null) 'minServiceRating': _minServiceRating.toString(),
        if (_minLocationRating != null) 'minLocationRating': _minLocationRating.toString(),
        if (_minPortionRating != null) 'minPortionRating': _minPortionRating.toString(),
        if (_minAmbianceRating != null) 'minAmbianceRating': _minAmbianceRating.toString(),
        if (_openingHours != null) 'openingHours': _openingHours,
        if (_selectedCategories.isNotEmpty) 'categories': _selectedCategories.join(","),
        if (_selectedDishTypes.isNotEmpty) 'dishTypes': _selectedDishTypes.join(","),
        if (_choice != null) 'choice': _choice,
        if (_minFavorites != null) 'minFavorites': _minFavorites.toString(),
        if (_minPrice != null) 'minPrice': _minPrice.toString(),
        if (_maxPrice != null) 'maxPrice': _maxPrice.toString(),
        if (_minItemRating != null) 'minItemRating': _minItemRating.toString(),
        if (_maxItemRating != null) 'maxItemRating': _maxItemRating.toString(),
      };

      // Extraire le domaine et le protocole de l'URL complète
      final baseUrl = getBaseUrl();
      Uri uri;
      
      if (baseUrl.startsWith('http://')) {
        // Si c'est http://
        final domain = baseUrl.replaceFirst('http://', '');
        uri = Uri.http(domain, '/api/producers/nearby', queryParameters);
      } else if (baseUrl.startsWith('https://')) {
        // Si c'est https://
        final domain = baseUrl.replaceFirst('https://', '');
        uri = Uri.https(domain, '/api/producers/nearby', queryParameters);
      } else {
        // Utiliser Uri.parse comme solution de secours
        uri = Uri.parse('$baseUrl/api/producers/nearby').replace(queryParameters: queryParameters);
      }
      
      print("🔍 Requête envoyée : $uri");

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        print("📩 Réponse reçue : ${response.body}");

        final List<dynamic> producers = json.decode(response.body);

        if (producers.isEmpty) {
          _showSnackBar("Aucun résultat trouvé pour les critères de recherche.");
          print("⚠️ Aucun producteur trouvé.");
        } else {
          // Calculer la distance pour chaque producteur
          for (var producer in producers) {
            if (producer['gps_coordinates']?['coordinates'] != null) {
              double lat = (producer['gps_coordinates']['coordinates'][1] ?? 0).toDouble();
              double lon = (producer['gps_coordinates']['coordinates'][0] ?? 0).toDouble();
              double generalRating = (producer['rating'] ?? 0).toDouble();

              producer['distance'] = _calculateDistance(
                _initialPosition.latitude,
                _initialPosition.longitude,
                lat,
                lon,
              );
            }
          }

          // Classement des producteurs
          List<Map<String, dynamic>> rankedProducers = _rankProducers(
            producers.where((producer) {
              return producer['gps_coordinates'] != null &&
                  producer['gps_coordinates']['coordinates'] != null &&
                  producer['_id'] != null;
            }).map((producer) {
              return Map<String, dynamic>.from(producer);
            }).toList(),
          );

          // Mise à jour des marqueurs avec classement
          _setMarkerColorsByRank(rankedProducers);
          print("✅ Producteurs classés et marqueurs mis à jour.");
        }
      } else {
        print('❌ Erreur HTTP : Code ${response.statusCode}');
        _showSnackBar("Erreur lors de la récupération des producteurs.");
      }
    } catch (e) {
      print('❌ Erreur réseau : $e');
      if (e is http.ClientException) {
        _showSnackBar("Erreur réseau : vérifiez votre connexion ou l'URL du serveur.");
      } else {
        _showSnackBar("Erreur réseau inconnue. Veuillez réessayer.");
      }
    } finally {
      setState(() {
        _isLoading = false; // Désactiver l'indicateur de chargement
      });
    }
  }

  void _resetFilters() {
    setState(() {
      // Réinitialisation des filtres
      _searchKeyword = null;
      _minCalories = null;
      _maxCalories = null;
      _maxCarbonFootprint = null;
      _selectedNutriScores.clear();

      _minRating = null;
      _minServiceRating = null;
      _minLocationRating = null;
      _minPortionRating = null;
      _minAmbianceRating = null;
      _openingHours = null;
      _selectedTime = null;
      _selectedCategories.clear();
      _selectedDishTypes.clear();
      // Remove old category reference since we now use _selectedCategories
      _choice = null;
      _minFavorites = null;
      _minPrice = null;
      _maxPrice = null;
      _minItemRating = null;
      _maxItemRating = null;

      // Réinitialisation du rayon à la valeur par défaut
      _selectedRadius = 7000;

      print("✅ Tous les filtres ont été réinitialisés !");
    });
  }


  /// Naviguer vers la page de détail du producteur
  void _navigateToProducerDetails(String producerId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProducerScreen(producerId: producerId),
      ),
    );
  }

  /// Affiche une barre d'alerte pour les erreurs ou messages
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  /// Applique les filtres et relance la recherche
  void _applyFilters() {
    if (_isMapReady) {
      // Appliquer les filtres sans les réinitialiser
      _fetchNearbyProducers(_initialPosition.latitude, _initialPosition.longitude);
      _showSnackBar("Filtres appliqués et recherche mise à jour !");
      _isFilterPanelVisible = false; // Fermer le panneau de filtres après application
    } else {
      _showSnackBar("La carte n'est pas encore prête. Veuillez patienter.");
    }
  }


  Widget _buildItemFilters() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Filtres items",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16.0),

            // Recherche pour un item
            TextField(
              decoration: const InputDecoration(
                labelText: 'Rechercher un item',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _searchKeyword = value;
                });
              },
            ),
            const SizedBox(height: 16.0),

            // Note min (> )
            const Text("Note min (> ) :", style: TextStyle(fontWeight: FontWeight.bold)),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Min Note',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                setState(() {
                  _minItemRating = double.tryParse(value);
                });
              },
            ),
            const SizedBox(height: 16.0),
            // Calories min et max
            const Text("Calories max (< kcal) :", style: TextStyle(fontWeight: FontWeight.bold)),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Max Calories (kcal)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                setState(() {
                  _maxCalories = double.tryParse(value);
                });
              },
            ),
            const SizedBox(height: 16.0),

            // Prix max (< €)
            const Text("Prix max (< €) :", style: TextStyle(fontWeight: FontWeight.bold)),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Max Prix (€)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                setState(() {
                  _maxPrice = double.tryParse(value);
                });
              },
            ),
            const SizedBox(height: 16.0),

            // NutriScore
            const Text("NutriScore :", style: TextStyle(fontWeight: FontWeight.bold)),
            Wrap(
              spacing: 8.0,
              children: ["A", "B", "C", "D", "E"].map((score) {
                return ChoiceChip(
                  label: Text(score),
                  selected: _selectedNutriScores.contains(score),
                  onSelected: (isSelected) {
                    setState(() {
                      if (isSelected) {
                        if (!_selectedNutriScores.contains(score)) {
                          _selectedNutriScores.add(score);
                        }
                      } else {
                        _selectedNutriScores.remove(score);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16.0),

            // Bilan carbone
            const Text("Bilan carbone (< kg) :", style: TextStyle(fontWeight: FontWeight.bold)),
            DropdownButtonFormField<double>(
              value: _maxCarbonFootprint ?? 0.25,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: "Bilan carbone",
              ),
              items: List.generate(
                40,
                (index) => DropdownMenuItem<double>(
                  value: 0.25 * (index + 1),
                  child: Text("${(0.25 * (index + 1)).toStringAsFixed(2)} kg"),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _maxCarbonFootprint = value!;
                });
              },
            ),
            const SizedBox(height: 16.0),

            // Rayon de recherche
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Rayon de recherche (mètres):", style: TextStyle(fontWeight: FontWeight.bold)),
                Slider(
                  value: _selectedRadius,
                  min: 1000,
                  max: 50000,
                  divisions: 49,
                  label: _selectedRadius.round().toString(),
                  onChanged: (double value) {
                    setState(() {
                      _selectedRadius = value;
                    });
                  },
                ),
                Text("Rayon sélectionné : ${_selectedRadius.round()} m"),
              ],
            ),
            const SizedBox(height: 16.0),

            // Bouton Appliquer
            ElevatedButton.icon(
              onPressed: () {
                _applyFilters();
                _showFilters();
              },
              icon: const Icon(Icons.search),
              label: const Text('Appliquer les filtres items'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }


  /// Affiche les filtres sélectionnés
  void _showFilters() {
    print("Filters Selected:");
    print("Keyword: $_searchKeyword");
    print("Min Calories: $_minCalories");
    print("Max Calories: $_maxCalories");
    print("NutriScores: $_selectedNutriScores");
    print("Carbon Footprint: $_maxCarbonFootprint");
    print("Radius: $_selectedRadius");
  }

  Widget _buildRestaurantFilters() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Filtres restaurants",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16.0),
            
            // Catégories de restaurants
            const Text(
              "Restaurations",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8.0),
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: [
                'Restaurant', 'Fast-food', 'Brasserie', 'Pizzeria', 'Bistro', 'Café', 'Bar'
              ].map((category) {
                return FilterChip(
                  label: Text(category),
                  selected: _selectedCategories.contains(category),
                  selectedColor: Colors.blue.withOpacity(0.2),
                  onSelected: (isSelected) {
                    setState(() {
                      if (isSelected) {
                        _selectedCategories.add(category);
                      } else {
                        _selectedCategories.remove(category);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16.0),

            // Types de plats
            const Text(
              "Type de plat",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8.0),
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: [
                'Italien', 'Français', 'Japonais', 'Indien', 'Mexicain', 'Libanais', 
                'Végétarien', 'Végétalien', 'Américain', 'Chinois', 'Thaïlandais'
              ].map((dishType) {
                return FilterChip(
                  label: Text(dishType),
                  selected: _selectedDishTypes.contains(dishType),
                  selectedColor: Colors.green.withOpacity(0.2),
                  onSelected: (isSelected) {
                    setState(() {
                      if (isSelected) {
                        _selectedDishTypes.add(dishType);
                      } else {
                        _selectedDishTypes.remove(dishType);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16.0),

            // Sélection du jour et de l'heure
            const Text(
              "Jour et Heure",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      final String? day = await showDialog<String>(
                        context: context,
                        builder: (BuildContext context) {
                          return SimpleDialog(
                            title: const Text("Choisir un jour"),
                            children: [
                              SimpleDialogOption(
                                onPressed: () => Navigator.pop(context, "Lundi"),
                                child: const Text("Lundi"),
                              ),
                              SimpleDialogOption(
                                onPressed: () => Navigator.pop(context, "Mardi"),
                                child: const Text("Mardi"),
                              ),
                              SimpleDialogOption(
                                onPressed: () => Navigator.pop(context, "Mercredi"),
                                child: const Text("Mercredi"),
                              ),
                              SimpleDialogOption(
                                onPressed: () => Navigator.pop(context, "Jeudi"),
                                child: const Text("Jeudi"),
                              ),
                              SimpleDialogOption(
                                onPressed: () => Navigator.pop(context, "Vendredi"),
                                child: const Text("Vendredi"),
                              ),
                              SimpleDialogOption(
                                onPressed: () => Navigator.pop(context, "Samedi"),
                                child: const Text("Samedi"),
                              ),
                              SimpleDialogOption(
                                onPressed: () => Navigator.pop(context, "Dimanche"),
                                child: const Text("Dimanche"),
                              ),
                            ],
                          );
                        },
                      );

                      if (day != null) {
                        setState(() {
                          _openingHours = day; // Enregistrer le jour sélectionné
                        });
                      }
                    },
                    child: Text(
                      _openingHours != null ? _openingHours! : "Choisir un jour",
                    ),
                  ),
                ),
                const SizedBox(width: 8.0),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      final TimeOfDay? picked = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.now(),
                      );
                      if (picked != null) {
                        setState(() {
                          _selectedTime = picked; // Enregistrer l'heure sélectionnée
                        });
                      }
                    },
                    child: Text(
                      _selectedTime != null
                          ? _selectedTime!.format(context)
                          : "Choisir une heure",
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8.0),

            // Affichage des sélections
            if (_openingHours != null || _selectedTime != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  "Sélection : ${_openingHours ?? "Aucun jour"} à ${_selectedTime != null ? _selectedTime!.format(context) : "Aucune heure"}",
                  style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.blue),
                ),
              ),
            const SizedBox(height: 16.0),

            // Note générale
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Note générale >',
                      prefixIcon: Icon(Icons.star),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      setState(() {
                        _minRating = double.tryParse(value);
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16.0),

            // Notes spécifiques
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Service >',
                      prefixIcon: Icon(Icons.room_service),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      setState(() {
                        _minServiceRating = double.tryParse(value);
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8.0),
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Lieu >',
                      prefixIcon: Icon(Icons.location_on),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      setState(() {
                        _minLocationRating = double.tryParse(value);
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8.0),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Portions >',
                      prefixIcon: Icon(Icons.restaurant_menu),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      setState(() {
                        _minPortionRating = double.tryParse(value);
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8.0),
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Ambiance >',
                      prefixIcon: Icon(Icons.mood),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      setState(() {
                        _minAmbianceRating = double.tryParse(value);
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16.0),

            // Curseur pour ajuster le rayon
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Rayon de recherche (mètres):", style: TextStyle(fontWeight: FontWeight.bold)),
                Slider(
                  value: _selectedRadius,
                  min: 1000,
                  max: 50000,
                  divisions: 49,
                  label: _selectedRadius.round().toString(),
                  onChanged: (double value) {
                    setState(() {
                      _selectedRadius = value;
                    });
                  },
                ),
                Text("Rayon sélectionné : ${_selectedRadius.round()} m"),
              ],
            ),
            const SizedBox(height: 16.0),

            // Bouton Appliquer
            ElevatedButton.icon(
              onPressed: _applyFilters,
              icon: const Icon(Icons.search),
              label: const Text('Appliquer les filtres restaurants'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }


  // This is the required build method for Flutter's StatefulWidget pattern
  @override
  Widget build(BuildContext context) {
    // Required for AutomaticKeepAliveClientMixin - must be called first
    super.build(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Carte des Restaurants et Items'),
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
          // Bouton stylisé pour basculer vers la carte des loisirs
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.deepPurple.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.theater_comedy),
                  SizedBox(width: 4),
                  Text(
                    "Loisirs",
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              tooltip: 'Carte des loisirs et événements',
              onPressed: () {
                // Animation de transition
                Navigator.of(context).push(
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) => const MapLeisureScreen(),
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
        onPopInvoked: (didPop) {
          // Si le panneau de filtres est ouvert, on le ferme au lieu de quitter
          if (_isFilterPanelVisible) {
            setState(() {
              _isFilterPanelVisible = false;
            });
            return;
          }
          
          // Afficher un dialogue de confirmation
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text("Quitter la carte ?"),
              content: const Text("Voulez-vous vraiment quitter la carte ?"),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context), // Fermer le dialogue
                  child: const Text("Annuler"),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // Fermer le dialogue
                    Navigator.pop(context); // Retourner à l'écran précédent
                  },
                  child: const Text("Quitter"),
                ),
              ],
            ),
          );
        },
        child: Stack(
          children: [
            AdaptiveMapWidget(
              initialPosition: _initialPosition,
              initialZoom: 15.0,
              markers: _markers,
              onMapCreated: (GoogleMapController controller) {
                _mapController = controller;
                setState(() {
                  _isMapReady = true;
                });
                
                // Afficher un guide visuel pour les critères uniquement si pas encore vu
                if (!_hasShownFilterHint) {
                  Future.delayed(const Duration(seconds: 1), () {
                    if (mounted) {
                      _showFilterHintTooltip();
                    }
                  });
                }
                
                // Améliorer le style de la carte pour plus de lisibilité
                _setMapStyle(controller);
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
            
            // Bulle informative indiquant où trouver les critères - visible uniquement si pas encore vu
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
                      color: Colors.blue.withOpacity(0.9),
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Correspondance",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        // Bouton pour masquer la légende
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
            
            // Bouton pour afficher les lieux si pas encore chargés
            if (_markers.isEmpty && !_isLoading && _isMapReady)
              Positioned(
                bottom: 80,
                left: 0,
                right: 0,
                child: Center(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.place),
                    label: const Text("Afficher les lieux"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      elevation: 4,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    onPressed: () {
                      setState(() {
                        _shouldShowMarkers = true;
                      });
                      _fetchNearbyProducers(_initialPosition.latitude, _initialPosition.longitude);
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
      // Boutons d'action flottants
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Bouton pour rafraîchir les données
          FloatingActionButton(
            mini: true,
            heroTag: "refreshBtn",
            child: const Icon(Icons.refresh),
            onPressed: () {
              if (_isMapReady) {
                setState(() {
                  _shouldShowMarkers = true; // Assurez-vous que les marqueurs sont affichés après rafraîchissement
                });
                _fetchNearbyProducers(_initialPosition.latitude, _initialPosition.longitude);
              }
            },
          ),
          const SizedBox(height: 8),
          // Bouton pour la position actuelle
          FloatingActionButton(
            mini: true,
            heroTag: "locateBtn",
            child: const Icon(Icons.my_location),
            onPressed: () {
              if (_mapController != null) {
                _mapController!.animateCamera(
                  CameraUpdate.newLatLngZoom(_initialPosition, 15.0),
                );
              }
            },
          ),
        ],
      ),
      // Pas de barre de navigation en bas pour éviter le bandeau blanc
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
          // En-tête avec onglets et bouton fermer
          Container(
            color: Colors.blue,
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
                    _resetFilters();
                  },
                ),
              ],
            ),
          ),
          // Onglets
          const TabBar(
            labelColor: Colors.blue,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.blue,
            tabs: [
              Tab(text: "Items", icon: Icon(Icons.fastfood)),
              Tab(text: "Restaurants", icon: Icon(Icons.restaurant)),
            ],
          ),
          // Contenu des onglets avec hauteur contrainte
          SizedBox(
            height: screenHeight * 0.5, // Hauteur fixe qui correspond à 50% de l'écran
            child: TabBarView(
              children: [
                _buildItemFilters(),
                _buildRestaurantFilters(),
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
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _applyFilters,
            ),
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
            Text("• Le premier onglet permet de filtrer par items (plats, boissons, etc.)"),
            SizedBox(height: 4),
            Text("• Le deuxième onglet permet de filtrer par type de restaurant"),
            SizedBox(height: 4),
            Text("• Sélectionnez vos critères puis cliquez sur 'Appliquer'"),
            SizedBox(height: 4),
            Text("• Les lieux correspondants apparaîtront sur la carte"),
            SizedBox(height: 8),
            Text("• Cliquez sur un marqueur pour voir les détails du restaurant"),
            SizedBox(height: 4),
            Text("• Cliquez deux fois sur un marqueur pour visiter la page du restaurant"),
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
  
  /// Affiche un dialogue de filtres rapides
  void _showQuickFilterDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Filtres rapides"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.star, color: Colors.amber),
              title: const Text("Meilleures notes"),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _minRating = 4.0;
                });
                _applyFilters();
              },
            ),
            ListTile(
              leading: const Icon(Icons.eco, color: Colors.green),
              title: const Text("Écologique"),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _selectedNutriScores = ["A", "B"];
                  _maxCarbonFootprint = 0.5;
                });
                _applyFilters();
              },
            ),
            ListTile(
              leading: const Icon(Icons.fastfood, color: Colors.orange),
              title: const Text("Faibles calories"),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _maxCalories = 500;
                });
                _applyFilters();
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
  
  double _calculateDynamicScore(Map<String, dynamic> producer) {
    double score = 0.0;
    double totalWeight = 0.0;

    // Distance (pondération fixe de 30%)
    double distance = (producer['distance'] ?? 0).toDouble();
    if (distance > 0) {
      double distanceImpact = (1 - (distance / 10000)).clamp(0.0, 1.0);
      score += distanceImpact * 0.3;
      totalWeight += 0.3;
    }

    // Séparer les critères Restaurants et Items
    List<Map<String, dynamic>> restaurantCriteria = [];
    List<Map<String, dynamic>> itemCriteria = [];

    // 🏠 Critères Restaurants
    if (_minRating != null) {
      restaurantCriteria.add({'value': (producer['rating'] ?? 0).toDouble(), 'min': _minRating!});
    }
    if (_minLocationRating != null) {
      restaurantCriteria.add({'value': (producer['notes_globales']?['lieu'] ?? 0).toDouble(), 'min': _minLocationRating!});
    }
    if (_minServiceRating != null) {
      restaurantCriteria.add({'value': (producer['notes_globales']?['service'] ?? 0).toDouble(), 'min': _minServiceRating!});
    }
    if (_minPortionRating != null) {
      restaurantCriteria.add({'value': (producer['notes_globales']?['portion'] ?? 0).toDouble(), 'min': _minPortionRating!});
    }
    if (_minAmbianceRating != null) {
      restaurantCriteria.add({'value': (producer['notes_globales']?['ambiance'] ?? 0).toDouble(), 'min': _minAmbianceRating!});
    }

    // 🍽 Critères Items
    if (_minItemRating != null && _maxItemRating != null) {
      itemCriteria.add({'value': (producer['structured_data']?['Items Indépendants']?['items']?[0]?['note'] ?? 0).toDouble(),
                        'min': _minItemRating!, 'max': _maxItemRating!, 'isItem': true});
    }
    if (_minPrice != null) {
      itemCriteria.add({'value': (producer['structured_data']?['Items Indépendants']?['items']?[0]?['price'] ?? 0).toDouble(),
                        'max': _minPrice!, 'isPrice': true});
    }
    if (_maxCalories != null) {
      itemCriteria.add({'value': (producer['structured_data']?['Items Indépendants']?['items']?[0]?['calories'] ?? 0).toDouble(),
                        'max': _maxCalories!, 'isCalories': true});
    }
    if (_selectedNutriScores.isNotEmpty) {
      itemCriteria.add({'value': producer['structured_data']?['Items Indépendants']?['items']?[0]?['nutriscore'] ?? "E",
                        'allowed': _selectedNutriScores, 'isNutriScore': true});
    }
    if (_maxCarbonFootprint != null) {
      itemCriteria.add({'value': (producer['structured_data']?['Items Indépendants']?['items']?[0]?['carbon_footprint'] ?? 0).toDouble(),
                        'max': _maxCarbonFootprint!, 'isCarbon': true});
    }

    // Déterminer la répartition des 70% restants
    bool hasRestaurantCriteria = restaurantCriteria.isNotEmpty;
    bool hasItemCriteria = itemCriteria.isNotEmpty;

    double weightRestaurant = 0.0;
    double weightItem = 0.0;

    if (hasRestaurantCriteria && hasItemCriteria) {
      weightRestaurant = 0.35; // 35% pour Restaurants
      weightItem = 0.35; // 35% pour Items
    } else if (hasRestaurantCriteria) {
      weightRestaurant = 0.7; // 70% pour Restaurants uniquement
    } else if (hasItemCriteria) {
      weightItem = 0.7; // 70% pour Items uniquement
    }

    // Répartition équitable dans chaque catégorie
    double weightPerRestaurantCriterion = (restaurantCriteria.isNotEmpty) ? (weightRestaurant / restaurantCriteria.length) : 0.0;
    double weightPerItemCriterion = (itemCriteria.isNotEmpty) ? (weightItem / itemCriteria.length) : 0.0;

    // Calcul du score pour les critères Restaurants
    for (var criterion in restaurantCriteria) {
      double impact = ((criterion['value'] - criterion['min']) / (10 - criterion['min'])).clamp(0.0, 1.0);
      score += impact * weightPerRestaurantCriterion;
      totalWeight += weightPerRestaurantCriterion;
    }

    // Calcul du score pour les critères Items
    for (var criterion in itemCriteria) {
      double impact = 0.0;

      if (criterion.containsKey('isItem')) {
        impact = ((criterion['value'] - criterion['min']) / (criterion['max'] - criterion['min'])).clamp(0.0, 1.0);
      } else if (criterion.containsKey('isPrice') || criterion.containsKey('isCalories') || criterion.containsKey('isCarbon')) {
        impact = ((criterion['max'] - criterion['value']) / criterion['max']).clamp(0.0, 1.0);
      } else if (criterion.containsKey('isNutriScore')) {
        List<String> nutriOrder = ["A", "B", "C", "D", "E"];
        int scoreIndex = nutriOrder.indexOf(criterion['value']);
        int bestIndex = nutriOrder.indexOf(criterion['allowed'][0]); // On prend le meilleur NutriScore sélectionné
        impact = ((bestIndex - scoreIndex) / bestIndex).clamp(0.0, 1.0);
      }

      score += impact * weightPerItemCriterion;
      totalWeight += weightPerItemCriterion;
    }

    // Si aucun critère dynamique n'a été appliqué
    if (totalWeight == 0.0) {
      return 0.1; // Score par défaut
    }

    // Normalisation
    return (score / totalWeight).clamp(0.0, 1.0);
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000; // Rayon de la Terre en mètres
    double dLat = (lat2 - lat1) * (3.141592653589793 / 180.0);
    double dLon = (lon2 - lon1) * (3.141592653589793 / 180.0);
    double a = 
        (sin(dLat / 2) * sin(dLat / 2)) +
        cos(lat1 * (3.141592653589793 / 180.0)) *
            cos(lat2 * (3.141592653589793 / 180.0)) *
            (sin(dLon / 2) * sin(dLon / 2));
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  List<Map<String, dynamic>> _rankProducers(List<Map<String, dynamic>> producers) {
    // Calcul des scores
    List<Map<String, dynamic>> scoredProducers = producers.map((producer) {
      double score = _calculateDynamicScore(producer);
      return {
        ...producer,
        'score': score,
      };
    }).toList();

    // Trier les producteurs par score décroissant
    scoredProducers.sort((a, b) => b['score'].compareTo(a['score']));

    print("Classement des producteurs par score :");
    scoredProducers.asMap().forEach((index, producer) {
      print("Rang ${index + 1}: ${producer['name']} - Score: ${producer['score']}");
    });

    return scoredProducers;
  }
  
  /// Affiche une bulle d'aide pour guider l'utilisateur vers le panneau de filtres
  void _showFilterHintTooltip() {
    // Vérifier si le panneau de filtres est déjà visible
    if (!_isFilterPanelVisible) {
      // Afficher temporairement la bulle d'aide puis la masquer après quelques secondes
      setState(() {
        // La bulle s'affiche grâce au widget Positioned dans le build
      });
      
      // Masquer après un délai (l'animation se fait dans le widget)
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) {
          setState(() {
            // Indiquer que l'utilisateur a vu l'indicateur
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
        "featureType": "poi.business",
        "elementType": "geometry.fill",
        "stylers": [
          {
            "color": "#f0f7eb"
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
            "color": "#d3eaf8"
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
  dynamic noSuchMethod(Invocation invocation) {
    return super.noSuchMethod(invocation);
  }
}
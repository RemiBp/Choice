import 'dart:math'; // Nécessaire pour sin, cos, sqrt, atan2
import 'dart:typed_data'; // Pour Uint8List et ByteData
import 'dart:ui' as ui; // Pour Picture et ImageByteFormat
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'producer_screen.dart'; // Importer l'écran ProducerScreen
import 'package:flutter/services.dart'; // Nécessaire pour rootBundle
import 'utils.dart';

// Ajout de la classe MapScreen
class MapScreen extends StatefulWidget {
  const MapScreen({Key? key}) : super(key: key);

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // Déclarations des variables d'état globales
  Set<Marker> _markers = {}; // Contiendra les marqueurs affichés sur la carte
  bool _isLoading = false; // Pour indiquer si les données sont en cours de chargement
  bool _isMapReady = false; // Pour vérifier si la carte est prête
  final LatLng _initialPosition = const LatLng(48.8566, 2.3522); // Paris
  late GoogleMapController _mapController;
  String? _lastTappedMarkerId; // Stocke l'ID du dernier marqueur cliqué

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
  String? _category; // Nouveau filtre
  String? _choice; // Nouveau filtre
  int? _minFavorites; // Nouveau filtre
  double? _minPrice; // Nouveau filtre
  double? _maxPrice; // Nouveau filtre
  double? _minItemRating; // Nouveau filtre
  double? _maxItemRating; // Nouveau filtre

  // Rayon de recherche
  double _selectedRadius = 1500;

  @override
  void initState() {
    super.initState();
    _fetchNearbyProducers(_initialPosition.latitude, _initialPosition.longitude);
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


  /// Charger une icône par défaut pour les marqueurs
/// Charger des icônes pour les marqueurs et les afficher sur la carte
  void _setMarkerColorsByRank(List<Map<String, dynamic>> rankedProducers) async {
    print("🔍 Début de la création des marqueurs avec classement.");

    if (rankedProducers.isEmpty) {
      print("⚠️ Aucun producteur à afficher.");
      return;
    }

    Set<Marker> newMarkers = {};
    int totalProducers = rankedProducers.length;

    for (int i = 0; i < rankedProducers.length; i++) {
      final producer = rankedProducers[i];

      try {
        final List<dynamic>? coordinates = producer['gps_coordinates']?['coordinates'];
        final String? producerId = producer['_id'];
        final String producerName = producer['name'] ?? "Nom inconnu";

        if (coordinates == null || coordinates.length < 2 || producerId == null) {
          print("❌ Données invalides pour le producteur ${producerId ?? 'ID inconnu'}.");
          continue;
        }

        double lat = coordinates[1].toDouble();
        double lon = coordinates[0].toDouble();

        // Utiliser directement la teinte
        double markerHue = _getColorBasedOnScoreRank(i, totalProducers);

        Marker marker = Marker(
          markerId: MarkerId(producerId),
          position: LatLng(lat, lon),
          icon: BitmapDescriptor.defaultMarkerWithHue(markerHue),
          infoWindow: InfoWindow(
            title: producerName,
            snippet: "Note : ${producer['rating']?.toStringAsFixed(1) ?? 'N/A'}",
          ),
          onTap: () {
            setState(() {
              if (_lastTappedMarkerId == producerId) {
                // Si on clique deux fois sur le même, on navigue vers le profil
                _navigateToProducerDetails(producerId);
                _lastTappedMarkerId = null; // Réinitialise après navigation
              } else {
                // Sinon, on affiche juste l'infoWindow du marqueur
                _lastTappedMarkerId = producerId;
                _mapController.showMarkerInfoWindow(MarkerId(producerId));
              }
            });
          },
        );

        // Ajouter le marqueur à la liste
        newMarkers.add(marker);

      } catch (e) {
        print("❌ Erreur lors de la création du marqueur pour ${producer['_id']} : $e");
      }
    }

    // Mettre à jour l'état avec les nouveaux marqueurs
    setState(() {
      _markers.clear();
      _markers.addAll(newMarkers);
      print("✅ ${_markers.length} marqueurs ajoutés à la carte.");
    });
  }


  /// Calculer une couleur de marqueur en fonction du rang
  double _getColorBasedOnScoreRank(int rank, int totalProducers) {
    double normalizedRank = (rank / totalProducers).clamp(0.0, 1.0);
    // Convertir une couleur interpolée en teinte (hue)
    return 120 * (1.0 - normalizedRank); // Vert (120°) pour les meilleurs, rouge (0°) pour les pires
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
        if (_category != null) 'category': _category,
        if (_choice != null) 'choice': _choice,
        if (_minFavorites != null) 'minFavorites': _minFavorites.toString(),
        if (_minPrice != null) 'minPrice': _minPrice.toString(),
        if (_maxPrice != null) 'maxPrice': _maxPrice.toString(),
        if (_minItemRating != null) 'minItemRating': _minItemRating.toString(),
        if (_maxItemRating != null) 'maxItemRating': _maxItemRating.toString(),
      };

      final uri = Uri.http('${getBaseUrl()}', '/api/producers/nearby', queryParameters);
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
      _category = null;
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
      _resetFilters(); // Réinitialiser tous les anciens critères
      _fetchNearbyProducers(_initialPosition.latitude, _initialPosition.longitude);
      _showSnackBar("Filtres réinitialisés et recherche mise à jour !");
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
            ElevatedButton(
              onPressed: () {
                _applyFilters();
                _showFilters();
              },
              child: const Text('Appliquer les filtres items'),
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
            ElevatedButton(
              onPressed: _applyFilters,
              child: const Text('Appliquer les filtres restaurants'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Carte des Restaurants et Items'),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Google Map Widget
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _initialPosition,
              zoom: 15.0,
            ),
            markers: _markers,
            onMapCreated: (GoogleMapController controller) {
              _mapController = controller;
              setState(() {
                _isMapReady = true;
              });
            },
          ),

          // Loader si les données sont en cours de chargement
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),

          // Bouton pour ouvrir les filtres des items
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: ElevatedButton(
              onPressed: () => showModalBottomSheet(
                context: context,
                builder: (context) => _buildItemFilters(),
              ),
              child: const Text(
                'Filtres pour les Items',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ),

          // Bouton pour ouvrir les filtres des restaurants
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: ElevatedButton(
              onPressed: () => showModalBottomSheet(
                context: context,
                builder: (context) => _buildRestaurantFilters(),
              ),
              child: const Text(
                'Filtres pour les Restaurants',
                style: TextStyle(fontSize: 16),
              ),
            ),
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
}
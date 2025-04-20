import 'package:flutter/material.dart';

/// Classe pour définir les types de filtres disponibles
enum FilterType {
  singleSelect,
  multiSelect,
  range,
  search,
  toggle,
}

/// Classe pour définir une section de filtres
class FilterSection {
  final String title;
  final List<FilterOption> options;
  final FilterType type;
  final double? minValue;
  final double? maxValue;
  final double? currentMinValue;
  final double? currentMaxValue;
  final double weight; // Poids du filtre dans le calcul du score
  final IconData icon;
  
  // Propriétés manquantes
  final double? min; // Alias pour minValue
  final double? max; // Alias pour maxValue
  final dynamic value; // Valeur pour les types singleSelect
  final List<String> selectedValues; // Valeurs sélectionnées pour les types multiSelect

  const FilterSection({
    required this.title,
    this.options = const [],
    this.type = FilterType.singleSelect,
    this.minValue,
    this.maxValue,
    this.currentMinValue,
    this.currentMaxValue,
    this.weight = 1.0, // Poids par défaut
    required this.icon,
    this.min,
    this.max,
    this.value,
    this.selectedValues = const [],
  });

  /// Crée une copie de cette section avec des propriétés modifiées
  FilterSection copyWith({
    String? title,
    List<FilterOption>? options,
    FilterType? type,
    double? minValue,
    double? maxValue,
    double? currentMinValue,
    double? currentMaxValue,
    double? weight,
    IconData? icon,
    double? min,
    double? max,
    dynamic value,
    List<String>? selectedValues,
  }) {
    return FilterSection(
      title: title ?? this.title,
      options: options ?? this.options,
      type: type ?? this.type,
      minValue: minValue ?? this.minValue,
      maxValue: maxValue ?? this.maxValue,
      currentMinValue: currentMinValue ?? this.currentMinValue,
      currentMaxValue: currentMaxValue ?? this.currentMaxValue,
      weight: weight ?? this.weight,
      icon: icon ?? this.icon,
      min: min,
      max: max,
      value: value,
      selectedValues: selectedValues ?? this.selectedValues,
    );
  }
}

/// Classe pour définir une option de filtre
class FilterOption {
  final String id;
  final String label;
  final bool isSelected;
  final String? iconPath;
  final Color? color;
  final double weight; // Poids de l'option dans le calcul du score
  final String value; // Valeur de l'option

  const FilterOption({
    required this.id,
    required this.label,
    this.isSelected = false,
    this.iconPath,
    this.color,
    this.weight = 1.0, // Poids par défaut
    String? value,
  }) : value = value ?? id; // Si value n'est pas fourni, on utilise l'id

  /// Crée une copie de cette option avec des propriétés modifiées
  FilterOption copyWith({
    String? id,
    String? label,
    bool? isSelected,
    String? iconPath,
    Color? color,
    double? weight,
    String? value,
  }) {
    return FilterOption(
      id: id ?? this.id,
      label: label ?? this.label,
      isSelected: isSelected ?? this.isSelected,
      iconPath: iconPath ?? this.iconPath,
      color: color ?? this.color,
      weight: weight ?? this.weight,
      value: value ?? this.value,
    );
  }
}

/// Classe utilitaire pour les couleurs des cartes
class MapColors {
  // Couleurs principales
  static final Color restaurantPrimary = Colors.deepOrange;
  static final Color restaurantSecondary = Colors.deepOrange[200]!;
  
  static final Color leisurePrimary = Colors.purple;
  static final Color leisureSecondary = Colors.purple[200]!;
  
  static final Color wellnessPrimary = Colors.green;
  static final Color wellnessSecondary = Colors.green[200]!;
  
  static final Color friendsPrimary = Colors.amber;
  static final Color friendsSecondary = Colors.amber[200]!;
  
  // Obtenir la couleur primaire en fonction du type de carte
  static Color getPrimaryColorByType(String mapType) {
    switch (mapType) {
      case 'restaurant':
        return restaurantPrimary;
      case 'leisure':
        return leisurePrimary;
      case 'wellness':
        return wellnessPrimary;
      case 'friends':
        return friendsPrimary;
      default:
        return restaurantPrimary;
    }
  }
  
  // Obtenir la couleur secondaire en fonction du type de carte
  static Color getSecondaryColorByType(String mapType) {
    switch (mapType) {
      case 'restaurant':
        return restaurantSecondary;
      case 'leisure':
        return leisureSecondary;
      case 'wellness':
        return wellnessSecondary;
      case 'friends':
        return friendsSecondary;
      default:
        return restaurantSecondary;
    }
  }
  
  // Obtenir la couleur du marqueur en fonction du score
  static Color getMarkerColorByScore(double score, String mapType) {
    final Color baseColor = getPrimaryColorByType(mapType);
    
    // Calculer les teintes en fonction du score
    if (score <= 0.3) {
      // Couleur plus claire pour les scores bas
      return Color.lerp(Colors.grey, baseColor, score / 0.3)!;
    } else if (score <= 0.7) {
      // Couleur normale pour les scores moyens
      return baseColor;
    } else {
      // Couleur plus saturée pour les scores élevés
      return Color.lerp(baseColor, darkenColor(baseColor, 0.3), (score - 0.7) / 0.3)!;
    }
  }
  
  // Assombrir une couleur
  static Color darkenColor(Color color, double factor) {
    assert(factor >= 0 && factor <= 1);
    
    final hsl = HSLColor.fromColor(color);
    final hslDarker = hsl.withLightness((hsl.lightness - factor).clamp(0.0, 1.0));
    
    return hslDarker.toColor();
  }
}

/// Classe pour calculer les scores en fonction des filtres
class ScoreCalculator {
  // Calcule un score pour un lieu en fonction des filtres sélectionnés
  static double calculateScore(
    Map<String, dynamic> place,
    List<FilterSection> filters,
    String mapType,
  ) {
    double score = 0.5; // Score de base
    double totalWeight = 0.0; // Poids total des filtres appliqués
    int matchCount = 0; // Nombre de critères correspondants
    
    // Vérifier si aucun filtre n'est appliqué
    bool hasActiveFilters = false;
    for (final section in filters) {
      if (section.type == FilterType.singleSelect) {
        if (section.options.any((option) => option.isSelected && option.id != "0" && option.id != "Tous")) {
          hasActiveFilters = true;
          break;
        }
      } else if (section.type == FilterType.multiSelect) {
        if (section.options.any((option) => option.isSelected)) {
          hasActiveFilters = true;
          break;
        }
      } else if (section.type == FilterType.range) {
        if (section.currentMinValue != section.minValue || section.currentMaxValue != section.maxValue) {
          hasActiveFilters = true;
          break;
        }
      }
    }
    
    if (!hasActiveFilters) {
      // Si aucun filtre actif, appliquer des variations mineures basées sur la note
      final double rating = place['rating']?.toDouble() ?? 0.0;
      if (rating > 0) {
        score = 0.4 + (rating / 5.0) * 0.2; // Score entre 0.4 et 0.6 basé sur la note
      }
      
      // Facteur de popularité
      final int ratingsCount = place['user_ratings_total'] ?? place['userRatingsTotal'] ?? 0;
      if (ratingsCount > 100) {
        score += 0.05;
      } else if (ratingsCount > 50) {
        score += 0.025;
      }
      
      return score.clamp(0.0, 1.0);
    }
    
    // Parcourir chaque section de filtre
    for (final section in filters) {
      switch (section.type) {
        case FilterType.singleSelect:
          final selectedOption = section.options.firstWhere(
            (option) => option.isSelected,
            orElse: () => FilterOption(id: "", label: ""),
          );
          
          if (selectedOption.id.isNotEmpty && selectedOption.id != "0" && selectedOption.id != "Tous") {
            totalWeight += section.weight;
            
            // Vérifier la correspondance selon le titre de la section
            bool isMatch = false;
            if (section.title == 'Catégories' || section.title == 'Catégorie') {
              final String category = place['category'] ?? '';
              isMatch = category.toLowerCase().contains(selectedOption.id.toLowerCase());
            } else if (section.title == 'Sous-catégories' || section.title == 'Sous-catégorie') {
              final String subCategory = place['sous_categorie'] ?? place['sous_category'] ?? place['subCategory'] ?? '';
              isMatch = subCategory.toLowerCase().contains(selectedOption.id.toLowerCase());
            } else if (section.title == 'Note minimale') {
              final double rating = place['rating']?.toDouble() ?? 0.0;
              final double minRating = double.tryParse(selectedOption.id) ?? 0.0;
              isMatch = rating >= minRating;
            }
            
            if (isMatch) {
              score += section.weight * selectedOption.weight;
              matchCount++;
            } else {
              score -= section.weight * 0.1; // Pénalité légère pour non-correspondance
            }
          }
          break;
          
        case FilterType.multiSelect:
          final selectedOptions = section.options.where((option) => option.isSelected).toList();
          
          if (selectedOptions.isNotEmpty) {
            totalWeight += section.weight;
            
            // Vérifier la correspondance selon le titre de la section
            int optionMatchCount = 0;
            if (section.title == 'Services' || section.title == 'Commodités') {
              final List<dynamic> services = place['services'] ?? [];
              for (final option in selectedOptions) {
                if (services.any((service) => service.toString().toLowerCase().contains(option.id.toLowerCase()))) {
                  optionMatchCount++;
                }
              }
            } else if (section.title == 'Plats' || section.title == 'Cuisine') {
              final List<dynamic> cuisines = place['cuisines'] ?? place['cuisine_type'] ?? [];
              for (final option in selectedOptions) {
                if (cuisines.any((cuisine) => cuisine.toString().toLowerCase().contains(option.id.toLowerCase()))) {
                  optionMatchCount++;
                }
              }
            }
            
            if (optionMatchCount > 0) {
              final matchRatio = optionMatchCount / selectedOptions.length;
              score += section.weight * matchRatio;
              matchCount++;
            } else {
              score -= section.weight * 0.1; // Pénalité légère pour non-correspondance
            }
          }
          break;
          
        case FilterType.range:
          if (section.currentMinValue != null && section.currentMaxValue != null &&
              (section.currentMinValue != section.minValue || section.currentMaxValue != section.maxValue)) {
            totalWeight += section.weight;
            
            // Vérifier la correspondance selon le titre de la section
            bool isInRange = false;
            if (section.title == 'Prix') {
              final int priceLevel = place['price_level'] ?? 0;
              isInRange = priceLevel >= section.currentMinValue! && priceLevel <= section.currentMaxValue!;
            } else if (section.title == 'Distance') {
              final double distance = place['distance']?.toDouble() ?? 0.0;
              isInRange = distance >= section.currentMinValue! && distance <= section.currentMaxValue!;
            }
            
            if (isInRange) {
              score += section.weight;
              matchCount++;
            } else {
              score -= section.weight * 0.1; // Pénalité légère pour non-correspondance
            }
          }
          break;
          
        case FilterType.search:
          // Non implémenté pour le moment
          break;
          
        case FilterType.toggle:
          if (section.value as bool? ?? false) {
            totalWeight += section.weight;
            
            // Vérifier la correspondance selon le titre de la section
            final String fieldName = section.title.toLowerCase().replaceAll(' ', '_');
            
            // Vérifier si le lieu a cette propriété
            if (place.containsKey(fieldName)) {
              if (place[fieldName] is bool) {
                if (place[fieldName]) {
                  score += section.weight;
                  matchCount++;
                }
              } else {
                // Si la propriété existe et n'est pas bool, considérer comme positif
                score += section.weight;
                matchCount++;
              }
            }
          }
          break;
      }
    }
    
    // Facteurs additionnels selon le type de carte
    if (mapType == 'restaurant') {
      // Bonus pour les restaurants populaires
      final int ratingsCount = place['user_ratings_total'] ?? place['userRatingsTotal'] ?? 0;
      if (ratingsCount > 200) {
        score += 0.1;
      } else if (ratingsCount > 100) {
        score += 0.05;
      }
    } else if (mapType == 'leisure') {
      // Bonus pour les lieux de loisirs récents
      if (place['opening_date'] != null) {
        // Plus l'événement est récent, plus le score est élevé
        final DateTime openingDate = place['opening_date'] is DateTime ? 
            place['opening_date'] : DateTime.tryParse(place['opening_date'].toString()) ?? DateTime.now();
        final int daysAgo = DateTime.now().difference(openingDate).inDays;
        
        if (daysAgo < 7) {
          score += 0.15; // Événement de la semaine
        } else if (daysAgo < 30) {
          score += 0.1; // Événement du mois
        }
      }
    } else if (mapType == 'wellness') {
      // Bonus pour les lieux de bien-être avec beaucoup de services
      final List<dynamic> services = place['services'] ?? [];
      if (services.length > 5) {
        score += 0.1;
      } else if (services.length > 3) {
        score += 0.05;
      }
    }
    
    // Si certains filtres correspondent mais pas tous, ajuster le score
    if (matchCount > 0 && matchCount < totalWeight) {
      score = score * (0.5 + (matchCount / totalWeight) * 0.5);
    }
    
    // Normaliser le score entre 0 et 1
    return score.clamp(0.0, 1.0);
  }
}

/// Classe utilitaire pour les filtres par défaut
class DefaultFilters {
  // Filtres pour la carte des restaurants
  static List<FilterSection> getRestaurantFilters() {
    return [
      FilterSection(
        title: 'Catégories',
        type: FilterType.singleSelect,
        weight: 1.5,
        options: [
          FilterOption(id: 'Tous', label: 'Tous', isSelected: true),
          FilterOption(id: 'restaurant', label: 'Restaurant', weight: 1.0),
          FilterOption(id: 'cafe', label: 'Café', weight: 0.9),
          FilterOption(id: 'bakery', label: 'Boulangerie', weight: 0.8),
          FilterOption(id: 'bar', label: 'Bar', weight: 0.8),
          FilterOption(id: 'meal_takeaway', label: 'À emporter', weight: 0.7),
        ],
        icon: Icons.restaurant_menu,
      ),
      FilterSection(
        title: 'Cuisine',
        type: FilterType.multiSelect,
        weight: 1.2,
        options: [
          FilterOption(id: 'french', label: 'Française'),
          FilterOption(id: 'italian', label: 'Italienne'),
          FilterOption(id: 'japanese', label: 'Japonaise'),
          FilterOption(id: 'chinese', label: 'Chinoise'),
          FilterOption(id: 'mexican', label: 'Mexicaine'),
          FilterOption(id: 'indian', label: 'Indienne'),
        ],
        icon: Icons.restaurant_menu,
      ),
      FilterSection(
        title: 'Note minimale',
        type: FilterType.singleSelect,
        weight: 1.0,
        options: [
          FilterOption(id: '0', label: 'Toutes les notes', isSelected: true),
          FilterOption(id: '3', label: '3+ ★★★', weight: 0.7),
          FilterOption(id: '3.5', label: '3.5+ ★★★⯪', weight: 0.8),
          FilterOption(id: '4', label: '4+ ★★★★', weight: 0.9),
          FilterOption(id: '4.5', label: '4.5+ ★★★★⯪', weight: 1.0),
        ],
        icon: Icons.star,
      ),
      FilterSection(
        title: 'Prix',
        type: FilterType.singleSelect,
        weight: 0.8,
        options: [
          FilterOption(id: '0', label: 'Tous les prix', isSelected: true),
          FilterOption(id: '1', label: '€'),
          FilterOption(id: '2', label: '€€'),
          FilterOption(id: '3', label: '€€€'),
          FilterOption(id: '4', label: '€€€€'),
        ],
        icon: Icons.euro,
      ),
    ];
  }
  
  // Filtres pour la carte des loisirs
  static List<FilterSection> getLeisureFilters() {
    return [
      FilterSection(
        title: 'Catégories',
        type: FilterType.singleSelect,
        weight: 1.5,
        options: [
          FilterOption(id: 'Tous', label: 'Tous', isSelected: true),
          FilterOption(id: 'entertainment', label: 'Divertissement', weight: 1.0),
          FilterOption(id: 'culture', label: 'Culture', weight: 1.0),
          FilterOption(id: 'sports', label: 'Sports', weight: 0.9),
          FilterOption(id: 'nightlife', label: 'Vie nocturne', weight: 0.8),
          FilterOption(id: 'nature', label: 'Nature', weight: 0.7),
        ],
        icon: Icons.theater_comedy,
      ),
      FilterSection(
        title: 'Note minimale',
        type: FilterType.singleSelect,
        weight: 1.0,
        options: [
          FilterOption(id: '0', label: 'Toutes les notes', isSelected: true),
          FilterOption(id: '3', label: '3+ ★★★', weight: 0.7),
          FilterOption(id: '3.5', label: '3.5+ ★★★⯪', weight: 0.8),
          FilterOption(id: '4', label: '4+ ★★★★', weight: 0.9),
          FilterOption(id: '4.5', label: '4.5+ ★★★★⯪', weight: 1.0),
        ],
        icon: Icons.star,
      ),
      FilterSection(
        title: 'Date',
        type: FilterType.singleSelect,
        weight: 1.2,
        options: [
          FilterOption(id: 'all', label: 'Toutes les dates', isSelected: true),
          FilterOption(id: 'today', label: 'Aujourd\'hui', weight: 1.0),
          FilterOption(id: 'week', label: 'Cette semaine', weight: 0.9),
          FilterOption(id: 'month', label: 'Ce mois-ci', weight: 0.8),
        ],
        icon: Icons.access_time,
      ),
      FilterSection(
        title: 'Prix',
        type: FilterType.singleSelect,
        weight: 0.8,
        options: [
          FilterOption(id: 'all', label: 'Tous les prix', isSelected: true),
          FilterOption(id: 'free', label: 'Gratuit', weight: 1.0),
          FilterOption(id: 'low', label: 'Bon marché', weight: 0.9),
          FilterOption(id: 'medium', label: 'Moyen', weight: 0.8),
          FilterOption(id: 'high', label: 'Cher', weight: 0.7),
        ],
        icon: Icons.euro,
      ),
    ];
  }
  
  // Filtres pour la carte du bien-être
  static List<FilterSection> getWellnessFilters() {
    return [
      FilterSection(
        title: 'Catégories',
        type: FilterType.singleSelect,
        weight: 1.5,
        options: [
          FilterOption(id: 'Tous', label: 'Tous', isSelected: true),
          FilterOption(id: 'spa', label: 'Spa', weight: 1.0),
          FilterOption(id: 'massage', label: 'Massage', weight: 1.0),
          FilterOption(id: 'yoga', label: 'Yoga', weight: 0.9),
          FilterOption(id: 'fitness', label: 'Fitness', weight: 0.9),
          FilterOption(id: 'beauty', label: 'Beauté', weight: 0.8),
        ],
        icon: Icons.spa,
      ),
      FilterSection(
        title: 'Services',
        type: FilterType.multiSelect,
        weight: 1.2,
        options: [
          FilterOption(id: 'massage', label: 'Massage'),
          FilterOption(id: 'sauna', label: 'Sauna'),
          FilterOption(id: 'jacuzzi', label: 'Jacuzzi'),
          FilterOption(id: 'hammam', label: 'Hammam'),
          FilterOption(id: 'facial', label: 'Soins du visage'),
          FilterOption(id: 'body', label: 'Soins du corps'),
        ],
        icon: Icons.spa_outlined,
      ),
      FilterSection(
        title: 'Note minimale',
        type: FilterType.singleSelect,
        weight: 1.0,
        options: [
          FilterOption(id: '0', label: 'Toutes les notes', isSelected: true),
          FilterOption(id: '3', label: '3+ ★★★', weight: 0.7),
          FilterOption(id: '3.5', label: '3.5+ ★★★⯪', weight: 0.8),
          FilterOption(id: '4', label: '4+ ★★★★', weight: 0.9),
          FilterOption(id: '4.5', label: '4.5+ ★★★★⯪', weight: 1.0),
        ],
        icon: Icons.star,
      ),
    ];
  }
  
  // Filtres pour la carte des amis
  static List<FilterSection> getFriendsFilters() {
    return [
      FilterSection(
        title: 'Afficher',
        type: FilterType.multiSelect,
        weight: 1.0,
        options: [
          FilterOption(id: 'choices', label: 'Choix', isSelected: true),
          FilterOption(id: 'interests', label: 'Intérêts', isSelected: true),
        ],
        icon: Icons.people,
      ),
      FilterSection(
        title: 'Amis',
        type: FilterType.multiSelect,
        weight: 1.2,
        options: [],
        icon: Icons.people,
      ),
      FilterSection(
        title: 'Catégories',
        type: FilterType.multiSelect,
        weight: 1.0,
        options: [
          FilterOption(id: 'restaurant', label: 'Restaurants'),
          FilterOption(id: 'leisure', label: 'Loisirs'),
          FilterOption(id: 'wellness', label: 'Bien-être'),
        ],
        icon: Icons.local_activity,
      ),
    ];
  }
  
  // Méthode pour obtenir les filtres en fonction du type de carte
  static List<FilterSection> getFiltersByType(String title) {
    if (title.contains('Restaurant')) {
      return getRestaurantFilters();
    } else if (title.contains('Loisir')) {
      return getLeisureFilters();
    } else if (title.contains('Wellness')) {
      return getWellnessFilters();
    } else if (title.contains('Ami')) {
      return getFriendsFilters();
    }
    return [];
  }
} 
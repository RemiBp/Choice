import 'dart:developer' as developer;

/// Modèle pour représenter un profil de lieu extrait par l'IA
class ProfileData {
  final String id;
  final String type;
  final String name;
  final String? address;
  final String? description;
  final double? rating;
  final String? image;
  final List<String> category;
  final int? priceLevel;
  final String? highlightedItem;
  final List<MenuItem>? menuItems;
  final Map<String, dynamic>? structuredData;
  final Map<String, dynamic>? businessData;
  
  ProfileData({
    required this.id,
    required this.type,
    required this.name,
    this.address,
    this.description,
    this.rating,
    this.image,
    required this.category,
    this.priceLevel,
    this.highlightedItem,
    this.menuItems,
    this.structuredData,
    this.businessData,
  });
  
  factory ProfileData.fromJson(Map<String, dynamic> json) {
    // Journalisation pour debug
    developer.log('[ProfileData] Parsing JSON: ${json.keys}');
    
    List<String> parseCategories(dynamic categories) {
      if (categories == null) return [];
      if (categories is String) return [categories];
      if (categories is List) {
        return categories.map((c) => c.toString()).toList();
      }
      return [];
    }
    
    // Extraire les items de menu s'ils existent
    List<MenuItem>? menuItems;
    if (json['menu_items'] != null) {
      menuItems = (json['menu_items'] as List)
          .map((item) => MenuItem.fromJson(item))
          .toList();
    }
    
    return ProfileData(
      id: json['id'] ?? '',
      type: json['type'] ?? 'unknown',
      name: json['name'] ?? 'Sans nom',
      address: json['address'],
      description: json['description'],
      rating: json['rating'] != null ? double.tryParse(json['rating'].toString()) : null,
      image: json['image'],
      category: parseCategories(json['category']),
      priceLevel: json['price_level'] != null ? int.tryParse(json['price_level'].toString()) : null,
      highlightedItem: json['highlighted_item'] ?? json['highlightedItem'],
      menuItems: menuItems,
      structuredData: json['structured_data'] ?? json['structuredData'],
      businessData: json['business_data'] ?? json['businessData'],
    );
  }
  
  /// Vérifie si ce profil contient un plat spécifique
  bool hasMenuItemWithKeyword(String keyword) {
    if (menuItems == null) return false;
    
    final lowercaseKeyword = keyword.toLowerCase();
    return menuItems!.any((item) => 
      (item.nom?.toLowerCase().contains(lowercaseKeyword) ?? false) ||
      (item.description?.toLowerCase().contains(lowercaseKeyword) ?? false)
    );
  }
  
  /// Convertit l'objet en Map pour le débogage et la sérialisation
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'name': name,
      'address': address,
      'description': description,
      'rating': rating,
      'image': image,
      'category': category,
      'price_level': priceLevel,
      'highlighted_item': highlightedItem,
    };
  }
  
  /// Crée une copie de ce ProfileData avec les champs spécifiés remplacés
  ProfileData copyWith({
    String? id,
    String? type,
    String? name,
    String? address,
    String? description,
    double? rating,
    String? image,
    List<String>? category,
    int? priceLevel,
    String? highlightedItem,
    List<MenuItem>? menuItems,
    Map<String, dynamic>? structuredData,
    Map<String, dynamic>? businessData,
  }) {
    return ProfileData(
      id: id ?? this.id,
      type: type ?? this.type,
      name: name ?? this.name,
      address: address ?? this.address,
      description: description ?? this.description,
      rating: rating ?? this.rating,
      image: image ?? this.image,
      category: category ?? this.category,
      priceLevel: priceLevel ?? this.priceLevel,
      highlightedItem: highlightedItem ?? this.highlightedItem,
      menuItems: menuItems ?? this.menuItems,
      structuredData: structuredData ?? this.structuredData,
      businessData: businessData ?? this.businessData,
    );
  }
}

/// Modèle pour représenter un item de menu
class MenuItem {
  final String? nom;
  final String? description;
  final dynamic prix;
  final double? note;
  
  MenuItem({this.nom, this.description, this.prix, this.note});
  
  factory MenuItem.fromJson(Map<String, dynamic> json) {
    return MenuItem(
      nom: json['nom'],
      description: json['description'],
      prix: json['prix'],
      note: json['note'] != null ? double.tryParse(json['note'].toString()) : null,
    );
  }
  
  @override
  String toString() {
    return '$nom${description != null ? ' - $description' : ''}${prix != null ? ' ($prix)' : ''}';
  }
  
  /// Convertit l'item de menu en Map pour la sérialisation
  Map<String, dynamic> toJson() {
    return {
      'nom': nom,
      'description': description,
      'prix': prix,
      'note': note,
    };
  }
} 
import 'dart:convert';
import 'package:flutter/material.dart';

class ContactTag {
  final String id;
  final String name;
  final Color color;
  final IconData icon;
  final String? description;
  final DateTime createdAt;
  final DateTime updatedAt;

  ContactTag({
    required this.id,
    required this.name,
    required this.color,
    required this.icon,
    this.description,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : 
    this.createdAt = createdAt ?? DateTime.now(),
    this.updatedAt = updatedAt ?? DateTime.now();

  // Constructeur de copie avec modification
  ContactTag copyWith({
    String? id,
    String? name,
    Color? color,
    IconData? icon,
    String? description,
    DateTime? updatedAt,
  }) {
    return ContactTag(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      description: description ?? this.description,
      createdAt: this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  // Convertir en Map pour le stockage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'color': color.value,
      'iconCodePoint': icon.codePoint,
      'iconFontFamily': icon.fontFamily,
      'iconFontPackage': icon.fontPackage,
      'description': description,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  // Créer à partir d'un Map
  factory ContactTag.fromMap(Map<String, dynamic> map) {
    return ContactTag(
      id: map['id'],
      name: map['name'],
      color: Color(map['color']),
      icon: IconData(
        map['iconCodePoint'],
        fontFamily: map['iconFontFamily'],
        fontPackage: map['iconFontPackage'],
      ),
      description: map['description'],
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
    );
  }

  // Convertir en JSON
  String toJson() => json.encode(toMap());

  // Créer à partir de JSON
  factory ContactTag.fromJson(String source) => ContactTag.fromMap(json.decode(source));

  // Comparer deux tags
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ContactTag && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'ContactTag(id: $id, name: $name, color: $color, icon: $icon, description: $description)';
  }
}

// Classe pour gérer l'association entre contacts et tags
class ContactTagAssociation {
  final String contactId;
  final String tagId;
  final DateTime createdAt;

  ContactTagAssociation({
    required this.contactId,
    required this.tagId,
    DateTime? createdAt,
  }) : this.createdAt = createdAt ?? DateTime.now();

  // Convertir en Map pour le stockage
  Map<String, dynamic> toMap() {
    return {
      'contactId': contactId,
      'tagId': tagId,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  // Créer à partir d'un Map
  factory ContactTagAssociation.fromMap(Map<String, dynamic> map) {
    return ContactTagAssociation(
      contactId: map['contactId'],
      tagId: map['tagId'],
      createdAt: DateTime.parse(map['createdAt']),
    );
  }

  // Convertir en JSON
  String toJson() => json.encode(toMap());

  // Créer à partir de JSON
  factory ContactTagAssociation.fromJson(String source) => 
      ContactTagAssociation.fromMap(json.decode(source));

  // Comparer deux associations
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ContactTagAssociation && 
           other.contactId == contactId && 
           other.tagId == tagId;
  }

  @override
  int get hashCode => contactId.hashCode ^ tagId.hashCode;

  @override
  String toString() {
    return 'ContactTagAssociation(contactId: $contactId, tagId: $tagId)';
  }
} 
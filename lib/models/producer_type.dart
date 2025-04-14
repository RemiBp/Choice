import 'package:flutter/material.dart';

/// Énumération des types de producteurs supportés par l'application
enum ProducerType {
  restaurant('restaurant'),
  leisureProducer('leisureProducer'),
  event('event'),
  wellnessProducer('wellnessProducer'),
  user('user');

  final String value;
  const ProducerType(this.value);

  /// Convertit une chaîne de caractères en type de producteur
  static ProducerType fromString(String? value) {
    if (value == null) return ProducerType.restaurant;
    
    return ProducerType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => ProducerType.restaurant,
    );
  }

  /// Obtient l'icône correspondante au type de producteur
  IconData get icon {
    switch (this) {
      case ProducerType.restaurant:
        return Icons.restaurant;
      case ProducerType.leisureProducer:
        return Icons.local_activity;
      case ProducerType.event:
        return Icons.event;
      case ProducerType.user:
        return Icons.person;
      case ProducerType.wellnessProducer:
        return Icons.spa;
    }
  }

  /// Obtient la couleur correspondante au type de producteur
  Color get color {
    switch (this) {
      case ProducerType.restaurant:
        return Color(0xFFFF7043); // Orange profond
      case ProducerType.leisureProducer:
        return Color(0xFF7E57C2); // Violet
      case ProducerType.event:
        return Color(0xFF26A69A); // Vert teal
      case ProducerType.user:
        return Color(0xFF42A5F5); // Bleu
      case ProducerType.wellnessProducer:
        return Color(0xFFEC407A); // Rose
    }
  }

  /// Obtient le libellé correspondant au type de producteur
  String get label {
    switch (this) {
      case ProducerType.restaurant:
        return 'Restaurant';
      case ProducerType.leisureProducer:
        return 'Loisir';
      case ProducerType.event:
        return 'Événement';
      case ProducerType.user:
        return 'Utilisateur';
      case ProducerType.wellnessProducer:
        return 'Bien-être';
    }
  }

  /// Obtient le chemin d'API correspondant au type de producteur
  String get apiPath {
    switch (this) {
      case ProducerType.restaurant:
        return 'producers';
      case ProducerType.leisureProducer:
        return 'leisureProducers';
      case ProducerType.event:
        return 'events';
      case ProducerType.user:
        return 'users';
      case ProducerType.wellnessProducer:
        return 'wellness';
    }
  }

  /// Détermine si le producteur peut utiliser le dashboard de croissance
  bool get canUseGrowthDashboard {
    switch (this) {
      case ProducerType.restaurant:
      case ProducerType.leisureProducer:
      case ProducerType.wellnessProducer:
        return true;
      case ProducerType.event:
      case ProducerType.user:
        return false;
    }
  }
} 
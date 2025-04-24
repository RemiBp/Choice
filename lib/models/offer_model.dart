import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Pour le formatage des dates

// Modèle simplifié pour les informations du producteur incluses dans l'offre
class ProducerInfo {
  final String id;
  final String name;
  final String? profilePicture;

  ProducerInfo({
    required this.id,
    required this.name,
    this.profilePicture,
  });

  factory ProducerInfo.fromJson(Map<String, dynamic> json) {
    return ProducerInfo(
      id: json['_id'] as String? ?? json['id'] as String? ?? 'unknown_producer',
      name: json['name'] as String? ?? 'Producteur Inconnu',
      profilePicture: json['profilePicture'] as String?,
    );
  }
}

// Modèle principal pour une offre reçue par l'utilisateur
class Offer {
  final String id;
  final ProducerInfo producer;
  final String targetUserId;
  final String? originalSearchQuery;
  final String title;
  final String body;
  final double? discountPercentage;
  final String status;
  final String offerCode;
  final DateTime expiresAt;
  final DateTime createdAt;
  final DateTime? validatedAt;
  final String? triggeringSearchId;

  Offer({
    required this.id,
    required this.producer,
    required this.targetUserId,
    this.originalSearchQuery,
    required this.title,
    required this.body,
    this.discountPercentage,
    required this.status,
    required this.offerCode,
    required this.expiresAt,
    required this.createdAt,
    this.validatedAt,
    this.triggeringSearchId,
  });

  factory Offer.fromJson(Map<String, dynamic> json) {
    return Offer(
      id: json['_id'] as String? ?? 'unknown_offer',
      // Gérer le producteur peuplé
      producer: json['producerId'] is Map<String, dynamic>
          ? ProducerInfo.fromJson(json['producerId'])
          : ProducerInfo(id: json['producerId']?.toString() ?? 'unknown', name: 'Détails Producteur Non Chargés'), // Fallback si non peuplé
      targetUserId: json['targetUserId'] as String? ?? 'unknown_user',
      originalSearchQuery: json['originalSearchQuery'] as String?,
      title: json['title'] as String? ?? 'Offre sans titre',
      body: json['body'] as String? ?? '',
      discountPercentage: (json['discountPercentage'] as num?)?.toDouble(),
      status: json['status'] as String? ?? 'unknown',
      offerCode: json['offerCode'] as String? ?? 'NO-CODE',
      expiresAt: DateTime.tryParse(json['expiresAt'] as String? ?? '') ?? DateTime.now().add(const Duration(days: -1)), // Expire hier si date invalide
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      validatedAt: DateTime.tryParse(json['validatedAt'] as String? ?? ''),
      triggeringSearchId: json['triggeringSearchId'] as String?,
    );
  }

  // Helper pour obtenir une couleur basée sur le statut
  Color getStatusColor() {
    switch (status) {
      case 'pending':
      case 'sent':
        return Colors.blue;
      case 'accepted':
        return Colors.orange;
      case 'validated':
        return Colors.green;
      case 'expired':
        return Colors.grey;
      case 'rejected':
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.black54;
    }
  }

  // Helper pour obtenir le texte du statut traduit (simplifié)
  String getStatusText() {
    // TODO: Utiliser easy_localization pour une vraie traduction
    switch (status) {
      case 'pending': return 'En attente';
      case 'sent': return 'Envoyée';
      case 'accepted': return 'Acceptée';
      case 'validated': return 'Utilisée';
      case 'expired': return 'Expirée';
      case 'rejected': return 'Rejetée';
      case 'cancelled': return 'Annulée';
      default: return status.toUpperCase();
    }
  }

   // Helper pour formater la date d'expiration
  String getFormattedExpiration() {
    // Vérifier si la date est valide et non expirée par défaut
    if (expiresAt.isAfter(DateTime.now().add(const Duration(days: -1)))) {
      return DateFormat('dd/MM/yyyy HH:mm', 'fr_FR').format(expiresAt);
    }
    return 'Date invalide';
  }

  // Vérifier si l'offre est actuellement valide
  bool get isValid => status == 'accepted' && expiresAt.isAfter(DateTime.now());
} 
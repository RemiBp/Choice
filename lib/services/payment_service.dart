import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart'; // ✅ Pour ouvrir Stripe sur Web & Mobile
import '../screens/utils.dart';
import 'storage_service.dart'; // ✅ Service de stockage
import 'webview_stripe_page.dart'; // ✅ Import de la WebView pour Stripe

/// Service de paiement gérant les abonnements Premium
class PaymentService {
  final _storageService = StorageService();

  // Définition des abonnements disponibles
  static final Map<String, Map<String, dynamic>> subscriptionTiers = {
    'gratuit': {
      'price': 0,
      'name': 'Gratuit',
      'features': ['Profil lieu', 'Poster', 'Voir les posts clients', 'Reco IA 1x/semaine', 'Stats basiques']
    },
    'starter': {
      'price': 5,
      'name': 'Starter',
      'features': ['Recos IA quotidiennes', 'Stats avancées', 'Accès au feed de tendances locales']
    },
    'pro': {
      'price': 10,
      'name': 'Pro',
      'features': ['Boosts illimités sur la map/feed', 'Accès à la Heatmap & Copilot IA', 'Campagnes simples']
    },
    'legend': {
      'price': 15,
      'name': 'Legend',
      'features': ['Classement public', 'Ambassadeurs', 'Campagnes avancées (ciblage fin)', 'Visuels IA stylisés']
    }
  };

  static Future<void> initialize() async {
    await StorageService.initStorage();
    // Additional initialization code...
  }

  /// 🔹 Initialisation du stockage
  static Future<void> initStorage() async {
    await StorageService.initStorage();
  }

  /// 🔹 Processus de paiement via Stripe Checkout avec support Apple Pay
  static Future<bool> processPayment(BuildContext context, String plan, String producerId) async {
    try {
      final int amount = _getAmount(plan);
      if (amount == 0 && plan.toLowerCase() != 'gratuit') {
        print("❌ Plan invalide : $plan");
        return false;
      }
      
      // Si le plan est gratuit, pas de paiement nécessaire
      if (plan.toLowerCase() == 'gratuit') {
        print("✅ Plan gratuit sélectionné, pas de paiement nécessaire");
        // Mettre à jour le statut d'abonnement gratuit dans le backend
        await _updateFreeSubscription(producerId);
        return true;
      }

      print("📤 Envoi de la requête de paiement pour $plan à $amount centimes...");

      // 🔹 Vérifie que le stockage est initialisé
      await initStorage();

      // 🔹 Appelle le backend pour obtenir une session Stripe Checkout
      final String? checkoutUrl = await _getCheckoutUrl(amount, producerId, plan);
      if (checkoutUrl == null) {
        print("❌ Erreur : URL Checkout non reçue.");
        return false;
      }

      print("✅ URL Checkout reçue : $checkoutUrl");

      // 🔹 Ouvrir Stripe Checkout en fonction de la plateforme (avec support Apple Pay)
      if (kIsWeb) {
        print("🌍 Redirection vers Stripe Checkout Web...");
        await launchUrl(Uri.parse(checkoutUrl), mode: LaunchMode.externalApplication);
      } else {
        print("📱 Ouverture de Stripe Checkout en WebView (avec support Apple Pay)...");
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => WebViewStripePage(url: checkoutUrl),
          ),
        );
      }

      print("🎉 Processus de paiement terminé !");
      return true;
    } catch (e) {
      print("❌ Erreur Stripe : $e");
      return false;
    }
  }

  /// 🔹 Mise à jour de l'abonnement gratuit directement
  static Future<bool> _updateFreeSubscription(String producerId) async {
    try {
      final url = Uri.parse("${getBaseUrl()}/api/subscription/update-free-tier");
      
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "producerId": producerId,
          "plan": "gratuit"
        }),
      );

      if (response.statusCode != 200) {
        print("❌ Erreur mise à jour abonnement gratuit : ${response.body}");
        return false;
      }
      
      return true;
    } catch (e) {
      print("❌ Erreur lors de la mise à jour de l'abonnement gratuit : $e");
      return false;
    }
  }

  /// 🔹 Récupérer dynamiquement l'URL Stripe Checkout depuis le backend
  static Future<String?> _getCheckoutUrl(int amount, String producerId, String plan) async {
    try {
      final url = Uri.parse("${getBaseUrl()}/api/subscription/create-payment-intent");

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "amount": amount,
          "currency": "eur",
          "producerId": producerId,
          "plan": plan
        }),
      );

      if (response.statusCode != 200) {
        print("❌ Erreur backend paiement : ${response.body}");
        return null;
      }

      final paymentData = json.decode(response.body);
      final clientSecret = paymentData['client_secret'];
      
      // Construit l'URL de paiement Stripe avec support Apple Pay
      final String stripeUrl = kIsWeb
          ? "https://checkout.stripe.com/pay/${clientSecret}"
          : "https://checkout.stripe.com/mobile/v1/payment_auth.html?client_secret=${clientSecret}&payment_method_types[]=card,apple_pay";
      
      return stripeUrl;
    } catch (e) {
      print("❌ Erreur lors de la récupération des données de paiement : $e");
      return null;
    }
  }

  /// 🔹 Récupère le montant en euros selon le plan
  static int _getAmount(String plan) {
    // Utiliser les niveaux d'abonnement définis
    switch (plan.toLowerCase()) {
      case "gratuit":
        return 0;
      case "starter":
        return 500; // 5,00 €
      case "pro":
        return 1000; // 10,00 €
      case "legend":
        return 1500; // 15,00 €
      // Compatibilité avec l'ancien système
      case "bronze":
        return 500; // 5,00 €
      case "silver":
        return 1000; // 10,00 €
      case "gold":
        return 1500; // 15,00 €
      default:
        return 0; // Plan inconnu
    }
  }

  /// 🔹 Récupère les informations d'un niveau d'abonnement
  static Map<String, dynamic> getPlanInfo(String plan) {
    final planKey = plan.toLowerCase();
    if (subscriptionTiers.containsKey(planKey)) {
      return subscriptionTiers[planKey]!;
    }
    
    // Fallback pour l'ancien système
    switch (planKey) {
      case "bronze":
        return subscriptionTiers['starter']!;
      case "silver":
        return subscriptionTiers['pro']!;
      case "gold":
        return subscriptionTiers['legend']!;
      default:
        return subscriptionTiers['gratuit']!;
    }
  }
}

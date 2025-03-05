import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart'; // ✅ Pour ouvrir Stripe sur Web & Mobile
import '../screens/utils.dart';
import 'storage_service.dart'; // ✅ Service de stockage
import 'webview_stripe_page.dart'; // ✅ Import de la WebView pour Stripe


class PaymentService {
  final _storageService = StorageService();

  static Future<void> initialize() async {
    await StorageService.initStorage();
    // Additional initialization code...
  }

  /// 🔹 Initialisation du stockage
  static Future<void> initStorage() async {
    await StorageService.initStorage();
  }

  /// 🔹 Processus de paiement via Stripe Checkout
  static Future<bool> processPayment(BuildContext context, String plan, String producerId) async {
    try {
      final int amount = _getAmount(plan);
      if (amount == 0) {
        print("❌ Plan invalide : $plan");
        return false;
      }

      print("📤 Envoi de la requête de paiement pour $plan à $amount centimes...");

      // 🔹 Vérifie que le stockage est initialisé
      await initStorage();

      // 🔹 Appelle le backend pour obtenir une session Stripe Checkout
      final String? checkoutUrl = await _getCheckoutUrl(amount, producerId);
      if (checkoutUrl == null) {
        print("❌ Erreur : URL Checkout non reçue.");
        return false;
      }

      print("✅ URL Checkout reçue : $checkoutUrl");

      // 🔹 Ouvrir Stripe Checkout en fonction de la plateforme
      if (kIsWeb) {
        print("🌍 Redirection vers Stripe Checkout Web...");
        await launchUrl(Uri.parse(checkoutUrl), mode: LaunchMode.externalApplication);
      } else {
        print("📱 Ouverture de Stripe Checkout en WebView...");
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => WebViewStripePage(url: checkoutUrl),
          ),
        );
      }

      print("🎉 Paiement terminé ou annulé !");
      return true;
    } catch (e) {
      print("❌ Erreur Stripe : $e");
      return false;
    }
  }

  /// 🔹 Récupérer dynamiquement l'URL Stripe Checkout depuis le backend
  static Future<String?> _getCheckoutUrl(int amount, String producerId) async {
    try {
      final url = Uri.parse("${getBaseUrl()}/api/subscription/create-checkout-session");

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "amount": amount,
          "currency": "eur",
          "producerId": producerId
        }),
      );

      if (response.statusCode != 200) {
        print("❌ Erreur backend paiement : ${response.body}");
        return null;
      }

      final checkoutSession = json.decode(response.body);
      return checkoutSession['checkout_url'];
    } catch (e) {
      print("❌ Erreur lors de la récupération de l'URL Checkout : $e");
      return null;
    }
  }

  /// 🔹 Récupère le montant en centimes selon le plan
  static int _getAmount(String plan) {
    switch (plan.toLowerCase()) {
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
}

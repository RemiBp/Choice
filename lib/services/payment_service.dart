import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/material.dart';  // Pour utiliser Colors et Color

class PaymentService {
  static const _storage = FlutterSecureStorage(); // 🔹 Stockage sécurisé

  /// 🔹 Processus de paiement avec Stripe
  static Future<bool> processPayment(String plan, String producerId) async {
    try {
      final int amount = _getAmount(plan);

      if (amount == 0) {
        print("❌ Plan invalide : $plan");
        return false;
      }

      print("📤 Envoi de la requête de paiement pour $plan à $amount centimes...");

      // 🔹 Appelle le backend pour obtenir un `client_secret`
      final String? clientSecret = await _getClientSecret(amount, producerId);
      if (clientSecret == null) {
        print("❌ Erreur : client_secret non reçu.");
        return false;
      }

      print("✅ Client secret reçu : $clientSecret");

      // 🔹 Initialisation du PaymentSheet
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          merchantDisplayName: "Choice App",
          paymentIntentClientSecret: clientSecret, // ✅ Utilisation dynamique
          appearance: PaymentSheetAppearance(
            colors: PaymentSheetAppearanceColors(
              primary: Color(0xFF007AFF), // Bleu Stripe
              background: Colors.white, // Fond blanc
            ),
          ),
        ),
      );

      print("✅ PaymentSheet prêt, ouverture...");

      // 🔹 Présenter le PaymentSheet
      await Stripe.instance.presentPaymentSheet();

      print("🎉 Paiement réussi !");

      // 🔹 Supprime le `client_secret` après un paiement réussi
      await _storage.delete(key: "stripe_client_secret");

      return true;
    } catch (e) {
      print("❌ Erreur Stripe : $e");

      // 🔹 Supprime le `client_secret` en cas d'échec pour éviter d'utiliser une ancienne session
      await _storage.delete(key: "stripe_client_secret");

      // 🔹 Gérer les erreurs Stripe spécifiques
      if (e is StripeException) {
        print("💡 Détails erreur Stripe : ${e.error.localizedMessage}");
      }

      return false;
    }
  }

  /// 🔹 Récupérer dynamiquement le `client_secret` depuis le backend
  static Future<String?> _getClientSecret(int amount, String producerId) async {
    try {
      final url = Uri.parse("http://10.0.2.2:5000/api/subscription/create-payment-intent");

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

      final paymentIntent = json.decode(response.body);
      return paymentIntent['client_secret'];
    } catch (e) {
      print("❌ Erreur lors de la récupération du client_secret : $e");
      return null;
    }
  }

  /// 🔹 Récupère le montant en centimes selon le plan
  static int _getAmount(String plan) {
    switch (plan.toLowerCase()) {
      case "bronze":
        return 5; // 5,00 €
      case "silver":
        return 10; // 10,00 €
      case "gold":
        return 15; // 15,00 €
      default:
        return 0; // Plan inconnu
    }
  }
}

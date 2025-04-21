import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart'; // ✅ Pour ouvrir Stripe sur Web & Mobile
import '../utils/constants.dart' as constants;
import 'storage_service.dart'; // ✅ Service de stockage
import 'webview_stripe_page.dart'; // ✅ Import de la WebView pour Stripe
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:intl/intl.dart';

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
        _showErrorDialog(context, "Plan invalide", "Le plan sélectionné n'est pas valide. Veuillez réessayer.");
        return false;
      }
      
      // Si le plan est gratuit, pas de paiement nécessaire
      if (plan.toLowerCase() == 'gratuit') {
        print("✅ Plan gratuit sélectionné, pas de paiement nécessaire");
        // Mettre à jour le statut d'abonnement gratuit dans le backend
        await _updateFreeSubscription(producerId);
        _showSuccessDialog(context, "Abonnement Gratuit Activé", "Votre abonnement gratuit a été activé avec succès.");
        return true;
      }

      print("📤 Envoi de la requête de paiement pour $plan à $amount centimes...");

      // 🔹 Vérifie que le stockage est initialisé
      await initStorage();

      // 🔹 Appelle le backend pour obtenir une session Stripe Checkout
      final String? checkoutUrl = await _getCheckoutUrl(amount, producerId, plan);
      if (checkoutUrl == null) {
        print("❌ Erreur : URL Checkout non reçue.");
        _showErrorDialog(context, "Erreur de paiement", "Impossible d'initialiser le paiement. Veuillez vérifier votre connexion et réessayer.");
        return false;
      }

      print("✅ URL Checkout reçue : $checkoutUrl");

      // 🔹 Ouvrir Stripe Checkout en fonction de la plateforme (avec support Apple Pay)
      bool paymentSuccess = false;
      
      if (kIsWeb) {
        print("🌍 Redirection vers Stripe Checkout Web...");
        final launched = await launchUrl(Uri.parse(checkoutUrl), mode: LaunchMode.externalApplication);
        
        if (!launched) {
          _showErrorDialog(context, "Erreur de navigation", "Impossible d'ouvrir la page de paiement. Veuillez vérifier vos paramètres de navigateur.");
          return false;
        }
        
        // Sur le web, nous ne pouvons pas suivre le résultat directement
        // Affichons une boîte de dialogue pour confirmer le paiement
        paymentSuccess = await _showWebPaymentConfirmDialog(context);
      } else {
        print("📱 Ouverture de Stripe Checkout en WebView (avec support Apple Pay)...");
        try {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => WebViewStripePage(url: checkoutUrl),
            ),
          );
          
          // Le résultat sera true si le paiement a réussi, false sinon
          paymentSuccess = result == true;
        } catch (e) {
          print("❌ Erreur lors de l'ouverture de la WebView: $e");
          _showErrorDialog(context, "Erreur de paiement", "Impossible d'afficher la page de paiement: $e");
          return false;
        }
      }
      
      if (paymentSuccess) {
        // Si le paiement a réussi, mettre à jour les informations d'abonnement
        await _updateSubscriptionAfterPayment(producerId, plan);
        
        // Afficher une boîte de dialogue de succès avec les détails de l'abonnement
        _showSubscriptionSuccessDialog(context, plan);
        return true;
      } else {
        print("❌ Paiement annulé ou échoué");
        return false;
      }
    } catch (e) {
      print("❌ Erreur Stripe : $e");
      _showErrorDialog(context, "Erreur de paiement", "Une erreur s'est produite: $e");
      return false;
    }
  }

  /// 🔹 Mise à jour de l'abonnement gratuit directement
  static Future<bool> _updateFreeSubscription(String producerId) async {
    try {
      final url = Uri.parse("${constants.getBaseUrl()}/api/subscription/update-free-tier");
      
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
      final url = Uri.parse("${constants.getBaseUrl()}/api/subscription/create-payment-intent");

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

  // Créer un intent de paiement pour un achat
  Future<Map<String, dynamic>> createPaymentIntent({
    required String amount,
    required String currency,
    String? customerId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${constants.getBaseUrl()}/api/payment/create-payment-intent'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'amount': amount,
          'currency': currency,
          'customerId': customerId,
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Erreur lors de la création de l\'intent de paiement');
      }
    } catch (e) {
      print('❌ Erreur lors de la création de l\'intent de paiement: $e');
      rethrow;
    }
  }

  // Créer un client Stripe
  Future<Map<String, dynamic>> createCustomer({
    required String email,
    String? name,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${constants.getBaseUrl()}/api/payments/create-customer'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'name': name,
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Erreur lors de la création du client Stripe');
      }
    } catch (e) {
      print('❌ Erreur lors de la création du client Stripe: $e');
      rethrow;
    }
  }

  // Effectuer un paiement via Stripe
  Future<void> makePayment({
    required String amount,
    required String currency,
    String? customerId,
    required Function onSuccess,
    required Function(String) onError,
  }) async {
    try {
      // Créer l'intent de paiement
      final paymentIntentData = await createPaymentIntent(
        amount: amount,
        currency: currency,
        customerId: customerId,
      );

      // Configurer la feuille de paiement
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: paymentIntentData['clientSecret'],
          merchantDisplayName: 'Choice App',
          customerId: customerId,
          customerEphemeralKeySecret: paymentIntentData['ephemeralKey'],
          style: ThemeMode.dark,
          // Configuration d'Apple Pay
          applePay: PaymentSheetApplePay(
            merchantCountryCode: 'FR',
          ),
          // Configuration de Google Pay
          googlePay: PaymentSheetGooglePay(
            merchantCountryCode: 'FR',
            testEnv: true, // Mettre à false en production
          ),
          returnURL: 'choiceapp://stripe-redirect',
        ),
      );

      // Afficher la feuille de paiement
      await Stripe.instance.presentPaymentSheet();

      // Paiement réussi
      onSuccess();
    } catch (e) {
      if (e is StripeException) {
        onError('Erreur Stripe: ${e.error.localizedMessage}');
      } else {
        onError('Erreur inattendue: $e');
      }
    }
  }
  
  // Récupérer les niveaux d'abonnement disponibles
  Future<List<Map<String, dynamic>>> getSubscriptionLevels() async {
    try {
      final response = await http.get(
        Uri.parse('${constants.getBaseUrl()}/api/subscription/levels'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['levels']);
      } else {
        throw Exception('Erreur lors de la récupération des niveaux d\'abonnement');
      }
    } catch (e) {
      print('❌ Erreur lors de la récupération des niveaux d\'abonnement: $e');
      rethrow;
    }
  }
  
  // Récupérer l'abonnement actuel d'un producteur
  Future<Map<String, dynamic>> getCurrentSubscription(String producerId) async {
    try {
      final response = await http.get(
        Uri.parse('${constants.getBaseUrl()}/api/subscription/producer/$producerId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Erreur lors de la récupération de l\'abonnement actuel');
      }
    } catch (e) {
      print('❌ Erreur lors de la récupération de l\'abonnement actuel: $e');
      rethrow;
    }
  }
  
  // Changer le niveau d'abonnement d'un producteur
  Future<Map<String, dynamic>> changeSubscription({
    required String producerId,
    required String newLevel,
    required String customerId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${constants.getBaseUrl()}/api/subscription/change-subscription'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'producerId': producerId,
          'newSubscriptionLevel': newLevel,
          'customerId': customerId,
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error'] ?? 'Erreur lors du changement d\'abonnement');
      }
    } catch (e) {
      print('❌ Erreur lors du changement d\'abonnement: $e');
      rethrow;
    }
  }
  
  // Obtenir les fonctionnalités disponibles pour un niveau d'abonnement
  Future<List<Map<String, dynamic>>> getFeaturesForLevel(String level) async {
    try {
      final response = await http.get(
        Uri.parse('${constants.getBaseUrl()}/api/subscription/features/$level'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['features']);
      } else {
        throw Exception('Erreur lors de la récupération des fonctionnalités');
      }
    } catch (e) {
      print('❌ Erreur lors de la récupération des fonctionnalités pour $level: $e');
      rethrow;
    }
  }
  
  // Vérifier si une fonctionnalité est disponible pour l'abonnement actuel
  Future<bool> isFeatureAvailable({
    required String producerId, 
    required String featureId
  }) async {
    try {
      final response = await http.get(
        Uri.parse('${constants.getBaseUrl()}/api/subscription/producer/$producerId/feature/$featureId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['available'] ?? false;
      } else {
        return false;
      }
    } catch (e) {
      print('❌ Erreur lors de la vérification de la disponibilité de la fonctionnalité: $e');
      return false;
    }
  }
  
  // Récupérer l'historique des abonnements d'un producteur
  Future<List<Map<String, dynamic>>> getSubscriptionHistory(String producerId) async {
    try {
      final response = await http.get(
        Uri.parse('${constants.getBaseUrl()}/api/subscription/producer/$producerId/history'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['history']);
      } else {
        throw Exception('Erreur lors de la récupération de l\'historique des abonnements');
      }
    } catch (e) {
      print('❌ Erreur lors de la récupération de l\'historique des abonnements: $e');
      rethrow;
    }
  }
  
  // Annuler un abonnement
  Future<void> cancelSubscription(String producerId) async {
    try {
      final response = await http.post(
        Uri.parse('${constants.getBaseUrl()}/api/subscription/producer/$producerId/cancel'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode != 200) {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error'] ?? 'Erreur lors de l\'annulation de l\'abonnement');
      }
    } catch (e) {
      print('❌ Erreur lors de l\'annulation de l\'abonnement: $e');
      rethrow;
    }
  }

  /// Mettre à jour l'abonnement après un paiement réussi
  static Future<void> _updateSubscriptionAfterPayment(String producerId, String plan) async {
    try {
      final url = Uri.parse("${constants.getBaseUrl()}/api/subscription/update");
      
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "producerId": producerId,
          "plan": plan
        }),
      );

      if (response.statusCode != 200) {
        print("❌ Erreur mise à jour abonnement: ${response.body}");
      } else {
        print("✅ Abonnement mis à jour avec succès");
      }
    } catch (e) {
      print("❌ Erreur lors de la mise à jour de l'abonnement: $e");
    }
  }

  /// Affiche une boîte de dialogue de confirmation pour les paiements web
  static Future<bool> _showWebPaymentConfirmDialog(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmation de paiement'),
        content: const Text('Avez-vous complété le paiement avec succès ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Non, paiement annulé'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Oui, paiement réussi'),
            style: TextButton.styleFrom(foregroundColor: Colors.green),
          ),
        ],
      ),
    ) ?? false;
  }
  
  /// Affiche une boîte de dialogue de réussite pour l'abonnement
  static void _showSubscriptionSuccessDialog(BuildContext context, String plan) {
    final Map<String, dynamic> planInfo = getPlanInfo(plan);
    final List<String> features = List<String>.from(planInfo['features'] ?? []);
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 10),
            Text('Félicitations !', style: TextStyle(color: Colors.green[700])),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Votre abonnement ${planInfo['name']} a été activé avec succès !',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Text('Fonctionnalités disponibles :'),
              SizedBox(height: 8),
              ...features.map((feature) => Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check, color: Colors.green, size: 16),
                    SizedBox(width: 8),
                    Expanded(child: Text(feature, style: TextStyle(fontSize: 14))),
                  ],
                ),
              )),
              SizedBox(height: 16),
              Text(
                'Votre abonnement sera renouvelé automatiquement à la fin du mois.',
                style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12, color: Colors.grey[700]),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  /// Affiche une boîte de dialogue de succès
  static void _showSuccessDialog(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 10),
            Text(title, style: TextStyle(color: Colors.green[700])),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Affiche une boîte de dialogue d'erreur
  static void _showErrorDialog(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: TextStyle(color: Colors.red[700])),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // Récupérer l'historique des transactions d'un producteur
  Future<Map<String, dynamic>> getTransactionHistory(String producerId) async {
    try {
      final response = await http.get(
        Uri.parse('${constants.getBaseUrl()}/api/payments/transaction-history/$producerId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Erreur lors de la récupération de l\'historique des transactions');
      }
    } catch (e) {
      print('❌ Erreur lors de la récupération de l\'historique des transactions: $e');
      rethrow;
    }
  }

  // Formater un abonnement pour l'affichage
  String formatSubscriptionLevel(String level) {
    switch (level.toLowerCase()) {
      case 'gratuit':
        return 'Gratuit';
      case 'starter':
        return 'Starter';
      case 'pro':
        return 'Pro';
      case 'legend':
        return 'Legend';
      default:
        return level;
    }
  }

  // Obtenir la couleur associée à un niveau d'abonnement
  Color getSubscriptionColor(String level) {
    switch (level.toLowerCase()) {
      case 'gratuit':
        return Colors.grey;
      case 'starter':
        return Colors.blue;
      case 'pro':
        return Colors.indigo;
      case 'legend':
        return Colors.amber.shade800;
      default:
        return Colors.grey;
    }
  }

  // Obtenir l'icône associée à un niveau d'abonnement
  IconData getSubscriptionIcon(String level) {
    switch (level.toLowerCase()) {
      case 'gratuit':
        return Icons.card_giftcard;
      case 'starter':
        return Icons.star;
      case 'pro':
        return Icons.verified;
      case 'legend':
        return Icons.workspace_premium;
      default:
        return Icons.card_giftcard;
    }
  }

  // Formater une date pour l'affichage
  String formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('dd/MM/yyyy - HH:mm').format(date);
    } catch (e) {
      return dateString;
    }
  }

  // Formater le statut d'une transaction pour l'affichage
  String formatTransactionStatus(String status) {
    switch (status.toLowerCase()) {
      case 'succeeded':
        return 'Réussie';
      case 'pending':
        return 'En attente';
      case 'failed':
        return 'Échouée';
      case 'refunded':
        return 'Remboursée';
      default:
        return status;
    }
  }

  // Obtenir la couleur associée au statut d'une transaction
  Color getTransactionStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'succeeded':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'failed':
        return Colors.red;
      case 'refunded':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}

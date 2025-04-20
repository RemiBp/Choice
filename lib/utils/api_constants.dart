// Constantes pour l'API

/// Retourne l'URL de base pour les requêtes API
/// Version simplifiée qui convient à tous les environnements
String getBaseUrl() {
  // Force l'URL de production dans tous les environnements
  return 'https://api.choiceapp.fr';  // URL de production
}

// Constantes de clés pour le stockage local
const String userDataKey = 'user_data';
const String tokenKey = 'token';
const String subscriptionKey = 'subscription_data';

// Paramètres de timeouts pour les appels API
const int apiTimeoutSeconds = 30;

// Endpoints API
class ApiEndpoints {
  // Auth
  static const String login = '/api/auth/login';
  static const String register = '/api/auth/register';
  static const String refreshToken = '/api/auth/refresh-token';
  static const String verifyEmail = '/api/auth/verify-email';
  static const String resetPassword = '/api/auth/reset-password';
  
  // Utilisateurs
  static const String userProfile = '/api/users/';
  
  // Subscriptions
  static const String subscriptionInfo = '/api/subscription/producer/';
  static const String checkFeatureAccess = '/api/subscription/check-feature-access';
  static const String subscriptionLevels = '/api/subscription/levels';
  static const String featuresForLevel = '/api/subscription/features/';
  
  // Paiements
  static const String createPaymentIntent = '/api/payment/create-payment-intent';
  static const String createCustomer = '/api/payment/create-customer';
}

// Headers par défaut
Map<String, String> getDefaultHeaders(String? token) {
  final headers = {
    'Content-Type': 'application/json',
  };
  
  if (token != null) {
    headers['Authorization'] = 'Bearer $token';
  }
  
  return headers;
} 
// Configuration pour les APIs et services externes
class ApiConfig {
  // Pour toutes les requêtes API
  static String baseUrl = 'https://api.choiceapp.fr';
  
  // Pour les connexions socket
  static String socketUrl = 'https://api.choiceapp.fr';
  
  // Pour les fichiers médias
  static String mediaUrl = 'https://api.choiceapp.fr/uploads';
  
  // Endpoint pour l'authentification
  static String loginEndpoint = '/api/auth/login';
  static String registerEndpoint = '/api/auth/register';
  static String refreshTokenEndpoint = '/api/auth/refresh';
  
  // Endpoint pour les utilisateurs
  static String usersEndpoint = '/api/users';
  static String searchUsersEndpoint = '/api/users/search';
  static String searchAllEndpoint = '/api/search';
  static String unifiedSearchEndpoint = '/api/unified/search';
  
  // Endpoint pour les conversations
  static String conversationsEndpoint = '/api/conversations';
  static String messagesEndpoint = '/api/messages';
  
  // Endpoint pour les uploads
  static String uploadEndpoint = '/api/upload';
  
  // Timeout en secondes
  static const int timeout = 30;
} 
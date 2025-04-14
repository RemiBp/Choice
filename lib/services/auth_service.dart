import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../utils/constants.dart' as constants;
import 'dart:async'; // Ajout de l'import pour TimeoutException
import '../utils/utils.dart';

class AuthService extends ChangeNotifier {
  String? _userId;
  String? _accountType;
  bool _isAuthenticated = false;
  String? _photoUrl;
  List<String> _likedTags = [];
  bool _hasCompletedOnboarding = false;
  String? _token;

  bool get isAuthenticated => _isAuthenticated;
  String? get userId => _userId;
  String? get accountType => _accountType;
  String? get photoUrl => _photoUrl;
  List<String> get likedTags => _likedTags;
  bool get hasCompletedOnboarding => _hasCompletedOnboarding;
  String? get token => _token;

  // Singleton pattern
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  // Define TOKEN_KEY constant
  static const String TOKEN_KEY = 'userToken';

  // Getters for public access
  set userId(String? value) {
    _userId = value;
    notifyListeners();
  }
  
  set accountType(String? value) {
    _accountType = value;
    notifyListeners();
  }
  
  set token(String? value) {
    _token = value;
    notifyListeners();
  }

  // Initialize auth state from storage and validate the session
  Future<void> initializeAuth() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString('userId');
    _accountType = prefs.getString('accountType');
    _isAuthenticated = _userId != null;
    _photoUrl = prefs.getString('photoUrl');
    _likedTags = prefs.getStringList('likedTags') ?? [];
    _hasCompletedOnboarding = prefs.getBool('hasCompletedOnboarding') ?? false;
    _token = prefs.getString('userToken');
    
    // If we have a stored user ID, validate it
    if (_isAuthenticated && _accountType != 'guest') {
      try {
        final isValid = await validateSession();
        if (!isValid) {
          // If the session is invalid, clear auth data
          _userId = null;
          _accountType = null;
          _isAuthenticated = false;
          _photoUrl = null;
          _likedTags = [];
          _hasCompletedOnboarding = false;
          await prefs.remove('userId');
          await prefs.remove('accountType');
          await prefs.remove('photoUrl');
          await prefs.remove('likedTags');
          await prefs.remove('hasCompletedOnboarding');
          await prefs.remove('userToken');
        }
      } catch (e) {
        print('Auth initialization error: $e');
        // Keep the user logged in if we can't validate (for offline use)
      }
    }
    
    notifyListeners();
  }

  // Complete onboarding process
  Future<Map<String, dynamic>> completeOnboarding(
      String userId, String? photoUrl, List<String> likedTags, bool allowContactsAccess) async {
    try {
      print('📱 Starting onboarding completion for user $userId');
      
      final token = await _getToken();
      final url = Uri.parse('${constants.getBaseUrl()}/api/newuser/$userId/onboarding');
      
      // Prepare the request body
      final Map<String, dynamic> body = {
        'liked_tags': likedTags,
        'contacts_permission_granted': allowContactsAccess,
      };
      
      // Add photo URL if provided 
      if (photoUrl != null && photoUrl.isNotEmpty) {
        body['photo_url'] = photoUrl;
      }
      
      print('📤 Sending onboarding data: ${json.encode(body)}');
      
      // Make the request
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': token ?? '',
        },
        body: json.encode(body),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ Onboarding completed successfully: ${response.body}');
        
        // Update local state
        _likedTags = likedTags;
        _photoUrl = photoUrl;
        _hasCompletedOnboarding = true;
        
        // Save to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        prefs.setStringList('likedTags', _likedTags);
        if (_photoUrl != null) prefs.setString('photoUrl', _photoUrl!);
        prefs.setBool('hasCompletedOnboarding', true);
        
        // Save token
        if (token != null) {
          await prefs.setString('userToken', token);
        }
        
        notifyListeners();
        return {
          'success': true,
          'message': 'Onboarding completed successfully',
        };
      } else {
        print('❌ Onboarding failed: ${response.statusCode} - ${response.body}');
        return {
          'success': false,
          'message': 'Failed to complete onboarding: ${response.statusCode}'
        };
      }
    } catch (e) {
      print('❌ Error during onboarding: $e');
      return {
        'success': false,
        'message': 'Error during onboarding: $e'
      };
    }
  }
  
  // Méthode privée pour récupérer le token depuis SharedPreferences
  Future<String?> _getToken() async {
    try {
      // Vérifier d'abord si nous avons déjà le token en mémoire
      if (_token != null && _token!.isNotEmpty) {
        print('📋 _getToken: Utilisation du token mis en cache');
        return _token;
      }
      
      // Si le token n'est pas en mémoire, le récupérer depuis SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      
      // Essayer d'abord avec la clé 'token'
      String? token = prefs.getString('token');
      
      // Si token est null, essayer avec 'userToken' (pour la compatibilité)
      if (token == null || token.isEmpty) {
        token = prefs.getString('userToken');
        
        // Si on trouve un token avec 'userToken', le migrer vers 'token' pour standardiser
        if (token != null && token.isNotEmpty) {
          print('🔄 _getToken: Migrating token from "userToken" to "token"');
          await prefs.setString('token', token);
        }
      }
      
      // Mettre à jour le token en mémoire
      _token = token;
      
      if (token != null && token.isNotEmpty) {
        print('✅ _getToken: Token obtenu depuis SharedPreferences: ${token.substring(0, 10)}...');
      } else {
        print('⚠️ _getToken: Aucun token trouvé dans SharedPreferences');
      }
      
      return token;
    } catch (e) {
      print('❌ _getToken: Erreur lors de la récupération du token: $e');
      return null;
    }
  }

  // Sauvegarder le token dans SharedPreferences
  Future<bool> _saveToken(String? token) async {
    try {
      if (token == null || token.isEmpty) {
        print('⚠️ _saveToken: Token null ou vide, suppression du token');
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('token');
        await prefs.remove('userToken');
        _token = null;
        return true;
      }
      
      final prefs = await SharedPreferences.getInstance();
      
      // Sauvegarder sous les deux clés pour assurer la compatibilité
      await prefs.setString('token', token);
      await prefs.setString('userToken', token);
      
      // Mettre à jour le token en mémoire
      _token = token;
      
      print('✅ _saveToken: Token sauvegardé avec succès');
      return true;
    } catch (e) {
      print('❌ _saveToken: Erreur lors de la sauvegarde du token: $e');
      return false;
    }
  }

  /// Récupère le token d'authentification
  Future<String?> getTokenInstance({bool forceRefresh = false}) async {
    if (forceRefresh) {
      // Tenter de rafraîchir le token
      await refreshToken();
    }
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(TOKEN_KEY);
      
      if (token == null || token.isEmpty) {
        print('⚠️ Aucun token disponible dans getTokenInstance');
        _isAuthenticated = false;
        notifyListeners();
        return null;
      }
      
      // Vérifier la validité du token (optionnel)
      if (_checkTokenExpiration(token)) {
        print('⚠️ Token expiré dans getTokenInstance');
        // Tentative de rafraîchissement
        await refreshToken();
        // Retourner le nouveau token ou null
        return prefs.getString(TOKEN_KEY);
      }
      
      return token;
    } catch (e) {
      print('❌ Erreur dans getTokenInstance: $e');
      return null;
    }
  }
  
  // Check if token is expired
  bool _checkTokenExpiration(String token) {
    try {
      // Implement token expiration check logic here
      // For now, we return false to assume token is not expired
      return false;
    } catch (e) {
      print('❌ Erreur lors de la vérification de l\'expiration du token: $e');
      return false;
    }
  }
  
  // Refresh token method
  Future<bool> refreshToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final refreshToken = prefs.getString('refreshToken');
      
      if (refreshToken == null || refreshToken.isEmpty) {
        print('⚠️ Refresh token not available');
        return false;
      }
      
      final response = await http.post(
        Uri.parse('${constants.getBaseUrl()}/api/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'refreshToken': refreshToken}),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final String? newToken = data['token'];
        
        if (newToken != null && newToken.isNotEmpty) {
          await prefs.setString(TOKEN_KEY, newToken);
          print('✅ Token refreshed successfully');
          return true;
        }
      }
      
      print('❌ Failed to refresh token: ${response.statusCode}');
      return false;
    } catch (e) {
      print('❌ Error refreshing token: $e');
      return false;
    }
  }
  
  // Static method to get the token from anywhere in the app
  static Future<String> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(TOKEN_KEY);
    if (token == null || token.isEmpty) {
      throw Exception('No token available');
    }
    return token;
  }
  
  // Login with support for onboarding redirection
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      // Clear any existing guest session first
      final wasGuest = _accountType == 'guest';
      if (wasGuest) {
        await _clearSession();
      }
      
      // Utiliser la même route que pour l'enregistrement mais avec login endpoint
      final response = await http.post(
        Uri.parse('${constants.getBaseUrl()}/api/newuser/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Debug the response structure
        print('📦 Login response: ${response.body}');
        
        // Properly extract user ID from the response
        String? newUserId;
        if (data['user'] != null && data['user']['_id'] != null) {
          newUserId = data['user']['_id'].toString();
        } else if (data['userId'] != null) {
          newUserId = data['userId'].toString();
        }
        
        if (newUserId == null || newUserId.isEmpty) {
          print('❌ Login response missing user ID');
          return {'success': false, 'message': 'User ID not found in response'};
        }
        
        // Extract token
        final String? token = data['token'];
        if (token == null || token.isEmpty) {
          print('⚠️ Login response missing token');
          // Continue anyway as user ID was found
        } else {
          print('🔑 Token received: $token');
        }
        
        // Store the user data
        _userId = newUserId;
        _accountType = data['accountType'] ?? 'user'; // Par défaut utilisateur si non spécifié
        _isAuthenticated = true;
        
        // Extract additional user data if available
        if (data['user'] != null) {
          _photoUrl = data['user']['photo_url'];
          if (data['user']['liked_tags'] != null) {
            _likedTags = List<String>.from(data['user']['liked_tags']);
          }
          _hasCompletedOnboarding = data['user']['onboarding_completed'] == true;
        }

        print('🔐 Login successful - User ID: $_userId, Account type: $_accountType');

        // Save to persistent storage
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userId', _userId!);
        await prefs.setString('accountType', _accountType!);
        
        // Save token if available
        await _saveToken(token);
        
        // Save additional user data
        if (_photoUrl != null) await prefs.setString('photoUrl', _photoUrl!);
        await prefs.setStringList('likedTags', _likedTags);
        await prefs.setBool('hasCompletedOnboarding', _hasCompletedOnboarding);

        // Add detailed login debug information
        print('✅ Authentication summary:');
        print('- User ID: $_userId');
        print('- Account type: $_accountType');
        print('- Token stored: ${token != null}');
        print('- Authentication state: $_isAuthenticated');
        print('- Photo URL: $_photoUrl');
        print('- Liked tags: $_likedTags');
        print('- Completed onboarding: $_hasCompletedOnboarding');
        
        // Ensure UI gets updated with correct user state
        notifyListeners();
        print('✅ notifyListeners() called - UI should update now');
        
        return {
          'success': true,
          'userId': _userId,
          'needsOnboarding': !_hasCompletedOnboarding,
        };
      }
      print('Login failed with status: ${response.statusCode}, body: ${response.body}');
      return {'success': false, 'message': 'Login failed'};
    } catch (e) {
      print('Login error: $e');
      return {'success': false, 'message': 'Login error: $e'};
    }
  }

  // Login as guest with updated return type
  Future<Map<String, dynamic>> loginAsGuest() async {
    try {
      // Créer un ID utilisateur invité unique basé sur le timestamp
      final guestId = 'guest-${DateTime.now().millisecondsSinceEpoch}';
      _userId = guestId;
      _accountType = 'guest'; // Type de compte spécial pour les invités
      _isAuthenticated = true;
      _hasCompletedOnboarding = true; // Guests don't need onboarding

      // Enregistrer dans le stockage persistant
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userId', _userId!);
      await prefs.setString('accountType', _accountType!);
      await prefs.setBool('hasCompletedOnboarding', true);

      notifyListeners();
      
      // Guests don't need onboarding
      return {
        'success': true,
        'userId': _userId,
        'needsOnboarding': false,
      };
    } catch (e) {
      print('Guest login error: $e');
      return {'success': false, 'message': 'Guest login error: $e'};
    }
  }
  
  // Register a new user with onboarding support
  Future<Map<String, dynamic>> register(String name, String email, String password, {String? gender, List<String>? likedTags}) async {
    try {
      final response = await http.post(
        Uri.parse('${constants.getBaseUrl()}/api/newuser/register-or-recover'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'name': name,
          'email': email,
          'password': password,
          'gender': gender,
          'liked_tags': likedTags ?? [],
        }),
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        
        // Debug the response structure
        print('📦 Registration response: ${response.body}');
        
        // Extract user ID
        String? newUserId;
        if (data['user'] != null && data['user']['_id'] != null) {
          newUserId = data['user']['_id'].toString();
        }
        
        if (newUserId == null || newUserId.isEmpty) {
          print('❌ Registration response missing user ID');
          return {'success': false, 'message': 'User ID not found in response'};
        }
        
        // Extract token
        final String? token = data['token'];
        if (token == null || token.isEmpty) {
          print('⚠️ Registration response missing token');
        } else {
          print('🔑 Token received: $token');
        }
        
        // Store the user data
        _userId = newUserId;
        _accountType = 'user'; // New registrations are always user accounts
        _isAuthenticated = true;
        _hasCompletedOnboarding = false; // New users need onboarding
        
        // Get initial data if available
        if (data['user'] != null) {
          _photoUrl = data['user']['photo_url'];
          if (likedTags != null) {
            _likedTags = likedTags;
          } else if (data['user']['liked_tags'] != null) {
            _likedTags = List<String>.from(data['user']['liked_tags']);
          }
        }

        // Save to persistent storage
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userId', _userId!);
        await prefs.setString('accountType', _accountType!);
        await prefs.setBool('hasCompletedOnboarding', false);
        if (_photoUrl != null) await prefs.setString('photoUrl', _photoUrl!);
        await prefs.setStringList('likedTags', _likedTags);
        
        // Save token if available
        await _saveToken(token);
        
        // New users always need onboarding
        notifyListeners();
        
        return {
          'success': true,
          'userId': _userId,
          'needsOnboarding': true, // New users always need onboarding
        };
      }
      
      print('Registration failed with status: ${response.statusCode}, body: ${response.body}');
      
      // Handle specific error cases
      if (response.statusCode == 400) {
        final data = json.decode(response.body);
        if (data['error'] == 'Email already exists') {
          return {'success': false, 'message': 'Cet email est déjà utilisé'};
        }
      }
      
      return {'success': false, 'message': 'L\'inscription a échoué'};
    } catch (e) {
      print('Registration error: $e');
      return {'success': false, 'message': 'Erreur d\'inscription: $e'};
    }
  }
  
  // Helper method to clear the current session
  Future<void> _clearSession() async {
    _userId = null;
    _accountType = null;
    _isAuthenticated = false;
    _photoUrl = null;
    _likedTags = [];
    _hasCompletedOnboarding = false;
    _token = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userId');
    await prefs.remove('accountType');
    await prefs.remove('userToken'); // Also clear the token
    await prefs.remove('photoUrl');
    await prefs.remove('likedTags');
    await prefs.remove('hasCompletedOnboarding');
    
    print('🧹 Session cleared: userId, accountType, and token removed from storage');
    // We don't notify listeners here as the login method will do that
  }

  // Logout
  Future<void> logout() async {
    // Use the same session clearing logic
    await _clearSession();
    // Notify listeners for UI update
    notifyListeners();
  }

  // Check if session is valid with better error handling
  Future<bool> validateSession() async {
    try {
      // Obtenir l'URL de base
      final baseUrl = await constants.getBaseUrl();
      String token = await getToken();
      
      if (token == null || token.isEmpty) {
        print('❌ Token inexistant, session invalide');
        return false;
      }
      
      // Vérifier si le token est valide auprès du serveur
      final response = await http.get(
        Uri.parse('$baseUrl/api/auth/validate'),
        headers: {
          'Authorization': 'Bearer $token',
          'Connection': 'keep-alive'
        },
      ).timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          print('⏱️ Timeout lors de la validation de session');
          // En cas de timeout, on considère la session comme valide
          // pour permettre à l'utilisateur de continuer à utiliser l'app
          return http.Response('Timeout', 408);
        }
      );
      
      // Si le statut est positif, la session est valide
      final isValid = response.statusCode == 200;
      
      print(isValid 
        ? '✅ Session validée avec succès'
        : '⚠️ Session invalide: ${response.statusCode}');
      
      return isValid;
    } catch (e) {
      print('❌ Erreur lors de la validation de session: $e');
      // En cas d'erreur, on considère la session comme invalide
      return false;
    }
  }
  
  // Get current authentication status - useful for checking in UI
  bool isUserAuthenticated() {
    // Ajouter une méthode synchrone qui vérifie si _userId et le token sont disponibles
    final hasUserId = _userId != null && _userId!.isNotEmpty;
    final bool hasToken = _token != null && _token!.isNotEmpty;
    
    print('📊 AuthService.isUserAuthenticated: hasUserId=$hasUserId, hasToken=$hasToken');
    return hasUserId && hasToken;
  }
  
  // Check if userId is valid (non-empty string that isn't just whitespace)
  bool hasValidUserId() {
    return _userId != null && _userId!.trim().isNotEmpty;
  }

  // Méthode pour se connecter avec un ID de producteur (restaurant, leisure ou wellness)
  Future<Map<String, dynamic>> loginWithId(String producerId) async {
    try {
      // Clear any existing guest session first
      final wasGuest = _accountType == 'guest';
      if (wasGuest) {
        await _clearSession();
      }
      
      final String baseUrl = await constants.getBaseUrl();
      final response = await http.post(
        Uri.parse('${baseUrl}/api/producer/login-by-id'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'producerId': producerId,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Pour le debugging
        print('📦 LoginWithId response: ${response.body}');
        
        // Extraction de l'ID producteur
        final String? newUserId = producerId;
        
        if (newUserId == null || newUserId.isEmpty) {
          print('❌ Login response missing producer ID');
          return {'success': false, 'message': 'Producer ID not found'};
        }
        
        // Extraction du token s'il existe
        final String? token = data['token'];
        
        // Stockage des données producteur
        _userId = newUserId;
        _accountType = data['accountType'] ?? 'RestaurantProducer'; // Par défaut RestaurantProducer
        _isAuthenticated = true;
        
        print('🔐 Login successful with ID - Producer ID: $_userId, Account type: $_accountType');

        // Sauvegarde dans le stockage persistant
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userId', _userId!);
        await prefs.setString('accountType', _accountType!);
        
        // Sauvegarde du token s'il est disponible
        await _saveToken(token);
        
        // Mise à jour de l'UI
        notifyListeners();
        
        return {
          'success': true,
          'userId': _userId,
        };
      }
      
      print('Login with ID failed with status: ${response.statusCode}, body: ${response.body}');
      return {'success': false, 'message': 'Login with ID failed'};
    } catch (e) {
      print('Login with ID error: $e');
      return {'success': false, 'message': 'Login with ID error: $e'};
    }
  }

  // Initialize auth state from storage and validate the session
  Future<void> loadFromStorage() async {
    await initializeAuth();
  }
  
  // Initialize the service
  Future<void> initialize() async {
    await loadFromStorage();
    print('AuthService initialisé: User ID: $_userId, Type: $_accountType');
  }

  /// Mettre à jour le token dans les préférences
  Future<void> _storeTokenInPreferences(String? token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (token != null) {
        await prefs.setString('userToken', token);
      } else {
        await prefs.remove('userToken');
      }
    } catch (e) {
      print('Erreur lors du stockage du token: $e');
    }
  }

  /// Mettre à jour les informations de l'utilisateur
  Future<void> updateUserInfo({
    required String userId,
    required String accountType,
    required String token,
  }) async {
    _userId = userId;
    _accountType = accountType;
    _token = token;
    
    await _storeTokenInPreferences(token);
    
    notifyListeners();
  }

  // Force l'initialisation du token si nécessaire
  Future<String?> ensureTokenAvailable() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('userToken');
      
      // Log détaillé pour le debug
      if (token == null || token.isEmpty) {
        print('⚠️ AuthService.ensureTokenAvailable: Token absent des SharedPreferences');
      } else {
        print('✅ AuthService.ensureTokenAvailable: Token trouvé dans SharedPreferences: ${token.substring(0, 10)}...');
      }
      
      // Si le token existe, vérifier sa validité
      if (token != null && token.isNotEmpty) {
        // Vérifier si le token est toujours valide
        bool isValid = await _validateToken(token);
        if (isValid) {
          print('✅ AuthService.ensureTokenAvailable: Token validé avec succès');
          return token;
        } else {
          print('⚠️ AuthService.ensureTokenAvailable: Token invalide, tentative de rafraîchissement');
          // Tenter de rafraîchir le token
          return await _refreshToken();
        }
      }
      
      // Si aucun token n'est trouvé, tenter de se connecter automatiquement
      return await _autoLogin();
    } catch (e) {
      print('❌ AuthService.ensureTokenAvailable: Erreur lors de la vérification du token: $e');
      return null;
    }
  }

  // Méthode pour vérifier la validité d'un token
  Future<bool> _validateToken(String token) async {
    try {
      final response = await http.get(
        Uri.parse('${constants.getBaseUrl()}/api/auth/validate-token'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json'
        },
      );
      
      return response.statusCode == 200;
    } catch (e) {
      print('❌ AuthService._validateToken: Erreur lors de la validation du token: $e');
      return false;
    }
  }

  // Méthode pour rafraîchir le token automatiquement
  Future<String?> _refreshToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final refreshToken = prefs.getString('refreshToken');
      
      if (refreshToken == null || refreshToken.isEmpty) {
        print('⚠️ AuthService._refreshToken: Refresh token absent');
        return null;
      }
      
      final response = await http.post(
        Uri.parse('${constants.getBaseUrl()}/api/auth/refresh-token'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'refreshToken': refreshToken}),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final newToken = data['token'];
        
        // Sauvegarder le nouveau token
        await prefs.setString('userToken', newToken);
        
        print('✅ AuthService._refreshToken: Token rafraîchi avec succès');
        return newToken;
      } else {
        print('⚠️ AuthService._refreshToken: Échec du rafraîchissement du token: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ AuthService._refreshToken: Erreur lors du rafraîchissement du token: $e');
      return null;
    }
  }

  // Méthode pour tenter une connexion automatique
  Future<String?> _autoLogin() async {
    print('⚠️ AuthService._autoLogin: Tentative de reconnexion automatique');
    // Implémentation de la reconnexion automatique si possible
    return null;
  }

  /// Valide le token actuel ou déconnecte l'utilisateur si le token est invalide
  Future<bool> validateTokenOrLogout([BuildContext? context]) async {
    try {
      final token = await getTokenInstance();
      
      if (token == null || token.isEmpty) {
        print('⚠️ validateTokenOrLogout: Aucun token disponible pour validation');
        // Ne pas déconnecter immédiatement si le token est absent
        return false;
      }
      
      // Vérifier si le token est valide en faisant une requête simple
      try {
        final response = await http.get(
          Uri.parse('${constants.getBaseUrl()}/api/users/profile'),
          headers: {'Authorization': 'Bearer $token'},
        ).timeout(const Duration(seconds: 5));
        
        if (response.statusCode == 200) {
          print('✅ validateTokenOrLogout: Token validé avec succès');
          return true;
        } else if (response.statusCode == 401 || response.statusCode == 403) {
          // Uniquement déconnecter sur les erreurs explicites d'authentification
          print('⚠️ validateTokenOrLogout: Token invalide ou expiré (${response.statusCode})');
          await logout();
          
          // Rediriger vers la page de connexion seulement si explicitement demandé
          if (context != null && context.mounted) {
            Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
          }
          
          return false;
        } else {
          // Pour les autres codes d'erreur (400, 404, 500, etc.)
          // Ne pas déconnecter car l'erreur peut être côté serveur ou temporaire
          print('⚠️ validateTokenOrLogout: Erreur de serveur ou temporaire (${response.statusCode})');
          
          // Considérer le token comme valide pour éviter les déconnexions intempestives
          return true;
        }
      } catch (requestError) {
        // En cas d'erreur réseau, timeout, etc.
        print('⚠️ validateTokenOrLogout: Erreur de requête: $requestError');
        // Tolérer les erreurs réseau
        return true;
      }
    } catch (e) {
      print('❌ validateTokenOrLogout: Erreur lors de la validation du token: $e');
      // Ne pas déconnecter en cas d'erreur technique
      return true;
    }
  }
  
  /// Assure que l'utilisateur est connecté ou redirige vers la page de connexion
  Future<bool> ensureAuthenticated(BuildContext context) async {
    // Si un userId est présent, on considère l'utilisateur comme connecté
    // même en cas d'erreur temporaire de validation
    if (_userId != null && _userId!.isNotEmpty) {
      try {
        // Essayer de valider le token mais ne pas rediriger immédiatement en cas d'échec
        final isValid = await validateTokenOrLogout();
        // Retourner vrai même si la validation échoue pour éviter les déconnexions intempestives
        return true;
      } catch (e) {
        print('⚠️ ensureAuthenticated: Erreur de validation ignorée: $e');
        // Ne pas rediriger en cas d'erreur technique
        return true;
      }
    } else {
      // Aucun ID utilisateur, considéré comme non authentifié
      print('⚠️ ensureAuthenticated: Aucun ID utilisateur trouvé');
      
      // Naviguer vers la page de connexion seulement si nous sommes dans un contexte UI
      // et si la redirection est explicitement demandée
      if (context.mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      }
      
      return false;
    }
  }

  Future<String> getBaseUrl() async {
    // Utiliser la méthode statique de constants
    return constants.getBaseUrl();
  }

  Future<Map<String, dynamic>?> getUserById(String userId) async {
    try {
      final String baseUrl = await constants.getBaseUrl();
      final token = await getToken();

      final response = await http.get(
        Uri.parse('$baseUrl/api/users/$userId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        print('❌ Erreur lors de la récupération du profil utilisateur: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Exception lors de la récupération du profil utilisateur: $e');
      return null;
    }
  }
} 
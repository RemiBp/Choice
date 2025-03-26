import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../screens/utils.dart' show getBaseUrl;

class AuthService extends ChangeNotifier {
  String? _userId;
  String? _accountType;
  bool _isAuthenticated = false;
  String? _photoUrl;
  List<String> _likedTags = [];
  bool _hasCompletedOnboarding = false;

  bool get isAuthenticated => _isAuthenticated;
  String? get userId => _userId;
  String? get accountType => _accountType;
  String? get photoUrl => _photoUrl;
  List<String> get likedTags => _likedTags;
  bool get hasCompletedOnboarding => _hasCompletedOnboarding;

  // Singleton pattern
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  // Initialize auth state from storage and validate the session
  Future<void> initializeAuth() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString('userId');
    _accountType = prefs.getString('accountType');
    _isAuthenticated = _userId != null;
    _photoUrl = prefs.getString('photoUrl');
    _likedTags = prefs.getStringList('likedTags') ?? [];
    _hasCompletedOnboarding = prefs.getBool('hasCompletedOnboarding') ?? false;
    
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
      final url = Uri.parse('${getBaseUrl()}/api/newuser/$userId/onboarding');
      
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
  
  // Helper to get the stored JWT token
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
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
        Uri.parse('${getBaseUrl()}/api/newuser/login'),
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
        if (token != null && token.isNotEmpty) {
          await prefs.setString('token', token);
        }
        
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
        Uri.parse('${getBaseUrl()}/api/newuser/register-or-recover'),
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
        if (token != null && token.isNotEmpty) {
          await prefs.setString('token', token);
        }
        
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

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userId');
    await prefs.remove('accountType');
    await prefs.remove('token'); // Also clear the token
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
    if (!_isAuthenticated || _userId == null) return false;
    
    // Pour les utilisateurs invités, la session est toujours valide
    if (_accountType == 'guest') return true;

    try {
      final baseUrl = getBaseUrl();
      Uri url;
      
      if (baseUrl.startsWith('http://')) {
        final domain = baseUrl.replaceFirst('http://', '');
        url = Uri.http(domain, '/api/newuser/auth/check');
      } else if (baseUrl.startsWith('https://')) {
        final domain = baseUrl.replaceFirst('https://', '');
        url = Uri.https(domain, '/api/newuser/auth/check');
      } else {
        url = Uri.parse('$baseUrl/api/newuser/auth/check');
      }
      
      // Extract token from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      
      if (token == null) {
        print('❌ No token found in storage for validation');
        return false;
      }
      
      print('🔑 Validating session with token: $token');
      
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': token
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception("Request timeout"),
      );

      if (response.statusCode == 200) {
        // Update onboarding status if available
        try {
          final data = json.decode(response.body);
          if (data['user'] != null) {
            _hasCompletedOnboarding = data['user']['onboarding_completed'] == true;
            
            // Update SharedPreferences
            final prefs = await SharedPreferences.getInstance();
            prefs.setBool('hasCompletedOnboarding', _hasCompletedOnboarding);
          }
        } catch (e) {
          print('❌ Error parsing session validation response: $e');
        }
        return true;
      } else {
        print('Session invalid: ${response.statusCode} - ${response.body}');
        // If session is invalid, logout
        await logout();
        return false;
      }
    } catch (e) {
      print('Session validation error: $e');
      // Ne pas déconnecter en cas d'erreur réseau pour permettre le mode hors ligne
      return true;
    }
  }
  
  // Get current authentication status - useful for checking in UI
  bool isUserAuthenticated() {
    return _isAuthenticated && _userId != null;
  }
  
  // Check if userId is valid (non-empty string that isn't just whitespace)
  bool hasValidUserId() {
    return _userId != null && _userId!.trim().isNotEmpty;
  }
}
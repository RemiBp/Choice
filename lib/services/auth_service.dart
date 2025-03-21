import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../screens/utils.dart' show getBaseUrl;

class AuthService extends ChangeNotifier {
  String? _userId;
  String? _accountType;
  bool _isAuthenticated = false;

  bool get isAuthenticated => _isAuthenticated;
  String? get userId => _userId;
  String? get accountType => _accountType;

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
    
    // If we have a stored user ID, validate it
    if (_isAuthenticated && _accountType != 'guest') {
      try {
        final isValid = await validateSession();
        if (!isValid) {
          // If the session is invalid, clear auth data
          _userId = null;
          _accountType = null;
          _isAuthenticated = false;
          await prefs.remove('userId');
          await prefs.remove('accountType');
        }
      } catch (e) {
        print('Auth initialization error: $e');
        // Keep the user logged in if we can't validate (for offline use)
      }
    }
    
    notifyListeners();
  }

  // Login
  Future<bool> login(String email, String password) async {
    try {
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
        _userId = data['userId'] ?? data['user']?['_id'];
        _accountType = data['accountType'] ?? 'user'; // Par défaut utilisateur si non spécifié
        _isAuthenticated = true;

        // Save to persistent storage
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userId', _userId!);
        await prefs.setString('accountType', _accountType!);

        notifyListeners();
        return true;
      }
      print('Login failed with status: ${response.statusCode}, body: ${response.body}');
      return false;
    } catch (e) {
      print('Login error: $e');
      return false;
    }
  }

  // Login as guest
  Future<bool> loginAsGuest() async {
    try {
      // Créer un ID utilisateur invité unique basé sur le timestamp
      final guestId = 'guest-${DateTime.now().millisecondsSinceEpoch}';
      _userId = guestId;
      _accountType = 'guest'; // Type de compte spécial pour les invités
      _isAuthenticated = true;

      // Enregistrer dans le stockage persistant
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userId', _userId!);
      await prefs.setString('accountType', _accountType!);

      notifyListeners();
      return true;
    } catch (e) {
      print('Guest login error: $e');
      return false;
    }
  }

  // Logout
  Future<void> logout() async {
    _userId = null;
    _accountType = null;
    _isAuthenticated = false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userId');
    await prefs.remove('accountType');

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
        url = Uri.http(domain, '/api/newuser/validate');
      } else if (baseUrl.startsWith('https://')) {
        final domain = baseUrl.replaceFirst('https://', '');
        url = Uri.https(domain, '/api/newuser/validate');
      } else {
        url = Uri.parse('$baseUrl/api/newuser/validate');
      }
      
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'userId': _userId!
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception("Request timeout"),
      );

      if (response.statusCode == 200) {
        // Session is valid
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
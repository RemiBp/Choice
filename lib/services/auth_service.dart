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

  // Initialize auth state from storage
  Future<void> initializeAuth() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString('userId');
    _accountType = prefs.getString('accountType');
    _isAuthenticated = _userId != null;
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

  // Check if session is valid
  Future<bool> validateSession() async {
    if (!_isAuthenticated || _userId == null) return false;

    try {
      final response = await http.get(
        Uri.parse('${getBaseUrl()}/api/newuser/validate'),
        headers: {
          'Content-Type': 'application/json',
          'userId': _userId!
        },
      );

      if (response.statusCode == 200) {
        return true;
      }

      // If session is invalid, logout
      await logout();
      return false;
    } catch (e) {
      print('Session validation error: $e');
      // Ne pas déconnecter en cas d'erreur réseau pour permettre le mode hors ligne
      return true;
    }
  }
}
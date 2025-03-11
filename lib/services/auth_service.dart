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
      final response = await http.post(
        Uri.parse('${getBaseUrl()}/api/auth/login'),
        body: {
          'email': email,
          'password': password,
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _userId = data['userId'];
        _accountType = data['accountType'];
        _isAuthenticated = true;

        // Save to persistent storage
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userId', _userId!);
        await prefs.setString('accountType', _accountType!);

        notifyListeners();
        return true;
      }
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
        Uri.parse('${getBaseUrl()}/api/auth/validate'),
        headers: {'userId': _userId!},
      );

      if (response.statusCode == 200) {
        return true;
      }

      // If session is invalid, logout
      await logout();
      return false;
    } catch (e) {
      print('Session validation error: $e');
      return false;
    }
  }
}
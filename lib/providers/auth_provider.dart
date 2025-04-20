import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';
import '../utils/api_constants.dart' as constants;

class AuthProvider extends ChangeNotifier {
  UserModel? _user;
  String? _token;
  bool _isLoading = false;
  String? _error;

  // Getters
  UserModel? get user => _user;
  String? get token => _token;
  bool get isAuthenticated => _token != null;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Constructeur
  AuthProvider() {
    loadUserData();
  }
  
  // Charger les données utilisateur depuis le stockage local
  Future<void> loadUserData() async {
    setLoading(true);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString(constants.userDataKey);
      final storedToken = prefs.getString(constants.tokenKey);
      
      if (userJson != null && storedToken != null) {
        final Map<String, dynamic> userData = json.decode(userJson);
        _user = UserModel.fromJson(userData);
        _token = storedToken;
        notifyListeners();
      }
    } catch (e) {
      print('❌ Erreur lors du chargement des données utilisateur: $e');
      _error = e.toString();
    } finally {
      setLoading(false);
    }
  }
  
  // Connexion
  Future<bool> login(String email, String password) async {
    setLoading(true);
    _error = null;
    
    try {
      // Appel API pour la connexion
      final response = await _apiPost(
        '/api/auth/login',
        {
          'email': email,
          'password': password,
        },
      );
      
      if (response['token'] != null && response['user'] != null) {
        _token = response['token'];
        _user = UserModel.fromJson(response['user']);
        
        // Sauvegarder dans les préférences
        await _saveUserData();
        
        notifyListeners();
        return true;
      } else {
        throw Exception('Identifiants invalides');
      }
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      setLoading(false);
    }
  }
  
  // Inscription
  Future<bool> register(Map<String, dynamic> userData) async {
    setLoading(true);
    _error = null;
    
    try {
      // Appel API pour l'inscription
      final response = await _apiPost(
        '/api/auth/register',
        userData,
      );
      
      if (response['token'] != null && response['user'] != null) {
        _token = response['token'];
        _user = UserModel.fromJson(response['user']);
        
        // Sauvegarder dans les préférences
        await _saveUserData();
        
        notifyListeners();
        return true;
      } else {
        throw Exception('Erreur lors de l\'inscription');
      }
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      setLoading(false);
    }
  }
  
  // Déconnexion
  Future<void> logout() async {
    _user = null;
    _token = null;
    
    // Supprimer les données du stockage local
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(constants.userDataKey);
    await prefs.remove(constants.tokenKey);
    
    notifyListeners();
  }
  
  // Mise à jour du profil utilisateur
  Future<bool> updateProfile(Map<String, dynamic> userData) async {
    if (_user == null || _token == null) {
      _error = 'Utilisateur non connecté';
      return false;
    }
    
    setLoading(true);
    _error = null;
    
    try {
      // Appel API pour la mise à jour du profil
      final response = await _apiPut(
        '/api/users/${_user!.id}',
        userData,
      );
      
      if (response['user'] != null) {
        _user = UserModel.fromJson(response['user']);
        
        // Mettre à jour les données dans les préférences
        await _saveUserData();
        
        notifyListeners();
        return true;
      } else {
        throw Exception('Erreur lors de la mise à jour du profil');
      }
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      setLoading(false);
    }
  }

  // Mise à jour de l'ID client Stripe
  Future<bool> updateStripeCustomerId(String customerId) async {
    if (_user == null) {
      _error = 'Utilisateur non connecté';
      return false;
    }
    
    try {
      // Mise à jour de l'utilisateur avec le nouvel ID client Stripe
      _user = _user!.copyWith(stripeCustomerId: customerId);
      
      // Sauvegarde des données utilisateur mises à jour
      await _saveUserData();
      
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    }
  }
  
  // Réinitialisation du mot de passe
  Future<bool> resetPassword(String email) async {
    setLoading(true);
    _error = null;
    
    try {
      // Appel API pour la réinitialisation du mot de passe
      final response = await _apiPost(
        '/api/auth/reset-password',
        {'email': email},
      );
      
      if (response['success'] == true) {
        return true;
      } else {
        throw Exception('Erreur lors de la réinitialisation du mot de passe');
      }
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      setLoading(false);
    }
  }
  
  // Vérifier l'email
  Future<bool> verifyEmail(String code) async {
    if (_user == null || _token == null) {
      _error = 'Utilisateur non connecté';
      return false;
    }
    
    setLoading(true);
    _error = null;
    
    try {
      // Appel API pour la vérification de l'email
      final response = await _apiPost(
        '/api/auth/verify-email',
        {'code': code},
      );
      
      if (response['success'] == true) {
        // Mettre à jour l'état de vérification de l'email dans l'objet utilisateur
        _user = _user!.copyWith(isEmailVerified: true);
        
        // Mettre à jour les données dans les préférences
        await _saveUserData();
        
        notifyListeners();
        return true;
      } else {
        throw Exception('Code de vérification invalide');
      }
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      setLoading(false);
    }
  }
  
  // Enregistrer les données utilisateur dans les préférences
  Future<void> _saveUserData() async {
    if (_user == null || _token == null) return;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(constants.userDataKey, json.encode(_user!.toJson()));
    await prefs.setString(constants.tokenKey, _token!);
  }
  
  // Appel API POST
  Future<Map<String, dynamic>> _apiPost(String endpoint, Map<String, dynamic> data) async {
    final url = '${constants.getBaseUrl()}$endpoint';
    
    final headers = {
      'Content-Type': 'application/json',
      if (_token != null) 'Authorization': 'Bearer $_token',
    };
    
    final response = await http.post(
      Uri.parse(url),
      headers: headers,
      body: json.encode(data),
    );
    
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return json.decode(response.body);
    } else {
      final errorResponse = json.decode(response.body);
      throw Exception(errorResponse['message'] ?? 'Erreur de serveur');
    }
  }
  
  // Appel API PUT
  Future<Map<String, dynamic>> _apiPut(String endpoint, Map<String, dynamic> data) async {
    final url = '${constants.getBaseUrl()}$endpoint';
    
    final headers = {
      'Content-Type': 'application/json',
      if (_token != null) 'Authorization': 'Bearer $_token',
    };
    
    final response = await http.put(
      Uri.parse(url),
      headers: headers,
      body: json.encode(data),
    );
    
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return json.decode(response.body);
    } else {
      final errorResponse = json.decode(response.body);
      throw Exception(errorResponse['message'] ?? 'Erreur de serveur');
    }
  }
  
  // Définir l'état de chargement
  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
} 
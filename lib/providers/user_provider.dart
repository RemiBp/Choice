import 'package:flutter/material.dart';

class UserProvider extends ChangeNotifier {
  // État de connexion
  bool _isLoggedIn = false;
  
  // ID utilisateur
  String? _userId;
  
  // Nom utilisateur  
  String? _username;
  
  // Données basiques utilisateur
  Map<String, dynamic>? _userData;
  
  // Constructeur
  UserProvider({String? initialUserId}) {
    if (initialUserId != null) {
      _userId = initialUserId;
      _isLoggedIn = true;
      notifyListeners();
    }
  }
  
  // Getters
  bool get isLoggedIn => _isLoggedIn;
  String? get userId => _userId;
  String? get username => _username;
  Map<String, dynamic>? get userData => _userData;
  
  // Connexion utilisateur
  Future<bool> login(String email, String password) async {
    try {
      // TODO: Implémenter l'API de connexion
      // Temporairement, on simule une connexion réussie
      _isLoggedIn = true;
      _userId = "user_123";
      _username = "Utilisateur Test";
      _userData = {
        "id": _userId,
        "name": _username,
        "email": email,
      };
      
      notifyListeners();
      return true;
    } catch (e) {
      print('Erreur de connexion: $e');
      return false;
    }
  }
  
  // Déconnexion utilisateur
  Future<void> logout() async {
    _isLoggedIn = false;
    _userId = null;
    _username = null;
    _userData = null;
    
    notifyListeners();
  }
  
  // Récupérer les données utilisateur depuis le serveur
  Future<void> fetchUserData() async {
    if (!_isLoggedIn || _userId == null) return;
    
    try {
      // TODO: Implémenter l'API pour récupérer les données utilisateur
      // Pour l'instant, utiliser des données fictives
      _userData = {
        "id": _userId,
        "name": _username,
        "email": "user@example.com",
        "preferences": {
          "favoriteCategories": ["Restaurant", "Musée", "Cinéma"],
          "radius": 3000,
          "notifications": true
        }
      };
      
      notifyListeners();
    } catch (e) {
      print('Erreur lors de la récupération des données utilisateur: $e');
    }
  }
  
  // Mettre à jour les préférences utilisateur
  Future<bool> updatePreferences(Map<String, dynamic> preferences) async {
    if (!_isLoggedIn || _userId == null) return false;
    
    try {
      // TODO: Implémenter l'API pour mettre à jour les préférences
      // Pour l'instant, mettre à jour localement
      if (_userData != null && _userData!.containsKey('preferences')) {
        _userData!['preferences'] = {
          ..._userData!['preferences'],
          ...preferences
        };
      } else {
        _userData = {
          ...(_userData ?? {}),
          'preferences': preferences
        };
      }
      
      notifyListeners();
      return true;
    } catch (e) {
      print('Erreur lors de la mise à jour des préférences: $e');
      return false;
    }
  }
} 
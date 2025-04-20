import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/constants.dart' as constants;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class UserService {
  static final UserService _instance = UserService._internal();
  
  factory UserService() => _instance;
  
  UserService._internal();
  
  String? _currentUserId;
  Map<String, dynamic>? _currentUserData;
  
  String? get currentUserId => _currentUserId;
  Map<String, dynamic>? get currentUserData => _currentUserData;
  
  // Méthode pour obtenir l'URL de base
  String getBaseUrl() {
    return constants.getBaseUrlSync();
  }
  
  Future<void> init() async {
    await _loadUserFromPrefs();
  }
  
  // Rechercher des utilisateurs par nom ou username
  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    if (query.length < 2) {
      return [];
    }
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      
      final response = await http.get(
        Uri.parse('${getBaseUrl()}/api/conversations/search?query=$query'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['results'] != null) {
          return List<Map<String, dynamic>>.from(data['results']
            .where((item) => item['type'] == 'user')
            .map((user) => {
              'id': user['id'] ?? user['_id'] ?? '',
              'name': user['name'] ?? '',
              'username': user['username'] ?? user['name'] ?? '',
              'avatar': user['avatar'] ?? user['profilePicture'] ?? '',
              'type': 'user'
            }));
        }
        return [];
      } else {
        print('❌ Erreur lors de la recherche d\'utilisateurs: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ Exception lors de la recherche d\'utilisateurs: $e');
      return [];
    }
  }
  
  Future<void> _loadUserFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userData = prefs.getString('user_data');
      
      if (userData != null && userData.isNotEmpty) {
        _currentUserData = json.decode(userData);
        _currentUserId = _currentUserData?['_id'] ?? _currentUserData?['id'];
      }
    } catch (e) {
      print('❌ Error loading user data: $e');
    }
  }
  
  Future<bool> setCurrentUser(Map<String, dynamic> userData) async {
    try {
      _currentUserData = userData;
      _currentUserId = userData['_id'] ?? userData['id'];
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_data', json.encode(userData));
      return true;
    } catch (e) {
      print('❌ Error saving user data: $e');
      return false;
    }
  }
  
  Future<bool> logout() async {
    try {
      const storage = FlutterSecureStorage();
      await storage.delete(key: 'user_id');
      await storage.delete(key: 'token');
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_id');
      
      return true;
    } catch (e) {
      print('❌ Erreur lors de la déconnexion: $e');
      return false;
    }
  }
  
  Future<Map<String, dynamic>?> getUserProfile() async {
    if (_currentUserId == null) {
      return null;
    }
    
    try {
      final response = await http.get(
        Uri.parse('${getBaseUrl()}/api/users/$_currentUserId'),
      );
      
      if (response.statusCode == 200) {
        final userData = json.decode(response.body);
        _currentUserData = userData;
        return userData;
      } else {
        print('❌ Error fetching user profile: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Error fetching user profile: $e');
      return null;
    }
  }
  
  // Récupérer un utilisateur par ID
  Future<Map<String, dynamic>?> getUserById(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('${getBaseUrl()}/api/users/$userId'),
      );
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        print('❌ Erreur lors de la récupération du profil: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Exception lors de la récupération du profil: $e');
      return null;
    }
  }
} 
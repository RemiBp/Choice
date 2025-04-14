import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/api_config.dart';

class WellnessAuthService {
  final String baseUrl = '${ApiConfig.baseUrl}/api/wellness/auth';

  Future<String> register({
    required String name,
    required String email,
    required String password,
    required String phone,
    required String address,
    required String city,
    required String postalCode,
    required String category,
    required String sousCategory,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'name': name,
          'email': email,
          'password': password,
          'phone': phone,
          'address': address,
          'city': city,
          'postalCode': postalCode,
          'category': category,
          'sousCategory': sousCategory,
        }),
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        return data['token'];
      } else {
        throw Exception('Erreur lors de l\'inscription');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  Future<String> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final token = data['token'];
        
        // Sauvegarder le token
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('wellness_token', token);
        
        return token;
      } else {
        throw Exception('Email ou mot de passe incorrect');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('wellness_token');
    } catch (e) {
      throw Exception('Erreur lors de la déconnexion: $e');
    }
  }

  Future<String?> getToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('wellness_token');
    } catch (e) {
      return null;
    }
  }

  Future<bool> isLoggedIn() async {
    try {
      final token = await getToken();
      return token != null;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>> getProfile() async {
    try {
      final token = await getToken();
      if (token == null) {
        throw Exception('Non connecté');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/profile'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Erreur lors de la récupération du profil');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  Future<void> updateProfile(Map<String, dynamic> data) async {
    try {
      final token = await getToken();
      if (token == null) {
        throw Exception('Non connecté');
      }

      final response = await http.put(
        Uri.parse('$baseUrl/profile'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(data),
      );

      if (response.statusCode != 200) {
        throw Exception('Erreur lors de la mise à jour du profil');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  Future<void> changePassword(String currentPassword, String newPassword) async {
    try {
      final token = await getToken();
      if (token == null) {
        throw Exception('Non connecté');
      }

      final response = await http.put(
        Uri.parse('$baseUrl/change-password'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Erreur lors du changement de mot de passe');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }
} 
// Secure storage service: Handles secure storage of tokens
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static const _tokenKey = 'auth_token';
  static const _storage = FlutterSecureStorage();

  // Get authentication token from secure storage
  static Future<String?> getToken() async {
    try {
      return await _storage.read(key: _tokenKey);
    } catch (e) {
      print('❌ Error retrieving token: $e');
      return null;
    }
  }

  // Save authentication token to secure storage
  static Future<void> saveToken(String token) async {
    try {
      await _storage.write(key: _tokenKey, value: token);
    } catch (e) {
      print('❌ Error saving token: $e');
    }
  }

  // Delete authentication token from secure storage
  static Future<void> deleteToken() async {
    try {
      await _storage.delete(key: _tokenKey);
    } catch (e) {
      print('❌ Error deleting token: $e');
    }
  }
} 
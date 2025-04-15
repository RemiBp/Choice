// Placeholder Service: Represents the logic in the main user app
// for handling FCM token registration and saving.
// IMPLEMENT THE ACTUAL LOGIC IN YOUR MAIN USER APPLICATION.

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io' show Platform; // To get platform info
import '../utils/constants.dart' as constants;
import 'secure_storage_service.dart'; // Needed for auth token

class UserAppFcmService {

  /// Called on user login/app start to register the device token with the backend.
  static Future<void> registerDeviceAndSaveToken(String userId) async {
    print('📱 UserAppFcmService: Attempting to register FCM token for user $userId');
    try {
      // 1. Get FCM token
      String? fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken == null) {
        print('   ❌ UserAppFcmService: Failed to get FCM token.');
        return;
      }
      print('   ✅ UserAppFcmService: Obtained FCM Token: ...${fcmToken.substring(fcmToken.length - 6)}');

      // 2. Get Auth Token
      String? authToken = await SecureStorageService.getToken();
      if (authToken == null) {
        print('   ❌ UserAppFcmService: Auth token not found. Cannot register FCM token.');
        return;
      }

      // 3. Send token to backend
      final url = Uri.parse('${constants.getBaseUrl()}/api/notifications/register-token');
      final deviceInfo = {
        'platform': Platform.operatingSystem,
        'osVersion': Platform.operatingSystemVersion,
        // Add more device info if needed (e.g., model, app version)
      };

      print('   ⬆️ UserAppFcmService: Sending token to backend...');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: json.encode({
          'userId': userId, // Ensure backend uses this or reads from auth token
          'fcm_token': fcmToken,
          'deviceInfo': deviceInfo,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        print('   ✅ UserAppFcmService: FCM token saved to backend successfully.');
      } else {
        print('   ❌ UserAppFcmService: Failed to save FCM token to backend: ${response.statusCode} ${response.body}');
      }

    } catch (e) {
      print('   ❌ UserAppFcmService: Exception during FCM registration: $e');
    }
  }
} 
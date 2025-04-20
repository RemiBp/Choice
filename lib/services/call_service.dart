import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart' as constants;
// import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../config/api_config.dart';
import '../services/auth_service.dart';

// Version simplifiée du service d'appel pour la démo
class CallService {
  final AuthService _authService = AuthService();
  final String baseUrl;
  
  CallService({String? customBaseUrl}) : baseUrl = customBaseUrl ?? constants.getBaseUrlSync();
  
  // late IO.Socket _socket;
  bool _isConnected = false;
  
  // Callbacks à définir par les utilisateurs du service
  Function(Map<String, dynamic>)? onIncomingCall;
  Function(Map<String, dynamic>)? onCallAccepted;
  Function(Map<String, dynamic>)? onCallRejected;
  Function(Map<String, dynamic>)? onCallEnded;
  Function(Map<String, dynamic>)? onIceCandidate;
  Function(Map<String, dynamic>)? onOffer;
  Function(Map<String, dynamic>)? onAnswer;
  
  // Méthode pour obtenir le token (simulée si non disponible)
  Future<String> _getToken() async {
    try {
      final token = await _authService.getTokenInstance();
      if (token != null) {
        return token;
      }
      // Retourner un token fictif en cas d'échec
      return 'dummy_token';
    } catch (e) {
      print('Erreur lors de la récupération du token: $e');
      return 'dummy_token';
    }
  }
  
  // Initialiser la connexion socket
  Future<void> initSocket() async {
    try {
      final token = await _getToken();
      
      // Simuler une connexion socket réussie
      await Future.delayed(Duration(seconds: 1));
      
      _isConnected = true;
      print('Socket simulé connecté');
    } catch (e) {
      print('Erreur lors de l\'initialisation du socket: $e');
      throw Exception('Erreur de connexion socket: $e');
    }
  }
  
  // Initier un appel avec un autre utilisateur
  Future<Map<String, dynamic>> startCall(String callerId, String recipientId, bool isVideo) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      
      final response = await http.post(
        Uri.parse('$baseUrl/api/call/start'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'callerId': callerId,
          'recipientId': recipientId,
          'isVideo': isVideo,
        }),
      );
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to start call');
      }
    } catch (e) {
      throw Exception('Error starting call: $e');
    }
  }
  
  // Répondre à un appel entrant
  Future<Map<String, dynamic>> answerCall(String callId, bool accept) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      
      final response = await http.post(
        Uri.parse('$baseUrl/api/call/answer'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'callId': callId,
          'accept': accept,
        }),
      );
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to answer call');
      }
    } catch (e) {
      throw Exception('Error answering call: $e');
    }
  }
  
  // Terminer un appel en cours
  Future<Map<String, dynamic>> endCall(String callId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      
      final response = await http.post(
        Uri.parse('$baseUrl/api/call/end'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'callId': callId,
        }),
      );
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to end call');
      }
    } catch (e) {
      throw Exception('Error ending call: $e');
    }
  }
  
  // Envoyer un signal WebRTC
  Future<void> sendSignal(String callId, String from, String to, dynamic signal) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      
      final response = await http.post(
        Uri.parse('$baseUrl/api/call/signal'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'callId': callId,
          'from': from,
          'to': to,
          'signal': signal,
        }),
      );
      
      if (response.statusCode != 200) {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to send signal');
      }
    } catch (e) {
      throw Exception('Error sending signal: $e');
    }
  }
  
  // Récupérer un signal WebRTC
  Future<Map<String, dynamic>> getSignal(String callId, String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      
      final response = await http.get(
        Uri.parse('$baseUrl/api/call/signal/$callId/$userId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to get signal');
      }
    } catch (e) {
      throw Exception('Error getting signal: $e');
    }
  }
  
  // Obtenir le numéro de téléphone d'un utilisateur
  Future<String> getPhoneNumber(String userId) async {
    try {
      final token = await _getToken();
      
      // Dans une vraie implémentation:
      // final response = await http.get(
      //   Uri.parse('${ApiConfig.baseUrl}/api/users/$userId/phone'),
      //   headers: {
      //     'Authorization': 'Bearer $token',
      //   },
      // );
      
      // Pour la démo, retourner un numéro fictif
      return '+33 6 12 34 56 78';
    } catch (e) {
      print('Erreur lors de la récupération du numéro: $e');
      return '';
    }
  }
  
  // Fermer la connexion
  void dispose() {
    if (_isConnected) {
      _isConnected = false;
      print('Socket simulé déconnecté');
    }
  }
} 
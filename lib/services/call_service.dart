import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart'; // For kDebugMode
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../services/auth_service.dart'; // Assuming AuthService is correctly implemented
import '../utils/constants.dart' as constants; // For base URL

class CallService {
  final AuthService _authService = AuthService(); // Get instance of AuthService
  final String _baseUrl = constants.getBaseUrlSync(); // Get base URL synchronously
  IO.Socket? _socket;

  // StreamControllers to notify UI about call events
  final StreamController<Map<String, dynamic>> _incomingCallController = StreamController.broadcast();
  final StreamController<Map<String, dynamic>> _callEndedController = StreamController.broadcast();
  final StreamController<Map<String, dynamic>> _callAcceptedController = StreamController.broadcast(); // When recipient accepts
  final StreamController<Map<String, dynamic>> _callRejectedController = StreamController.broadcast(); // When recipient rejects
  final StreamController<Map<String, dynamic>> _participantJoinedController = StreamController.broadcast();
  final StreamController<Map<String, dynamic>> _participantLeftController = StreamController.broadcast();
  // Stream for WebRTC signaling messages (received from others)
  final StreamController<Map<String, dynamic>> _signalingController = StreamController.broadcast();


  // Streams for UI to listen to
  Stream<Map<String, dynamic>> get incomingCallStream => _incomingCallController.stream;
  Stream<Map<String, dynamic>> get callEndedStream => _callEndedController.stream;
  Stream<Map<String, dynamic>> get callAcceptedStream => _callAcceptedController.stream;
  Stream<Map<String, dynamic>> get callRejectedStream => _callRejectedController.stream;
  Stream<Map<String, dynamic>> get participantJoinedStream => _participantJoinedController.stream;
  Stream<Map<String, dynamic>> get participantLeftStream => _participantLeftController.stream;
  Stream<Map<String, dynamic>> get signalingStream => _signalingController.stream;

  // Flag to check connection status
  bool get isConnected => _socket?.connected ?? false;

  // Singleton pattern (optional, but often useful for services)
  static final CallService _instance = CallService._internal();
  factory CallService() => _instance;
  CallService._internal();

  Future<String?> _getToken() async {
    // Use AuthService to get the token
    return await _authService.getTokenInstance();
  }

  Future<String?> _getUserId() async {
    // Use AuthService to get the user ID
    return _authService.userId;
  }

  // Initialize WebSocket connection
  Future<void> initializeSocket() async {
    // Prevent multiple initializations
    if (_socket != null && _socket!.connected) {
      print('📞 CallService: Socket already initialized and connected.');
      return;
    }

    final token = await _getToken();
    final userId = await _getUserId();

    if (userId == null || userId.isEmpty) {
      print('❌ CallService: Cannot initialize socket without user ID.');
      return;
    }

    print('📞 CallService: Initializing WebSocket connection to $_baseUrl');
    try {
      _socket = IO.io(_baseUrl, <String, dynamic>{
        'transports': ['websocket'],
        'autoConnect': false, // Connect manually after setting up listeners
        'query': {
          'userId': userId, // Send user ID for identification on backend
          // Add token if your backend WebSocket auth needs it
          // 'token': token,
        },
        // Optional: Add reconnection options
        'reconnection': true,
        'reconnectionAttempts': 5,
        'reconnectionDelay': 1000,
      });

      // --- Register Socket Event Listeners ---
      _socket!.onConnect((_) {
        print('✅ CallService: WebSocket connected (ID: ${_socket?.id})');
        // Optionally join a user-specific room if needed
        // _socket!.emit('join_user_room', userId);
      });

      _socket!.onDisconnect((reason) {
        print('🔌 CallService: WebSocket disconnected (Reason: $reason)');
      });

      _socket!.onError((error) {
        print('❌ CallService: WebSocket Error: $error');
      });

      _socket!.onConnectError((error) {
        print('❌ CallService: WebSocket Connection Error: $error');
      });

      // --- Call Specific Event Listeners ---
      _socket!.on('incoming_call', (data) {
        print('📞 Received incoming_call: $data');
        if (data is Map<String, dynamic>) {
          _incomingCallController.add(data);
        }
      });

      _socket!.on('call_accepted', (data) {
         print('📞 Received call_accepted: $data');
         if (data is Map<String, dynamic>) {
             _callAcceptedController.add(data); // Notify UI that recipient accepted
         }
      });

      _socket!.on('call_rejected', (data) {
         print('📞 Received call_rejected: $data');
         if (data is Map<String, dynamic>) {
             _callRejectedController.add(data); // Notify UI that recipient rejected
         }
      });

      _socket!.on('call_ended', (data) {
        print('📞 Received call_ended: $data');
        if (data is Map<String, dynamic>) {
          _callEndedController.add(data);
        }
      });

      _socket!.on('participant_joined', (data) {
        print('📞 Received participant_joined: $data');
         if (data is Map<String, dynamic>) {
           _participantJoinedController.add(data);
         }
      });

      _socket!.on('participant_left', (data) {
         print('📞 Received participant_left: $data');
         if (data is Map<String, dynamic>) {
           _participantLeftController.add(data);
         }
      });

      _socket!.on('participant_declined', (data) {
         print('📞 Received participant_declined: $data');
         // Could reuse callRejected or have a specific handler
         if (data is Map<String, dynamic>) {
             _callRejectedController.add(data); 
         }
      });

      // --- WebRTC Signaling Listener ---
      _socket!.on('webrtc_signal', (data) {
         if (kDebugMode) {
            print('📡 Received webrtc_signal: ${data?['type']} from ${data?['fromUserId']}');
         }
         if (data is Map<String, dynamic>) {
           _signalingController.add(data);
         }
      });

      // --- End Listeners ---

      // Connect the socket
      _socket!.connect();

    } catch (e) {
      print('❌ CallService: Failed to initialize WebSocket: $e');
      _socket = null; // Ensure socket is null on error
    }
  }

  // Disconnect socket
  void disconnectSocket() {
    print('📞 CallService: Disconnecting WebSocket.');
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }

  // --- API Call Methods ---

  /// Initiate a new call (audio or video)
  Future<Map<String, dynamic>> initiateCall({
    String? conversationId,
    List<String>? recipientIds,
    String type = 'video', // 'audio' or 'video'
    Map<String, dynamic>? deviceInfo,
    bool useExternalProvider = false, // Flag for Twilio/Agora
  }) async {
    final token = await _getToken();
    final userId = await _getUserId(); // Get current user ID

    if (userId == null || userId.isEmpty) throw Exception("User not authenticated");
    if (token == null || token.isEmpty) throw Exception("Auth token missing");
    if (conversationId == null && (recipientIds == null || recipientIds.isEmpty)) {
      throw ArgumentError("Either conversationId or recipientIds must be provided.");
    }

    final url = Uri.parse('$_baseUrl/api/call/initiate');
    print('📞 CallService: Initiating call - POST $url');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'conversationId': conversationId,
          'recipientIds': recipientIds,
          'type': type,
          'deviceInfo': deviceInfo,
          'useExternalProvider': useExternalProvider,
          // Backend gets initiatorId from auth token
        }),
      );
      
      final responseBody = json.decode(response.body);

      if (response.statusCode == 201) {
        print('✅ CallService: Call initiated successfully: $responseBody');
        // Optionally join the call room immediately after initiating
        if (responseBody['success'] == true && responseBody['callId'] != null) {
           joinCallRoom(responseBody['callId']);
        }
        return responseBody;
      } else {
        print('❌ CallService: Failed to initiate call (${response.statusCode}): ${response.body}');
        throw Exception(responseBody['message'] ?? 'Failed to initiate call');
      }
    } catch (e) {
      print('❌ CallService: Error initiating call: $e');
      rethrow; // Rethrow the exception to be caught by the UI
    }
  }

  /// Join an existing call
  Future<Map<String, dynamic>> joinCall(String callId, {Map<String, dynamic>? deviceInfo}) async {
    final token = await _getToken();
    if (token == null || token.isEmpty) throw Exception("Auth token missing");

    final url = Uri.parse('$_baseUrl/api/call/join');
    print('📞 CallService: Joining call $callId - POST $url');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'callId': callId,
          'deviceInfo': deviceInfo,
        }),
      );

      final responseBody = json.decode(response.body);
      
      if (response.statusCode == 200) {
        print('✅ CallService: Joined call successfully: $responseBody');
         joinCallRoom(callId); // Join socket room on successful API call
        return responseBody;
      } else {
        print('❌ CallService: Failed to join call (${response.statusCode}): ${response.body}');
        throw Exception(responseBody['message'] ?? 'Failed to join call');
      }
    } catch (e) {
      print('❌ CallService: Error joining call: $e');
      rethrow;
    }
  }

  /// Decline an incoming call
  Future<void> declineCall(String callId, {String reason = 'declined'}) async {
    final token = await _getToken();
    if (token == null || token.isEmpty) throw Exception("Auth token missing");

    final url = Uri.parse('$_baseUrl/api/call/decline');
    print('📞 CallService: Declining call $callId - POST $url');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'callId': callId,
          'reason': reason,
        }),
      );

      final responseBody = json.decode(response.body);
      
      if (response.statusCode == 200) {
        print('✅ CallService: Call declined successfully.');
        // No return needed, success indicated by lack of exception
      } else {
        print('❌ CallService: Failed to decline call (${response.statusCode}): ${response.body}');
        throw Exception(responseBody['message'] ?? 'Failed to decline call');
      }
    } catch (e) {
      print('❌ CallService: Error declining call: $e');
      rethrow;
    }
  }

  /// End/Leave the current call
  Future<void> endCall(String callId) async {
    final token = await _getToken();
    if (token == null || token.isEmpty) throw Exception("Auth token missing");

    final url = Uri.parse('$_baseUrl/api/call/end');
    print('📞 CallService: Ending call $callId - POST $url');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'callId': callId,
        }),
      );
      
      final responseBody = json.decode(response.body);
      
      if (response.statusCode == 200) {
        print('✅ CallService: Call ended successfully.');
         leaveCallRoom(callId); // Leave socket room
        // No return needed
      } else {
        print('❌ CallService: Failed to end call (${response.statusCode}): ${response.body}');
        throw Exception(responseBody['message'] ?? 'Failed to end call');
      }
    } catch (e) {
      print('❌ CallService: Error ending call: $e');
      rethrow;
    }
  }

  // --- WebSocket Emit Methods ---

  /// Join the Socket.IO room for a specific call
  void joinCallRoom(String callId) {
    if (_socket != null && _socket!.connected) {
      print('🚪 CallService: Joining call room: call_$callId');
      _socket!.emit('join_call_room', callId);
    } else {
       print('⚠️ CallService: Cannot join call room - socket not connected.');
    }
  }

   /// Leave the Socket.IO room for a specific call
  void leaveCallRoom(String callId) {
    if (_socket != null && _socket!.connected) {
       print('🚪 CallService: Leaving call room: call_$callId');
      _socket!.emit('leave_call_room', callId);
    } else {
        print('⚠️ CallService: Cannot leave call room - socket not connected.');
    }
  }

  /// Send WebRTC signaling data (offer, answer, ICE candidate) via WebSocket
  void sendWebRTCSignal(String callId, String targetUserId, Map<String, dynamic> signalData) {
     if (_socket != null && _socket!.connected) {
       final userId = _authService.userId; // Get current user's ID
       if (userId == null) {
          print('❌ CallService: Cannot send signal - user ID not found.');
          return;
       }
       if (kDebugMode) {
         print('📡 CallService: Sending webrtc_signal to $targetUserId (Type: ${signalData['type']})');
       }
       _socket!.emit('webrtc_signal', {
         'callId': callId,
         'fromUserId': userId,
         'toUserId': targetUserId,
         'signal': signalData, // Contains type ('offer', 'answer', 'ice_candidate') and payload
       });
     } else {
       print('⚠️ CallService: Cannot send WebRTC signal - socket not connected.');
     }
   }

  // Dispose resources
  void dispose() {
    print('📞 CallService: Disposing...');
    disconnectSocket(); // Ensure socket is disconnected
    _incomingCallController.close();
    _callEndedController.close();
    _callAcceptedController.close();
    _callRejectedController.close();
    _participantJoinedController.close();
    _participantLeftController.close();
    _signalingController.close();
  }
} 
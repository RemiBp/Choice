import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../config/api_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SocketService {
  static final SocketService _instance = SocketService._internal();
  IO.Socket? _socket;
  bool _isConnected = false;
  final String _baseUrl = ApiConfig.baseUrl;
  
  // Streams for various events
  final _onConnectController = StreamController<void>.broadcast();
  final _onDisconnectController = StreamController<void>.broadcast();
  final _onNewMessageController = StreamController<Map<String, dynamic>>.broadcast();
  final _onTypingController = StreamController<Map<String, dynamic>>.broadcast();
  final _onMessageReadController = StreamController<Map<String, dynamic>>.broadcast();
  final _onMessageReactionController = StreamController<Map<String, dynamic>>.broadcast();
  
  // Stream getters
  Stream<void> get onConnect => _onConnectController.stream;
  Stream<void> get onDisconnect => _onDisconnectController.stream;
  Stream<Map<String, dynamic>> get onNewMessage => _onNewMessageController.stream;
  Stream<Map<String, dynamic>> get onTyping => _onTypingController.stream;
  Stream<Map<String, dynamic>> get onMessageRead => _onMessageReadController.stream;
  Stream<Map<String, dynamic>> get onMessageReaction => _onMessageReactionController.stream;
  
  // Private constructor
  SocketService._internal();
  
  // Factory constructor
  factory SocketService() {
    return _instance;
  }
  
  bool get isConnected => _isConnected;
  IO.Socket? get socket => _socket;
  
  // Initialize and connect socket
  Future<void> init({String? userId}) async {
    if (_socket != null) {
      print('Socket already initialized');
      return;
    }
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      
      print('🔌 Initializing socket connection to $_baseUrl');
      
      // Handle different URL formats
      var socketUrl = _baseUrl;
      if (socketUrl.endsWith('/')) {
        socketUrl = socketUrl.substring(0, socketUrl.length - 1);
      }
      
      _socket = IO.io(
        socketUrl,
        IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .enableForceNew()
          .setExtraHeaders({'Authorization': 'Bearer $token'})
          .setQuery({'userId': userId ?? ''})
          .build()
      );
      
      _setupEventListeners();
      _socket!.connect();
      
      print('🔌 Socket connection attempt initiated');
    } catch (e) {
      print('❌ Error initializing socket: $e');
    }
  }
  
  // Setup socket event listeners
  void _setupEventListeners() {
    _socket!.on('connect', (_) {
      print('🔌 Socket connected');
      _isConnected = true;
      _onConnectController.add(null);
    });
    
    _socket!.on('disconnect', (_) {
      print('🔌 Socket disconnected');
      _isConnected = false;
      _onDisconnectController.add(null);
    });
    
    _socket!.on('error', (error) {
      print('❌ Socket error: $error');
    });
    
    _socket!.on('connecting', (_) {
      print('🔌 Socket connecting...');
    });
    
    _socket!.on('connect_error', (error) {
      print('❌ Socket connect error: $error');
    });
    
    // Custom event listeners
    _socket!.on('new_message', (data) {
      print('📩 New message received via socket');
      if (data is Map) {
        _onNewMessageController.add(Map<String, dynamic>.from(data));
      }
    });
    
    _socket!.on('typing', (data) {
      if (data is Map) {
        _onTypingController.add(Map<String, dynamic>.from(data));
      }
    });
    
    _socket!.on('messages_read', (data) {
      if (data is Map) {
        _onMessageReadController.add(Map<String, dynamic>.from(data));
      }
    });
    
    _socket!.on('message_reaction', (data) {
      if (data is Map) {
        _onMessageReactionController.add(Map<String, dynamic>.from(data));
      }
    });
  }
  
  // Join a specific conversation room
  void joinConversation(String conversationId) {
    if (_socket != null && _isConnected) {
      _socket!.emit('join_conversation', {'conversationId': conversationId});
      print('🔌 Joined conversation room: $conversationId');
    } else {
      print('❌ Cannot join conversation: socket not connected');
    }
  }
  
  // Leave a specific conversation room
  void leaveConversation(String conversationId) {
    if (_socket != null && _isConnected) {
      _socket!.emit('leave_conversation', {'conversationId': conversationId});
      print('🔌 Left conversation room: $conversationId');
    }
  }
  
  // Send typing status
  void sendTypingStatus(String conversationId, String userId, bool isTyping) {
    if (_socket != null && _isConnected) {
      _socket!.emit('typing', {
        'conversationId': conversationId,
        'userId': userId,
        'isTyping': isTyping
      });
    }
  }
  
  // Disconnect socket
  void disconnect() {
    if (_socket != null) {
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
      _isConnected = false;
      print('🔌 Socket disconnected and disposed');
    }
  }
  
  // Cleanup resources
  void dispose() {
    disconnect();
    _onConnectController.close();
    _onDisconnectController.close();
    _onNewMessageController.close();
    _onTypingController.close();
    _onMessageReadController.close();
    _onMessageReactionController.close();
  }
} 
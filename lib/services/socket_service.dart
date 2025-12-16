

import 'dart:async';
import 'dart:convert';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:shared_preferences/shared_preferences.dart';

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  IO.Socket? _socket;
  bool _isConnected = false;

  // Stream controllers for events that your provider expects
  final StreamController<bool> _connectionController = StreamController<bool>.broadcast();
  final StreamController<Map<String, dynamic>> _newMessageController = StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _messageDeletedController = StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _messageEditedController = StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _readStatusController = StreamController<Map<String, dynamic>>.broadcast();

  // Streams that your provider expects
  Stream<bool> get onConnectionChanged => _connectionController.stream;
  Stream<Map<String, dynamic>> get onNewMessage => _newMessageController.stream;
  Stream<Map<String, dynamic>> get onMessageDeleted => _messageDeletedController.stream;
  Stream<Map<String, dynamic>> get onMessageEdited => _messageEditedController.stream;
  Stream<Map<String, dynamic>> get onReadStatusUpdated => _readStatusController.stream;

  bool get isConnected => _isConnected;

  Future<bool> connect() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      final userId = prefs.getString('user_id');

      if (token == null || userId == null) {
        print('❗ Cannot connect socket: missing token/userId');
        return false;
      }

      // Use your WebSocket URL from constants
      const String socketUrl = "wss://api.ixes.ai";

      _socket = IO.io(
        socketUrl,
        IO.OptionBuilder()
            .setTransports(['websocket'])
            .setQuery({'token': token, 'userId': userId})
            .disableAutoConnect()
            .build(),
      );

      // Setup connection callbacks
      _socket!.onConnect((_) {
        print("✅ Connected to socket server");
        _isConnected = true;
        _connectionController.add(true);
        _socket!.emit("joinUser", userId);
      });

      _socket!.onDisconnect((_) {
        print("❌ Disconnected from socket server");
        _isConnected = false;
        _connectionController.add(false);
      });

      _socket!.onError((data) {
        print("💥 Socket error: $data");
        _isConnected = false;
        _connectionController.add(false);
      });

      // Connect
      _socket!.connect();

      // Setup event listeners
      _setupEventListeners();

      return true;
    } catch (e) {
      print("💥 Socket connection error: $e");
      _isConnected = false;
      _connectionController.add(false);
      return false;
    }
  }

  void _setupEventListeners() {
    if (_socket == null) return;

    // Listen for incoming messages - matches API documentation
    _socket!.on("receiveMessage", (data) {
      try {
        final Map<String, dynamic> messageData =
        data is String ? jsonDecode(data) : Map<String, dynamic>.from(data);
        print("📩 Received message via socket: $messageData");
        _newMessageController.add({'message': messageData});
      } catch (e) {
        print("Error parsing receiveMessage: $e");
      }
    });

    _socket!.on("receiveVoiceMessage", (data) {
      try {
        final Map<String, dynamic> messageData =
        data is String ? jsonDecode(data) : Map<String, dynamic>.from(data);
        print("🎤 Received voice message via socket: $messageData");
        _newMessageController.add({'message': messageData});
      } catch (e) {
        print("Error parsing receiveVoiceMessage: $e");
      }
    });

    _socket!.on("receiveFileMessage", (data) {
      try {
        final Map<String, dynamic> messageData =
        data is String ? jsonDecode(data) : Map<String, dynamic>.from(data);
        print("📁 Received file message via socket: $messageData");
        _newMessageController.add({'message': messageData});
      } catch (e) {
        print("Error parsing receiveFileMessage: $e");
      }
    });

    // Listen for message deletions
    _socket!.on("messageDeleted", (data) {
      try {
        final Map<String, dynamic> deleteData =
        data is String ? jsonDecode(data) : Map<String, dynamic>.from(data);
        print("🗑️ Message deleted via socket: $deleteData");
        _messageDeletedController.add(deleteData);
      } catch (e) {
        print("Error parsing messageDeleted: $e");
      }
    });

    // Listen for message edits
    _socket!.on("messageEdited", (data) {
      try {
        final Map<String, dynamic> editData =
        data is String ? jsonDecode(data) : Map<String, dynamic>.from(data);
        print("✏️ Message edited via socket: $editData");
        _messageEditedController.add(editData);
      } catch (e) {
        print("Error parsing messageEdited: $e");
      }
    });

    // Listen for read status updates
    _socket!.on("readStatusUpdated", (data) {
      try {
        final Map<String, dynamic> readData =
        data is String ? jsonDecode(data) : Map<String, dynamic>.from(data);
        print("👁️ Read status updated via socket: $readData");
        _readStatusController.add(readData);
      } catch (e) {
        print("Error parsing readStatusUpdated: $e");
      }
    });

    print('🎯 Socket event listeners setup complete');
  }

  // Methods that your service calls
  Future<Map<String, dynamic>> sendMessage({
    required String receiverId,
    required String text,
    bool readBy = false,
    String? image,
    String? replayTo,
  }) async {
    if (!_isConnected || _socket == null) {
      return {
        'error': true,
        'message': 'Socket not connected',
      };
    }

    try {
      // Create message data
      final messageData = {
        'receiverId': receiverId,
        'text': text,
        'readBy': readBy,
        'timestamp': DateTime.now().toIso8601String(),
        if (image != null) 'image': image,
        if (replayTo != null) 'replayTo': replayTo,
      };

      // Emit via socket
      _socket!.emit('sendMessage', messageData);

      // Create mock response since socket doesn't return response immediately
      return {
        'error': false,
        'message': 'Message sent via socket',
        'data': {
          'message': {
            '_id': 'temp_${DateTime.now().millisecondsSinceEpoch}',
            'senderId': (await SharedPreferences.getInstance()).getString('user_id'),
            'receiverId': receiverId,
            'text': text,
            'readBy': readBy,
            'createdAt': DateTime.now().toIso8601String(),
            'status': 'sent',
            if (image != null) 'image': image,
            if (replayTo != null) 'replayTo': replayTo,
          }
        }
      };
    } catch (e) {
      return {
        'error': true,
        'message': 'Error sending message via socket: $e',
      };
    }
  }

  Future<Map<String, dynamic>> sendVoiceMessage({
    required String receiverId,
    required String audioPath,
    bool readBy = false,
    String? image,
  }) async {
    // Voice/file uploads typically need HTTP API since socket.io doesn't handle files well
    // Return error to force HTTP fallback
    return {
      'error': true,
      'message': 'Voice message via socket not implemented - use HTTP fallback',
    };
  }

  Future<Map<String, dynamic>> sendFileMessage({
    required String receiverId,
    required String filePath,
    required String fileName,
    required String fileType,
    bool readBy = false,
  }) async {
    // File uploads typically need HTTP API since socket.io doesn't handle files well
    // Return error to force HTTP fallback
    return {
      'error': true,
      'message': 'File message via socket not implemented - use HTTP fallback',
    };
  }

  Future<Map<String, dynamic>> updateReadStatus({
    required String senderId,
    required String receiverId,
  }) async {
    if (!_isConnected || _socket == null) {
      return {
        'error': true,
        'message': 'Socket not connected',
      };
    }

    try {
      // Emit the correct event name from API documentation
      _socket!.emit('updatereadBy', {
        'senderId': senderId,
        'receiverId': receiverId,
      });

      print('👁️ Read status event emitted via socket');

      return {
        'error': false,
        'message': 'Read status updated via socket',
      };
    } catch (e) {
      return {
        'error': true,
        'message': 'Error updating read status via socket: $e',
      };
    }
  }

  Future<Map<String, dynamic>> deleteMessage({
    required String messageId,
    required String receiverId,
  }) async {
    if (!_isConnected || _socket == null) {
      return {
        'error': true,
        'message': 'Socket not connected',
      };
    }

    try {
      // Emit the correct event name from API documentation
      _socket!.emit('deleteMessage', {
        'messageId': messageId,
        'receiverId': receiverId,
      });

      print('🗑️ Delete message event emitted via socket');

      return {
        'error': false,
        'message': 'Message deleted via socket',
      };
    } catch (e) {
      return {
        'error': true,
        'message': 'Error deleting message via socket: $e',
      };
    }
  }

  Future<Map<String, dynamic>> editMessage({
    required String messageId,
    required String newText,
    required String receiverId,
  }) async {
    if (!_isConnected || _socket == null) {
      return {
        'error': true,
        'message': 'Socket not connected',
      };
    }

    try {
      // Emit the correct event name from API documentation
      _socket!.emit('editMessage', {
        'messageId': messageId,
        'newText': newText,
        'receiverId': receiverId,
      });

      print('✏️ Edit message event emitted via socket');

      return {
        'error': false,
        'message': 'Message edited via socket',
      };
    } catch (e) {
      return {
        'error': true,
        'message': 'Error editing message via socket: $e',
      };
    }
  }

  void joinConversation(String userId, String receiverId) {
    if (_isConnected && _socket != null) {
      _socket!.emit('joinConversation', {
        'userId': userId,
        'receiverId': receiverId,
      });
      print('👥 Joined conversation: $userId <-> $receiverId');
    }
  }

  void leaveConversation(String userId, String receiverId) {
    if (_isConnected && _socket != null) {
      _socket!.emit('leaveConversation', {
        'userId': userId,
        'receiverId': receiverId,
      });
      print('👋 Left conversation: $userId <-> $receiverId');
    }
  }

  Future<void> disconnect() async {
    try {
      _isConnected = false;
      _socket?.disconnect();
      _socket?.dispose();
      _socket = null;
      _connectionController.add(false);
      print('🔌 Socket disconnected');
    } catch (e) {
      print('Error disconnecting socket: $e');
    }
  }

  void dispose() {
    try {
      _connectionController.close();
      _newMessageController.close();
      _messageDeletedController.close();
      _messageEditedController.close();
      _readStatusController.close();
      disconnect();
    } catch (e) {
      print('Error disposing socket service: $e');
    }
  }
}
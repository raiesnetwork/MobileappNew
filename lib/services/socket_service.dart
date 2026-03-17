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
  bool _isConnecting = false;
  Timer? _reconnectTimer;

  IO.Socket? get socket => _socket;

  // ── Stream controllers ─────────────────────────────────────────────────
  final StreamController<bool>               _connectionController  = StreamController<bool>.broadcast();
  final StreamController<Map<String, dynamic>> _newMessageController  = StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _messageDeletedController = StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _messageEditedController  = StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _readStatusController     = StreamController<Map<String, dynamic>>.broadcast();

  // ── NEW: broadcasts the live socket whenever it (re)connects ──────────
  // GroupChatProvider subscribes to this to call setSocket() automatically.
  final StreamController<IO.Socket> _socketReadyController =
  StreamController<IO.Socket>.broadcast();

  // ── Public streams ─────────────────────────────────────────────────────
  Stream<bool>               get onConnectionChanged  => _connectionController.stream;
  Stream<Map<String, dynamic>> get onNewMessage        => _newMessageController.stream;
  Stream<Map<String, dynamic>> get onMessageDeleted    => _messageDeletedController.stream;
  Stream<Map<String, dynamic>> get onMessageEdited     => _messageEditedController.stream;
  Stream<Map<String, dynamic>> get onReadStatusUpdated => _readStatusController.stream;

  /// Fires every time the socket successfully connects (or reconnects).
  /// GroupChatProvider uses this to call setSocket() at the right moment.
  Stream<IO.Socket> get onSocketReady => _socketReadyController.stream;

  bool get isConnected => _isConnected;

  // ════════════════════════════════════════════════════════════════════════
  //  CONNECT
  // ════════════════════════════════════════════════════════════════════════
  Future<bool> connect() async {
    if (_isConnected || _isConnecting) {
      print('⚠️ Socket already connected or connecting');
      return _isConnected;
    }

    try {
      _isConnecting = true;
      final prefs  = await SharedPreferences.getInstance();
      final token  = prefs.getString('auth_token');
      final userId = prefs.getString('user_id');

      if (token == null || userId == null) {
        print('❗ Cannot connect socket: missing token/userId');
        _isConnecting = false;
        return false;
      }

      if (_socket != null) await _disposeSocket();

      _socket = IO.io(
        'wss://api.ixes.ai',
        IO.OptionBuilder()
            .setTransports(['websocket'])
            .setQuery({'token': token, 'userId': userId})
            .setReconnectionAttempts(5)
            .setReconnectionDelay(2000)
            .setTimeout(10000)
            .disableAutoConnect()
            .build(),
      );

      _setupEventListeners();

      _socket!.onConnect((_) {
        print("✅ Connected to socket server");
        _isConnected  = true;
        _isConnecting = false;
        _connectionController.add(true);
        _socket!.emit("joinUser", userId);
        _cancelReconnectTimer();

        // ── NEW: broadcast the live socket so GroupChatProvider can wire up ──
        if (!_socketReadyController.isClosed && _socket != null) {
          _socketReadyController.add(_socket!);
          print('📡 [SocketService] onSocketReady fired');
        }
      });

      _socket!.onDisconnect((_) {
        print("❌ Disconnected from socket server");
        _isConnected  = false;
        _isConnecting = false;
        _connectionController.add(false);
        _startReconnectTimer();
      });

      _socket!.onConnectError((data) {
        print("💥 Socket connection error: $data");
        _isConnected  = false;
        _isConnecting = false;
        _connectionController.add(false);
      });

      _socket!.onError((data) {
        print("💥 Socket error: $data");
        _isConnected  = false;
        _isConnecting = false;
        _connectionController.add(false);
      });

      _socket!.onReconnect((data) {
        print("🔄 Socket reconnecting... attempt: $data");
      });

      _socket!.onReconnectError((data) {
        print("💥 Reconnection error: $data");
      });

      _socket!.onReconnectFailed((_) {
        print("❌ Reconnection failed");
        _startReconnectTimer();
      });

      _socket!.connect();
      return true;
    } catch (e) {
      print("💥 Socket connection error: $e");
      _isConnected  = false;
      _isConnecting = false;
      _connectionController.add(false);
      return false;
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  //  EVENT LISTENERS  (personal chat only — group events handled by
  //  GroupChatProvider directly via setSocket / .on())
  // ════════════════════════════════════════════════════════════════════════
  void _setupEventListeners() {
    if (_socket == null) return;

    // Clean up before re-registering
    _socket!.off("receive");
    _socket!.off("receiveVoiceMessage");
    _socket!.off("receiveFileMessage");
    _socket!.off("messageDeleted");
    _socket!.off("messageEdited");
    _socket!.off("readStatusUpdated");
    // Group events are managed by GroupChatProvider — no streams needed here,
    // but we off() them on reconnect so GroupChatProvider's re-registration is clean.
    _socket!.off("groupMessage");
    _socket!.off("groupVoiceMessage");
    _socket!.off("groupFileMessage");
    _socket!.off("groupMessageEdited");
    _socket!.off("groupMessageDeleted");

    _socket!.onAny((event, data) {
      print('🔔 [Socket ANY] event=$event | data=$data');
    });

    // ── Personal chat: text ─────────────────────────────────────────────
    _socket!.on("receive", (data) {
      try {
        final Map<String, dynamic> raw =
        data is String ? jsonDecode(data) : Map<String, dynamic>.from(data);
        final messageData = raw['message'] ?? raw;
        print("📩 Received message via socket: $messageData");
        Future.microtask(() {
          if (!_newMessageController.isClosed) {
            _newMessageController.add({'message': messageData});
          }
        });
      } catch (e) { print("Error parsing receive: $e"); }
    });

    // ── Personal chat: voice ────────────────────────────────────────────
    _socket!.on("receiveVoiceMessage", (data) {
      try {
        final Map<String, dynamic> raw =
        data is String ? jsonDecode(data) : Map<String, dynamic>.from(data);
        final messageData = raw['message'] ?? raw;
        print("🎤 Received voice message via socket: $messageData");
        Future.microtask(() {
          if (!_newMessageController.isClosed) {
            _newMessageController.add({'message': messageData});
          }
        });
      } catch (e) { print("Error parsing receiveVoiceMessage: $e"); }
    });

    // ── Personal chat: file ─────────────────────────────────────────────
    _socket!.on("receiveFileMessage", (data) {
      try {
        final Map<String, dynamic> raw =
        data is String ? jsonDecode(data) : Map<String, dynamic>.from(data);
        final messageData = raw['message'] ?? raw;
        print("📁 Received file message via socket: $messageData");
        Future.microtask(() {
          if (!_newMessageController.isClosed) {
            _newMessageController.add({'message': messageData});
          }
        });
      } catch (e) { print("Error parsing receiveFileMessage: $e"); }
    });

    // ── Personal chat: delete ───────────────────────────────────────────
    _socket!.on("messageDeleted", (data) {
      try {
        final Map<String, dynamic> deleteData =
        data is String ? jsonDecode(data) : Map<String, dynamic>.from(data);
        print("🗑️ Message deleted via socket: $deleteData");
        Future.microtask(() {
          if (!_messageDeletedController.isClosed) {
            _messageDeletedController.add(deleteData);
          }
        });
      } catch (e) { print("Error parsing messageDeleted: $e"); }
    });

    // ── Personal chat: edit ─────────────────────────────────────────────
    _socket!.on("messageEdited", (data) {
      try {
        final Map<String, dynamic> editData =
        data is String ? jsonDecode(data) : Map<String, dynamic>.from(data);
        print("✏️ Message edited via socket: $editData");
        Future.microtask(() {
          if (!_messageEditedController.isClosed) {
            _messageEditedController.add(editData);
          }
        });
      } catch (e) { print("Error parsing messageEdited: $e"); }
    });

    // ── Personal chat: read status ──────────────────────────────────────
    _socket!.on("readStatusUpdated", (data) {
      try {
        final Map<String, dynamic> readData =
        data is String ? jsonDecode(data) : Map<String, dynamic>.from(data);
        print("👁️ Read status updated via socket: $readData");
        Future.microtask(() {
          if (!_readStatusController.isClosed) {
            _readStatusController.add(readData);
          }
        });
      } catch (e) { print("Error parsing readStatusUpdated: $e"); }
    });

    print('🎯 Socket event listeners setup complete');
  }

  // ════════════════════════════════════════════════════════════════════════
  //  RECONNECT
  // ════════════════════════════════════════════════════════════════════════
  void _startReconnectTimer() {
    _cancelReconnectTimer();
    _reconnectTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!_isConnected && !_isConnecting) {
        print('🔄 Attempting to reconnect...');
        connect();
      } else {
        _cancelReconnectTimer();
      }
    });
  }

  void _cancelReconnectTimer() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  // ════════════════════════════════════════════════════════════════════════
  //  EMIT HELPERS
  // ════════════════════════════════════════════════════════════════════════
  Future<Map<String, dynamic>> sendMessage({
    required String receiverId,
    required String text,
    bool readBy = false,
    String? image,
    String? replayTo,
  }) async {
    if (!_isConnected || _socket == null) {
      return {'error': true, 'message': 'Socket not connected'};
    }
    try {
      final prefs  = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      final messageData = {
        'receiverId': receiverId,
        'text': text,
        'readBy': readBy,
        'timestamp': DateTime.now().toIso8601String(),
        if (image    != null) 'image':   image,
        if (replayTo != null) 'replayTo': replayTo,
      };
      _socket!.emit('sendMessage', messageData);
      return {
        'error': false,
        'message': 'Message sent via socket',
        'data': {
          'message': {
            '_id': 'temp_${DateTime.now().millisecondsSinceEpoch}',
            'senderId': userId,
            'receiverId': receiverId,
            'text': text,
            'readBy': readBy,
            'createdAt': DateTime.now().toIso8601String(),
            'status': 'sent',
          }
        }
      };
    } catch (e) {
      return {'error': true, 'message': 'Error sending message via socket: $e'};
    }
  }

  Future<Map<String, dynamic>> updateReadStatus({
    required String senderId,
    required String receiverId,
  }) async {
    if (!_isConnected || _socket == null) {
      return {'error': true, 'message': 'Socket not connected'};
    }
    try {
      _socket!.emit('updatereadBy', {'senderId': senderId, 'receiverId': receiverId});
      print('👁️ Read status event emitted via socket');
      return {'error': false, 'message': 'Read status updated via socket'};
    } catch (e) {
      return {'error': true, 'message': 'Error updating read status via socket: $e'};
    }
  }

  Future<Map<String, dynamic>> deleteMessage({
    required String messageId,
    required String receiverId,
  }) async {
    if (!_isConnected || _socket == null) {
      return {'error': true, 'message': 'Socket not connected'};
    }
    try {
      _socket!.emit('deleteMessage', {'messageId': messageId, 'receiverId': receiverId});
      return {'error': false, 'message': 'Message deleted via socket'};
    } catch (e) {
      return {'error': true, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> editMessage({
    required String messageId,
    required String newText,
    required String receiverId,
  }) async {
    if (!_isConnected || _socket == null) {
      return {'error': true, 'message': 'Socket not connected'};
    }
    try {
      _socket!.emit('editMessage', {
        'messageId': messageId,
        'newText': newText,
        'receiverId': receiverId,
      });
      return {'error': false, 'message': 'Message edited via socket'};
    } catch (e) {
      return {'error': true, 'message': 'Error: $e'};
    }
  }

  void joinConversation(String userId, String receiverId) {
    if (_isConnected && _socket != null) {
      _socket!.emit('joinConversation', {'userId': userId, 'receiverId': receiverId});
      print('👥 Joined conversation: $userId <-> $receiverId');
    }
  }

  void leaveConversation(String userId, String receiverId) {
    if (_isConnected && _socket != null) {
      _socket!.emit('leaveConversation', {'userId': userId, 'receiverId': receiverId});
      print('👋 Left conversation: $userId <-> $receiverId');
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  //  DISPOSE
  // ════════════════════════════════════════════════════════════════════════
  Future<void> _disposeSocket() async {
    try {
      if (_socket != null) {
        _socket!.off("receive");
        _socket!.off("receiveVoiceMessage");
        _socket!.off("receiveFileMessage");
        _socket!.off("messageDeleted");
        _socket!.off("messageEdited");
        _socket!.off("readStatusUpdated");
        _socket!.off("groupMessage");
        _socket!.off("groupVoiceMessage");
        _socket!.off("groupFileMessage");
        _socket!.off("groupMessageEdited");
        _socket!.off("groupMessageDeleted");
        _socket!.disconnect();
        _socket!.dispose();
        _socket = null;
      }
    } catch (e) {
      print('Error disposing socket: $e');
    }
  }

  Future<void> disconnect() async {
    try {
      _cancelReconnectTimer();
      _isConnected  = false;
      _isConnecting = false;
      await _disposeSocket();
      if (!_connectionController.isClosed) _connectionController.add(false);
      print('🔌 Socket disconnected');
    } catch (e) {
      print('Error disconnecting socket: $e');
    }
  }

  void dispose() {
    try {
      _cancelReconnectTimer();
      disconnect();
      _connectionController.close();
      _newMessageController.close();
      _messageDeletedController.close();
      _messageEditedController.close();
      _readStatusController.close();
      _socketReadyController.close(); // ← NEW
    } catch (e) {
      print('Error disposing socket service: $e');
    }
  }
}
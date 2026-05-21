import 'dart:async';
import 'dart:convert';
import 'dart:io';
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
  int _reconnectCount = 0;
  static const int _maxReconnectCount = 5;

  IO.Socket? get socket => _socket;

  // ── Stream controllers ─────────────────────────────────────────────────
  final StreamController<bool> _connectionController =
  StreamController<bool>.broadcast();
  final StreamController<Map<String, dynamic>> _newMessageController =
  StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _messageDeletedController =
  StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _messageEditedController =
  StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _readStatusController =
  StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<IO.Socket> _socketReadyController =
  StreamController<IO.Socket>.broadcast();

  // ── Public streams ─────────────────────────────────────────────────────
  Stream<bool> get onConnectionChanged => _connectionController.stream;
  Stream<Map<String, dynamic>> get onNewMessage => _newMessageController.stream;
  Stream<Map<String, dynamic>> get onMessageDeleted =>
      _messageDeletedController.stream;
  Stream<Map<String, dynamic>> get onMessageEdited =>
      _messageEditedController.stream;
  Stream<Map<String, dynamic>> get onReadStatusUpdated =>
      _readStatusController.stream;
  Stream<IO.Socket> get onSocketReady => _socketReadyController.stream;

  bool get isConnected => _isConnected;

  // ════════════════════════════════════════════════════════════════════════
  //  SAFE STREAM ADD — never throws even if controller is closed
  // ════════════════════════════════════════════════════════════════════════
  void _safeAdd<T>(StreamController<T> controller, T value) {
    try {
      if (!controller.isClosed) controller.add(value);
    } catch (_) {}
  }

  // ════════════════════════════════════════════════════════════════════════
  //  CONNECT
  // ════════════════════════════════════════════════════════════════════════
  Future<bool> connect() async {
    if (_isConnected && _socket != null) {
      return true;
    }

    if (_isConnecting) {
      int attempts = 0;
      while (_isConnecting && attempts < 40) {
        await Future.delayed(const Duration(milliseconds: 500));
        attempts++;
      }
      return _isConnected;
    }

    try {
      _isConnecting = true;

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      final userId = prefs.getString('user_id');

      if (token == null || userId == null) {
        _isConnecting = false;
        return false;
      }


      if (_socket != null) {
        await _disposeSocket();
      }

      _socket = IO.io(
        'wss//api.ixes.ai',
        IO.OptionBuilder()
            .setTransports(['polling', 'websocket'])
            .setQuery({'userId': userId})
            .enableForceNew()
            .enableReconnection()
            .setReconnectionAttempts(999999)
            .setReconnectionDelay(2000)
            .setTimeout(20000)
            .disableAutoConnect()
            .build(),
      );

      _socket!.onConnect((_) {
        _isConnected = true;
        _isConnecting = false;
        _reconnectCount = 0;
        _safeAdd(_connectionController, true);

        try {
          _socket!.emit("joinUser", userId);
        } catch (_) {}

        _cancelReconnectTimer();

        if (!_socketReadyController.isClosed && _socket != null) {
          _safeAdd(_socketReadyController, _socket!);
        }

        print('✅ Socket connected: ${_socket?.id}');
      });

      _socket!.onConnectError((data) {
        _isConnected = false;
        _isConnecting = false;
        _safeAdd(_connectionController, false);
        print('❌ Socket connect error: $data');
        _startReconnectTimer();
      });

      _socket!.onError((data) {
        _isConnected = false;
        _isConnecting = false;
        _safeAdd(_connectionController, false);
        print('💥 Socket error: $data');
      });

      _socket!.onDisconnect((reason) {
        _isConnected = false;
        _isConnecting = false;
        _safeAdd(_connectionController, false);
        print('🔌 Socket disconnected: $reason');
        _startReconnectTimer();
      });

      _socket!.onAny((event, data) {
        print('🔔 [Socket ANY] event=$event | data=$data');
      });

      _setupEventListeners();

      _socket!.connect();

      return true;
    } catch (e) {
      print('💥 Socket connect exception: $e');
      _isConnected = false;
      _isConnecting = false;
      return false;
    }
  }

  Future<bool> reconnectAndWait() async {
    if (_isConnected && _socket != null) return true;
    return false;
  }

  // ════════════════════════════════════════════════════════════════════════
  //  EVENT LISTENERS
  // ════════════════════════════════════════════════════════════════════════
  void _setupEventListeners() {
    if (_socket == null) return;

    _socket!.off("receive");
    _socket!.off("receiveVoiceMessage");
    _socket!.off("receiveFileMessage");
    _socket!.off("messageDeleted");
    _socket!.off("messageEdited");
    _socket!.off("readStatusUpdated");
    _socket!.off("groupMessageEdited");
    _socket!.off("groupMessageDeleted");
    _socket!.off("groupMessage");
    _socket!.off("groupVoiceMessage");
    _socket!.off("groupFileMessage");

    _socket!.on("receive", (data) {
      try {
        final Map<String, dynamic> raw =
        data is String ? jsonDecode(data) : Map<String, dynamic>.from(data);
        final messageData = raw['message'] ?? raw;
        Future.microtask(
                () => _safeAdd(_newMessageController, {'message': messageData}));
      } catch (_) {}
    });

    _socket!.on("receiveVoiceMessage", (data) {
      try {
        final Map<String, dynamic> raw =
        data is String ? jsonDecode(data) : Map<String, dynamic>.from(data);
        final messageData = raw['message'] ?? raw;
        Future.microtask(
                () => _safeAdd(_newMessageController, {'message': messageData}));
      } catch (_) {}
    });

    _socket!.on("receiveFileMessage", (data) {
      try {
        final Map<String, dynamic> raw =
        data is String ? jsonDecode(data) : Map<String, dynamic>.from(data);
        final messageData = raw['message'] ?? raw;
        Future.microtask(
                () => _safeAdd(_newMessageController, {'message': messageData}));
      } catch (_) {}
    });

    _socket!.on("messageDeleted", (data) {
      try {
        final Map<String, dynamic> deleteData =
        data is String ? jsonDecode(data) : Map<String, dynamic>.from(data);
        Future.microtask(
                () => _safeAdd(_messageDeletedController, deleteData));
      } catch (_) {}
    });

    _socket!.on("messageEdited", (data) {
      try {
        final Map<String, dynamic> editData =
        data is String ? jsonDecode(data) : Map<String, dynamic>.from(data);
        Future.microtask(() => _safeAdd(_messageEditedController, editData));
      } catch (_) {}
    });

    _socket!.on("readStatusUpdated", (data) {
      try {
        final Map<String, dynamic> readData =
        data is String ? jsonDecode(data) : Map<String, dynamic>.from(data);
        Future.microtask(() => _safeAdd(_readStatusController, readData));
      } catch (_) {}
    });

    print('🎯 Socket event listeners setup complete');
  }

  void joinGroup(String groupId) {
    try {
      if (_isConnected && _socket != null) {
        _socket!.emit('joinGroup', groupId);
      }
    } catch (_) {}
  }

  void leaveGroup(String groupId) {
    try {
      if (_isConnected && _socket != null) {
        _socket!.emit('leaveGroup', groupId);
      }
    } catch (_) {}
  }

  // ════════════════════════════════════════════════════════════════════════
  //  RECONNECT — stops after max attempts to avoid infinite loop
  // ════════════════════════════════════════════════════════════════════════
  void _startReconnectTimer() {
    _cancelReconnectTimer();

    if (_reconnectCount >= _maxReconnectCount) {
      print('⛔ Max reconnect attempts reached — giving up');
      return;
    }

    _reconnectTimer = Timer.periodic(const Duration(seconds: 25), (timer) {
      if (!_isConnected && !_isConnecting) {
        _reconnectCount++;
        if (_reconnectCount > _maxReconnectCount) {
          _cancelReconnectTimer();
          print('⛔ Max reconnects reached — stopping');
          return;
        }
        print('🔄 Reconnect attempt $_reconnectCount/$_maxReconnectCount');
        connect();
      } else {
        _cancelReconnectTimer();
      }
    });
  }

  void _cancelReconnectTimer() {
    try {
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
    } catch (_) {}
  }

  // ════════════════════════════════════════════════════════════════════════
  //  EMIT HELPERS — all wrapped in try-catch
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
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      final messageData = {
        'receiverId': receiverId,
        'text': text,
        'readBy': readBy,
        'timestamp': DateTime.now().toIso8601String(),
        if (image != null) 'image': image,
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
      return {'error': true, 'message': 'Error sending message: $e'};
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
      _socket!.emit(
          'updatereadBy', {'senderId': senderId, 'receiverId': receiverId});
      return {'error': false, 'message': 'Read status updated via socket'};
    } catch (e) {
      return {'error': true, 'message': 'Error: $e'};
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
      _socket!.emit(
          'deleteMessage', {'messageId': messageId, 'receiverId': receiverId});
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
    try {
      if (_isConnected && _socket != null) {
        _socket!.emit(
            'joinConversation', {'userId': userId, 'receiverId': receiverId});
      }
    } catch (_) {}
  }

  void leaveConversation(String userId, String receiverId) {
    try {
      if (_isConnected && _socket != null) {
        _socket!.emit(
            'leaveConversation', {'userId': userId, 'receiverId': receiverId});
      }
    } catch (_) {}
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
        _socket!.off("receiveGroupMessage");
        _socket!.off("receiveGroupVoiceMessage");
        _socket!.off("receiveGroupFileMessage");
        _socket!.off("groupMessageEdited");
        _socket!.off("groupMessageDeleted");
        _socket!.off("groupMessage");
        _socket!.off("groupVoiceMessage");
        _socket!.off("groupFileMessage");
        _socket!.disconnect();
        _socket!.dispose();
        _socket = null;
      }
    } catch (_) {}
  }

  Future<void> disconnect() async {
    try {
      _cancelReconnectTimer();
      _isConnected = false;
      _isConnecting = false;
      await _disposeSocket();
      _safeAdd(_connectionController, false);
      print('🔌 Socket disconnected');
    } catch (_) {}
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
      _socketReadyController.close();
    } catch (_) {}
  }
}
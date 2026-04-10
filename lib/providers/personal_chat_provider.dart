import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:ixes.app/constants/apiConstants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/personal_chat_service.dart';
import '../services/socket_service.dart';

class PersonalChatProvider with ChangeNotifier {
  final PersonalChatService _chatService = PersonalChatService();
  late SocketService _socketService;

  StreamSubscription<bool>? _connectionSubscription;
  StreamSubscription<Map<String, dynamic>>? _newMessageSubscription;
  StreamSubscription<Map<String, dynamic>>? _messageDeletedSubscription;
  StreamSubscription<Map<String, dynamic>>? _messageEditedSubscription;
  StreamSubscription<Map<String, dynamic>>? _readStatusSubscription;

  bool _isSendingMessage = false;
  String? _sendMessageError;
  Map<String, dynamic>? _lastSentMessage;
  VoidCallback? onNewMessageReceived;

  bool get isSendingMessage => _isSendingMessage;
  String? get sendMessageError => _sendMessageError;
  Map<String, dynamic>? get lastSentMessage => _lastSentMessage;

  bool _isLoading = false;
  bool _isConversationLoading = false;
  String? _error;
  Map<String, dynamic> _chatData = {
    'error': true,
    'message': 'No chats loaded',
    'data': []
  };

  bool get isLoading => _isLoading;
  bool get isConversationLoading => _isConversationLoading;
  String? get error => _error;
  Map<String, dynamic> get chatData => _chatData;

  List<dynamic> _messages = [];
  Map<String, dynamic> _userData = {};
  String? _currentUserId;
  String? _currentReceiverId;
  bool _socketConnected = false;
  bool _isDisposed = false;

  List<dynamic> get messages => _messages;
  Map<String, dynamic> get userData => _userData;
  String? get currentUserId => _currentUserId;
  String? get currentReceiverId => _currentReceiverId;
  bool get socketConnected => _socketConnected;

  @override
  void dispose() {
    _isDisposed = true;
    _cancelSocketSubscriptions();
    _chatService.dispose();
    super.dispose();
  }

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _currentUserId = prefs.getString('user_id');
    _socketService = _chatService.socketService;
    await initializeSocket();
    _safeNotifyListeners();
  }

  Future<bool> initializeSocket() async {
    try {
      print('🔌 Initializing socket connection...');
      final connected = await _chatService.initializeSocket();
      if (connected) {
        _setupSocketEventListeners();
        print('✅ Socket initialized successfully');
      } else {
        print('❌ Socket initialization failed');
      }
      return connected;
    } catch (e) {
      print('💥 Error initializing socket: $e');
      return false;
    }
  }

  void _setupSocketEventListeners() {
    _cancelSocketSubscriptions();

    _connectionSubscription = _socketService.onConnectionChanged.listen(
          (connected) {
        _socketConnected = connected;
        print('🔌 Socket connection changed: $connected');
        _safeNotifyListeners();
      },
      cancelOnError: false,
    );

    _newMessageSubscription = _socketService.onNewMessage.listen(
          (messageData) {
        print('📥 Socket new message: ${messageData['message']}');
        _handleNewMessage(messageData);
      },
      cancelOnError: false,
    );

    _messageDeletedSubscription = _socketService.onMessageDeleted.listen(
          (data) => _handleMessageDeleted(data),
      cancelOnError: false,
    );

    _messageEditedSubscription = _socketService.onMessageEdited.listen(
          (data) => _handleMessageEdited(data),
      cancelOnError: false,
    );

    _readStatusSubscription = _socketService.onReadStatusUpdated.listen(
          (data) => _handleReadStatusUpdated(data),
      cancelOnError: false,
    );

    print('🎯 Socket event listeners setup complete');
  }

  void _cancelSocketSubscriptions() {
    _connectionSubscription?.cancel();
    _newMessageSubscription?.cancel();
    _messageDeletedSubscription?.cancel();
    _messageEditedSubscription?.cancel();
    _readStatusSubscription?.cancel();

    _connectionSubscription = null;
    _newMessageSubscription = null;
    _messageDeletedSubscription = null;
    _messageEditedSubscription = null;
    _readStatusSubscription = null;
  }

  // ════════════════════════════════════════════════════════════════════════
  //  ID EXTRACTOR
  // ════════════════════════════════════════════════════════════════════════
  String _extractId(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    if (value is Map) return value['_id']?.toString() ?? '';
    return value.toString();
  }

  // ════════════════════════════════════════════════════════════════════════
  //  HANDLE NEW MESSAGE
  // ════════════════════════════════════════════════════════════════════════
  void _handleNewMessage(Map<String, dynamic> data) {
    if (_isDisposed) return;

    try {
      final message = data['message'];
      if (message == null) return;

      final messageSenderId   = _extractId(message['senderId']);
      final messageReceiverId = _extractId(message['receiverId']);
      final messageId         = message['_id']?.toString() ?? '';

      print('📥 [Socket] msg from=$messageSenderId to=$messageReceiverId '
          '| currentUser=$_currentUserId currentReceiver=$_currentReceiverId');

      final myId    = _currentUserId ?? '';
      final theirId = _currentReceiverId ?? '';

      if (myId.isEmpty || theirId.isEmpty) {
        print('⚠️ [Socket] No active conversation — dropping message');
        return;
      }

      final isForCurrentConversation =
          (messageSenderId == theirId && messageReceiverId == myId) ||
              (messageSenderId == myId && messageReceiverId == theirId);

      if (!isForCurrentConversation) {
        print('⚠️ [Socket] Message is for a different conversation — ignoring');
        return;
      }

      final existingIndex = _messages.indexWhere(
              (m) => m['_id']?.toString() == messageId);

      if (existingIndex >= 0) {
        final existing = _messages[existingIndex];
        if (existing['_id'].toString().startsWith('temp_') ||
            existing['isOptimistic'] == true) {
          final List<dynamic> updated = List.from(_messages);
          updated[existingIndex] = _processMessage(message);
          _messages = updated;
          print('✅ [Socket] Replaced optimistic message');
        } else {
          final List<dynamic> updated = List.from(_messages);
          updated[existingIndex] = _processMessage(message);
          _messages = updated;
          print('✅ [Socket] Updated existing message');
        }
      } else {
        _messages = [..._messages, _processMessage(message)];
        print('✅ [Socket] Appended new message — total: ${_messages.length}');
      }

      // Bump unread + move to top only for messages from the other person
      if (messageSenderId != myId) {
        _incrementUnreadCount(messageSenderId);
        _moveChatToTop(
            messageSenderId, Map<String, dynamic>.from(message));
      }
      // ✅ Auto scroll to bottom
      if (onNewMessageReceived != null) {
        onNewMessageReceived!();
      }
      _safeNotifyListeners();

      _safeNotifyListeners();
    } catch (e) {
      print('💥 Error handling new message: $e');
    }
  }

  void _handleMessageDeleted(Map<String, dynamic> data) {
    if (_isDisposed) return;
    try {
      final messageId = data['messageId'];
      if (messageId != null) {
        _messages = _messages
            .where((m) => m['_id']?.toString() != messageId.toString())
            .toList();
        _safeNotifyListeners();
      }
    } catch (e) {
      print('💥 Error handling message deletion: $e');
    }
  }

  void _handleMessageEdited(Map<String, dynamic> data) {
    if (_isDisposed) return;
    try {
      final messageId = data['messageId']?.toString();
      final newText   = data['newText'];
      if (messageId != null && newText != null) {
        final idx = _messages.indexWhere(
                (m) => m['_id']?.toString() == messageId);
        if (idx >= 0) {
          final List<dynamic> updated = List.from(_messages);
          updated[idx] = {
            ...Map<String, dynamic>.from(updated[idx]),
            'text': newText,
            'isEdited': true,
            'editedAt': DateTime.now().toIso8601String(),
          };
          _messages = updated;
          _safeNotifyListeners();
        }
      }
    } catch (e) {
      print('💥 Error handling message edit: $e');
    }
  }

  void _handleReadStatusUpdated(Map<String, dynamic> data) {
    if (_isDisposed) return;
    try {
      final senderId   = _extractId(data['senderId']);
      final receiverId = _extractId(data['receiverId']);
      if (senderId.isNotEmpty && receiverId.isNotEmpty) {
        _messages = _messages.map((msg) {
          final msgMap     = Map<String, dynamic>.from(msg);
          final msgSender  = _extractId(msgMap['senderId']);
          final msgReceiver = _extractId(msgMap['receiverId']);
          if (msgSender == senderId && msgReceiver == receiverId) {
            msgMap['readBy'] = true;
          }
          return msgMap;
        }).toList();
        _safeNotifyListeners();
      }
    } catch (e) {
      print('💥 Error handling read status: $e');
    }
  }

  Map<String, dynamic> _processMessage(Map<String, dynamic> message) {
    final m = Map<String, dynamic>.from(message);

    m['status'] = m['status'] ?? 'sent';
    m['readBy'] = m['readBy'] ?? false;

    if (m['receiverId'] is Map) m['receiverId'] = _extractId(m['receiverId']);
    if (m['senderId']  is Map) m['senderId']  = _extractId(m['senderId']);

    if (m['isFile'] == true && m['fileUrl'] != null) {
      m['fileUrl'] = constructFullUrl(m['fileUrl'] as String);
    }
    if (m['isAudio'] == true && m['audioUrl'] != null) {
      m['audioUrl'] = constructFullUrl(m['audioUrl'] as String);
    }

    return m;
  }

  // ════════════════════════════════════════════════════════════════════════
  //  DATA FETCHING
  // ════════════════════════════════════════════════════════════════════════
  Future<void> fetchPersonalChats() async {
    if (_isDisposed) return;
    _isLoading = true;
    _error = null;
    _safeNotifyListeners();
    try {
      final response = await _chatService.getPersonalChats();
      if (response['error'] == false) {
        _chatData = response;
      } else {
        _error = response['message'] ?? 'Failed to fetch chats';
      }
    } catch (e) {
      _error = 'Exception: $e';
    }
    _isLoading = false;
    _safeNotifyListeners();
  }

  Future<void> fetchConversation(String userId) async {
    if (_isDisposed) return;
    
    if (_currentReceiverId != userId) {
      _messages = []; // Prevent split-second flash of old chat's messages
    }

    _isConversationLoading = true;
    _error = null;
    _currentReceiverId = userId;
    _safeNotifyListeners();

    try {
      if (_currentUserId != null) {
        _chatService.joinConversation(_currentUserId!, userId);
      }

      final result = await _chatService.getMessages(userId: userId);

      if (result['error'] == false && result['data'] != null) {
        final data        = result['data'];
        _userData         = data['userData'] ?? {};
        final rawMessages = data['messages'] as List<dynamic>? ?? [];
        _messages = rawMessages
            .map((m) => _processMessage(m as Map<String, dynamic>))
            .toList();
        print('✅ Loaded ${_messages.length} messages');
      } else {
        _error    = result['message'] ?? 'Failed to fetch conversation';
        _messages = [];
        _userData = {};
      }
    } catch (e) {
      _error    = 'Error fetching conversation: $e';
      _messages = [];
      _userData = {};
    } finally {
      _isConversationLoading = false;
      _safeNotifyListeners();
    }
  }

  void leaveConversation() {
    if (_currentUserId != null && _currentReceiverId != null) {
      _chatService.leaveConversation(_currentUserId!, _currentReceiverId!);
    }
    _currentReceiverId = null;
  }

  // ════════════════════════════════════════════════════════════════════════
  //  SEND MESSAGE
  // ════════════════════════════════════════════════════════════════════════
  Future<Map<String, dynamic>?> sendMessage({
    required String receiverId,
    required String text,
    bool readBy = false,
    String? image,
    String? replyTo,
  }) async {
    if (_isDisposed) return null;

    _isSendingMessage = true;
    _sendMessageError = null;
    _lastSentMessage  = null;

    final tempId    = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final optimistic = {
      '_id':         tempId,
      'text':        text,
      'senderId':    _currentUserId ?? '',
      'receiverId':  receiverId,
      'readBy':      readBy,
      'createdAt':   DateTime.now().toIso8601String(),
      'status':      'sending',
      'isOptimistic': true,
      if (image   != null) 'image':   image,
      if (replyTo != null) 'replyTo': replyTo,
    };
    _messages = [..._messages, optimistic];
    _safeNotifyListeners();

    try {
      final response = await _chatService.sendMessage(
        receiverId: receiverId,
        text:       text,
        readBy:     readBy,
        image:      image,
        replyTo:    replyTo,
      );

      if (response['error'] == false) {
        _lastSentMessage    = response['data'];
        final messageData   = response['data']['message'] ?? response['data'];
        final idx           = _messages.indexWhere((m) => m['_id'] == tempId);
        if (idx >= 0) {
          final List<dynamic> updated = List.from(_messages);
          updated[idx] = _processMessage(messageData);
          _messages    = updated;
        }
        // Move chat to top with latest text preview
        _moveChatToTop(receiverId, {'text': text});
        _isSendingMessage = false;
        _safeNotifyListeners();
        return {'success': true, 'error': false, 'data': response['data']};
      } else {
        _messages         = _messages.where((m) => m['_id'] != tempId).toList();
        _sendMessageError = response['message'];
        _isSendingMessage = false;
        _safeNotifyListeners();
        return {'success': false, 'error': true, 'message': _sendMessageError};
      }
    } catch (e) {
      _messages         = _messages.where((m) => m['_id'] != tempId).toList();
      _sendMessageError = 'Exception: $e';
      _isSendingMessage = false;
      _safeNotifyListeners();
      return {'success': false, 'error': true, 'message': e.toString()};
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  //  SEND FILE MESSAGE
  // ════════════════════════════════════════════════════════════════════════
  Future<Map<String, dynamic>?> sendFileMessage({
    required File file,
    required String receiverId,
    String? replyTo,
    bool readBy = false,
  }) async {
    _isSendingMessage = true;
    _sendMessageError = null;
    _lastSentMessage  = null;

    final tempId    = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final optimistic = {
      '_id':          tempId,
      'fileName':     file.path.split('/').last,
      'fileUrl':      file.path,
      'senderId':     _currentUserId ?? '',
      'receiverId':   receiverId,
      'isFile':       true,
      'readBy':       readBy,
      'createdAt':    DateTime.now().toIso8601String(),
      'status':       'sending',
      'isOptimistic': true,
      'localFilePath': file.path,
    };
    _messages = [..._messages, optimistic];
    notifyListeners();

    try {
      final response = await _chatService.sendFileMessage(
        file:       file,
        receiverId: receiverId,
        readBy:     readBy,
        replyTo:    replyTo,
        useSocket:  _socketConnected,
      );

      final idx = _messages.indexWhere((m) => m['_id'] == tempId);

      if (response['error'] == false && response['data'] != null) {
        _lastSentMessage  = response['data'];
        final messageData = response['data']['message'] ?? response['data'];
        final real        = _processMessage(messageData);
        if (idx >= 0) {
          final List<dynamic> updated = List.from(_messages);
          updated[idx] = real;
          _messages    = updated;
        } else {
          _messages = [..._messages, real];
        }
        // Move chat to top with file preview
        _moveChatToTop(receiverId, {'isFile': true});
        notifyListeners();
        return response['data'];
      } else {
        _sendMessageError = response['message'] ?? 'Failed to send file message';
        if (idx >= 0) {
          final List<dynamic> updated = List.from(_messages);
          updated[idx] = {
            ...Map<String, dynamic>.from(updated[idx]),
            'status': 'failed'
          };
          _messages = updated;
        }
        notifyListeners();
        return null;
      }
    } catch (e) {
      _sendMessageError = 'Exception: $e';
      notifyListeners();
      return null;
    } finally {
      _isSendingMessage = false;
      notifyListeners();
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  //  SEND VOICE MESSAGE
  // ════════════════════════════════════════════════════════════════════════
  Future<Map<String, dynamic>?> sendVoiceMessage({
    required File audioFile,
    required String receiverId,
    bool readBy = false,
    String? replyTo,
    String? image,
    int? audioDurationMs,
  }) async {
    _isSendingMessage = true;
    _sendMessageError = null;
    _lastSentMessage  = null;

    final tempId    = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final optimistic = {
      '_id':          tempId,
      'audioUrl':     audioFile.path,
      'senderId':     _currentUserId ?? '',
      'receiverId':   receiverId,
      'isAudio':      true,
      'readBy':       readBy,
      'createdAt':    DateTime.now().toIso8601String(),
      'status':       'sending',
      'isOptimistic': true,
      'localFilePath': audioFile.path,
      if (audioDurationMs != null) 'audioDurationMs': audioDurationMs,
      if (image   != null) 'image':   image,
      if (replyTo != null) 'replyTo': replyTo,
    };
    _messages = [..._messages, optimistic];
    notifyListeners();

    try {
      final response = await _chatService.sendVoiceMessage(
        audioFile:      audioFile,
        receiverId:     receiverId,
        readBy:         readBy,
        image:          image,
        replyTo:        replyTo,
        audioDurationMs: audioDurationMs,
        useSocket:      _socketConnected,
      );

      final idx = _messages.indexWhere((m) => m['_id'] == tempId);

      if (response['error'] == false) {
        _lastSentMessage  = response['data'];
        final messageData = response['data']['message'] ?? response['data'];
        final real        = _processMessage(messageData);
        real['localFilePath'] = audioFile.path;
        if (real['audioDurationMs'] == null && audioDurationMs != null) {
          real['audioDurationMs'] = audioDurationMs;
        }
        if (idx >= 0) {
          final List<dynamic> updated = List.from(_messages);
          updated[idx] = real;
          _messages    = updated;
        }
        // Move chat to top with voice preview
        _moveChatToTop(receiverId, {'isAudio': true});
        notifyListeners();
        return response['data'];
      } else {
        _sendMessageError = response['message'] ?? 'Failed to send voice message';
        if (idx >= 0) {
          final List<dynamic> updated = List.from(_messages);
          updated[idx] = {
            ...Map<String, dynamic>.from(updated[idx]),
            'status': 'failed'
          };
          _messages = updated;
        }
        notifyListeners();
        return null;
      }
    } catch (e) {
      _sendMessageError = 'Exception: $e';
      notifyListeners();
      return null;
    } finally {
      _isSendingMessage = false;
      notifyListeners();
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  //  READ STATUS
  // ════════════════════════════════════════════════════════════════════════
  Future<Map<String, dynamic>?> updateReadStatus({
    required String senderId,
    required String receiverId,
  }) async {
    try {
      final response = await _chatService.updateReadStatus(
        senderId:  senderId,
        receiverId: receiverId,
        useSocket: _socketConnected,
      );

      if (response['error'] == false && !_socketConnected) {
        _messages = _messages.map((msg) {
          final m           = Map<String, dynamic>.from(msg);
          final msgSender   = _extractId(m['senderId']);
          final msgReceiver = _extractId(m['receiverId']);
          if (msgSender == senderId && msgReceiver == receiverId) {
            m['readBy'] = true;
          }
          return m;
        }).toList();
        notifyListeners();
      }
      return response;
    } catch (e) {
      return {'success': false, 'error': true, 'message': e.toString()};
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  //  DELETE / EDIT
  // ════════════════════════════════════════════════════════════════════════
  Future<Map<String, dynamic>?> deleteMessage({
    required String messageId,
    required String receiverId,
  }) async {
    try {
      final response = await _chatService.deleteMessage(
        messageId:  messageId,
        receiverId: receiverId,
        useSocket:  _socketConnected,
      );
      if (response != null && response['error'] != true) {
        _messages = _messages
            .where((m) => m['_id']?.toString() != messageId)
            .toList();
        notifyListeners();
      }
      return response;
    } catch (e) {
      return {'error': true, 'message': 'Error deleting message: $e'};
    }
  }

  Future<Map<String, dynamic>?> editMessage({
    required String messageId,
    required String newText,
    required String receiverId,
  }) async {
    try {
      final response = await _chatService.editMessage(
        messageId:  messageId,
        newText:    newText,
        receiverId: receiverId,
        useSocket:  _socketConnected,
      );
      if (response != null && response['error'] != true) {
        final idx = _messages.indexWhere(
                (m) => m['_id']?.toString() == messageId);
        if (idx >= 0) {
          final List<dynamic> updated = List.from(_messages);
          updated[idx] = {
            ...Map<String, dynamic>.from(updated[idx]),
            'text':     newText,
            'isEdited': true,
            'editedAt': DateTime.now().toIso8601String(),
          };
          _messages = updated;
          notifyListeners();
        }
      }
      return response;
    } catch (e) {
      return {'error': true, 'message': 'Error editing message: $e'};
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  //  LOCAL STATE HELPERS
  // ════════════════════════════════════════════════════════════════════════

  /// Moves a chat to the top of the list and updates the last message preview.
  /// Pass the raw message map — text/isFile/isAudio are auto-detected.
  void _moveChatToTop(String chatUserId, Map<String, dynamic> message) {
    final data = _chatData['data'];
    if (data is! List) return;

    final list = List<dynamic>.from(data);
    final idx  = list.indexWhere(
          (chat) => chat['pairedUser']?['_id']?.toString() == chatUserId,
    );

    if (idx == -1) return;

    final updated = Map<String, dynamic>.from(list[idx]);
    updated['updatedAt']   = DateTime.now().toIso8601String();
    updated['lastMessage'] = message['text']?.toString().isNotEmpty == true
        ? message['text'].toString()
        : message['isAudio'] == true
        ? '🎤 Voice message'
        : message['isFile'] == true
        ? '📎 File'
        : '';

    list.removeAt(idx);
    list.insert(0, updated);

    _chatData = {..._chatData, 'data': list};
  }

  /// Increments unreadMessage count for a chat when a socket message arrives.
  void _incrementUnreadCount(String senderId) {
    final data = _chatData['data'];
    if (data is! List) return;

    final updated = data.map((chat) {
      final pairedId = chat['pairedUser']?['_id']?.toString();
      if (pairedId == senderId) {
        final current = (chat['unreadMessage'] as int?) ?? 0;
        return {
          ...Map<String, dynamic>.from(chat),
          'unreadMessage': current + 1
        };
      }
      return chat;
    }).toList();

    _chatData = {..._chatData, 'data': updated};
  }

  /// Clears the unread badge for a chat when the user opens it.
  void clearUnreadCount(String chatUserId) {
    final data = _chatData['data'];
    if (data is! List) return;

    bool changed = false;
    final updated = data.map((chat) {
      final pairedId = chat['pairedUser']?['_id']?.toString();
      if (pairedId == chatUserId) {
        final current = chat['unreadMessage'] ?? 0;
        if (current != 0) {
          changed = true;
          return {
            ...Map<String, dynamic>.from(chat),
            'unreadMessage': 0
          };
        }
      }
      return chat;
    }).toList();

    if (changed) {
      _chatData = {..._chatData, 'data': updated};
      _safeNotifyListeners();
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  //  OPTIMISTIC HELPERS
  // ════════════════════════════════════════════════════════════════════════
  void addOptimisticMessage(Map<String, dynamic> message) {
    _messages = [..._messages, message];
    notifyListeners();
  }

  void replaceOptimisticMessage(String tempId, Map<String, dynamic> real) {
    final idx = _messages.indexWhere((m) => m['_id'] == tempId);
    if (idx >= 0) {
      final List<dynamic> updated = List.from(_messages);
      updated[idx] = real;
      _messages    = updated;
      notifyListeners();
    }
  }

  void updateOptimisticMessageStatus(String tempId, String status) {
    final idx = _messages.indexWhere((m) => m['_id'] == tempId);
    if (idx >= 0) {
      final List<dynamic> updated = List.from(_messages);
      updated[idx] = {
        ...Map<String, dynamic>.from(updated[idx]),
        'status': status
      };
      _messages = updated;
      notifyListeners();
    }
  }

  void removeOptimisticMessage(String tempId) {
    _messages = _messages.where((m) => m['_id'] != tempId).toList();
    notifyListeners();
  }

  void clearMessages() {
    if (_isDisposed) return;
    _messages.clear();
    _userData.clear();
    _currentReceiverId = null;
    _safeNotifyListeners();
  }

  void _safeNotifyListeners() {
    if (!_isDisposed) notifyListeners();
  }

  Future<bool> reconnectSocket() async => await initializeSocket();

  bool isSocketConnected() => _socketService.isConnected;

  Map<String, dynamic>? getMessageById(String id) {
    try {
      return _messages.firstWhere((m) => m['_id'] == id)
      as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  void cleanup() {
    _cancelSocketSubscriptions();
    _chatService.disconnectSocket();
    clearMessages();
    clearErrors();
  }

  void clearErrors() {
    _error            = null;
    _sendMessageError = null;
    notifyListeners();
  }

  Future<void> refreshConversation() async {
    if (_currentReceiverId != null) {
      await fetchConversation(_currentReceiverId!);
    }
  }

  bool isMessageFromCurrentUser(Map<String, dynamic> msg) =>
      _extractId(msg['senderId']) == _currentUserId;
}
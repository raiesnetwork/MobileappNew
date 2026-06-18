  import 'dart:io';
  import 'dart:async';
  import 'package:flutter/foundation.dart';
  import 'package:ixes.app/constants/apiConstants.dart';
  import 'package:shared_preferences/shared_preferences.dart';
  import '../services/personal_chat_service.dart';
  import '../services/socket_service.dart';

  class PersonalChatProvider with ChangeNotifier {
    final PersonalChatService _chatService = PersonalChatService();

    // ✅ Changed from `late` to nullable
    SocketService? _socketService;

    // ✅ Safe getter — always reads live socket state
    bool get _isSocketConnected => _socketService?.isConnected ?? false;

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
      _socketService = _chatService.socketService; // ✅ works fine now (nullable)
      await initializeSocket();
      _safeNotifyListeners();
    }

    Future<bool> initializeSocket() async {
      try {
        if (_socketService?.isConnected == true) {
          _setupSocketEventListeners();
          return true;
        }
        // Don't await — just trigger connect and listen via streams
        _chatService.initializeSocket(); // ← no await
        _setupSocketEventListeners();
        print('🔌 Socket connect triggered');
        return true;
      } catch (e) {
        print('💥 Error: $e');
        return false;
      }
    }

    void _setupSocketEventListeners() {
      _cancelSocketSubscriptions();

      // ✅ All uses of _socketService are now null-safe with ?.
      _connectionSubscription = _socketService?.onConnectionChanged.listen(
            (connected) {
          _socketConnected = connected;
          print('🔌 Socket connection changed: $connected');
          _safeNotifyListeners();
        },
        cancelOnError: false,
      );

      _newMessageSubscription = _socketService?.onNewMessage.listen(
            (messageData) {
          print('📥 Socket new message: ${messageData['message']}');
          _handleNewMessage(messageData);
        },
        cancelOnError: false,
      );

      _messageDeletedSubscription = _socketService?.onMessageDeleted.listen(
            (data) => _handleMessageDeleted(data),
        cancelOnError: false,
      );

      _messageEditedSubscription = _socketService?.onMessageEdited.listen(
            (data) => _handleMessageEdited(data),
        cancelOnError: false,
      );

      _readStatusSubscription = _socketService?.onReadStatusUpdated.listen(
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

        if (messageSenderId != myId) {
          _incrementUnreadCount(messageSenderId);
          _moveChatToTop(messageSenderId, Map<String, dynamic>.from(message));
        }

        if (onNewMessageReceived != null) {
          onNewMessageReceived!();
        }
        _safeNotifyListeners();
      } catch (e) {
        print('💥 Error handling new message: $e');
      }
    }

    void _handleMessageDeleted(Map<String, dynamic> data) {
      if (_isDisposed) return;
      try {
        print('🗑️ [Provider] handleMessageDeleted raw data: $data');

        final messageId = data['messageId']?.toString();

        if (messageId != null && messageId.isNotEmpty) {
          final idx = _messages.indexWhere(
                  (m) => m['_id']?.toString() == messageId);
          if (idx >= 0) {
            final List<dynamic> updated = List.from(_messages);
            updated[idx] = {
              ...Map<String, dynamic>.from(updated[idx]),
              'isDelete': true,
              'text': 'Message deleted',
            };
            _messages = updated;
            _safeNotifyListeners();
            print('✅ Message deleted in UI: $messageId');
          } else {
            print('⚠️ Message not found for deletion: $messageId');
          }
        }
      } catch (e) {
        print('💥 Error handling message deletion: $e');
      }
    }

    // ════════════════════════════════════════════════════════════════════════
    //  CALL HISTORY STATE
    // ════════════════════════════════════════════════════════════════════════
    List<dynamic> _callHistory = [];
    Map<String, dynamic> _callPagination = {};
    bool _isCallHistoryLoading = false;

    List<dynamic> get callHistory => _callHistory;
    Map<String, dynamic> get callPagination => _callPagination;
    bool get isCallHistoryLoading => _isCallHistoryLoading;

    Future<void> fetchCallHistory({
      int pageNo = 1,
      int limit = 20,
      String? communityId,
    }) async {
      if (_isDisposed) return;
      _isCallHistoryLoading = true;
      _safeNotifyListeners();
      try {
        final result = await _chatService.getCallHistory(
          pageNo: pageNo,
          limit: limit,
          communityId: communityId,
        );
        if (result['error'] == false) {
          if (pageNo == 1) {
            _callHistory = result['data'] ?? [];
          } else {
            _callHistory = [..._callHistory, ...result['data'] ?? []];
          }
          _callPagination = result['pagination'] ?? {};
        }
      } catch (e) {
        debugPrint('💥 Error fetching call history: $e');
      }
      _isCallHistoryLoading = false;
      _safeNotifyListeners();
    }

    Future<Map<String, dynamic>?> saveCallHistory({
      required String receiverId,
      required String type,
      required String status,
      String? callerId,
      int? duration,
      String? communityId,
    }) async {
      if (_isDisposed) return null;
      try {
        final result = await _chatService.saveCallHistory(
          receiverId: receiverId,
          type: type,
          status: status,
          callerId: callerId,
          duration: duration,
          communityId: communityId,
        );
        return result;
      } catch (e) {
        debugPrint('💥 Error saving call history: $e');
        return null;
      }
    }

    void _handleMessageEdited(Map<String, dynamic> data) {
      if (_isDisposed) return;
      try {
        final messageId = data['messageId']?.toString()
            ?? data['message']?['_id']?.toString();

        final newText = data['message']?['text']?.toString()
            ?? data['newText']?.toString();

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
            final msgMap      = Map<String, dynamic>.from(msg);
            final msgSender   = _extractId(msgMap['senderId']);
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
      if (m['senderId']  is Map) m['senderId']    = _extractId(m['senderId']);

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

    // ADD these to PersonalChatProvider class (after existing message-related fields):

// ════════════════════════════════════════════════════════════════════════
//  PAGINATION STATE
// ════════════════════════════════════════════════════════════════════════
    int _messagePageNo = 1;
    int _messageTotalPages = 1;
    bool _messageHasMore = false;
    bool _isLoadingMoreMessages = false;

    int get messagePageNo => _messagePageNo;
    int get messageTotalPages => _messageTotalPages;
    bool get messageHasMore => _messageHasMore;
    bool get isLoadingMoreMessages => _isLoadingMoreMessages;

// ════════════════════════════════════════════════════════════════════════
//  REPLACE fetchConversation with pagination support
// ════════════════════════════════════════════════════════════════════════

    Future<void> fetchConversation(String userId, {int pageNo = 1}) async {
      if (_isDisposed) return;

      final isNewConversation = _currentReceiverId != userId;
      if (isNewConversation) {
        _messages = [];
        _currentReceiverId = userId;
        _messagePageNo = 1;
      }

      if (_messages.isEmpty && pageNo == 1) {
        _isConversationLoading = true;
        _safeNotifyListeners();
      } else if (pageNo > 1) {
        _isLoadingMoreMessages = true;
        _safeNotifyListeners();
      }

      _error = null;

      try {
        if (_currentUserId != null) {
          _chatService.joinConversation(_currentUserId!, userId);
        }

        final result = await _chatService.getMessages(
          userId: userId,
          pageNo: pageNo,
          limit: 10,
        );

        print('🔍 Result error: ${result['error']}');
        print('🔍 Data type: ${result['data'].runtimeType}');

        // ❌ CHECK FOR ERROR FIRST
        if (result['error'] == true) {
          _error = result['message'] ?? 'Failed to fetch';
          _isConversationLoading = false;
          _isLoadingMoreMessages = false;
          _safeNotifyListeners();
          return;
        }

        // ✅ STEP 1: Extract the nested data object
        // Backend sends: { data: { messages: [...], userData: {...} }, pagination: {...} }
        Map<String, dynamic>? dataObj;
        List<dynamic> rawMessages = [];

        if (result['data'] is Map<String, dynamic>) {
          dataObj = result['data'] as Map<String, dynamic>;

          // ✅ STEP 2: Get messages from nested structure
          if (dataObj!['messages'] is List) {
            rawMessages = dataObj['messages'] as List<dynamic>;
          }

          // ✅ STEP 3: Get user data
          if (dataObj['userData'] is Map<String, dynamic>) {
            _userData = dataObj['userData'] as Map<String, dynamic>;
          }
        }

        print('📨 Extracted ${rawMessages.length} messages');

        // ✅ STEP 4: Process each message
        final fetched = rawMessages.map((m) {
          if (m is Map<String, dynamic>) {
            return _processMessage(m);
          }
          return <String, dynamic>{};
        }).toList();

        // ✅ STEP 5: Extract pagination
        final pagination = result['pagination'] as Map<String, dynamic>? ?? {};
        _messagePageNo = (pagination['currentPage'] as int?) ?? pageNo;
        _messageTotalPages = (pagination['totalPages'] as int?) ?? 1;
        _messageHasMore = (pagination['hasMore'] as bool?) ?? false;

        print('✅ Page $pageNo: ${fetched.length} messages | '
            'Pages: $_messageTotalPages | hasMore: $_messageHasMore');

        // ✅ STEP 6: Update messages list
        if (pageNo == 1) {
          // First page: replace all
          final optimisticOnly = _messages.where(
                (m) => m['isOptimistic'] == true &&
                fetched.every((f) => f['_id'] != m['_id']),
          ).toList();
          _messages = [...fetched, ...optimisticOnly];
        } else {
          // Load more: prepend older
          _messages = [...fetched, ..._messages];
          print('➕ Total messages now: ${_messages.length}');
        }

        // ✅ STEP 7: Sort by date
        _messages.sort((a, b) {
          try {
            final aDate = DateTime.parse(a['createdAt'].toString());
            final bDate = DateTime.parse(b['createdAt'].toString());
            return aDate.compareTo(bDate);
          } catch (e) {
            return 0;
          }
        });

        _error = null;

      } catch (e, st) {
        print('💥 CATCH ERROR: $e');
        print('📍 Stack: $st');
        _error = 'Error: $e';
      } finally {
        _isConversationLoading = false;
        _isLoadingMoreMessages = false;
        _safeNotifyListeners();
      }
    }

// ════════════════════════════════════════════════════════════════════════
//  LOAD OLDER MESSAGES (call when scrolling up)
// ════════════════════════════════════════════════════════════════════════

    Future<void> loadOlderMessages(String userId) async {
      if (_isDisposed) return;

      // ✅ Don't load if already at the end or already loading
      if (!_messageHasMore || _isLoadingMoreMessages) {
        print('⚠️ No more messages or already loading');
        return;
      }

      final nextPage = _messagePageNo + 1;
      print('🔄 Loading page $nextPage...');

      await fetchConversation(userId, pageNo: nextPage);
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

      final tempId     = 'temp_${DateTime.now().millisecondsSinceEpoch}';
      final optimistic = {
        '_id':          tempId,
        'text':         text,
        'senderId':     _currentUserId ?? '',
        'receiverId':   receiverId,
        'readBy':       readBy,
        'createdAt':    DateTime.now().toIso8601String(),
        'status':       'sending',
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
          _lastSentMessage  = response['data'];
          final messageData = response['data']['message'] ?? response['data'];
          final idx         = _messages.indexWhere((m) => m['_id'] == tempId);
          if (idx >= 0) {
            final List<dynamic> updated = List.from(_messages);
            updated[idx] = _processMessage(messageData);
            _messages    = updated;
          }
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

      final tempId     = 'temp_${DateTime.now().millisecondsSinceEpoch}';
      final optimistic = {
        '_id':           tempId,
        'fileName':      file.path.split('/').last,
        'fileUrl':       file.path,
        'senderId':      _currentUserId ?? '',
        'receiverId':    receiverId,
        'isFile':        true,
        'readBy':        readBy,
        'createdAt':     DateTime.now().toIso8601String(),
        'status':        'sending',
        'isOptimistic':  true,
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
          useSocket:  _isSocketConnected, // ✅ live check
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

      final tempId     = 'temp_${DateTime.now().millisecondsSinceEpoch}';
      final optimistic = {
        '_id':           tempId,
        'audioUrl':      audioFile.path,
        'senderId':      _currentUserId ?? '',
        'receiverId':    receiverId,
        'isAudio':       true,
        'readBy':        readBy,
        'createdAt':     DateTime.now().toIso8601String(),
        'status':        'sending',
        'isOptimistic':  true,
        'localFilePath': audioFile.path,
        if (audioDurationMs != null) 'audioDurationMs': audioDurationMs,
        if (image   != null) 'image':   image,
        if (replyTo != null) 'replyTo': replyTo,
      };
      _messages = [..._messages, optimistic];
      notifyListeners();

      try {
        final response = await _chatService.sendVoiceMessage(
          audioFile:       audioFile,
          receiverId:      receiverId,
          readBy:          readBy,
          image:           image,
          replyTo:         replyTo,
          audioDurationMs: audioDurationMs,
          useSocket:       _isSocketConnected, // ✅ live check
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
          senderId:   senderId,
          receiverId: receiverId,
          useSocket:  _isSocketConnected, // ✅ live check
        );

        if (response['error'] == false && !_isSocketConnected) {
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
    //  DELETE MESSAGE
    // ════════════════════════════════════════════════════════════════════════
    // ════════════════════════════════════════════════════════════════════════
  //  DELETE MESSAGE
  // ════════════════════════════════════════════════════════════════════════
    Future<Map<String, dynamic>?> deleteMessage({
      required String messageId,
      required String receiverId,
    }) async {
      try {
        // ✅ Optimistic update first
        final idx = _messages.indexWhere(
                (m) => m['_id']?.toString() == messageId);
        if (idx >= 0) {
          final List<dynamic> updated = List.from(_messages);
          updated[idx] = {
            ...Map<String, dynamic>.from(updated[idx]),
            'isDelete': true,
            'text': 'Message deleted',
          };
          _messages = updated;
          notifyListeners();
        }

        // ✅ Wait up to 10s for socket if not connected
        int attempts = 0;
        while (!(_socketService?.isConnected ?? false) && attempts < 20) {
          await Future.delayed(const Duration(milliseconds: 500));
          attempts++;
          print('⏳ [DELETE] Waiting for socket... attempt $attempts');
        }

        final socket = _socketService?.socket;
        if (socket == null || !(_socketService?.isConnected ?? false)) {
          print('❌ [DELETE] Socket not ready — optimistic update kept');
          return {'error': false, 'message': 'Deleted locally'};
        }

        socket.emit('deleteMessage', {
          'messageId': messageId,
          'receiverId': receiverId,
        });
        print('✅ [DELETE] Emitted via socket');
        return {'error': false, 'message': 'Message deleted'};
      } catch (e) {
        return {'error': true, 'message': 'Error deleting: $e'};
      }
    }

  // ════════════════════════════════════════════════════════════════════════
  //  EDIT MESSAGE
  // ════════════════════════════════════════════════════════════════════════
    Future<Map<String, dynamic>?> editMessage({
      required String messageId,
      required String newText,
      required String receiverId,
    }) async {
      try {
        // ✅ Optimistic update first
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
          notifyListeners();
        }

        // ✅ Wait up to 10s for socket if not connected
        int attempts = 0;
        while (!(_socketService?.isConnected ?? false) && attempts < 20) {
          await Future.delayed(const Duration(milliseconds: 500));
          attempts++;
          print('⏳ [EDIT] Waiting for socket... attempt $attempts');
        }

        final socket = _socketService?.socket;
        if (socket == null || !(_socketService?.isConnected ?? false)) {
          print('❌ [EDIT] Socket not ready — optimistic update kept');
          return {'error': false, 'message': 'Edited locally'};
        }

        socket.emit('editMessage', {
          'messageId': messageId,
          'newText': newText,
          'receiverId': receiverId,
        });
        print('✅ [EDIT] Emitted via socket');
        return {'error': false, 'message': 'Message edited'};
      } catch (e) {
        return {'error': true, 'message': 'Error editing: $e'};
      }
    }

    // ════════════════════════════════════════════════════════════════════════
    //  LOCAL STATE HELPERS
    // ════════════════════════════════════════════════════════════════════════
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

    Future<bool> reconnectSocket() async {
      if (_socketService?.isConnected == true) {
        print('✅ Socket already connected — skip reconnect');
        return true;
      }
      return await initializeSocket();
    }

    // ✅ Null-safe
    bool isSocketConnected() => _socketService?.isConnected ?? false;

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
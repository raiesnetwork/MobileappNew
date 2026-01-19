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

  // CRITICAL FIX: Use separate subscriptions with proper cancellation
  StreamSubscription<bool>? _connectionSubscription;
  StreamSubscription<Map<String, dynamic>>? _newMessageSubscription;
  StreamSubscription<Map<String, dynamic>>? _messageDeletedSubscription;
  StreamSubscription<Map<String, dynamic>>? _messageEditedSubscription;
  StreamSubscription<Map<String, dynamic>>? _readStatusSubscription;

  bool _isSendingMessage = false;
  String? _sendMessageError;
  Map<String, dynamic>? _lastSentMessage;

  bool get isSendingMessage => _isSendingMessage;
  String? get sendMessageError => _sendMessageError;
  Map<String, dynamic>? get lastSentMessage => _lastSentMessage;

  bool _isLoading = false;
  String? _error;
  Map<String, dynamic> _chatData = {
    'error': true,
    'message': 'No chats loaded',
    'data': []
  };

  bool get isLoading => _isLoading;
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
    // CRITICAL FIX: Cancel existing subscriptions first
    _cancelSocketSubscriptions();

    // Listen for connection changes
    _connectionSubscription = _socketService.onConnectionChanged.listen(
      (connected) {
        _socketConnected = connected;
        print('🔌 Socket connection changed: $connected');
        _safeNotifyListeners();
      },
      onError: (error) {
        print('💥 Connection stream error: $error');
      },
      cancelOnError: false,
    );

    // Listen for new messages
    _newMessageSubscription = _socketService.onNewMessage.listen(
      (messageData) {
        print('📥 Received new message via socket: ${messageData['message']}');
        _handleNewMessage(messageData);
      },
      onError: (error) {
        print('💥 New message stream error: $error');
      },
      cancelOnError: false,
    );

    // Listen for message deletions
    _messageDeletedSubscription = _socketService.onMessageDeleted.listen(
      (data) {
        print('🗑️ Message deleted via socket: ${data['messageId']}');
        _handleMessageDeleted(data);
      },
      onError: (error) {
        print('💥 Message deleted stream error: $error');
      },
      cancelOnError: false,
    );

    // Listen for message edits
    _messageEditedSubscription = _socketService.onMessageEdited.listen(
      (data) {
        print('✏️ Message edited via socket: ${data['messageId']}');
        _handleMessageEdited(data);
      },
      onError: (error) {
        print('💥 Message edited stream error: $error');
      },
      cancelOnError: false,
    );

    // Listen for read status updates
    _readStatusSubscription = _socketService.onReadStatusUpdated.listen(
      (data) {
        print('👁️ Read status updated via socket');
        _handleReadStatusUpdated(data);
      },
      onError: (error) {
        print('💥 Read status stream error: $error');
      },
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

  // CRITICAL FIX: Handle new messages without duplicates
  void _handleNewMessage(Map<String, dynamic> data) {
    if (_isDisposed) return;

    try {
      final message = data['message'];
      if (message == null) return;

      final messageId = message['_id'];
      final messageSenderId = message['senderId'] is Map
          ? message['senderId']['_id']
          : message['senderId'];
      final messageReceiverId = message['receiverId'] is Map
          ? message['receiverId']['_id']
          : message['receiverId'];

      // Only process if this is for current conversation
      if (_currentReceiverId != null &&
          (messageSenderId == _currentReceiverId ||
              messageReceiverId == _currentReceiverId ||
              messageSenderId == _currentUserId ||
              messageReceiverId == _currentUserId)) {
        // Check if message already exists
        final existingIndex =
            _messages.indexWhere((m) => m['_id'] == messageId);

        if (existingIndex == -1) {
          // New message - add it
          final processedMessage = _processMessage(message);
          _messages.add(processedMessage);
          _safeNotifyListeners();
          print('✅ New message added to conversation');
        } else {
          // Message exists - check if it's a temp message to replace
          final existing = _messages[existingIndex];
          if (existing['_id'].toString().startsWith('temp_')) {
            // Replace temp message with real one
            _messages[existingIndex] = _processMessage(message);
            _safeNotifyListeners();
            print('✅ Temp message replaced with real message');
          } else {
            // Update existing message (status change, etc.)
            _messages[existingIndex] = _processMessage(message);
            _safeNotifyListeners();
            print('✅ Existing message updated');
          }
        }
      }
    } catch (e) {
      print('💥 Error handling new message: $e');
    }
  }

  void _handleMessageDeleted(Map<String, dynamic> data) {
    if (_isDisposed) return;

    try {
      final messageId = data['messageId'];
      if (messageId != null) {
        _messages.removeWhere((message) => message['_id'] == messageId);
        _safeNotifyListeners();
        print('✅ Message removed from local list');
      }
    } catch (e) {
      print('💥 Error handling message deletion: $e');
    }
  }

  void _handleMessageEdited(Map<String, dynamic> data) {
    if (_isDisposed) return;

    try {
      final messageId = data['messageId'];
      final newText = data['newText'];

      if (messageId != null && newText != null) {
        final messageIndex =
            _messages.indexWhere((message) => message['_id'] == messageId);
        if (messageIndex >= 0) {
          _messages[messageIndex]['text'] = newText;
          _messages[messageIndex]['isEdited'] = true;
          _messages[messageIndex]['editedAt'] = DateTime.now().toString();
          _safeNotifyListeners();
          print('✅ Message updated in local list');
        }
      }
    } catch (e) {
      print('💥 Error handling message edit: $e');
    }
  }

  void _handleReadStatusUpdated(Map<String, dynamic> data) {
    if (_isDisposed) return;

    try {
      final senderId = data['senderId'];
      final receiverId = data['receiverId'];

      if (senderId != null && receiverId != null) {
        _messages = _messages.map((message) {
          final messageMap = Map<String, dynamic>.from(message);
          if (messageMap['senderId'] == senderId &&
              messageMap['receiverId'] == receiverId) {
            messageMap['readBy'] = true;
          }
          return messageMap;
        }).toList();
        _safeNotifyListeners();
        print('✅ Read status updated in local messages');
      }
    } catch (e) {
      print('💥 Error handling read status update: $e');
    }
  }

  Map<String, dynamic> _processMessage(Map<String, dynamic> message) {
    final messageMap = Map<String, dynamic>.from(message);

    messageMap['status'] = messageMap['status'] ?? 'sent';
    messageMap['readBy'] = messageMap['readBy'] ?? false;

    if (messageMap['receiverId'] is Map) {
      messageMap['receiverId'] = messageMap['receiverId']['_id'];
    }
    if (messageMap['senderId'] is Map) {
      messageMap['senderId'] = messageMap['senderId']['_id'];
    }

    if (messageMap['isFile'] == true && messageMap['fileUrl'] != null) {
      final rawUrl = messageMap['fileUrl'] as String;
      messageMap['fileUrl'] = constructFullUrl(rawUrl);
    }

    if (messageMap['isAudio'] == true && messageMap['audioUrl'] != null) {
      final rawUrl = messageMap['audioUrl'] as String;
      messageMap['audioUrl'] = constructFullUrl(rawUrl);
    }

    return messageMap;
  }

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
      _error = 'Exception: ${e.toString()}';
    }

    _isLoading = false;
    _safeNotifyListeners();
  }

  Future<void> fetchConversation(String userId) async {
    if (_isDisposed) return;

    _isLoading = true;
    _error = null;
    _currentReceiverId = userId;
    _safeNotifyListeners();

    try {
      if (_currentUserId != null) {
        _chatService.joinConversation(_currentUserId!, userId);
      }

      final result = await _chatService.getMessages(userId: userId);

      if (result['error'] == false && result['data'] != null) {
        final data = result['data'];
        _userData = data['userData'] ?? {};

        final rawMessages = data['messages'] as List<dynamic>? ?? [];
        _messages =
            rawMessages.map((message) => _processMessage(message)).toList();

        print('✅ Conversation loaded: ${_messages.length} messages');
      } else {
        _error = result['message'] ?? 'Failed to fetch conversation';
        _messages = [];
        _userData = {};
      }
    } catch (e) {
      _error = "Error fetching conversation: $e";
      _messages = [];
      _userData = {};
    } finally {
      _isLoading = false;
      _safeNotifyListeners();
    }
  }

  void leaveConversation() {
    if (_currentUserId != null && _currentReceiverId != null) {
      _chatService.leaveConversation(_currentUserId!, _currentReceiverId!);
    }
    _currentReceiverId = null;
  }

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
    _lastSentMessage = null;
    _safeNotifyListeners();

    try {
      final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';

      final optimisticMessage = {
        '_id': tempId,
        'text': text,
        'senderId': _currentUserId ?? '',
        'receiverId': receiverId,
        'readBy': readBy,
        'createdAt': DateTime.now().toIso8601String(),
        'status': 'sending',
        'isOptimistic': true,
        if (image != null && image.isNotEmpty) 'image': image,
        if (replyTo != null && replyTo.isNotEmpty) 'replayTo': replyTo,
      };

      _messages.add(optimisticMessage);
      _safeNotifyListeners();

      final response = await _chatService.sendMessage(
        receiverId: receiverId,
        text: text,
        readBy: readBy,
        image: image,
        replyTo: replyTo,
      );

      if (response['error'] == false) {
        _lastSentMessage = response['data'];
        final messageData = response['data']['message'] ?? response['data'];

        // Replace temp message with real one
        final messageIndex = _messages.indexWhere((m) => m['_id'] == tempId);
        if (messageIndex >= 0) {
          final realMessage = _processMessage(messageData);
          _messages[messageIndex] = realMessage;
        }

        _safeNotifyListeners();
        return {'success': true, 'error': false, 'data': response['data']};
      } else {
        _messages.removeWhere((m) => m['_id'] == tempId);
        _sendMessageError = response['message'];
        _safeNotifyListeners();
        return {'success': false, 'error': true, 'message': _sendMessageError};
      }
    } catch (e) {
      _sendMessageError = 'Exception: ${e.toString()}';
      _safeNotifyListeners();
      return {'success': false, 'error': true, 'message': e.toString()};
    } finally {
      _isSendingMessage = false;
      _safeNotifyListeners();
    }
  }

  // Add this helper method to safely notify listeners
  void _safeNotifyListeners() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  void clearMessages() {
    if (_isDisposed) return;
    _messages.clear();
    _userData.clear();
    _currentReceiverId = null;
    _safeNotifyListeners();
  }

  Future<Map<String, dynamic>?> sendFileMessage({
    required File file,
    required String receiverId,
    String? replyTo,
    bool readBy = false,
  }) async {
    _isSendingMessage = true;
    _sendMessageError = null;
    _lastSentMessage = null;
    notifyListeners();

    try {
      final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
      final fileName = file.path.split('/').last;

      final optimisticMessage = {
        '_id': tempId,
        'fileName': fileName,
        'fileUrl': file.path,
        'senderId': _currentUserId ?? '',
        'receiverId': receiverId,
        'isFile': true,
        'readBy': readBy,
        'createdAt': DateTime.now().toIso8601String(),
        'status': 'sending',
        'isOptimistic': true,
        'localFilePath': file.path,
      };

      _messages.add(optimisticMessage);
      notifyListeners();

      final response = await _chatService.sendFileMessage(
        file: file,
        receiverId: receiverId,
        readBy: readBy,
        replyTo: replyTo,
        useSocket: _socketConnected,
      );

      final messageIndex = _messages.indexWhere((m) => m['_id'] == tempId);

      if (response['error'] == false && response['data'] != null) {
        _lastSentMessage = response['data'];

        final messageData = response['data']['message'] ?? response['data'];
        final realMessage = _processMessage(messageData);

        if (messageIndex >= 0) {
          _messages[messageIndex] = realMessage;
        } else {
          _messages.add(realMessage);
        }

        print('✅ File message sent successfully');
        notifyListeners();
        return response['data'];
      } else {
        _sendMessageError =
            response['message'] ?? 'Failed to send file message';
        if (messageIndex >= 0) {
          _messages[messageIndex]['status'] = 'failed';
        }
        print('❌ Failed to send file message: $_sendMessageError');
        notifyListeners();
        return null;
      }
    } catch (e) {
      _sendMessageError = 'Exception: ${e.toString()}';
      print('💥 Exception while sending file message: $_sendMessageError');
      notifyListeners();
      return null;
    } finally {
      _isSendingMessage = false;
      notifyListeners();
    }
  }

  /// Send voice message with socket integration
  // In personal_chat_provider.dart
// Replace the sendVoiceMessage method with this:

  /// Send voice message with socket integration
  Future<Map<String, dynamic>?> sendVoiceMessage({
    required File audioFile,
    required String receiverId,
    bool readBy = false,
    String? replyTo,
    String? image,
    int? audioDurationMs, // ✅ ADD THIS PARAMETER
  }) async {
    _isSendingMessage = true;
    _sendMessageError = null;
    _lastSentMessage = null;
    notifyListeners();

    try {
      // Create optimistic message with duration
      final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
      final optimisticMessage = {
        '_id': tempId,
        'audioUrl': audioFile.path,
        'senderId': _currentUserId ?? '',
        'receiverId': receiverId,
        'isAudio': true,
        'readBy': readBy,
        'createdAt': DateTime.now().toIso8601String(),
        'status': 'sending',
        'isOptimistic': true,
        'localFilePath': audioFile.path,
        // ✅ INCLUDE DURATION IN OPTIMISTIC MESSAGE
        if (audioDurationMs != null) 'audioDurationMs': audioDurationMs,
        if (image != null && image.isNotEmpty) 'image': image,
        if (replyTo != null && replyTo.isNotEmpty) 'replyTo': replyTo,
      };

      _messages = [..._messages, optimisticMessage];
      notifyListeners();

      print('📤 Sending voice with duration: $audioDurationMs ms');

      // ✅ PASS DURATION TO SERVICE
      final response = await _chatService.sendVoiceMessage(
        audioFile: audioFile,
        receiverId: receiverId,
        readBy: readBy,
        image: image,
        replyTo: replyTo,
        audioDurationMs: audioDurationMs, // ✅ PASS IT HERE
        useSocket: _socketConnected,
      );

      final messageIndex = _messages.indexWhere((m) => m['_id'] == tempId);

      if (response['error'] == false && messageIndex >= 0) {
        _lastSentMessage = response['data'];

        // Replace optimistic message with real message
        final messageData = response['data']['message'] ?? response['data'];
        final realMessage = _processMessage(messageData);

        // Keep local path and ensure duration is present
        realMessage['localFilePath'] = audioFile.path;

        // ✅ ENSURE DURATION IS IN THE MESSAGE
        if (realMessage['audioDurationMs'] == null && audioDurationMs != null) {
          realMessage['audioDurationMs'] = audioDurationMs;
          print('⚠️ Duration not in response, using local value: $audioDurationMs ms');
        } else {
          print('✅ Duration in message: ${realMessage['audioDurationMs']} ms');
        }

        _messages[messageIndex] = realMessage;

        print('✅ Voice message sent successfully');
        notifyListeners();
        return response['data'];
      } else {
        _sendMessageError =
            response['message'] ?? 'Failed to send voice message';
        if (messageIndex >= 0) {
          _messages[messageIndex] = {
            ..._messages[messageIndex],
            'status': 'failed',
          };
        }
        print('❌ Failed to send voice message: $_sendMessageError');
        notifyListeners();
        return null;
      }
    } catch (e) {
      _sendMessageError = 'Exception: ${e.toString()}';
      print('💥 Exception while sending voice message: $_sendMessageError');
      notifyListeners();
      return null;
    } finally {
      _isSendingMessage = false;
      notifyListeners();
    }
  }

  /// Update read status with socket integration
  Future<Map<String, dynamic>?> updateReadStatus({
    required String senderId,
    required String receiverId,
  }) async {
    try {
      final response = await _chatService.updateReadStatus(
        senderId: senderId,
        receiverId: receiverId,
        useSocket: _socketConnected,
      );

      print('Debug - updateReadStatus response: $response');

      if (response['error'] == false) {
        print('✅ Read status updated successfully');

        // Update local messages if not updated by socket event
        if (!_socketConnected) {
          _messages = _messages.map((message) {
            final messageMap = Map<String, dynamic>.from(message);
            if (messageMap['senderId'] == senderId &&
                messageMap['receiverId'] == receiverId) {
              messageMap['readBy'] = true;
            }
            return messageMap;
          }).toList();
          notifyListeners();
        }

        return {
          'success': true,
          'error': false,
          'message': response['message'],
          'data': response['data'],
        };
      } else {
        _sendMessageError =
            response['message'] ?? 'Failed to update read status';
        print('❌ Failed to update read status: $_sendMessageError');
        return {
          'success': false,
          'error': true,
          'message': _sendMessageError,
        };
      }
    } catch (e) {
      _sendMessageError = 'Exception: ${e.toString()}';
      print('💥 Exception while updating read status: $_sendMessageError');
      return {
        'success': false,
        'error': true,
        'message': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>?> deleteMessage({
    required String messageId,
    required String receiverId,
  }) async {
    try {
      print('🗑️ Deleting message: $messageId');

      final response = await _chatService.deleteMessage(
        messageId: messageId,
        receiverId: receiverId,
        useSocket: _socketConnected,
      );

      if (response != null && response['error'] != true) {
        _messages.removeWhere((message) => message['_id'] == messageId);
        print('✅ Message removed from local list');
        notifyListeners();

        // Socket will handle real-time sync for other users
        // No need to refresh entire conversation
        return response;
      } else {
        print('❌ Delete failed: ${response?['message']}');
        return response;
      }
    } catch (e) {
      print('💥 Error in deleteMessage: $e');
      return {
        'error': true,
        'message': 'Error deleting message: $e',
      };
    }
  }


  Future<Map<String, dynamic>?> editMessage({
    required String messageId,
    required String newText,
    required String receiverId,
  }) async {
    try {
      print('✏️ Editing message: $messageId');

      final response = await _chatService.editMessage(
        messageId: messageId,
        newText: newText,
        receiverId: receiverId,
        useSocket: _socketConnected,
      );

      if (response != null && response['error'] != true) {
        // Update local message immediately
        final messageIndex =
            _messages.indexWhere((message) => message['_id'] == messageId);
        if (messageIndex >= 0) {
          _messages[messageIndex]['text'] = newText;
          _messages[messageIndex]['isEdited'] = true;
          _messages[messageIndex]['editedAt'] = DateTime.now().toString();
          notifyListeners();
        }



        print('✅ Message edited successfully');
        return response;
      } else {
        print('❌ Edit failed: ${response?['message']}');
        return response;
      }
    } catch (e) {
      print('💥 Error in editMessage: $e');
      return {
        'error': true,
        'message': 'Error editing message: $e',
      };
    }
  }

  /// Helper methods for optimistic message handling
  void addOptimisticMessage(Map<String, dynamic> message) {
    _messages = [..._messages, message];
    notifyListeners();
  }

  void replaceOptimisticMessage(
      String tempId, Map<String, dynamic> realMessage) {
    final messageIndex = _messages.indexWhere((m) => m['_id'] == tempId);
    if (messageIndex >= 0) {
      final updatedMessages = List<Map<String, dynamic>>.from(_messages);
      updatedMessages[messageIndex] = realMessage;
      _messages = updatedMessages;
      notifyListeners();
    }
  }

  void updateOptimisticMessageStatus(String tempId, String status) {
    final messageIndex = _messages.indexWhere((m) => m['_id'] == tempId);
    if (messageIndex >= 0) {
      final updatedMessages = List<Map<String, dynamic>>.from(_messages);
      updatedMessages[messageIndex] = {
        ...updatedMessages[messageIndex],
        'status': status,
      };
      _messages = updatedMessages;
      notifyListeners();
    }
  }

  void removeOptimisticMessage(String tempId) {
    _messages = _messages.where((m) => m['_id'] != tempId).toList();
    notifyListeners();
  }

  void clearOptimisticMessages() {
    _messages = _messages.where((m) => m['isOptimistic'] != true).toList();
    notifyListeners();
  }

  /// Retry failed message
  Future<void> retryMessage(String tempId) async {
    final messageIndex = _messages.indexWhere((m) => m['_id'] == tempId);
    if (messageIndex >= 0) {
      final message = _messages[messageIndex];

      // Update status to sending
      updateOptimisticMessageStatus(tempId, 'sending');

      // Retry based on message type
      if (message['isAudio'] == true) {
        final audioFile = File(message['localFilePath']);
        await sendVoiceMessage(
          audioFile: audioFile,
          receiverId: message['receiverId'],
          readBy: message['readBy'] ?? false,
          image: message['image'],
        );
      } else if (message['isFile'] == true) {
        final file = File(message['localFilePath']);
        await sendFileMessage(
          file: file,
          receiverId: message['receiverId'],
          readBy: message['readBy'] ?? false,
        );
      } else {
        await sendMessage(
          receiverId: message['receiverId'],
          text: message['text'] ?? '',
          readBy: message['readBy'] ?? false,
          image: message['image'],
          replyTo: message['replyTo'],
        );
      }

      // Remove the failed message after retry
      removeOptimisticMessage(tempId);
    }
  }

  /// Reconnect socket manually
  Future<bool> reconnectSocket() async {
    print('🔄 Manually reconnecting socket...');
    return await initializeSocket();
  }

  /// Check socket connection status
  bool isSocketConnected() {
    return _socketService.isConnected;
  }

  /// Get message by ID
  Map<String, dynamic>? getMessageById(String messageId) {
    try {
      return _messages.firstWhere(
        (message) => message['_id'] == messageId,
      );
    } catch (e) {
      return null;
    }
  }

  /// Get failed messages count
  int get failedMessagesCount {
    return _messages.where((message) => message['status'] == 'failed').length;
  }

  /// Get pending messages count
  int get pendingMessagesCount {
    return _messages.where((message) => message['status'] == 'sending').length;
  }

  /// Retry all failed messages
  Future<void> retryAllFailedMessages() async {
    final failedMessages =
        _messages.where((message) => message['status'] == 'failed').toList();

    for (final message in failedMessages) {
      await retryMessage(message['_id']);
    }
  }

  /// Mark conversation as read
  Future<void> markConversationAsRead() async {
    if (_currentUserId != null && _currentReceiverId != null) {
      await updateReadStatus(
        senderId: _currentReceiverId!,
        receiverId: _currentUserId!,
      );
    }
  }

  /// Get unread messages count for current conversation
  int get unreadMessagesCount {
    return _messages
        .where((message) =>
            message['senderId'] == _currentReceiverId &&
            message['readBy'] != true)
        .length;
  }

  /// Check if user is typing (placeholder for future implementation)
  bool _isTyping = false;
  bool get isTyping => _isTyping;

  /// Set typing status (placeholder for future implementation)
  void setTypingStatus(bool typing) {
    _isTyping = typing;
    notifyListeners();
  }

  /// Get last message in conversation
  Map<String, dynamic>? get lastMessage {
    if (_messages.isNotEmpty) {
      return _messages.last;
    }
    return null;
  }

  /// Search messages by text
  List<Map<String, dynamic>> searchMessages(String query) {
    if (query.trim().isEmpty) return [];

    final lowerQuery = query.toLowerCase();
    return _messages
        .where((message) {
          final text = message['text']?.toString().toLowerCase() ?? '';
          final fileName = message['fileName']?.toString().toLowerCase() ?? '';
          return text.contains(lowerQuery) || fileName.contains(lowerQuery);
        })
        .cast<Map<String, dynamic>>()
        .toList();
  }

  /// Get messages by date
  List<Map<String, dynamic>> getMessagesByDate(DateTime date) {
    return _messages
        .where((message) {
          final messageDate = DateTime.tryParse(message['createdAt'] ?? '');
          if (messageDate == null) return false;

          return messageDate.year == date.year &&
              messageDate.month == date.month &&
              messageDate.day == date.day;
        })
        .cast<Map<String, dynamic>>()
        .toList();
  }

  /// Get messages by type (text, file, audio)
  List<Map<String, dynamic>> getMessagesByType(String type) {
    switch (type.toLowerCase()) {
      case 'text':
        return _messages
            .where((message) =>
                message['isFile'] != true && message['isAudio'] != true)
            .cast<Map<String, dynamic>>()
            .toList();
      case 'file':
        return _messages
            .where((message) => message['isFile'] == true)
            .cast<Map<String, dynamic>>()
            .toList();
      case 'audio':
      case 'voice':
        return _messages
            .where((message) => message['isAudio'] == true)
            .cast<Map<String, dynamic>>()
            .toList();
      default:
        return [];
    }
  }

  /// Export conversation (placeholder for future implementation)
  Future<String> exportConversation({String format = 'json'}) async {
    // This could be implemented to export chat history
    throw UnimplementedError('Export functionality not yet implemented');
  }

  /// Clear error states
  void clearErrors() {
    _error = null;
    _sendMessageError = null;
    notifyListeners();
  }

  /// Refresh current conversation
  Future<void> refreshConversation() async {
    if (_currentReceiverId != null) {
      await fetchConversation(_currentReceiverId!);
    }
  }

  /// Check if current user is sender of message
  bool isMessageFromCurrentUser(Map<String, dynamic> message) {
    return message['senderId'] == _currentUserId;
  }

  /// Get conversation statistics
  Map<String, dynamic> get conversationStats {
    if (_messages.isEmpty) {
      return {
        'totalMessages': 0,
        'textMessages': 0,
        'fileMessages': 0,
        'voiceMessages': 0,
        'unreadMessages': 0,
        'failedMessages': 0,
      };
    }

    return {
      'totalMessages': _messages.length,
      'textMessages': getMessagesByType('text').length,
      'fileMessages': getMessagesByType('file').length,
      'voiceMessages': getMessagesByType('audio').length,
      'unreadMessages': unreadMessagesCount,
      'failedMessages': failedMessagesCount,
    };
  }

  /// Validate message before sending
  bool _validateMessage(String text, {File? file, File? audioFile}) {
    // Check text message
    if (file == null && audioFile == null) {
      return text.trim().isNotEmpty && text.length <= 1000; // Max 1000 chars
    }

    // Check file message
    if (file != null) {
      final fileSizeMB = file.lengthSync() / (1024 * 1024);
      return fileSizeMB <= 50; // Max 50MB
    }

    // Check audio message
    if (audioFile != null) {
      final audioSizeMB = audioFile.lengthSync() / (1024 * 1024);
      return audioSizeMB <= 25; // Max 25MB
    }

    return false;
  }

  /// Get message validation error
  String? getValidationError(String text, {File? file, File? audioFile}) {
    if (file == null && audioFile == null) {
      if (text.trim().isEmpty) {
        return 'Message cannot be empty';
      }
      if (text.length > 1000) {
        return 'Message too long (max 1000 characters)';
      }
    }

    if (file != null) {
      final fileSizeMB = file.lengthSync() / (1024 * 1024);
      if (fileSizeMB > 50) {
        return 'File too large (max 50MB)';
      }
    }

    if (audioFile != null) {
      final audioSizeMB = audioFile.lengthSync() / (1024 * 1024);
      if (audioSizeMB > 25) {
        return 'Audio file too large (max 25MB)';
      }
    }

    return null;
  }

  /// Dispose and cleanup
  void cleanup() {
    _cancelSocketSubscriptions();
    _chatService.disconnectSocket();
    clearMessages();
    clearErrors();
  }
}

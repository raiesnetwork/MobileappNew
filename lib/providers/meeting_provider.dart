import 'package:flutter/material.dart';
import '../services/meeting_service.dart';

enum MeetingRole { host, participant }

enum JoinStatus { idle, requesting, approved, rejected, joined }

class MeetingProvider extends ChangeNotifier {
  final MeetingService _service = MeetingService();

  // Current user info
  String? _currentUserId;
  String? _currentUserName;
  String? _authToken;

  // Connection state
  bool _isConnected = false;

  // Meeting state
  String? _currentMeetingId;
  MeetingRole? _currentRole;
  JoinStatus _joinStatus = JoinStatus.idle;
  bool _isHost = false;

  // Access token
  String? _accessToken;

  // Messages
  String? _errorMessage;
  String? _successMessage;

  // Join requests (for hosts)
  List<Map<String, dynamic>> _pendingRequests = [];

  // Chat
  List<Map<String, dynamic>> _chatMessages = [];
  bool _isChatJoined = false;

  // Getters
  MeetingService get service => _service;
  String? get currentUserId => _currentUserId;
  String? get currentUserName => _currentUserName;
  bool get isConnected => _isConnected;
  String? get currentMeetingId => _currentMeetingId;
  MeetingRole? get currentRole => _currentRole;
  JoinStatus get joinStatus => _joinStatus;
  bool get isHost => _isHost;
  String? get accessToken => _accessToken;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;
  List<Map<String, dynamic>> get pendingRequests => _pendingRequests;
  List<Map<String, dynamic>> get chatMessages => _chatMessages;
  bool get isChatJoined => _isChatJoined;

  void initialize({
    required String userId,
    required String userName,
    String? authToken,
  }) {
    _currentUserId = userId;
    _currentUserName = userName;
    _authToken = authToken;

    _service.connectSocket();
    _setupListeners();
    _service.connect();
  }

  void _setupListeners() {
    // Connection listeners
    _service.onConnect(() {
      debugPrint('✅ Socket connected in provider');
      _isConnected = true;
      if (_currentUserId != null) {
        _service.joinAsUser(_currentUserId!);
      }
      _safeNotifyListeners();
    });

    _service.onDisconnect(() {
      debugPrint('❌ Socket disconnected in provider');
      _isConnected = false;
      _safeNotifyListeners();
    });

    // Join request listeners
    _service.onPendingRequestsUpdate((data) {
      debugPrint('📋 ===== PENDING REQUESTS UPDATE IN PROVIDER =====');
      debugPrint('📋 Raw data: $data');
      debugPrint('📋 Data type: ${data.runtimeType}');

      if (data is List) {
        debugPrint('📋 List length: ${data.length}');
        _pendingRequests = List<Map<String, dynamic>>.from(
          data.map((item) {
            debugPrint('📋 Processing item: $item');
            if (item is Map) {
              return Map<String, dynamic>.from(item);
            }
            return item as Map<String, dynamic>;
          }),
        );
        debugPrint('📋 ✅ Updated pending requests count: ${_pendingRequests.length}');
        if (_pendingRequests.isNotEmpty) {
          debugPrint('📋 Requests details:');
          for (var req in _pendingRequests) {
            debugPrint('   - ${req['name']} (${req['userId']})');
          }
        }
        debugPrint('📋 ================================================');
        _safeNotifyListeners();
      } else {
        debugPrint('⚠️ Data is not a List! Type: ${data.runtimeType}');
      }
    });

    _service.onNewJoinRequest((data) {
      debugPrint('🆕 ===== NEW JOIN REQUEST IN PROVIDER =====');
      debugPrint('🆕 Data: $data');
      debugPrint('🆕 Name: ${data['name']}');
      debugPrint('🆕 UserId: ${data['userId']}');
      debugPrint('🆕 MeetingId: ${data['meetingId']}');

      _successMessage = '${data['name']} wants to join the meeting';
      final requestId = '${data['meetingId']}-${data['userId']}';
      final exists = _pendingRequests.any((req) =>
      '${req['meetingId']}-${req['userId']}' == requestId
      );

      if (!exists) {
        _pendingRequests.add(Map<String, dynamic>.from(data));
        debugPrint('🆕 Added to pending requests. Total: ${_pendingRequests.length}');
      }

      _safeNotifyListeners();
    });

    _service.onJoinApproved((data) async {
      debugPrint('✅ ===== JOIN APPROVED IN PROVIDER =====');
      debugPrint('✅ Data: $data');
      debugPrint('✅ Meeting ID: ${data['meetingId']}');

      _currentMeetingId = data['meetingId'];
      _successMessage = 'Your join request was approved!';

      // CRITICAL: Fetch access token immediately when approved
      debugPrint('🎫 Fetching access token after approval...');
      final tokenSuccess = await _fetchAccessToken(data['meetingId']);

      if (tokenSuccess) {
        debugPrint('✅ Token fetched successfully, setting status to approved');
        _joinStatus = JoinStatus.approved;
      } else {
        debugPrint('❌ Failed to fetch token after approval');
        _errorMessage = 'Failed to get access token after approval';
        _joinStatus = JoinStatus.rejected;
      }

      _safeNotifyListeners();
      debugPrint('✅ ===== JOIN APPROVAL COMPLETE =====');
    });

    _service.onJoinRejected((data) {
      debugPrint('❌ Join rejected: $data');
      _joinStatus = JoinStatus.rejected;
      _errorMessage = 'Your join request was rejected';
      _clearMeetingData();
      _safeNotifyListeners();
    });

    _service.onParticipantApproved((requestId) {
      debugPrint('✅ Participant approved: $requestId');
      _pendingRequests.removeWhere((req) =>
      '${req['meetingId']}-${req['userId']}' == requestId);
      debugPrint('📋 Remaining pending requests: ${_pendingRequests.length}');
      _safeNotifyListeners();
    });

    _service.onParticipantRejected((requestId) {
      debugPrint('❌ Participant rejected: $requestId');
      _pendingRequests.removeWhere((req) =>
      '${req['meetingId']}-${req['userId']}' == requestId);
      debugPrint('📋 Remaining pending requests: ${_pendingRequests.length}');
      _safeNotifyListeners();
    });

    _service.onParticipantCancelled((requestId) {
      debugPrint('🚫 Participant cancelled: $requestId');
      _pendingRequests.removeWhere((req) =>
      '${req['meetingId']}-${req['userId']}' == requestId);
      debugPrint('📋 Remaining pending requests: ${_pendingRequests.length}');
      _safeNotifyListeners();
    });

    // Chat listeners
    _service.onUserJoinedChat((data) {
      debugPrint('👤 User joined chat: ${data['username']}');
      _successMessage = '${data['username']} joined the chat';
      _safeNotifyListeners();
    });

    _service.onNewMessage((message) {
      debugPrint('💬 New message: ${message['username']}: ${message['message']}');
      _chatMessages.add(Map<String, dynamic>.from(message));
      _safeNotifyListeners();
    });

    _service.onChatHistory((messages) {
      debugPrint('📜 Chat history received: ${messages.length} messages');
      if (messages is List) {
        _chatMessages = List<Map<String, dynamic>>.from(
          messages.map((msg) => Map<String, dynamic>.from(msg)),
        );
        _safeNotifyListeners();
      }
    });
  }
  /// Fetch access token after approval (public method for waiting screen)
  Future<bool> fetchAccessTokenAfterApproval(String meetingId) async {
    return await _fetchAccessToken(meetingId);
  }

  /// Join as meeting host
  Future<void> joinAsMeetingHost(String meetingId) async {
    if (_currentUserId == null || _currentUserName == null) {
      _errorMessage = 'User not initialized';
      _safeNotifyListeners();
      return;
    }

    _currentMeetingId = meetingId;
    _currentRole = MeetingRole.host;
    _isHost = true;

    debugPrint('🎬 ===== CREATING AND JOINING MEETING AS HOST =====');
    debugPrint('🎬 Meeting ID: $meetingId');
    debugPrint('🎬 User: $_currentUserName ($_currentUserId)');
    debugPrint('🔌 Socket connected? ${_service.socket?.connected}');

    // Wait for socket connection if not connected
    if (_service.socket?.connected != true) {
      debugPrint('⚠️ Socket not connected, waiting for connection...');

      bool connected = await _waitForConnection();

      if (!connected) {
        _errorMessage = 'Failed to establish socket connection';
        _isHost = false;
        _currentRole = null;
        _currentMeetingId = null;
        _safeNotifyListeners();
        return;
      }
    }

    // Create/join meeting via API
    debugPrint('📡 Calling request-join API...');
    final result = await _service.requestToJoin(
      name: _currentUserName!,
      meetingId: meetingId,
      userId: _currentUserId!,
      authToken: _authToken,
    );

    debugPrint('📦 Request-join result: $result');

    if (result['error'] == true) {
      _errorMessage = result['message'] ?? 'Failed to create meeting';
      _isHost = false;
      _currentRole = null;
      _currentMeetingId = null;
      _safeNotifyListeners();
      return;
    }

    _isHost = result['isHost'] ?? true;
    debugPrint('✅ Is host confirmed from API: $_isHost');

    // CRITICAL: Emit socket event to join as host
    debugPrint('🔌 Emitting join-meeting-host socket event...');
    _service.joinAsMeetingHost(
      meetingId: meetingId,
      userId: _currentUserId!,
    );
    debugPrint('✅ Socket event emitted');

    // Wait for socket to process
    await Future.delayed(const Duration(milliseconds: 1000));

    debugPrint('📋 Pending requests after join: ${_pendingRequests.length}');

    // Get access token
    debugPrint('🎫 Fetching access token...');
    final tokenSuccess = await _fetchAccessToken(meetingId);

    if (tokenSuccess) {
      debugPrint('✅ ===== HOST SETUP COMPLETE =====');
      debugPrint('📊 Final state:');
      debugPrint('   - Is Host: $_isHost');
      debugPrint('   - Meeting ID: $_currentMeetingId');
      debugPrint('   - Socket Connected: ${_service.socket?.connected}');
      debugPrint('   - Pending Requests: ${_pendingRequests.length}');
      debugPrint('================================');
    } else {
      debugPrint('❌ Failed to get access token');
    }

    _safeNotifyListeners();
  }

  /// Wait for socket connection with timeout
  Future<bool> _waitForConnection({int maxAttempts = 20}) async {
    int attempts = 0;

    while (attempts < maxAttempts) {
      if (_service.socket?.connected == true) {
        debugPrint('✅ Socket connected after $attempts attempts');
        return true;
      }

      await Future.delayed(const Duration(milliseconds: 500));
      attempts++;
      debugPrint('🔄 Connection attempt $attempts/$maxAttempts');
    }

    debugPrint('❌ Connection timeout after $attempts attempts');
    return false;
  }

  /// Rejoin as host (for when entering meeting room screen)
  Future<void> rejoinAsHost() async {
    if (_currentMeetingId == null || _currentUserId == null || !_isHost) {
      debugPrint('⚠️ Cannot rejoin as host: missing data or not host');
      return;
    }

    debugPrint('🔄 ===== REJOINING AS HOST =====');
    debugPrint('🔄 Meeting ID: $_currentMeetingId');
    debugPrint('🔄 User ID: $_currentUserId');

    // Ensure socket is connected
    if (_service.socket?.connected != true) {
      debugPrint('⚠️ Socket not connected, waiting...');
      bool connected = await _waitForConnection();

      if (!connected) {
        debugPrint('❌ Cannot rejoin: socket not connected');
        return;
      }
    }

    // Emit join-meeting-host event
    debugPrint('🔌 Emitting join-meeting-host...');
    _service.joinAsMeetingHost(
      meetingId: _currentMeetingId!,
      userId: _currentUserId!,
    );

    // Wait for pending requests update
    await Future.delayed(const Duration(milliseconds: 1000));

    debugPrint('📋 Pending requests after rejoin: ${_pendingRequests.length}');
    debugPrint('✅ ===== REJOIN COMPLETE =====');
  }

  /// Approve a join request (host only)
  void approveJoinRequest(String requestId) {
    if (!_isHost) {
      _errorMessage = 'Only host can approve requests';
      _safeNotifyListeners();
      return;
    }

    debugPrint('✅ Approving request: $requestId');
    _service.approveParticipant(requestId);
  }

  /// Reject a join request (host only)
  void rejectJoinRequest(String requestId) {
    if (!_isHost) {
      _errorMessage = 'Only host can reject requests';
      _safeNotifyListeners();
      return;
    }

    debugPrint('❌ Rejecting request: $requestId');
    _service.rejectParticipant(requestId);
  }

  Future<void> kickParticipant(String participantIdentity) async {
    if (!_isHost || _currentMeetingId == null) {
      _errorMessage = 'Only host can kick participants';
      _safeNotifyListeners();
      return;
    }

    final result = await _service.kickParticipant(
      roomId: _currentMeetingId!,
      identity: participantIdentity,
      authToken: _authToken,
    );

    if (result['error'] == true) {
      _errorMessage = result['message'];
    } else {
      _successMessage = 'Participant removed from meeting';
    }
    _safeNotifyListeners();
  }

  Future<void> requestToJoinMeeting(String meetingId) async {
    if (_currentUserId == null || _currentUserName == null) {
      _errorMessage = 'User not initialized';
      _safeNotifyListeners();
      return;
    }

    _currentMeetingId = meetingId;
    _currentRole = MeetingRole.participant;
    _joinStatus = JoinStatus.requesting;
    _safeNotifyListeners();

    debugPrint('🚪 Requesting to join meeting: $meetingId');

    // Send join request via REST API
    final result = await _service.requestToJoin(
      name: _currentUserName!,
      meetingId: meetingId,
      userId: _currentUserId!,
      authToken: _authToken,
    );

    debugPrint('📦 Join request result: $result');

    if (result['error'] == true) {
      _errorMessage = result['message'];
      _joinStatus = JoinStatus.idle;
      _safeNotifyListeners();
      return;
    }

    // Check if user is host or request is pending
    if (result['isHost'] == true || result['approved'] == true) {
      _isHost = result['isHost'] ?? false;
      _joinStatus = JoinStatus.approved;
      debugPrint('✅ Auto-approved (is host: $_isHost)');
      await _fetchAccessToken(meetingId);
    } else {
      // Request sent, waiting for approval
      _successMessage = result['message'] ?? 'Join request sent to host';
      debugPrint('⏳ Waiting for host approval');

      // Also send via socket for real-time updates
      _service.sendJoinRequest(
        name: _currentUserName!,
        meetingId: meetingId,
        userId: _currentUserId!,
      );
    }
    _safeNotifyListeners();
  }

  /// Cancel join request
  void cancelJoinRequest() {
    if (_currentMeetingId == null || _currentUserId == null) {
      return;
    }

    debugPrint('🚫 Cancelling join request');
    _service.cancelJoinRequest(
      meetingId: _currentMeetingId!,
      userId: _currentUserId!,
    );

    _joinStatus = JoinStatus.idle;
    _clearMeetingData();
    _safeNotifyListeners();
  }

  /// Fetch access token for joining the meeting
  Future<bool> _fetchAccessToken(String meetingId) async {
    if (_currentUserId == null || _currentUserName == null) {
      _errorMessage = 'User not initialized';
      _safeNotifyListeners();
      return false;
    }

    debugPrint('🎫 Fetching access token for meeting: $meetingId');

    final result = await _service.getAccessToken(
      name: _currentUserName!,
      meetingId: meetingId,
      userId: _currentUserId!,
      authToken: _authToken,
    );

    debugPrint('📦 Access token result: $result');

    if (result['error'] == false && result['token'] != null) {
      _accessToken = result['token'];
      _isHost = result['isHost'] ?? false;
      _joinStatus = JoinStatus.joined;
      _successMessage = 'Access token received';
      debugPrint('✅ Access token received, isHost: $_isHost');
      _safeNotifyListeners();
      return true;
    } else {
      _errorMessage = result['message'] ?? 'Failed to get access token';
      debugPrint('❌ Failed to get token: $_errorMessage');
      _safeNotifyListeners();
      return false;
    }
  }

  /// Join the chat room
  void joinChatRoom() {
    if (_currentMeetingId == null ||
        _currentUserId == null ||
        _currentUserName == null) {
      _errorMessage = 'Cannot join chat: missing meeting or user data';
      _safeNotifyListeners();
      return;
    }

    debugPrint('💬 Joining chat room');
    _service.joinChat(
      meetingId: _currentMeetingId!,
      userId: _currentUserId!,
      username: _currentUserName!,
    );

    _isChatJoined = true;

    // Load chat history
    _service.getChatHistory(_currentMeetingId!);
    _safeNotifyListeners();
  }

  /// Send a chat message
  void sendChatMessage(String message) {
    if (!_isChatJoined ||
        _currentMeetingId == null ||
        _currentUserId == null ||
        _currentUserName == null) {
      _errorMessage = 'Cannot send message: not in chat';
      _safeNotifyListeners();
      return;
    }

    _service.sendMessage(
      meetingId: _currentMeetingId!,
      userId: _currentUserId!,
      username: _currentUserName!,
      message: message,
    );
  }

  /// Clear chat messages
  void clearChatMessages() {
    _chatMessages.clear();
    _safeNotifyListeners();
  }

  void _safeNotifyListeners() {
    if (hasListeners) {
      notifyListeners();
    }
  }

  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    _safeNotifyListeners();
  }

  void _clearMeetingData() {
    _currentMeetingId = null;
    _currentRole = null;
    _isHost = false;
    _accessToken = null;
    _joinStatus = JoinStatus.idle;
    _pendingRequests.clear();
    _chatMessages.clear();
    _isChatJoined = false;
  }

  void leaveMeeting() {
    debugPrint('🚪 Leaving meeting');
    _clearMeetingData();
    _safeNotifyListeners();
  }

  @override
  void dispose() {
    debugPrint('🧹 Cleaning up MeetingProvider');

    // Remove all listeners
    _service.offPendingRequestsUpdate();
    _service.offNewJoinRequest();
    _service.offJoinApproved();
    _service.offJoinRejected();
    _service.offParticipantApproved();
    _service.offParticipantRejected();
    _service.offParticipantCancelled();
    _service.offUserJoinedChat();
    _service.offNewMessage();
    _service.offChatHistory();

    // Disconnect and dispose socket
    _service.disconnect();
    _service.dispose();

    super.dispose();
  }
}
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

  // ============================================================================
  // INITIALIZATION
  // ============================================================================

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

    debugPrint('📞 Meeting provider initialized for user: $userName ($userId)');
  }

  void _setupListeners() {
    // Connection listeners
    _service.onConnect(() {
      _isConnected = true;
      if (_currentUserId != null) {
        _service.joinAsUser(_currentUserId!);
      }
      _safeNotifyListeners();
    });

    _service.onDisconnect(() {
      _isConnected = false;
      _safeNotifyListeners();
    });

    // Join request listeners
    _service.onPendingRequestsUpdate((data) {
      debugPrint('📋 Pending requests updated: $data');
      if (data is List) {
        _pendingRequests = List<Map<String, dynamic>>.from(
          data.map((item) => Map<String, dynamic>.from(item)),
        );
        _safeNotifyListeners();
      }
    });

    _service.onNewJoinRequest((data) {
      debugPrint('🆕 New join request: $data');
      _successMessage = '${data['name']} wants to join the meeting';
      _safeNotifyListeners();
    });

    _service.onJoinApproved((data) {
      debugPrint('✅ Join approved: $data');
      _joinStatus = JoinStatus.approved;
      _currentMeetingId = data['meetingId'];
      _successMessage = 'Your join request was approved!';
      _safeNotifyListeners();
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
      '${req['meetingId']}-${req['userId']}' == requestId
      );
      _safeNotifyListeners();
    });

    _service.onParticipantRejected((requestId) {
      debugPrint('❌ Participant rejected: $requestId');
      _pendingRequests.removeWhere((req) =>
      '${req['meetingId']}-${req['userId']}' == requestId
      );
      _safeNotifyListeners();
    });

    _service.onParticipantCancelled((requestId) {
      debugPrint('🚫 Participant cancelled: $requestId');
      _pendingRequests.removeWhere((req) =>
      '${req['meetingId']}-${req['userId']}' == requestId
      );
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

  // ============================================================================
  // MEETING OPERATIONS - HOST
  // ============================================================================

  /// Join as meeting host
  // Replace the existing joinAsMeetingHost method with this:

  /// Create and join as meeting host
  /// Join as meeting host (uses request-join endpoint)
  Future<void> joinAsMeetingHost(String meetingId) async {
    if (_currentUserId == null || _currentUserName == null) {
      _errorMessage = 'User not initialized';
      _safeNotifyListeners();
      return;
    }

    _currentMeetingId = meetingId;
    _currentRole = MeetingRole.host;
    _isHost = true;

    debugPrint('🎬 Creating and joining meeting as host: $meetingId');

    // Use request-join endpoint which will create the meeting and mark us as host
    final result = await _service.requestToJoin(
      name: _currentUserName!,
      meetingId: meetingId,
      userId: _currentUserId!,
      authToken: _authToken,
    );

    if (result['error'] == true) {
      _errorMessage = result['message'] ?? 'Failed to create meeting';
      _isHost = false;
      _currentRole = null;
      _currentMeetingId = null;
      _safeNotifyListeners();
      return;
    }

    // The response should indicate we're the host
    _isHost = result['isHost'] ?? true;

    // Join as host via socket
    _service.joinAsMeetingHost(
      meetingId: meetingId,
      userId: _currentUserId!,
    );

    // Get access token
    await _fetchAccessToken(meetingId);
  }

  /// Approve a join request (host only)
  void approveJoinRequest(String requestId) {
    if (!_isHost) {
      _errorMessage = 'Only host can approve requests';
      _safeNotifyListeners();
      return;
    }

    _service.approveParticipant(requestId);
    debugPrint('✅ Approving request: $requestId');
  }

  /// Reject a join request (host only)
  void rejectJoinRequest(String requestId) {
    if (!_isHost) {
      _errorMessage = 'Only host can reject requests';
      _safeNotifyListeners();
      return;
    }

    _service.rejectParticipant(requestId);
    debugPrint('❌ Rejecting request: $requestId');
  }

  /// Kick a participant (host only)
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

  // ============================================================================
  // MEETING OPERATIONS - PARTICIPANT
  // ============================================================================

  /// Request to join a meeting
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

    // Send join request via REST API
    final result = await _service.requestToJoin(
      name: _currentUserName!,
      meetingId: meetingId,
      userId: _currentUserId!,
      authToken: _authToken,
    );

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
      await _fetchAccessToken(meetingId);
    } else {
      // Request sent, waiting for approval
      _successMessage = result['message'] ?? 'Join request sent to host';

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

  // ============================================================================
  // CHAT OPERATIONS
  // ============================================================================

  /// Join the chat room
  void joinChatRoom() {
    if (_currentMeetingId == null ||
        _currentUserId == null ||
        _currentUserName == null) {
      _errorMessage = 'Cannot join chat: missing meeting or user data';
      _safeNotifyListeners();
      return;
    }

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

  // ============================================================================
  // UTILITY METHODS
  // ============================================================================

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
    _clearMeetingData();
    _safeNotifyListeners();
  }

  // ============================================================================
  // CLEANUP
  // ============================================================================

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
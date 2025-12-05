import 'package:flutter/cupertino.dart';

import '../services/video_call_service.dart';

enum CallState {
  idle,
  calling,
  ringing,
  connected,
  ended,
}

class VideoCallProvider extends ChangeNotifier {
  final VideoCallService _service = VideoCallService();

  // Current user info
  String? _currentUserId;
  String? _currentUserName;
  String? _authToken;

  // Call state
  CallState _callState = CallState.idle;
  bool _isConnected = false;
  String? _errorMessage;
  String? _successMessage;

  // Current call data
  String? _currentRoomName;
  String? _currentCallerId;
  String? _currentCallerName;
  String? _currentReceiverId;
  String? _currentReceiverName;

  // LiveKit token
  String? _livekitToken;

  // Participants
  List<Map<String, dynamic>> _participants = [];

  // Getters
  VideoCallService get service => _service;
  String? get currentUserId => _currentUserId;
  String? get currentUserName => _currentUserName;
  CallState get callState => _callState;
  bool get isConnected => _isConnected;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;
  String? get currentRoomName => _currentRoomName;
  String? get currentCallerId => _currentCallerId;
  String? get currentCallerName => _currentCallerName;
  String? get currentReceiverId => _currentReceiverId;
  String? get currentReceiverName => _currentReceiverName;
  String? get livekitToken => _livekitToken;
  List<Map<String, dynamic>> get participants => _participants;

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
  }

  void _setupListeners() {
    // Connection listeners
    _service.onConnect(() {
      debugPrint('✅ Socket connected');
      _isConnected = true;
      if (_currentUserId != null) {
        _service.registerUser(_currentUserId!);
      }
      _safeNotifyListeners();
    });

    _service.onDisconnect(() {
      debugPrint('❌ Socket disconnected');
      _isConnected = false;
      _safeNotifyListeners();
    });

    // Incoming call
    _service.onIncomingVideoCall((data) {
      debugPrint('📞 Incoming call: $data');
      _currentRoomName = data['roomName'];
      _currentCallerId = data['callerId'];
      _currentCallerName = data['callerName'];
      _callState = CallState.ringing;
      _safeNotifyListeners();
    });

    // Call accepted
    _service.onCallAccepted((data) {
      debugPrint('✅ Call accepted: $data');
      _successMessage = data['message'];
      _callState = CallState.connected;
      _safeNotifyListeners();
    });

    // Call rejected
    _service.onCallRejected((data) {
      debugPrint('❌ Call rejected: $data');
      _errorMessage = data['message'];
      _callState = CallState.ended;
      _clearCallData();
      _safeNotifyListeners();
    });

    // Call ended
    _service.onVideoCallEnded((data) {
      debugPrint('📴 Call ended: $data');
      _callState = CallState.ended;
      _clearCallData();
      _safeNotifyListeners();
    });

    // User offline
    _service.onUserOffline((message) {
      debugPrint('🔴 User offline: $message');
      _errorMessage = message.toString();
      _callState = CallState.ended;
      _clearCallData();
      _safeNotifyListeners();
    });

    // Participant joined
    _service.onParticipantJoinedCall((data) {
      debugPrint('👤 Participant joined: $data');
      if (!_participants.any((p) => p['userId'] == data['userId'])) {
        _participants.add(data);
        _safeNotifyListeners();
      }
    });

    // Participant left
    _service.onParticipantLeftCall((data) {
      debugPrint('👋 Participant left: $data');
      _participants.removeWhere((p) => p['userId'] == data['userId']);
      _safeNotifyListeners();
    });
  }

  // ============================================================================
  // CALL OPERATIONS
  // ============================================================================

  /// Check if a user is currently busy (in another call)
  Future<bool> checkUserBusy(String receiverId) async {
    final result = await _service.checkUserBusy(receiverId);
    if (result != null) {
      return result['busy'] ?? false;
    }
    return false;
  }

  /// Initiate a video call to another user
  Future<void> initiateCall({
    required String receiverId,
    required String receiverName,
  }) async {
    if (_currentUserId == null || _currentUserName == null) {
      _errorMessage = 'User not initialized';
      notifyListeners();
      return;
    }

    // Check if user is busy
    final isBusy = await checkUserBusy(receiverId);
    if (isBusy) {
      _errorMessage = '$receiverName is currently in another call';
      notifyListeners();
      return;
    }

    _currentRoomName = 'room-${DateTime.now().millisecondsSinceEpoch}';
    _currentReceiverId = receiverId;
    _currentReceiverName = receiverName;
    _callState = CallState.calling;
    notifyListeners();

    _service.initiateVideoCall(
      roomName: _currentRoomName!,
      callerId: _currentUserId!,
      callerName: _currentUserName!,
      receiverId: receiverId,
    );
  }

  /// Accept an incoming video call
  Future<void> acceptCall() async {
    if (_currentCallerId == null) {
      _errorMessage = 'No caller ID found';
      notifyListeners();
      return;
    }

    debugPrint('✅ Accepting call from: $_currentCallerId');

    // Emit call-accepted event
    _service.acceptCall(_currentCallerId!);

    // Update call state
    _callState = CallState.connected;
    _successMessage = 'Call accepted';

    notifyListeners();
  }

  /// Reject an incoming video call
  Future<void> rejectCall() async {
    if (_currentCallerId == null || _currentUserName == null) {
      _errorMessage = 'Missing call data';
      notifyListeners();
      return;
    }

    debugPrint('❌ Rejecting call from: $_currentCallerId');

    // Emit call-rejected event
    _service.rejectCall(
      callerId: _currentCallerId!,
      receiverName: _currentUserName!,
    );

    // Update state and clear data
    _callState = CallState.ended;
    _successMessage = 'Call rejected';
    _clearCallData();

    notifyListeners();
  }

  /// End an active call or cancel an outgoing call
  Future<void> endCall() async {
    if (_currentUserId == null || _currentUserName == null) {
      _errorMessage = 'User not initialized';
      notifyListeners();
      return;
    }

    // Determine receiver info based on call direction
    String receiverId = _currentReceiverId ?? _currentCallerId ?? '';
    String receiverName = _currentReceiverName ?? _currentCallerName ?? '';

    if (receiverId.isEmpty) {
      _errorMessage = 'No active call to end';
      notifyListeners();
      return;
    }

    debugPrint('📴 Ending call with: $receiverId');

    // Notify that participant is leaving
    notifyParticipantLeft();

    // Emit video-call-canceled event
    _service.cancelVideoCall(
      receiverId: receiverId,
      receiverName: receiverName,
      callerName: _currentUserName!,
      callerId: _currentUserId!,
    );

    // Update state and clear data
    _callState = CallState.ended;
    _successMessage = 'Call ended';
    _clearCallData();

    notifyListeners();
  }

  /// Invite additional participant to ongoing call (group call)
  Future<void> inviteParticipant({
    required String receiverId,
    required String receiverName,
  }) async {
    if (_currentUserId == null ||
        _currentUserName == null ||
        _currentRoomName == null) {
      _errorMessage = 'Missing required data';
      notifyListeners();
      return;
    }

    debugPrint('📧 Inviting $receiverName to call');

    _service.inviteToCall(
      roomName: _currentRoomName!,
      callerId: _currentUserId!,
      callerName: _currentUserName!,
      receiverId: receiverId,
      receiverName: receiverName,
    );

    _successMessage = 'Invitation sent to $receiverName';
    notifyListeners();
  }

  /// Notify other participants that current user joined the call
  void notifyParticipantJoined() {
    if (_currentUserId == null ||
        _currentUserName == null ||
        _currentRoomName == null) {
      debugPrint('⚠️ Cannot notify join: Missing data');
      return;
    }

    _service.participantJoinedCall(
      userId: _currentUserId!,
      userName: _currentUserName!,
      roomName: _currentRoomName!,
    );
  }

  /// Notify other participants that current user left the call
  void notifyParticipantLeft() {
    if (_currentUserId == null ||
        _currentUserName == null ||
        _currentRoomName == null) {
      debugPrint('⚠️ Cannot notify leave: Missing data');
      return;
    }

    _service.participantLeftCall(
      userId: _currentUserId!,
      userName: _currentUserName!,
      roomName: _currentRoomName!,
    );
  }

  // ============================================================================
  // LIVEKIT TOKEN
  // ============================================================================

  /// Fetch LiveKit token for joining the video call room
  Future<bool> fetchLivekitToken() async {
    if (_currentUserId == null ||
        _currentUserName == null ||
        _currentRoomName == null) {
      _errorMessage = 'Missing required data for token generation';
      notifyListeners();
      return false;
    }

    debugPrint('🎫 Fetching LiveKit token...');

    final result = await _service.generateLivekitToken(
      roomName: _currentRoomName!,
      participantName: _currentUserName!,
      userId: _currentUserId!,
      authToken: _authToken,
    );

    if (result['error'] == false && result['token'] != null) {
      _livekitToken = result['token'];
      _successMessage = 'Token generated successfully';
      debugPrint('✅ LiveKit token received');
      notifyListeners();
      return true;
    } else {
      _errorMessage = result['message'] ?? 'Failed to generate token';
      debugPrint('❌ Failed to get token: $_errorMessage');
      notifyListeners();
      return false;
    }
  }

  // ============================================================================
  // UTILITY METHODS
  // ============================================================================

  /// Safely notify listeners only if there are listeners
  void _safeNotifyListeners() {
    if (hasListeners) {
      notifyListeners();
    }
  }

  /// Clear error and success messages
  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    _safeNotifyListeners();
  }

  /// Clear all call-related data
  void _clearCallData() {
    _currentRoomName = null;
    _currentCallerId = null;
    _currentCallerName = null;
    _currentReceiverId = null;
    _currentReceiverName = null;
    _livekitToken = null;
    _participants.clear();
  }

  /// Reset call state to idle
  void resetCallState() {
    _callState = CallState.idle;
    _clearCallData();
    clearMessages();
    notifyListeners();
  }

  // ============================================================================
  // CLEANUP
  // ============================================================================

  @override
  void dispose() {
    debugPrint('🧹 Cleaning up VideoCallProvider');

    // Remove all listeners
    _service.offIncomingVideoCall();
    _service.offCallAccepted();
    _service.offCallRejected();
    _service.offVideoCallEnded();
    _service.offUserOffline();
    _service.offParticipantJoinedCall();
    _service.offParticipantLeftCall();

    // Disconnect and dispose socket
    _service.disconnect();
    _service.dispose();

    super.dispose();
  }
}
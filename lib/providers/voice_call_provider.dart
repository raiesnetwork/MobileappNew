import 'package:flutter/material.dart';
import '../services/voice_call_service.dart';

enum VoiceCallState {
  idle,
  calling,
  ringing,
  connected,
  ended,
}

class VoiceCallProvider extends ChangeNotifier {
  final VoiceCallService _service = VoiceCallService();

  // Current user info
  String? _currentUserId;
  String? _currentUserName;
  String? _authToken;

  // Call state
  VoiceCallState _callState = VoiceCallState.idle;
  bool _isConnected = false;
  String? _errorMessage;
  String? _successMessage;

  // Current call data
  String? _currentRoomName;
  String? _currentCallerId;
  String? _currentCallerName;
  String? _currentReceiverId;
  String? _currentReceiverName;
  bool _isConference = false;

  // LiveKit token
  String? _voiceToken;

  // Participants (for conference calls)
  List<Map<String, dynamic>> _participants = [];

  // Getters
  VoiceCallService get service => _service;
  String? get currentUserId => _currentUserId;
  String? get currentUserName => _currentUserName;
  VoiceCallState get callState => _callState;
  bool get isConnected => _isConnected;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;
  String? get currentRoomName => _currentRoomName;
  String? get currentCallerId => _currentCallerId;
  String? get currentCallerName => _currentCallerName;
  String? get currentReceiverId => _currentReceiverId;
  String? get currentReceiverName => _currentReceiverName;
  bool get isConference => _isConference;
  String? get voiceToken => _voiceToken;
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

    debugPrint('🎙️ Initializing voice call provider for: $userName ($userId)');

    // CRITICAL: Setup listeners BEFORE connecting
    _service.connectSocket();
    _setupListeners();

    // Connect after listeners are set up
    _service.connect();

    debugPrint('🎙️ Voice call provider initialized');
  }

  void _setupListeners() {
    debugPrint('👂 Setting up voice call listeners...');

    // Connection listeners - MUST be set before connect()
    _service.onConnect(() {
      debugPrint('✅ Voice call socket connected - Provider callback');
      _isConnected = true;

      // Register user immediately after connection
      if (_currentUserId != null) {
        _service.registerUser(_currentUserId!);
        debugPrint('📝 User registered: $_currentUserId');
      } else {
        debugPrint('⚠️ Cannot register: No user ID');
      }

      _safeNotifyListeners();
    });

    _service.onDisconnect(() {
      debugPrint('❌ Voice call socket disconnected - Provider callback');
      _isConnected = false;
      _safeNotifyListeners();
    });

    // Incoming voice call
    _service.onIncomingVoiceCall((data) {
      debugPrint('📞 PROVIDER: Incoming voice call received');
      debugPrint('📞 Call data: $data');

      _currentRoomName = data['roomName'];
      _currentCallerId = data['callerId'];
      _currentCallerName = data['callerName'];
      _isConference = data['isConference'] ?? false;
      _callState = VoiceCallState.ringing;

      debugPrint('📞 Updated state: roomName=$_currentRoomName, caller=$_currentCallerName, state=$_callState');

      _safeNotifyListeners();
    });

    // Call accepted
    _service.onCallAcceptedVoice((data) {
      debugPrint('✅ PROVIDER: Voice call accepted');
      debugPrint('✅ Accept data: $data');

      _successMessage = data['message'];
      _isConference = data['isConference'] ?? false;
      _callState = VoiceCallState.connected;

      _safeNotifyListeners();
    });

    // Call rejected
    _service.onCallRejectedVoice((data) {
      debugPrint('❌ PROVIDER: Voice call rejected');
      debugPrint('❌ Reject data: $data');

      _errorMessage = data['message'];
      _callState = VoiceCallState.ended;
      _clearCallData();
      _safeNotifyListeners();
    });

    // Call ended
    _service.onVoiceCallEnded((data) {
      debugPrint('📴 PROVIDER: Voice call ended');
      debugPrint('📴 End data: $data');

      _callState = VoiceCallState.ended;
      _clearCallData();
      _safeNotifyListeners();
    });

    // User offline
    _service.onUserOfflineVoice((message) {
      debugPrint('🔴 PROVIDER: User offline - $message');

      _errorMessage = message.toString();
      _callState = VoiceCallState.ended;
      _clearCallData();
      _safeNotifyListeners();
    });

    // New participant invited (conference)
    _service.onNewParticipantInvitedVoice((data) {
      debugPrint('📧 PROVIDER: New participant invited');
      debugPrint('📧 Invite data: $data');

      _currentRoomName = data['roomName'];
      _currentCallerId = data['callerId'];
      _currentCallerName = data['callerName'];
      _isConference = true;
      _callState = VoiceCallState.ringing;
      _safeNotifyListeners();
    });

    // Participant joined
    _service.onParticipantJoinedVoiceCall((data) {
      debugPrint('👤 PROVIDER: Participant joined');
      debugPrint('👤 Join data: $data');

      if (!_participants.any((p) => p['participantId'] == data['participantId'])) {
        _participants.add(Map<String, dynamic>.from(data));
        _safeNotifyListeners();
      }
    });

    // Participant joined
    _service.onParticipantJoinedVoiceCall((data) {
      debugPrint('👤 PROVIDER: Participant joined');
      debugPrint('👤 Join data: $data');

      // Add participant to list
      if (!_participants.any((p) => p['participantId'] == data['participantId'])) {
        _participants.add(Map<String, dynamic>.from(data));
      }

      // 🔥 FIX: Update call state to connected when receiver joins
      // Only update if we're the caller and we're in calling state
      if (_callState == VoiceCallState.calling &&
          data['participantId'] == _currentReceiverId) {
        debugPrint('🎯 Receiver joined! Updating state to CONNECTED');
        _callState = VoiceCallState.connected;
      }

      _safeNotifyListeners();
    });

    debugPrint('✅ All voice call listeners set up');
  }

  // ============================================================================
  // CALL OPERATIONS
  // ============================================================================

  /// Check if user is busy
  Future<bool> checkUserBusy(String receiverId) async {
    debugPrint('🔍 Checking if user $receiverId is busy...');
    final result = await _service.checkUserBusy(receiverId);
    if (result != null) {
      debugPrint('🔍 Busy check result: ${result['busy']}');
      return result['busy'] ?? false;
    }
    debugPrint('🔍 Busy check returned null');
    return false;
  }

  /// Initiate voice call
  Future<void> initiateVoiceCall({
    required String receiverId,
    required String receiverName,
    bool isConference = false,
  }) async {
    debugPrint('📞 INITIATING VOICE CALL to $receiverName ($receiverId)');

    if (_currentUserId == null || _currentUserName == null) {
      _errorMessage = 'User not initialized';
      debugPrint('❌ Cannot initiate: User not initialized');
      _safeNotifyListeners();
      return;
    }

    if (!_isConnected) {
      _errorMessage = 'Not connected to server';
      debugPrint('❌ Cannot initiate: Not connected');
      _safeNotifyListeners();
      return;
    }

    // Check if user is busy
    final isBusy = await checkUserBusy(receiverId);
    if (isBusy) {
      _errorMessage = '$receiverName is currently in another call';
      debugPrint('❌ Cannot call: User is busy');
      _safeNotifyListeners();
      return;
    }

    _currentRoomName = 'voice-room-${DateTime.now().millisecondsSinceEpoch}';
    _currentReceiverId = receiverId;
    _currentReceiverName = receiverName;
    _isConference = isConference;
    _callState = VoiceCallState.calling;

    debugPrint('📞 Room name: $_currentRoomName');
    debugPrint('📞 Call state changed to: $_callState');

    _safeNotifyListeners();

    _service.initiateVoiceCall(
      roomName: _currentRoomName!,
      callerId: _currentUserId!,
      callerName: _currentUserName!,
      receiverId: receiverId,
      isConference: isConference,
    );

    debugPrint('📞 Voice call initiated via service');
  }

  /// Accept voice call
  Future<void> acceptVoiceCall() async {
    debugPrint('✅ ACCEPTING VOICE CALL from $_currentCallerName ($_currentCallerId)');

    if (_currentCallerId == null) {
      _errorMessage = 'No caller ID found';
      debugPrint('❌ Cannot accept: No caller ID');
      _safeNotifyListeners();
      return;
    }

    _service.acceptVoiceCall(
      receiverId: _currentCallerId!,
      isConference: _isConference,
    );

    _callState = VoiceCallState.connected;
    _successMessage = 'Call accepted';

    debugPrint('✅ Call accepted, state changed to: $_callState');

    _safeNotifyListeners();
  }

  /// Reject voice call
  Future<void> rejectVoiceCall() async {
    debugPrint('❌ REJECTING VOICE CALL from $_currentCallerName ($_currentCallerId)');

    if (_currentCallerId == null ||
        _currentUserName == null ||
        _currentUserId == null) {
      _errorMessage = 'Missing call data';
      debugPrint('❌ Cannot reject: Missing data');
      _safeNotifyListeners();
      return;
    }

    _service.rejectVoiceCall(
      callerId: _currentCallerId!,
      receiverName: _currentUserName!,
      currentUserId: _currentUserId!,
    );

    _callState = VoiceCallState.ended;
    _successMessage = 'Call rejected';
    _clearCallData();

    debugPrint('❌ Call rejected');

    _safeNotifyListeners();
  }

  /// End voice call
  Future<void> endVoiceCall() async {
    debugPrint('📴 ENDING VOICE CALL');

    if (_currentUserId == null || _currentUserName == null) {
      _errorMessage = 'User not initialized';
      debugPrint('❌ Cannot end: User not initialized');
      _safeNotifyListeners();
      return;
    }

    String receiverId = _currentReceiverId ?? _currentCallerId ?? '';
    String receiverName = _currentReceiverName ?? _currentCallerName ?? '';

    if (receiverId.isEmpty) {
      _errorMessage = 'No active call to end';
      debugPrint('❌ Cannot end: No active call');
      _safeNotifyListeners();
      return;
    }

    // Notify that participant is leaving
    if (_currentRoomName != null) {
      notifyParticipantLeft();
    }

    _service.endVoiceCall(
      receiverId: receiverId,
      receiverName: receiverName,
      callerName: _currentUserName!,
      callerId: _currentUserId!,
    );

    _callState = VoiceCallState.ended;
    _successMessage = 'Call ended';
    _clearCallData();

    debugPrint('📴 Call ended');

    _safeNotifyListeners();
  }

  /// Invite participant to voice call (conference)
  Future<void> inviteToVoiceCall({
    required String receiverId,
    required String receiverName,
  }) async {
    debugPrint('📧 INVITING $receiverName to voice call');

    if (_currentUserId == null ||
        _currentUserName == null ||
        _currentRoomName == null) {
      _errorMessage = 'Missing required data';
      debugPrint('❌ Cannot invite: Missing data');
      _safeNotifyListeners();
      return;
    }

    _service.inviteToVoiceCall(
      roomName: _currentRoomName!,
      callerId: _currentUserId!,
      callerName: _currentUserName!,
      receiverId: receiverId,
      receiverName: receiverName,
    );

    _successMessage = 'Invitation sent to $receiverName';
    debugPrint('📧 Invitation sent');
    _safeNotifyListeners();
  }

  /// Notify others that participant joined
  void notifyParticipantJoined() {
    if (_currentUserId == null ||
        _currentUserName == null ||
        _currentRoomName == null) {
      debugPrint('⚠️ Cannot notify join: Missing data');
      return;
    }

    _service.participantJoinedVoiceCall(
      participantId: _currentUserId!,
      participantName: _currentUserName!,
      roomName: _currentRoomName!,
    );

    debugPrint('👤 Notified others of join');
  }

  /// Notify others that participant left
  void notifyParticipantLeft() {
    if (_currentUserId == null) {
      debugPrint('⚠️ Cannot notify leave: Missing user ID');
      return;
    }

    _service.participantLeftVoiceCall(
      participantId: _currentUserId!,
    );

    debugPrint('👋 Notified others of leave');
  }

  // ============================================================================
  // LIVEKIT TOKEN
  // ============================================================================

  /// Fetch LiveKit voice token
  Future<bool> fetchVoiceToken() async {
    debugPrint('🎫 FETCHING VOICE TOKEN');

    if (_currentUserId == null ||
        _currentUserName == null ||
        _currentRoomName == null) {
      _errorMessage = 'Missing required data for token generation';
      debugPrint('❌ Cannot fetch token: Missing data');
      _safeNotifyListeners();
      return false;
    }

    final result = await _service.generateVoiceToken(
      roomName: _currentRoomName!,
      participantName: _currentUserName!,
      userId: _currentUserId!,
      authToken: _authToken,
    );

    if (result['error'] == false && result['token'] != null) {
      _voiceToken = result['token'];
      _successMessage = 'Token generated successfully';
      debugPrint('✅ Voice token received');
      _safeNotifyListeners();
      return true;
    } else {
      _errorMessage = result['message'] ?? 'Failed to generate token';
      debugPrint('❌ Failed to get token: $_errorMessage');
      _safeNotifyListeners();
      return false;
    }
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

  void _clearCallData() {
    _currentRoomName = null;
    _currentCallerId = null;
    _currentCallerName = null;
    _currentReceiverId = null;
    _currentReceiverName = null;
    _isConference = false;
    _voiceToken = null;
    _participants.clear();
  }

  void resetCallState() {
    _callState = VoiceCallState.idle;
    _clearCallData();
    clearMessages();
    _safeNotifyListeners();
  }

  // ============================================================================
  // DEBUG HELPERS
  // ============================================================================

  void printStatus() {
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('Voice Call Provider Status:');
    debugPrint('  User: $_currentUserName ($_currentUserId)');
    debugPrint('  Connected: $_isConnected');
    debugPrint('  Registered: ${_service.isRegistered}');
    debugPrint('  Call State: $_callState');
    debugPrint('  Current Room: $_currentRoomName');
    debugPrint('  Caller: $_currentCallerName ($_currentCallerId)');
    debugPrint('  Receiver: $_currentReceiverName ($_currentReceiverId)');
    debugPrint('  Socket ID: ${_service.socketId}');
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    _service.printStatus();
  }

  // ============================================================================
  // CLEANUP
  // ============================================================================

  @override
  void dispose() {
    debugPrint('🧹 Cleaning up VoiceCallProvider');

    // Remove all listeners
    _service.offIncomingVoiceCall();
    _service.offCallAcceptedVoice();
    _service.offCallRejectedVoice();
    _service.offVoiceCallEnded();
    _service.offUserOfflineVoice();
    _service.offNewParticipantInvitedVoice();
    _service.offParticipantJoinedVoiceCall();
    _service.offParticipantLeftVoiceCall();

    // Disconnect and dispose socket
    _service.disconnect();
    _service.dispose();

    super.dispose();
  }
}
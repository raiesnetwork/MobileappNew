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

  String? _currentUserId;
  String? _currentUserName;
  String? _authToken;

  VoiceCallState _callState = VoiceCallState.idle;
  bool _isConnected = false;
  String? _errorMessage;
  String? _successMessage;

  String? _currentRoomName;
  String? _currentCallerId;
  String? _currentCallerName;
  String? _currentReceiverId;
  String? _currentReceiverName;
  bool _isConference = false;
  bool _listenersSetUp = false;

  String? _voiceToken;
  List<Map<String, dynamic>> _participants = [];

  bool _acceptedViaCallKit = false;
  // Add these fields in VoiceCallProvider:
  bool _isMuted = false;
  bool _isSpeakerOn = false;

  bool get isMuted => _isMuted;
  bool get isSpeakerOn => _isSpeakerOn;

  void setMuted(bool value) {
    _isMuted = value;
    _safeNotifyListeners();
  }

  void setSpeaker(bool value) {
    _isSpeakerOn = value;
    _safeNotifyListeners();
  }

// Reset in _clearCallData():


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
  bool get acceptedViaCallKit => _acceptedViaCallKit;

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

    if (!_listenersSetUp) {
      _setupListeners();
      _listenersSetUp = true;
    }

    _service.connect();
  }

  void _setupListeners() {
    debugPrint('👂 Setting up voice call listeners...');

    _service.onConnect(() {
      debugPrint('✅ Voice socket connected');
      _isConnected = true;
      if (_currentUserId != null) {
        _service.registerUser(_currentUserId!);
        debugPrint('📝 User registered: $_currentUserId');
      }
      _safeNotifyListeners();
    });

    _service.onDisconnect(() {
      debugPrint('❌ Voice socket disconnected');
      _isConnected = false;
      _safeNotifyListeners();
    });

    _service.onIncomingVoiceCall((data) {
      debugPrint('📞 PROVIDER: Incoming voice call: $data');
      _currentRoomName = data['roomName'];
      _currentCallerId = data['callerId'];
      _currentCallerName = data['callerName'];
      _isConference = data['isConference'] ?? false;
      _callState = VoiceCallState.ringing;
      _safeNotifyListeners();
    });

    _service.onCallAcceptedVoice((data) {
      debugPrint('✅ PROVIDER: Voice call accepted: $data');
      _successMessage = data['message'];
      _isConference = data['isConference'] ?? false;
      _callState = VoiceCallState.connected;
      _safeNotifyListeners();
    });

    _service.onCallRejectedVoice((data) {
      debugPrint('❌ PROVIDER: Voice call rejected: $data');
      _errorMessage = data['message'];
      _callState = VoiceCallState.ended;
      _clearCallData();
      _safeNotifyListeners();
      Future.delayed(const Duration(seconds: 3), () {
        if (_callState == VoiceCallState.ended) {
          _callState = VoiceCallState.idle;
          _safeNotifyListeners();
        }
      });
    });

    _service.onVoiceCallEnded((data) {
      debugPrint('📴 PROVIDER: Voice call ended: $data');
      _callState = VoiceCallState.ended;
      _clearCallData();
      _safeNotifyListeners();
      Future.delayed(const Duration(seconds: 3), () {
        if (_callState == VoiceCallState.ended) {
          _callState = VoiceCallState.idle;
          _safeNotifyListeners();
        }
      });
    });

    _service.onUserOfflineVoice((message) {
      debugPrint('🔴 PROVIDER: User offline: $message');
      _errorMessage = message.toString();
      _callState = VoiceCallState.ended;
      _clearCallData();
      _safeNotifyListeners();
      Future.delayed(const Duration(seconds: 3), () {
        if (_callState == VoiceCallState.ended) {
          _callState = VoiceCallState.idle;
          _safeNotifyListeners();
        }
      });
    });

    _service.onNewParticipantInvitedVoice((data) {
      debugPrint('📧 PROVIDER: New participant invited: $data');
      _currentRoomName = data['roomName'];
      _currentCallerId = data['callerId'];
      _currentCallerName = data['callerName'];
      _isConference = true;
      _callState = VoiceCallState.ringing;
      _safeNotifyListeners();
    });

    _service.onParticipantJoinedVoiceCall((data) {
      debugPrint('👤 PROVIDER: Participant joined: $data');
      if (!_participants.any((p) => p['participantId'] == data['participantId'])) {
        _participants.add(Map<String, dynamic>.from(data));
      }
      if (_callState == VoiceCallState.calling &&
          data['participantId'] == _currentReceiverId) {
        debugPrint('🎯 Receiver joined — state → CONNECTED');
        _callState = VoiceCallState.connected;
      }
      _safeNotifyListeners();
    });

    _service.onParticipantLeftVoiceCall((data) {
      debugPrint('👋 PROVIDER: Participant left: $data');
      _participants.removeWhere((p) => p['participantId'] == data['participantId']);
      _safeNotifyListeners();
    });

    debugPrint('✅ Voice call listeners set up');
  }

  // ============================================================================
  // ACCEPT VOICE CALL
  // ✅ KEY FIX: waits for socket to be connected + user registered
  // before emitting call-accepted-voice.
  // When app is killed and user presses Answer, socket may not be
  // connected yet. We wait up to 5s for it.
  // ============================================================================
  Future<void> acceptVoiceCall() async {
    if (_currentCallerId == null || _currentUserId == null) {
      debugPrint('❌ acceptVoiceCall: missing callerId or userId');
      return;
    }

    debugPrint('✅ acceptVoiceCall: callerId=$_currentCallerId | userId=$_currentUserId');

    await _service.acceptVoiceCall(
      userId: _currentUserId!,        // ← pass userId
      receiverId: _currentCallerId!,
      isConference: _isConference,
    );

    _callState = VoiceCallState.connected;
    _safeNotifyListeners();
  }

  // ============================================================================
  // CALL OPERATIONS
  // ============================================================================

  Future<bool> checkUserBusy(String receiverId) async {
    debugPrint('🔍 Checking if user $receiverId is busy...');
    final result = await _service.checkUserBusy(receiverId);
    if (result != null) {
      debugPrint('🔍 Busy check result: ${result['busy']}');
      return result['busy'] ?? false;
    }
    return false;
  }

  Future<void> initiateVoiceCall({
    required String receiverId,
    required String receiverName,
    bool isConference = false,
  }) async {
    debugPrint('📞 INITIATING VOICE CALL to $receiverName ($receiverId)');

    if (_currentUserId == null || _currentUserName == null) {
      _errorMessage = 'User not initialized';
      _safeNotifyListeners();
      return;
    }

    if (_callState == VoiceCallState.ended) {
      _callState = VoiceCallState.idle;
      _clearCallData();
    }

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
    _errorMessage = null;

    debugPrint('📞 Room name: $_currentRoomName');
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

  void cancelIncomingCall() {
    if (_callState != VoiceCallState.ringing && _callState != VoiceCallState.calling) return;
    debugPrint('📵 VoiceCallProvider.cancelIncomingCall()');
    _callState = VoiceCallState.ended;
    _clearCallData();
    _safeNotifyListeners();
    Future.delayed(const Duration(seconds: 3), () {
      if (_callState == VoiceCallState.ended) {
        _callState = VoiceCallState.idle;
        _safeNotifyListeners();
      }
    });
  }

  Future<void> rejectVoiceCall() async {
    debugPrint('❌ REJECTING VOICE CALL from $_currentCallerName ($_currentCallerId)');

    if (_currentCallerId == null || _currentUserName == null || _currentUserId == null) {
      _errorMessage = 'Missing call data';
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
    _safeNotifyListeners();

    Future.delayed(const Duration(seconds: 1), () {
      if (_callState == VoiceCallState.ended) {
        _callState = VoiceCallState.idle;
        _safeNotifyListeners();
      }
    });
  }

  Future<void> endVoiceCall() async {
    debugPrint('📴 ENDING VOICE CALL');

    if (_currentUserId == null || _currentUserName == null) {
      debugPrint('❌ Cannot end: User not initialized');
      _callState = VoiceCallState.idle;
      _clearCallData();
      _safeNotifyListeners();
      return;
    }

    String receiverId = _currentReceiverId ?? _currentCallerId ?? '';
    String receiverName = _currentReceiverName ?? _currentCallerName ?? '';

    if (receiverId.isEmpty) {
      debugPrint('❌ Cannot end: No active call');
      _callState = VoiceCallState.idle;
      _clearCallData();
      _safeNotifyListeners();
      return;
    }

    if (_currentRoomName != null) {
      notifyParticipantLeft();
    }

    try {
      _service.endVoiceCall(
        receiverId: receiverId,
        receiverName: receiverName,
        callerName: _currentUserName!,
        callerId: _currentUserId!,
      );
    } catch (e) {
      debugPrint('⚠️ endVoiceCall ignored: $e');
    }

    _callState = VoiceCallState.idle;
    _successMessage = 'Call ended';
    _clearCallData();
    debugPrint('📴 Call ended, state → idle');
    _safeNotifyListeners();
  }

  Future<void> inviteToVoiceCall({
    required String receiverId,
    required String receiverName,
  }) async {
    if (_currentUserId == null || _currentUserName == null || _currentRoomName == null) {
      _errorMessage = 'Missing required data';
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
    _safeNotifyListeners();
  }

  void notifyParticipantJoined() {
    if (_currentUserId == null || _currentUserName == null || _currentRoomName == null) {
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

  void notifyParticipantLeft() {
    if (_currentUserId == null) {
      debugPrint('⚠️ Cannot notify leave: Missing user ID');
      return;
    }
    _service.participantLeftVoiceCall(participantId: _currentUserId!);
    debugPrint('👋 Notified others of leave');
  }

  // ============================================================================
  // TOKEN
  // ============================================================================

  Future<bool> fetchVoiceToken() async {
    debugPrint('🎫 FETCHING VOICE TOKEN');

    if (_currentUserId == null || _currentUserName == null || _currentRoomName == null) {
      _errorMessage = 'Missing required data for token';
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
  // UTILITY
  // ============================================================================

  void _safeNotifyListeners() {
    if (hasListeners) notifyListeners();
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
    _acceptedViaCallKit = false;
    _participants.clear();
    _isMuted = false;
    _isSpeakerOn = false;
  }

  void resetCallState() {
    _callState = VoiceCallState.idle;
    _clearCallData();
    clearMessages();
    _safeNotifyListeners();
  }

  void setIncomingCallFromFCM({
    required String roomName,
    required String callerId,
    required String callerName,
    bool acceptedViaCallKit = false,
  }) {
    _currentRoomName = roomName;
    _currentCallerId = callerId;
    _currentCallerName = callerName;
    _acceptedViaCallKit = acceptedViaCallKit;

    if (!acceptedViaCallKit) {
      _callState = VoiceCallState.ringing;
    }

    debugPrint('📲 FCM voice call set — room: $roomName | caller: $callerName | acceptedViaCallKit=$acceptedViaCallKit');
    notifyListeners();
  }

  // ============================================================================
  // CLEANUP
  // ============================================================================

  @override
  void dispose() {
    debugPrint('🧹 Cleaning up VoiceCallProvider');
    _service.offIncomingVoiceCall();
    _service.offCallAcceptedVoice();
    _service.offCallRejectedVoice();
    _service.offVoiceCallEnded();
    _service.offUserOfflineVoice();
    _service.offNewParticipantInvitedVoice();
    _service.offParticipantJoinedVoiceCall();
    _service.offParticipantLeftVoiceCall();
    _service.disconnect();
    _service.dispose();
    super.dispose();
  }
}
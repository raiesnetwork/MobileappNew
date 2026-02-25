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

  String? _currentUserId;
  String? _currentUserName;
  String? _authToken;

  CallState _callState = CallState.idle;
  bool _isConnected = false;
  String? _errorMessage;
  String? _successMessage;

  String? _currentRoomName;
  String? _currentCallerId;
  String? _currentCallerName;
  String? _currentReceiverId;
  String? _currentReceiverName;

  String? _livekitToken;
  List<Map<String, dynamic>> _participants = [];

  bool _acceptedViaCallKit = false;

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
    _setupListeners();
    _service.connect();
  }

  void _setupListeners() {
    _service.onConnect(() {
      debugPrint('✅ Video socket connected');
      _isConnected = true;
      if (_currentUserId != null) {
        _service.registerUser(_currentUserId!);
      }
      _safeNotifyListeners();
    });

    _service.onDisconnect(() {
      debugPrint('❌ Video socket disconnected');
      _isConnected = false;
      _safeNotifyListeners();
    });

    _service.onIncomingVideoCall((data) {
      debugPrint('📞 Incoming video call: $data');
      _currentRoomName = data['roomName'];
      _currentCallerId = data['callerId'];
      _currentCallerName = data['callerName'];
      _callState = CallState.ringing;
      _safeNotifyListeners();
    });

    _service.onCallAccepted((data) {
      debugPrint('✅ Call accepted: $data');
      _successMessage = data['message'];
      _callState = CallState.connected;
      _safeNotifyListeners();
    });

    // ✅ FIX: Only clear data ONCE here, not again in the idle reset.
    // Clearing again on idle would wipe a NEW incoming call's data → "Unknown" bug.
    _service.onCallRejected((data) {
      debugPrint('❌ Call rejected: $data');
      _errorMessage = data['message'];
      _callState = CallState.ended;
      _clearCallData(); // ✅ Clear immediately on ended
      _safeNotifyListeners();

      // ✅ Delay increased to 3s (was 2s) to give UI time to fully dismiss.
      // Only reset state, do NOT call _clearCallData() again here.
      Future.delayed(const Duration(seconds: 3), () {
        if (_callState == CallState.ended) {
          _callState = CallState.idle;
          _safeNotifyListeners();
        }
      });
    });

    // ✅ FIX: Same pattern — clear once, reset state after delay only
    _service.onVideoCallEnded((data) {
      debugPrint('📴 Call ended: $data');
      _callState = CallState.ended;
      _clearCallData(); // ✅ Clear immediately
      _safeNotifyListeners();

      Future.delayed(const Duration(seconds: 3), () {
        if (_callState == CallState.ended) {
          _callState = CallState.idle;
          _safeNotifyListeners();
        }
      });
    });

    // ✅ FIX: Same pattern for user offline
    _service.onUserOffline((message) {
      debugPrint('🔴 User offline: $message');
      _errorMessage = message.toString();
      _callState = CallState.ended;
      _clearCallData(); // ✅ Clear immediately
      _safeNotifyListeners();

      Future.delayed(const Duration(seconds: 3), () {
        if (_callState == CallState.ended) {
          _callState = CallState.idle;
          _safeNotifyListeners();
        }
      });
    });

    _service.onParticipantJoinedCall((data) {
      debugPrint('👤 Participant joined: $data');
      if (!_participants.any((p) => p['userId'] == data['userId'])) {
        _participants.add(data);
        _safeNotifyListeners();
      }
    });

    _service.onParticipantLeftCall((data) {
      debugPrint('👋 Participant left: $data');
      _participants.removeWhere((p) => p['userId'] == data['userId']);
      _safeNotifyListeners();
    });
  }

  // ============================================================================
  // CALL OPERATIONS
  // ============================================================================

  Future<bool> checkUserBusy(String receiverId) async {
    final result = await _service.checkUserBusy(receiverId);
    if (result != null) return result['busy'] ?? false;
    return false;
  }

  Future<void> initiateCall({
    required String receiverId,
    required String receiverName,
  }) async {
    if (_currentUserId == null || _currentUserName == null) {
      _errorMessage = 'User not initialized';
      notifyListeners();
      return;
    }

    if (_callState == CallState.ended) {
      _callState = CallState.idle;
      _clearCallData();
    }

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
    _errorMessage = null;
    notifyListeners();

    _service.initiateVideoCall(
      roomName: _currentRoomName!,
      callerId: _currentUserId!,
      callerName: _currentUserName!,
      receiverId: receiverId,
    );
  }

  Future<void> acceptCall() async {
    if (_currentCallerId == null) {
      _errorMessage = 'No caller ID found';
      notifyListeners();
      return;
    }

    debugPrint('✅ Accepting call from: $_currentCallerId');
    _service.acceptCall(_currentCallerId!);
    _callState = CallState.connected;
    _successMessage = 'Call accepted';
    notifyListeners();
  }

  Future<void> rejectCall() async {
    if (_currentCallerId == null || _currentUserName == null) {
      _errorMessage = 'Missing call data';
      notifyListeners();
      return;
    }

    debugPrint('❌ Rejecting call from: $_currentCallerId');
    _service.rejectCall(
      callerId: _currentCallerId!,
      receiverName: _currentUserName!,
    );

    _callState = CallState.ended;
    _successMessage = 'Call rejected';
    _clearCallData();
    notifyListeners();

    // ✅ Delay 3s and only reset state — do NOT clear data again
    Future.delayed(const Duration(seconds: 3), () {
      if (_callState == CallState.ended) {
        _callState = CallState.idle;
        _safeNotifyListeners();
      }
    });
  }

  Future<void> endCall() async {
    if (_currentUserId == null || _currentUserName == null) {
      debugPrint('❌ Cannot end: User not initialized — resetting anyway');
      _callState = CallState.idle;
      _clearCallData();
      _safeNotifyListeners();
      return;
    }

    String receiverId = _currentReceiverId ?? _currentCallerId ?? '';
    String receiverName = _currentReceiverName ?? _currentCallerName ?? '';

    if (receiverId.isEmpty) {
      debugPrint('❌ Cannot end: No active call — resetting state');
      _callState = CallState.idle;
      _clearCallData();
      _safeNotifyListeners();
      return;
    }

    debugPrint('📴 Ending call with: $receiverId');
    notifyParticipantLeft();

    _service.cancelVideoCall(
      receiverId: receiverId,
      receiverName: receiverName,
      callerName: _currentUserName!,
      callerId: _currentUserId!,
    );

    _callState = CallState.idle;
    _successMessage = 'Call ended';
    _clearCallData();
    notifyListeners();
  }

  Future<void> inviteParticipant({
    required String receiverId,
    required String receiverName,
  }) async {
    if (_currentUserId == null || _currentUserName == null || _currentRoomName == null) {
      _errorMessage = 'Missing required data';
      notifyListeners();
      return;
    }

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

  void notifyParticipantJoined() {
    if (_currentUserId == null || _currentUserName == null || _currentRoomName == null) {
      debugPrint('⚠️ Cannot notify join: Missing data');
      return;
    }
    _service.participantJoinedCall(
      userId: _currentUserId!,
      userName: _currentUserName!,
      roomName: _currentRoomName!,
    );
  }

  void notifyParticipantLeft() {
    if (_currentUserId == null || _currentUserName == null || _currentRoomName == null) {
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

  Future<bool> fetchLivekitToken() async {
    if (_currentUserId == null || _currentUserName == null || _currentRoomName == null) {
      _errorMessage = 'Missing required data for token';
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
    _livekitToken = null;
    _acceptedViaCallKit = false;
    _participants.clear();
  }

  void resetCallState() {
    _callState = CallState.idle;
    _clearCallData();
    clearMessages();
    notifyListeners();
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
      _callState = CallState.ringing;
    }

    debugPrint('📲 FCM call set — room: $roomName | caller: $callerName | acceptedViaCallKit=$acceptedViaCallKit');
    notifyListeners();
  }
  void cancelIncomingCall() {
    if (_callState != CallState.ringing && _callState != CallState.calling) return;
    debugPrint('📵 VideoCallProvider.cancelIncomingCall()');
    _callState = CallState.ended;
    _clearCallData();
    _safeNotifyListeners();

    Future.delayed(const Duration(seconds: 3), () {
      if (_callState == CallState.ended) {
        _callState = CallState.idle;
        _safeNotifyListeners();
      }
    });
  }

  // ============================================================================
  // CLEANUP
  // ============================================================================

  @override
  void dispose() {
    debugPrint('🧹 Cleaning up VideoCallProvider');
    _service.offIncomingVideoCall();
    _service.offCallAccepted();
    _service.offCallRejected();
    _service.offVideoCallEnded();
    _service.offUserOffline();
    _service.offParticipantJoinedCall();
    _service.offParticipantLeftCall();
    _service.disconnect();
    _service.dispose();
    super.dispose();
  }
}
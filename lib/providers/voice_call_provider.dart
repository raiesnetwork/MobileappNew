import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/voice_call_service.dart';

enum VoiceCallState { idle, calling, ringing, connected, ended }

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

  bool _callAcceptEmitted = false;

  // ✅ FIX 1: Guard against double-initiate.
  // Must be set as the VERY FIRST synchronous line in initiateVoiceCall()
  // to block concurrent calls in the same microtask.
  bool _isInitiating = false;

  // ✅ FIX 2: Track when last call ended.
  // endVoiceCall() sets state to IDLE (not ended), so we cannot rely on
  // checking _callState == ended to know if we recently had a call.
  // Instead we track the timestamp and always delay if within 3 seconds.
  DateTime? _lastEndTime;

  // ✅ FIX 3: Track last cancelled receiver to bypass busy check.
  // When caller cancels a call to UserX and immediately re-dials UserX,
  // the server may not have cleared UserX's busy flag yet.
  // We bypass the busy check for the same receiver within 5s of cancelling.
  String? _lastCancelledReceiverId;

  // ✅ FIX 4: Deduplicate busy-check response.
  // VoiceCallService.checkUserBusy() uses socket.on() which accumulates
  // listeners across calls — causing the callback to fire 2-3x per check.
  // We track a flag to ignore duplicate responses.
  bool _busyCheckInProgress = false;

  String? _voiceToken;
  List<Map<String, dynamic>> _participants = [];

  bool _acceptedViaCallKit = false;
  bool _isMuted = false;
  bool _isSpeakerOn = false;

  bool get isMuted => _isMuted;
  bool get isSpeakerOn => _isSpeakerOn;
  void setMuted(bool v) { _isMuted = v; _safeNotify(); }
  void setSpeaker(bool v) { _isSpeakerOn = v; _safeNotify(); }

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

  bool get isReceiver =>
      _currentCallerId != null &&
          _currentCallerId!.isNotEmpty &&
          _currentCallerId != _currentUserId;

  void initialize({required String userId, required String userName, String? authToken}) {
    final bool isNewUser = _currentUserId != userId;
    _currentUserId = userId;
    _currentUserName = userName;
    _authToken = authToken;
    _service.connectSocket();
    // ✅ FIX: Re-setup listeners if new user — new socket needs new listeners
    if (!_listenersSetUp || isNewUser) {
      _listenersSetUp = false; // reset so listeners attach to new socket
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
      if (_currentUserId != null && _currentUserId!.isNotEmpty) {
        _service.registerUser(_currentUserId!);
        debugPrint('📝 Voice user registered: $_currentUserId');
      }
      _safeNotify();
    });

    _service.onDisconnect(() {
      debugPrint('❌ Voice socket disconnected');
      _isConnected = false; _safeNotify();
    });

    _service.onIncomingVoiceCall((data) {
      debugPrint('📞 PROVIDER: Incoming voice call: $data');
      _currentRoomName = data['roomName'];
      _currentCallerId = data['callerId'];
      _currentCallerName = data['callerName'];
      _isConference = data['isConference'] ?? false;
      _callAcceptEmitted = false;
      _callState = VoiceCallState.ringing;
      _safeNotify();
    });

    _service.onCallAcceptedVoice((data) {
      debugPrint('✅ PROVIDER: Voice call accepted: $data');
      _successMessage = data['message'];
      _isConference = data['isConference'] ?? false;
      _callState = VoiceCallState.connected;
      _isInitiating = false;
      _safeNotify();
    });

    _service.onCallRejectedVoice((data) {
      debugPrint('❌ PROVIDER: Voice call rejected: $data');
      _errorMessage = data['message'];
      _callState = VoiceCallState.ended;
      _isInitiating = false;
      _lastEndTime = DateTime.now();
      _clearCallData(); _safeNotify();
      Future.delayed(const Duration(seconds: 3), () {
        if (_callState == VoiceCallState.ended) { _callState = VoiceCallState.idle; _safeNotify(); }
      });
    });

    _service.onVoiceCallEnded((data) {
      debugPrint('📴 PROVIDER: Voice call ended: $data');
      _callState = VoiceCallState.ended;
      _isInitiating = false;
      _lastEndTime = DateTime.now();
      _clearCallData(); _safeNotify();
      Future.delayed(const Duration(seconds: 3), () {
        if (_callState == VoiceCallState.ended) { _callState = VoiceCallState.idle; _safeNotify(); }
      });
    });

    _service.onUserOfflineVoice((message) {
      debugPrint('🔴 PROVIDER: User offline: $message');
      _errorMessage = message.toString();
      _callState = VoiceCallState.ended;
      _isInitiating = false;
      _lastEndTime = DateTime.now();
      _clearCallData(); _safeNotify();
      Future.delayed(const Duration(seconds: 3), () {
        if (_callState == VoiceCallState.ended) { _callState = VoiceCallState.idle; _safeNotify(); }
      });
    });

    _service.onNewParticipantInvitedVoice((data) {
      _currentRoomName = data['roomName'];
      _currentCallerId = data['callerId'];
      _currentCallerName = data['callerName'];
      _isConference = true;
      _callAcceptEmitted = false;
      _callState = VoiceCallState.ringing;
      _safeNotify();
    });

    _service.onParticipantJoinedVoiceCall((data) {
      debugPrint('👤 PROVIDER: Participant joined: $data');
      if (!_participants.any((p) => p['participantId'] == data['participantId'])) {
        _participants.add(Map<String, dynamic>.from(data));
      }
      if (_callState == VoiceCallState.calling && data['participantId'] == _currentReceiverId) {
        _callState = VoiceCallState.connected;
      }
      _safeNotify();
    });

    _service.onParticipantLeftVoiceCall((data) {
      debugPrint('👋 PROVIDER: Participant left: $data');
      _participants.removeWhere((p) => p['participantId'] == data['participantId']);
      _safeNotify();
    });

    debugPrint('✅ Voice call listeners set up');
  }

  // ============================================================================
  // ACCEPT VOICE CALL
  // ============================================================================
  Future<void> acceptVoiceCall() async {
    if (_currentCallerId == null || _currentCallerId!.isEmpty) {
      debugPrint('⚠️ acceptVoiceCall: no callerId — CALLER side, skipping'); return;
    }
    if (_currentUserId == null || _currentUserId!.isEmpty) {
      debugPrint('❌ acceptVoiceCall: missing userId'); return;
    }
    if (_callAcceptEmitted) {
      debugPrint('⚠️ acceptVoiceCall: already emitted'); return;
    }
    debugPrint('✅ acceptVoiceCall: callerId=$_currentCallerId | userId=$_currentUserId');
    _callAcceptEmitted = true;
    await _service.acceptVoiceCall(
      userId: _currentUserId!, receiverId: _currentCallerId!, isConference: _isConference,
    );
    _callState = VoiceCallState.connected;
    _safeNotify();
  }

  // ============================================================================
  // SET CALLER FOR REJECT — does NOT touch callState (avoids IncomingCallScreen flash)
  // ============================================================================
  void setCallerForReject({
    required String callerId,
    required String callerName,
    required String roomName,
  }) {
    _currentCallerId = callerId;
    _currentCallerName = callerName;
    _currentRoomName = roomName;
    debugPrint('📋 [VOICE] setCallerForReject: callerId=$callerId');
    // ✅ Do NOT set _callState here
  }

  // ============================================================================
  // INITIATE VOICE CALL
  //
  // ✅ FIX 1: _isInitiating = true is the ABSOLUTE FIRST LINE (synchronous).
  //   This is critical — if two calls enter this function in the same event
  //   loop turn, both read _isInitiating=false before either sets it.
  //   By setting it first (before any await), the second call is blocked.
  //
  // ✅ FIX 2: Delay is based on _lastEndTime, NOT callState.
  //   endVoiceCall() sets state → IDLE (not ended!), so
  //   `if (_callState == ended)` NEVER triggered the delay.
  //   Now we check: did we have a call in the last 3 seconds? If yes → wait.
  //   This gives the server time to clear the busy flag.
  //
  // ✅ FIX 3: Bypass busy check for same receiver within 5s of cancelling.
  //   The server takes ~1-2s to clear busy after receiving endVoiceCall.
  //   Even with the delay, if the user immediately retries the same person,
  //   skip the busy check and just call them directly.
  //
  // ✅ FIX 4: _busyCheckInProgress deduplicates the socket response.
  //   The VoiceCallService registers socket.on() listeners that accumulate,
  //   causing "checking busy" to print twice. We ignore the second response.
  // ============================================================================
  Future<void> initiateVoiceCall({
    required String receiverId,
    required String receiverName,
    bool isConference = false,
  }) async {
    debugPrint('📞 INITIATING VOICE CALL to $receiverName ($receiverId)');

    if (_currentUserId == null || _currentUserName == null) {
      _errorMessage = 'User not initialized'; _safeNotify(); return;
    }

    // ✅ FIX 1: SYNCHRONOUS — must be the absolute first line
    if (_isInitiating) {
      debugPrint('⚠️ initiateVoiceCall: already initiating — ignoring duplicate'); return;
    }
    _isInitiating = true; // ← set before ANY await

    // ✅ FIX 2: Apply delay if we recently ended/cancelled any call.
    // endVoiceCall() → state=idle, so check _lastEndTime instead of state.
    final bool recentlyEnded = _lastEndTime != null &&
        DateTime.now().difference(_lastEndTime!).inSeconds < 4;

    if (recentlyEnded) {
      debugPrint('⏳ [VOICE] Recently ended call — waiting 2s for server to clear busy...');
      await Future.delayed(const Duration(milliseconds: 2000));
    }

    // Re-register socket so server has current socketId → userId mapping
    if (_currentUserId != null && _isConnected) {
      _service.registerUser(_currentUserId!);
      debugPrint('📝 [VOICE] Re-registered user before initiate: $_currentUserId');
    }

    // ✅ FIX 3: Bypass busy check if we just cancelled to this same receiver
    bool skipBusyCheck = false;
    if (_lastCancelledReceiverId == receiverId && _lastEndTime != null) {
      final elapsedSec = DateTime.now().difference(_lastEndTime!).inSeconds;
      if (elapsedSec < 5) {
        skipBusyCheck = true;
        debugPrint('⚡ [VOICE] Bypassing busy check — same receiver, ${elapsedSec}s since cancel');
      }
    }

    if (!skipBusyCheck) {
      // ✅ FIX 4: Guard against duplicate busy-check responses
      if (_busyCheckInProgress) {
        debugPrint('⚠️ [VOICE] Busy check already in progress — skipping');
      } else {
        _busyCheckInProgress = true;
        final isBusy = await checkUserBusy(receiverId);
        _busyCheckInProgress = false;

        if (isBusy) {
          _errorMessage = '$receiverName is currently in another call';
          debugPrint('❌ Cannot call: User is busy');
          _isInitiating = false;
          _safeNotify(); return;
        }
      }
    }

    _currentRoomName = 'voice-room-${DateTime.now().millisecondsSinceEpoch}';
    _currentReceiverId = receiverId;
    _currentReceiverName = receiverName;
    _isConference = isConference;
    _callAcceptEmitted = false;
    _callState = VoiceCallState.calling;
    _errorMessage = null;
    _safeNotify();

    _service.initiateVoiceCall(
      roomName: _currentRoomName!, callerId: _currentUserId!,
      callerName: _currentUserName!, receiverId: receiverId, isConference: isConference,
    );
    debugPrint('📞 Voice call initiated via service');

    // Safety: reset _isInitiating if call never connects (35s timeout)
    Future.delayed(const Duration(seconds: 35), () {
      if (_isInitiating) _isInitiating = false;
    });
  }

  Future<bool> checkUserBusy(String receiverId) async {
    debugPrint('🔍 Checking if user $receiverId is busy...');
    final result = await _service.checkUserBusy(receiverId);
    if (result != null) {
      debugPrint('📨 Received busy check response: $result');
      debugPrint('🔍 Busy check result: ${result['busy']}');
      return result['busy'] ?? false;
    }
    return false;
  }

  void cancelIncomingCall() {
    if (_callState != VoiceCallState.ringing && _callState != VoiceCallState.calling) return;
    _callState = VoiceCallState.ended;
    _lastEndTime = DateTime.now();
    _clearCallData(); _safeNotify();
    Future.delayed(const Duration(seconds: 3), () {
      if (_callState == VoiceCallState.ended) { _callState = VoiceCallState.idle; _safeNotify(); }
    });
  }

  Future<void> rejectVoiceCall() async {
    debugPrint('❌ REJECTING VOICE CALL from $_currentCallerName ($_currentCallerId)');
    if (_currentCallerId == null || _currentUserName == null || _currentUserId == null) {
      _errorMessage = 'Missing call data'; _safeNotify(); return;
    }
    _service.rejectVoiceCall(
      callerId: _currentCallerId!, receiverName: _currentUserName!, currentUserId: _currentUserId!,
    );
    _callState = VoiceCallState.ended;
    _lastEndTime = DateTime.now();
    _clearCallData(); _safeNotify();
    Future.delayed(const Duration(seconds: 1), () {
      if (_callState == VoiceCallState.ended) { _callState = VoiceCallState.idle; _safeNotify(); }
    });
  }

  Future<void> endVoiceCall() async {
    debugPrint('📴 ENDING VOICE CALL');
    if (_currentUserId == null || _currentUserName == null) {
      _callState = VoiceCallState.idle; _isInitiating = false;
      _lastEndTime = DateTime.now();
      _clearCallData(); _safeNotify(); return;
    }

    final String receiverId = _currentReceiverId ?? _currentCallerId ?? '';
    final String receiverName = _currentReceiverName ?? _currentCallerName ?? '';

    // ✅ FIX 2+3: Record who we cancelled and when
    if (receiverId.isNotEmpty) {
      _lastCancelledReceiverId = receiverId;
      _lastEndTime = DateTime.now();
    }

    if (receiverId.isEmpty) {
      _callState = VoiceCallState.idle; _isInitiating = false; _clearCallData(); _safeNotify(); return;
    }

    if (_currentRoomName != null) notifyParticipantLeft();

    try {
      _service.endVoiceCall(
        receiverId: receiverId, receiverName: receiverName,
        callerName: _currentUserName!, callerId: _currentUserId!,
      );
    } catch (e) { debugPrint('⚠️ endVoiceCall socket error (ignored): $e'); }

    _callState = VoiceCallState.idle;
    _isInitiating = false;
    _successMessage = 'Call ended';
    _clearCallData();
    debugPrint('📴 Call ended, state → idle');
    _safeNotify();
  }

  Future<void> inviteToVoiceCall({required String receiverId, required String receiverName}) async {
    if (_currentUserId == null || _currentUserName == null || _currentRoomName == null) {
      _errorMessage = 'Missing required data'; _safeNotify(); return;
    }
    _service.inviteToVoiceCall(
      roomName: _currentRoomName!, callerId: _currentUserId!,
      callerName: _currentUserName!, receiverId: receiverId, receiverName: receiverName,
    );
    _successMessage = 'Invitation sent to $receiverName';
    _safeNotify();
  }

  void notifyParticipantJoined() {
    if (_currentUserId == null || _currentUserName == null || _currentRoomName == null) return;
    _service.participantJoinedVoiceCall(
      participantId: _currentUserId!, participantName: _currentUserName!, roomName: _currentRoomName!,
    );
  }

  void notifyParticipantLeft() {
    if (_currentUserId == null) return;
    _service.participantLeftVoiceCall(participantId: _currentUserId!);
  }

  Future<bool> fetchVoiceToken() async {
    debugPrint('🎫 FETCHING VOICE TOKEN');
    if (_currentUserId == null || _currentUserName == null || _currentRoomName == null) {
      _errorMessage = 'Missing required data for token'; _safeNotify(); return false;
    }
    debugPrint('🎫 Generating voice token for room: $_currentRoomName');

    String? freshToken = _authToken;
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString('auth_token');
      if (stored != null && stored.isNotEmpty) freshToken = stored;
    } catch (e) { debugPrint('⚠️ Could not read fresh auth token: $e'); }

    final result = await _service.generateVoiceToken(
      roomName: _currentRoomName!, participantName: _currentUserName!,
      userId: _currentUserId!, authToken: freshToken,
    );

    if (result['error'] == false && result['token'] != null) {
      _voiceToken = result['token'];
      debugPrint('✅ Voice token received');
      _safeNotify(); return true;
    } else {
      _errorMessage = result['message'] ?? 'Failed to generate token';
      debugPrint('❌ Failed to get token: $_errorMessage');
      _safeNotify(); return false;
    }
  }

  void _safeNotify() { if (hasListeners) notifyListeners(); }
  void clearMessages() { _errorMessage = null; _successMessage = null; _safeNotify(); }

  void _clearCallData() {
    _currentRoomName = null;
    _currentCallerId = null;
    _currentCallerName = null;
    _currentReceiverId = null;
    _currentReceiverName = null;
    _isConference = false;
    _voiceToken = null;
    _acceptedViaCallKit = false;
    _callAcceptEmitted = false;
    _participants.clear();
    _isMuted = false;
    _isSpeakerOn = false;
  }

  void resetCallState() {
    _callState = VoiceCallState.idle;
    _isInitiating = false;
    _clearCallData();
    clearMessages();
    _safeNotify();
  }

  void setIncomingCallFromFCM({
    required String roomName, required String callerId,
    required String callerName, bool acceptedViaCallKit = false,
  }) {
    _currentRoomName = roomName;
    _currentCallerId = callerId;
    _currentCallerName = callerName;
    _acceptedViaCallKit = acceptedViaCallKit;
    _callAcceptEmitted = false;
    if (!acceptedViaCallKit) _callState = VoiceCallState.ringing;
    debugPrint('📲 FCM voice call set — room: $roomName | caller: $callerName | acceptedViaCallKit=$acceptedViaCallKit');
    notifyListeners();
  }

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
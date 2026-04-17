import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/video_call_service.dart';

enum CallState { idle, calling, ringing, connected, ended }

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
  bool _callAcceptEmitted = false;
  bool _listenersSetUp = false;

  // ✅ FIX 1: Guard against double-initiate — set synchronously as FIRST line
  bool _isInitiating = false;

  // ✅ FIX 2: Track last call end time — endCall() sets state=idle not ended,
  // so we check _lastEndTime instead of callState for the busy delay.
  DateTime? _lastEndTime;

  // ✅ FIX 3: Bypass busy check for same receiver within 5s of cancelling
  String? _lastCancelledReceiverId;

  // ✅ FIX 4: Deduplicate busy-check socket responses
  bool _busyCheckInProgress = false;

  bool _isMuted = false;
  bool _isSpeakerOn = false;
  bool get isMuted => _isMuted;
  bool get isSpeakerOn => _isSpeakerOn;
  void setMuted(bool v) { _isMuted = v; _safeNotify(); }
  void setSpeaker(bool v) { _isSpeakerOn = v; _safeNotify(); }

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
      _listenersSetUp = false;
      _setupListeners();
      _listenersSetUp = true;
    }
    _service.connect();
  }

  void _setupListeners() {
    _service.onConnect(() {
      debugPrint('✅ Video socket connected');
      _isConnected = true;
      if (_currentUserId != null && _currentUserId!.isNotEmpty) {
        _service.registerUser(_currentUserId!);
      }
      _safeNotify();
    });

    _service.onDisconnect(() {
      debugPrint('❌ Video socket disconnected');
      _isConnected = false; _safeNotify();
    });

    _service.onIncomingVideoCall((data) {
      debugPrint('📞 Incoming video call: $data');
      _currentRoomName = data['roomName'];
      _currentCallerId = data['callerId'];
      _currentCallerName = data['callerName'];
      _callAcceptEmitted = false;
      _callState = CallState.ringing;
      _safeNotify();
    });

    _service.onCallAccepted((data) {
      debugPrint('✅ Call accepted: $data');
      _successMessage = data['message'];
      _callState = CallState.connected;
      _isInitiating = false;
      _safeNotify();
    });

    _service.onCallRejected((data) {
      debugPrint('❌ Call rejected: $data');
      _errorMessage = data['message'];
      _callState = CallState.ended;
      _isInitiating = false;
      _lastEndTime = DateTime.now();
      _clearCallData(); _safeNotify();
      Future.delayed(const Duration(seconds: 3), () {
        if (_callState == CallState.ended) { _callState = CallState.idle; _safeNotify(); }
      });
    });

    _service.onVideoCallEnded((data) {
      debugPrint('📴 Call ended: $data');
      _callState = CallState.ended;
      _isInitiating = false;
      _lastEndTime = DateTime.now();
      _clearCallData(); _safeNotify();
      Future.delayed(const Duration(seconds: 3), () {
        if (_callState == CallState.ended) { _callState = CallState.idle; _safeNotify(); }
      });
    });

    _service.onUserOffline((message) {
      debugPrint('🔴 User offline: $message');
      _errorMessage = message.toString();
      _callState = CallState.ended;
      _isInitiating = false;
      _lastEndTime = DateTime.now();
      _clearCallData(); _safeNotify();
      Future.delayed(const Duration(seconds: 3), () {
        if (_callState == CallState.ended) { _callState = CallState.idle; _safeNotify(); }
      });
    });

    _service.onParticipantJoinedCall((data) {
      if (!_participants.any((p) => p['userId'] == data['userId'])) {
        _participants.add(data); _safeNotify();
      }
    });

    _service.onParticipantLeftCall((data) {
      _participants.removeWhere((p) => p['userId'] == data['userId']); _safeNotify();
    });
  }

  // ============================================================================
  // ACCEPT CALL — receiver only, double-emit guarded
  // ============================================================================
  Future<void> acceptCall() async {
    if (_currentCallerId == null || _currentCallerId!.isEmpty) {
      debugPrint('⚠️ acceptCall: no callerId — CALLER side, skipping'); return;
    }
    if (_currentUserId == null || _currentUserId!.isEmpty) {
      debugPrint('❌ acceptCall: missing userId'); return;
    }
    if (_callAcceptEmitted) {
      debugPrint('⚠️ acceptCall: already emitted'); return;
    }
    debugPrint('✅ acceptCall: callerId=$_currentCallerId | userId=$_currentUserId');
    _callAcceptEmitted = true;
    await _service.acceptCall(userId: _currentUserId!, callerId: _currentCallerId!);
    _callState = CallState.connected;
    _successMessage = 'Call accepted';
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
    debugPrint('📋 [VIDEO] setCallerForReject: callerId=$callerId');
    // ✅ Do NOT set _callState here
  }

  // ============================================================================
  // INITIATE CALL
  //
  // ✅ FIX 1: _isInitiating = true is the ABSOLUTE FIRST LINE (synchronous).
  // ✅ FIX 2: Delay based on _lastEndTime, not callState.
  //   endCall() → state=idle. Old check `if (state==ended)` never triggered.
  // ✅ FIX 3: Bypass busy for same receiver within 5s of cancelling.
  // ✅ FIX 4: _busyCheckInProgress deduplicates socket responses.
  // ============================================================================
  Future<void> initiateCall({
    required String receiverId,
    required String receiverName,
  }) async {
    if (_currentUserId == null || _currentUserName == null) {
      _errorMessage = 'User not initialized'; notifyListeners(); return;
    }

    // ✅ FIX 1: SYNCHRONOUS — absolute first line before any await
    if (_isInitiating) {
      debugPrint('⚠️ initiateCall: already initiating — ignoring duplicate'); return;
    }
    _isInitiating = true; // ← set before any await

    // ✅ FIX 2: Delay if recently ended/cancelled any call
    final bool recentlyEnded = _lastEndTime != null &&
        DateTime.now().difference(_lastEndTime!).inSeconds < 4;

    if (recentlyEnded) {
      debugPrint('⏳ [VIDEO] Recently ended call — waiting 2s for server to clear busy...');
      await Future.delayed(const Duration(milliseconds: 2000));
    }

    // Re-register socket to refresh server's userId→socketId mapping
    if (_currentUserId != null && _isConnected) {
      _service.registerUser(_currentUserId!);
      debugPrint('📝 [VIDEO] Re-registered user before initiate: $_currentUserId');
    }

    // ✅ FIX 3: Bypass busy check for same receiver within 5s of cancel
    bool skipBusyCheck = false;
    if (_lastCancelledReceiverId == receiverId && _lastEndTime != null) {
      final elapsedSec = DateTime.now().difference(_lastEndTime!).inSeconds;
      if (elapsedSec < 5) {
        skipBusyCheck = true;
        debugPrint('⚡ [VIDEO] Bypassing busy check — same receiver, ${elapsedSec}s since cancel');
      }
    }

    if (!skipBusyCheck) {
      // ✅ FIX 4: Deduplicate busy check responses
      if (_busyCheckInProgress) {
        debugPrint('⚠️ [VIDEO] Busy check already in progress — skipping');
      } else {
        _busyCheckInProgress = true;
        final isBusy = await checkUserBusy(receiverId);
        _busyCheckInProgress = false;

        if (isBusy) {
          _errorMessage = '$receiverName is currently in another call';
          _isInitiating = false;
          notifyListeners(); return;
        }
      }
    }

    _currentRoomName = 'room-${DateTime.now().millisecondsSinceEpoch}';
    _currentReceiverId = receiverId;
    _currentReceiverName = receiverName;
    _callAcceptEmitted = false;
    _callState = CallState.calling;
    _errorMessage = null;
    notifyListeners();

    _service.initiateVideoCall(
      roomName: _currentRoomName!, callerId: _currentUserId!,
      callerName: _currentUserName!, receiverId: receiverId,
    );
    debugPrint('📞 Initiating call: {roomName: $_currentRoomName, callerId: $_currentUserId, callerName: $_currentUserName, receiverId: $receiverId}');

    // Safety: reset if call never connects (35s timeout)
    Future.delayed(const Duration(seconds: 35), () {
      if (_isInitiating) _isInitiating = false;
    });
  }

  Future<bool> checkUserBusy(String receiverId) async {
    final result = await _service.checkUserBusy(receiverId);
    if (result != null) return result['busy'] ?? false;
    return false;
  }

  Future<void> rejectCall() async {
    if (_currentCallerId == null || _currentUserName == null) {
      _errorMessage = 'Missing call data'; notifyListeners(); return;
    }
    debugPrint('❌ Rejecting call from: $_currentCallerId');
    _service.rejectCall(callerId: _currentCallerId!, receiverName: _currentUserName!);
    _callState = CallState.ended;
    _lastEndTime = DateTime.now();
    _clearCallData(); notifyListeners();
    Future.delayed(const Duration(seconds: 3), () {
      if (_callState == CallState.ended) { _callState = CallState.idle; _safeNotify(); }
    });
  }

  Future<void> endCall() async {
    if (_currentUserId == null || _currentUserName == null) {
      _callState = CallState.idle; _isInitiating = false;
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
      _callState = CallState.idle; _isInitiating = false; _clearCallData(); _safeNotify(); return;
    }

    debugPrint('📴 Ending call with: $receiverId');
    notifyParticipantLeft();
    _service.cancelVideoCall(
      receiverId: receiverId, receiverName: receiverName,
      callerName: _currentUserName!, callerId: _currentUserId!,
    );

    _callState = CallState.idle;
    _isInitiating = false;
    _successMessage = 'Call ended';
    _clearCallData();
    notifyListeners();
  }

  Future<void> inviteParticipant({required String receiverId, required String receiverName}) async {
    if (_currentUserId == null || _currentUserName == null || _currentRoomName == null) {
      _errorMessage = 'Missing required data'; notifyListeners(); return;
    }
    _service.inviteToCall(
      roomName: _currentRoomName!, callerId: _currentUserId!,
      callerName: _currentUserName!, receiverId: receiverId, receiverName: receiverName,
    );
    _successMessage = 'Invitation sent to $receiverName';
    notifyListeners();
  }

  void notifyParticipantJoined() {
    if (_currentUserId == null || _currentUserName == null || _currentRoomName == null) return;
    _service.participantJoinedCall(userId: _currentUserId!, userName: _currentUserName!, roomName: _currentRoomName!);
  }

  void notifyParticipantLeft() {
    if (_currentUserId == null || _currentUserName == null || _currentRoomName == null) return;
    _service.participantLeftCall(userId: _currentUserId!, userName: _currentUserName!, roomName: _currentRoomName!);
  }

  Future<bool> fetchLivekitToken() async {
    if (_currentUserId == null || _currentUserName == null || _currentRoomName == null) {
      _errorMessage = 'Missing required data for token'; notifyListeners(); return false;
    }
    debugPrint('🎫 Generating LiveKit token for room: $_currentRoomName');

    String? freshToken = _authToken;
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString('auth_token');
      if (stored != null && stored.isNotEmpty) freshToken = stored;
    } catch (e) { debugPrint('⚠️ Could not read fresh auth token: $e'); }

    final result = await _service.generateLivekitToken(
      roomName: _currentRoomName!, participantName: _currentUserName!,
      userId: _currentUserId!, authToken: freshToken,
    );

    if (result['error'] == false && result['token'] != null) {
      _livekitToken = result['token'];
      debugPrint('✅ LiveKit token received');
      notifyListeners(); return true;
    } else {
      _errorMessage = result['message'] ?? 'Failed to generate token';
      debugPrint('❌ Failed to get token: $_errorMessage');
      notifyListeners(); return false;
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
    _livekitToken = null;
    _acceptedViaCallKit = false;
    _callAcceptEmitted = false;
    _participants.clear();
    _isMuted = false;
    _isSpeakerOn = false;
  }

  void resetCallState() {
    _callState = CallState.idle;
    _isInitiating = false;
    _clearCallData();
    clearMessages();
    notifyListeners();
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
    if (!acceptedViaCallKit) _callState = CallState.ringing;
    debugPrint('📲 FCM call set — room: $roomName | caller: $callerName | acceptedViaCallKit=$acceptedViaCallKit');
    notifyListeners();
  }

  void cancelIncomingCall() {
    if (_callState != CallState.ringing && _callState != CallState.calling) return;
    _callState = CallState.ended;
    _lastEndTime = DateTime.now();
    _clearCallData(); _safeNotify();
    Future.delayed(const Duration(seconds: 3), () {
      if (_callState == CallState.ended) { _callState = CallState.idle; _safeNotify(); }
    });
  }

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
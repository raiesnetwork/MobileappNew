import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/video_call_service.dart';
import 'personal_chat_provider.dart';

enum CallState { idle, calling, ringing, connected, ended }

class VideoCallProvider extends ChangeNotifier {
  final VideoCallService _service = VideoCallService();

  PersonalChatProvider? _chatProvider;
  void setChatProvider(PersonalChatProvider p) => _chatProvider = p;

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
  bool _callAlreadySaved = false;

  bool _isInitiating = false;
  DateTime? _lastEndTime;
  String? _lastCancelledReceiverId;
  bool _busyCheckInProgress = false;

  // ✅ FIX: Timestamp when WE (as caller) ended the call.
  // Used to ignore stale server echoes of video-call-ended that arrive
  // after we already cleaned up — even if a new incoming call is ringing.
  DateTime? _selfEndedAt;

  // ✅ FIX: Track call-ended-during-join race condition
  bool _callEndedBeforeJoin = false;

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

  // ✅ FIX: Expose so screens can check if call ended during join
  bool get callEndedBeforeJoin => _callEndedBeforeJoin;
  void clearCallEndedBeforeJoin() => _callEndedBeforeJoin = false;

  bool get isReceiver =>
      _currentCallerId != null &&
          _currentCallerId!.isNotEmpty &&
          _currentCallerId != _currentUserId;

  void initialize({required String userId, required String userName, String? authToken}) {
    final bool isNewUser = _currentUserId != userId;
    _currentUserId = userId;
    _currentUserName = userName;
    _authToken = authToken;

    // ✅ FIX: connectSocket() now safely reuses existing socket if connected
    _service.connectSocket();

    if (!_listenersSetUp || isNewUser) {
      _listenersSetUp = false;
      _setupListeners();
      _listenersSetUp = true;
    }
    _service.connect();

    // ✅ FIX: Don't rely only on onConnect callback for registration.
    // onConnect is async — if a call arrives before it fires, user is unreachable.
    // Poll in background until connected, then register immediately.
    _ensureRegisteredOnStartup();
  }

  Future<void> _ensureRegisteredOnStartup() async {
    const pollInterval = Duration(milliseconds: 100);  // ✅ FASTER poll
    const maxWait = Duration(seconds: 8);  // ✅ SHORTER timeout
    final deadline = DateTime.now().add(maxWait);

    debugPrint('🔌 [VIDEO] Fast registration starting for $_currentUserId');

    while (_service.isConnected != true) {
      if (DateTime.now().isAfter(deadline)) {
        debugPrint('⏰ [VIDEO] Fast registration: timeout — socket did not connect');
        return;
      }
      await Future.delayed(pollInterval);
    }

    if (_currentUserId != null && _currentUserId!.isNotEmpty) {
      _service.registerUser(_currentUserId!);
      debugPrint('✅ [VIDEO] Fast registered $_currentUserId');
    }

    // ✅ Wait for registration to complete
    await Future.delayed(const Duration(milliseconds: 500));
  }

  void _setupListeners() {
    _service.onConnect(() {
      debugPrint('✅ Video socket connected');
      _isConnected = true;
      if (_currentUserId != null && _currentUserId!.isNotEmpty) {
        _service.registerUser(_currentUserId!);
      }
      // ✅ FIX: Re-attach listeners on every reconnect
      _reattachSocketListeners();
      _safeNotify();
    });

    _service.onDisconnect(() {
      debugPrint('❌ Video socket disconnected');
      _isConnected = false;
      _safeNotify();
    });

    // ✅ Initial listener attachment
    _reattachSocketListeners();
  }

// ✅ NEW METHOD: Re-attach listeners on reconnect
  void _reattachSocketListeners() {
    _service.onIncomingVideoCall((data) {
      debugPrint('📞 Incoming video call: $data');
      _currentRoomName   = data['roomName'];
      _currentCallerId   = data['callerId'];
      _currentCallerName = data['callerName'];
      _callAcceptEmitted = false;
      _callEndedBeforeJoin = false;
      _callState         = CallState.ringing;
      _safeNotify();
    });

    _service.onCallAccepted((data) {
      debugPrint('✅ Call accepted: $data');
      _successMessage = data['message'];
      _callState      = CallState.connected;
      _isInitiating   = false;
      _safeNotify();
    });

    _service.onCallRejected((data) {
      debugPrint('❌ Call rejected: $data');
      _errorMessage = data['message'];
      _callState    = CallState.ended;
      _isInitiating = false;
      _lastEndTime  = DateTime.now();
      _saveCallRecord(status: 'outgoing');
      _clearCallData();
      _reRegisterUser();
      _safeNotify();
      Future.delayed(const Duration(seconds: 3), () {
        if (_callState == CallState.ended) { _callState = CallState.idle; _safeNotify(); }
      });
    });

    _service.onVideoCallEnded((data) {
      debugPrint('📴 Call ended: $data');

      final selfEndedRecently = _selfEndedAt != null &&
          DateTime.now().difference(_selfEndedAt!).inSeconds < 5;

      if (_callState == CallState.idle || selfEndedRecently) {
        debugPrint('⚠️ [VIDEO] Ignoring video-call-ended — '
            'idle=${_callState == CallState.idle} selfEndedRecently=$selfEndedRecently');
        return;
      }

      _isInitiating = false;
      _lastEndTime  = DateTime.now();

      final bool iAmReceiver = _currentCallerId != null &&
          _currentCallerId!.isNotEmpty &&
          _currentCallerId != _currentUserId;

      if (!_callAlreadySaved) {
        _saveCallRecord(status: iAmReceiver ? 'incoming' : 'outgoing');
      }
      _callAlreadySaved = false;

      _callEndedBeforeJoin = true;
      _callState = CallState.ended;
      _clearCallData();
      _reRegisterUser();
      _safeNotify();

      Future.delayed(const Duration(seconds: 3), () {
        if (_callState == CallState.ended) { _callState = CallState.idle; _safeNotify(); }
      });
    });

    _service.onUserOffline((message) {
      debugPrint('🔴 User offline: $message');
      _errorMessage = message.toString();
      _callState    = CallState.ended;
      _isInitiating = false;
      _lastEndTime  = DateTime.now();
      if (!_callAlreadySaved) {
        _saveCallRecord(status: 'completed');
        _callAlreadySaved = true;
      }
      _callEndedBeforeJoin = true;
      _clearCallData();
      _reRegisterUser();
      _safeNotify();
      Future.delayed(const Duration(seconds: 3), () {
        if (_callState == CallState.ended) { _callState = CallState.idle; _safeNotify(); }
      });
    });

    _service.onParticipantJoinedCall((data) {
      if (!_participants.any((p) => p['userId'] == data['userId'])) {
        _participants.add(data);
        _safeNotify();
      }
    });

    _service.onParticipantLeftCall((data) {
      _participants.removeWhere((p) => p['userId'] == data['userId']);
      _safeNotify();
    });
  }

  // ════════════════════════════════════════════════════════════════════════
  //  RE-REGISTER HELPER
  // ✅ FIX: Server clears userId→socketId mapping when a call ends.
  // Without re-registering, Person1 (who was caller) can't receive the
  // next incoming call until they restart the app (which triggers onConnect
  // → registerUser). Calling this after every call end restores the mapping.
  // ════════════════════════════════════════════════════════════════════════
  void _reRegisterUser() {
    if (_currentUserId != null && _currentUserId!.isNotEmpty) {
      // ✅ FIX: Delay slightly to ensure socket is ready
      Future.delayed(const Duration(milliseconds: 200), () {
        if (_currentUserId != null) {
          _service.registerUser(_currentUserId!);
          debugPrint('📝 [VIDEO] Re-registered after call end: $_currentUserId');
        }
      });
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  //  CALL RECORD HELPER
  // ════════════════════════════════════════════════════════════════════════

  void _saveCallRecord({required String status, int duration = 0}) {
    final bool iAmReceiver = _currentCallerId != null &&
        _currentCallerId!.isNotEmpty &&
        _currentCallerId != _currentUserId;

    final String callerId = iAmReceiver
        ? _currentCallerId!
        : (_currentUserId ?? '');

    final String receiverId = iAmReceiver
        ? (_currentUserId ?? '')
        : (_currentReceiverId ?? _currentCallerId ?? '');

    if (callerId.isEmpty || receiverId.isEmpty) {
      debugPrint('⚠️ [VIDEO SAVE CALL] Missing IDs — skipping. '
          'callerId=$callerId receiverId=$receiverId');
      return;
    }

    debugPrint('📹 [VIDEO SAVE CALL] iAmReceiver=$iAmReceiver | '
        'status=$status | callerId=$callerId | receiverId=$receiverId');

    _chatProvider?.saveCallHistory(
      callerId:   callerId,
      receiverId: receiverId,
      type:       'video',
      status:     status,
      duration:   duration,
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  //  CALL ACTIONS
  // ════════════════════════════════════════════════════════════════════════

  Future<void> acceptCall() async {
    if (_currentCallerId == null || _currentCallerId!.isEmpty) {
      debugPrint('⚠️ acceptCall: no callerId — CALLER side, skipping');
      return;
    }
    if (_currentUserId == null || _currentUserId!.isEmpty) {
      debugPrint('❌ acceptCall: missing userId');
      return;
    }
    if (_callAcceptEmitted) {
      debugPrint('⚠️ acceptCall: already emitted');
      return;
    }
    debugPrint('✅ acceptCall: callerId=$_currentCallerId | userId=$_currentUserId');
    _callAcceptEmitted = true;
    await _service.acceptCall(userId: _currentUserId!, callerId: _currentCallerId!);
    _callState      = CallState.connected;
    _successMessage = 'Call accepted';
    _safeNotify();
  }

  void setCallerForReject({
    required String callerId,
    required String callerName,
    required String roomName,
  }) {
    _currentCallerId   = callerId;
    _currentCallerName = callerName;
    _currentRoomName   = roomName;
    debugPrint('📋 [VIDEO] setCallerForReject: callerId=$callerId');
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

    if (_isInitiating) {
      debugPrint('⚠️ initiateCall: already initiating — ignoring duplicate');
      return;
    }
    _isInitiating = true;

    final bool recentlyEnded = _lastEndTime != null &&
        DateTime.now().difference(_lastEndTime!).inSeconds < 4;
    if (recentlyEnded) {
      debugPrint('⏳ [VIDEO] Recently ended — waiting 2s...');
      await Future.delayed(const Duration(milliseconds: 2000));
    }

    if (_currentUserId != null && _isConnected) {
      _service.registerUser(_currentUserId!);
      debugPrint('📝 [VIDEO] Re-registered user: $_currentUserId');
    }

    bool skipBusyCheck = false;
    if (_lastCancelledReceiverId == receiverId && _lastEndTime != null) {
      final elapsedSec = DateTime.now().difference(_lastEndTime!).inSeconds;
      if (elapsedSec < 5) {
        skipBusyCheck = true;
        debugPrint('⚡ [VIDEO] Bypassing busy check — same receiver, ${elapsedSec}s since cancel');
      }
    }

    if (!skipBusyCheck) {
      if (_busyCheckInProgress) {
        debugPrint('⚠️ [VIDEO] Busy check already in progress — skipping');
      } else {
        _busyCheckInProgress = true;
        final isBusy = await checkUserBusy(receiverId);
        _busyCheckInProgress = false;
        if (isBusy) {
          _errorMessage = '$receiverName is currently in another call';
          _isInitiating = false;
          notifyListeners();
          return;
        }
      }
    }

    _currentRoomName     = 'room-${DateTime.now().millisecondsSinceEpoch}';
    _currentReceiverId   = receiverId;
    _currentReceiverName = receiverName;
    _callAcceptEmitted   = false;
    _callEndedBeforeJoin = false;
    _callState           = CallState.calling;
    _errorMessage        = null;
    notifyListeners();

    // ✅ FIX: initiateVideoCall is now a proper Future — awaited properly
    await _service.initiateVideoCall(
      roomName:   _currentRoomName!,
      callerId:   _currentUserId!,
      callerName: _currentUserName!,
      receiverId: receiverId,
    );
    debugPrint('📞 Initiating call: roomName=$_currentRoomName | '
        'callerId=$_currentUserId | receiverId=$receiverId');

    // ✅ FIX: Timeout is in initiateCall, not in onVideoCallEnded
    Future.delayed(const Duration(seconds: 30), () {
      if (_isInitiating && _callState == CallState.calling) {
        debugPrint('⏱️ [VIDEO] Call timeout — no answer after 30s');
        _errorMessage = 'No answer';
        _isInitiating = false;
        endCall();
      }
    });
  }

  Future<bool> checkUserBusy(String receiverId) async {
    final result = await _service.checkUserBusy(receiverId);
    if (result != null) return result['busy'] ?? false;
    return false;
  }

  Future<void> rejectCall() async {
    if (_currentCallerId == null || _currentUserName == null) {
      _errorMessage = 'Missing call data';
      notifyListeners();
      return;
    }
    debugPrint('❌ Rejecting video call from: $_currentCallerId');
    _saveCallRecord(status: 'rejected');
    _service.rejectCall(callerId: _currentCallerId!, receiverName: _currentUserName!);
    _callState   = CallState.ended;
    _lastEndTime = DateTime.now();
    _clearCallData();
    _reRegisterUser(); // ✅ restore server registration so next incoming call works
    notifyListeners();
    Future.delayed(const Duration(seconds: 3), () {
      if (_callState == CallState.ended) { _callState = CallState.idle; _safeNotify(); }
    });
  }

  Future<void> endCall() async {
    if (_currentUserId == null || _currentUserName == null) {
      _callState    = CallState.idle;
      _isInitiating = false;
      _lastEndTime  = DateTime.now();
      _clearCallData();
      _safeNotify();
      return;
    }

    final String receiverId   = _currentReceiverId ?? _currentCallerId ?? '';
    final String receiverName = _currentReceiverName ?? _currentCallerName ?? '';

    if (receiverId.isNotEmpty) {
      _lastCancelledReceiverId = receiverId;
      _lastEndTime             = DateTime.now();
    }

    if (receiverId.isEmpty) {
      _callState    = CallState.idle;
      _isInitiating = false;
      _clearCallData();
      _safeNotify();
      return;
    }

    debugPrint('📴 Ending video call with: $receiverId');
    notifyParticipantLeft();

    _callAlreadySaved = true;
    _selfEndedAt = DateTime.now(); // ✅ mark that WE ended — suppress server echo for 5s
    _saveCallRecord(status: 'outgoing');

    _service.cancelVideoCall(
      receiverId:   receiverId,
      receiverName: receiverName,
      callerName:   _currentUserName!,
      callerId:     _currentUserId!,
    );

    _callState      = CallState.idle;
    _isInitiating   = false;
    _successMessage = 'Call ended';
    _clearCallData();
    _reRegisterUser(); // ✅ restore server registration so next incoming call works
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
      roomName:     _currentRoomName!,
      callerId:     _currentUserId!,
      callerName:   _currentUserName!,
      receiverId:   receiverId,
      receiverName: receiverName,
    );
    _successMessage = 'Invitation sent to $receiverName';
    notifyListeners();
  }

  void notifyParticipantJoined() {
    if (_currentUserId == null || _currentUserName == null || _currentRoomName == null) return;
    _service.participantJoinedCall(
      userId:   _currentUserId!,
      userName: _currentUserName!,
      roomName: _currentRoomName!,
    );
  }

  void notifyParticipantLeft() {
    if (_currentUserId == null || _currentUserName == null || _currentRoomName == null) return;
    _service.participantLeftCall(
      userId:   _currentUserId!,
      userName: _currentUserName!,
      roomName: _currentRoomName!,
    );
  }

  Future<bool> fetchLivekitToken() async {
    if (_currentUserId == null || _currentUserName == null || _currentRoomName == null) {
      _errorMessage = 'Missing required data for token';
      notifyListeners();
      return false;
    }
    debugPrint('🎫 Generating LiveKit token for room: $_currentRoomName');

    String? freshToken = _authToken;
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString('auth_token');
      if (stored != null && stored.isNotEmpty) freshToken = stored;
    } catch (e) {
      debugPrint('⚠️ Could not read fresh auth token: $e');
    }

    final result = await _service.generateLivekitToken(
      roomName:        _currentRoomName!,
      participantName: _currentUserName!,
      userId:          _currentUserId!,
      authToken:       freshToken,
    );

    // ✅ FIX: Don't check result['error'] == false — check token != null
    // Server may return {token: "xxx"} without an 'error' key at all
    final token = result['token'];
    if (token != null && token.toString().isNotEmpty) {
      _livekitToken = token.toString();
      debugPrint('✅ LiveKit token received');
      notifyListeners();
      return true;
    } else {
      _errorMessage = result['message']?.toString() ?? 'Failed to generate token';
      debugPrint('❌ Failed to get token: $_errorMessage | full result: $result');
      notifyListeners();
      return false;
    }
  }

  void _safeNotify() { if (hasListeners) notifyListeners(); }
  void clearMessages() { _errorMessage = null; _successMessage = null; _safeNotify(); }

  void _clearCallData() {
    // ✅ FIX: Don't reset _callAlreadySaved here — it's reset explicitly after use
    _currentRoomName     = null;
    _currentCallerId     = null;
    _currentCallerName   = null;
    _currentReceiverId   = null;
    _currentReceiverName = null;
    _livekitToken        = null;
    _acceptedViaCallKit  = false;
    _callAcceptEmitted   = false;
    _participants.clear();
    _isMuted     = false;
    _isSpeakerOn = false;
  }

  void resetCallState() {
    _callState       = CallState.idle;
    _isInitiating    = false;
    _callAlreadySaved = false;
    _callEndedBeforeJoin = false;
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
    _currentRoomName     = roomName;
    _currentCallerId     = callerId;
    _currentCallerName   = callerName;
    _acceptedViaCallKit  = acceptedViaCallKit;
    _callAcceptEmitted   = false;
    _callEndedBeforeJoin = false;
    if (!acceptedViaCallKit) _callState = CallState.ringing;
    debugPrint('📲 FCM call set — room: $roomName | caller: $callerName | '
        'acceptedViaCallKit=$acceptedViaCallKit');
    notifyListeners();
  }

  void cancelIncomingCall() {
    if (_callState != CallState.ringing && _callState != CallState.calling) return;
    _saveCallRecord(status: 'incoming');
    _callState   = CallState.ended;
    _lastEndTime = DateTime.now();
    _callEndedBeforeJoin = true;
    _clearCallData();
    _reRegisterUser(); // ✅ restore server registration so next incoming call works
    _safeNotify();
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
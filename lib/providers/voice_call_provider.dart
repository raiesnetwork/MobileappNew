import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/voice_call_service.dart';
import 'personal_chat_provider.dart';

enum VoiceCallState { idle, calling, ringing, connected, ended }

class VoiceCallProvider extends ChangeNotifier {
  final VoiceCallService _service = VoiceCallService();

  PersonalChatProvider? _chatProvider;
  void setChatProvider(PersonalChatProvider p) => _chatProvider = p;

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
  bool _isInitiating = false;
  bool _callAlreadySaved = false; // ✅ flag to prevent double save
  DateTime? _lastEndTime;
  String? _lastCancelledReceiverId;
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
    _currentUserId   = userId;
    _currentUserName = userName;
    _authToken       = authToken;
    _service.connectSocket();
    if (!_listenersSetUp || isNewUser) {
      _listenersSetUp = false;
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
      _isConnected = false;
      _safeNotify();
    });

    _service.onIncomingVoiceCall((data) {
      debugPrint('📞 PROVIDER: Incoming voice call: $data');
      _currentRoomName   = data['roomName'];
      _currentCallerId   = data['callerId'];
      _currentCallerName = data['callerName'];
      _isConference      = data['isConference'] ?? false;
      _callAcceptEmitted = false;
      _callState         = VoiceCallState.ringing;
      _safeNotify();
    });

    _service.onCallAcceptedVoice((data) {
      debugPrint('✅ PROVIDER: Voice call accepted: $data');
      _successMessage = data['message'];
      _isConference   = data['isConference'] ?? false;
      _callState      = VoiceCallState.connected;
      _isInitiating   = false;
      _safeNotify();
    });

    _service.onCallRejectedVoice((data) {
      debugPrint('❌ PROVIDER: Voice call rejected: $data');
      _errorMessage = data['message'];
      _callState    = VoiceCallState.ended;
      _isInitiating = false;
      _lastEndTime  = DateTime.now();
      // Caller saves outgoing when receiver rejects
      _saveCallRecord(status: 'outgoing');
      _clearCallData();
      _safeNotify();
      Future.delayed(const Duration(seconds: 3), () {
        if (_callState == VoiceCallState.ended) { _callState = VoiceCallState.idle; _safeNotify(); }
      });
    });

    _service.onVoiceCallEnded((data) {
      debugPrint('📴 PROVIDER: Voice call ended: $data');
      _callState    = VoiceCallState.ended;
      _isInitiating = false;
      _lastEndTime  = DateTime.now();

      final bool iAmReceiver = _currentCallerId != null &&
          _currentCallerId!.isNotEmpty &&
          _currentCallerId != _currentUserId;

      // ✅ Caller already saved in endVoiceCall() — skip to avoid duplicate
      // ✅ Receiver saves here as 'incoming'
      if (!_callAlreadySaved) {
        _saveCallRecord(status: iAmReceiver ? 'incoming' : 'outgoing');
      }
      _callAlreadySaved = false; // reset for next call

      _clearCallData();
      _safeNotify();
      Future.delayed(const Duration(seconds: 3), () {
        if (_callState == VoiceCallState.ended) { _callState = VoiceCallState.idle; _safeNotify(); }
      });
    });

    _service.onUserOfflineVoice((message) {
      debugPrint('🔴 PROVIDER: User offline: $message');
      _errorMessage = message.toString();
      _callState    = VoiceCallState.ended;
      _isInitiating = false;
      _lastEndTime  = DateTime.now();
      // Caller saves outgoing — receiver was offline
      _saveCallRecord(status: 'outgoing');
      _clearCallData();
      _safeNotify();
      Future.delayed(const Duration(seconds: 3), () {
        if (_callState == VoiceCallState.ended) { _callState = VoiceCallState.idle; _safeNotify(); }
      });
    });

    _service.onNewParticipantInvitedVoice((data) {
      _currentRoomName   = data['roomName'];
      _currentCallerId   = data['callerId'];
      _currentCallerName = data['callerName'];
      _isConference      = true;
      _callAcceptEmitted = false;
      _callState         = VoiceCallState.ringing;
      _safeNotify();
    });

    _service.onParticipantJoinedVoiceCall((data) {
      debugPrint('👤 PROVIDER: Participant joined: $data');
      if (!_participants.any((p) => p['participantId'] == data['participantId'])) {
        _participants.add(Map<String, dynamic>.from(data));
      }
      if (_callState == VoiceCallState.calling &&
          data['participantId'] == _currentReceiverId) {
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
      debugPrint('⚠️ [VOICE SAVE CALL] Missing IDs — skipping. '
          'callerId=$callerId receiverId=$receiverId');
      return;
    }

    debugPrint('📞 [VOICE SAVE CALL] iAmReceiver=$iAmReceiver | '
        'status=$status | callerId=$callerId | receiverId=$receiverId');

    _chatProvider?.saveCallHistory(
      callerId:   callerId,
      receiverId: receiverId,
      type:       'voice',
      status:     status,
      duration:   duration,
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  //  CALL ACTIONS
  // ════════════════════════════════════════════════════════════════════════

  Future<void> acceptVoiceCall() async {
    if (_currentCallerId == null || _currentCallerId!.isEmpty) {
      debugPrint('⚠️ acceptVoiceCall: no callerId — CALLER side, skipping');
      return;
    }
    if (_currentUserId == null || _currentUserId!.isEmpty) {
      debugPrint('❌ acceptVoiceCall: missing userId');
      return;
    }
    if (_callAcceptEmitted) {
      debugPrint('⚠️ acceptVoiceCall: already emitted');
      return;
    }
    debugPrint('✅ acceptVoiceCall: callerId=$_currentCallerId | userId=$_currentUserId');
    _callAcceptEmitted = true;
    await _service.acceptVoiceCall(
      userId:       _currentUserId!,
      receiverId:   _currentCallerId!,
      isConference: _isConference,
    );
    _callState = VoiceCallState.connected;
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
    debugPrint('📋 [VOICE] setCallerForReject: callerId=$callerId');
  }

  Future<void> initiateVoiceCall({
    required String receiverId,
    required String receiverName,
    bool isConference = false,
  }) async {
    debugPrint('📞 INITIATING VOICE CALL to $receiverName ($receiverId)');

    if (_currentUserId == null || _currentUserName == null) {
      _errorMessage = 'User not initialized';
      _safeNotify();
      return;
    }

    if (_isInitiating) {
      debugPrint('⚠️ initiateVoiceCall: already initiating — ignoring duplicate');
      return;
    }
    _isInitiating = true;

    final bool recentlyEnded = _lastEndTime != null &&
        DateTime.now().difference(_lastEndTime!).inSeconds < 4;
    if (recentlyEnded) {
      debugPrint('⏳ [VOICE] Recently ended — waiting 2s...');
      await Future.delayed(const Duration(milliseconds: 2000));
    }

    if (_currentUserId != null && _isConnected) {
      _service.registerUser(_currentUserId!);
      debugPrint('📝 [VOICE] Re-registered user: $_currentUserId');
    }

    bool skipBusyCheck = false;
    if (_lastCancelledReceiverId == receiverId && _lastEndTime != null) {
      final elapsedSec = DateTime.now().difference(_lastEndTime!).inSeconds;
      if (elapsedSec < 5) {
        skipBusyCheck = true;
        debugPrint('⚡ [VOICE] Bypassing busy check — same receiver, ${elapsedSec}s since cancel');
      }
    }

    if (!skipBusyCheck) {
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
          _safeNotify();
          return;
        }
      }
    }

    _currentRoomName     = 'voice-room-${DateTime.now().millisecondsSinceEpoch}';
    _currentReceiverId   = receiverId;
    _currentReceiverName = receiverName;
    _isConference        = isConference;
    _callAcceptEmitted   = false;
    _callState           = VoiceCallState.calling;
    _errorMessage        = null;
    _safeNotify();

    _service.initiateVoiceCall(
      roomName:     _currentRoomName!,
      callerId:     _currentUserId!,
      callerName:   _currentUserName!,
      receiverId:   receiverId,
      isConference: isConference,
    );
    debugPrint('📞 Voice call initiated via service');

    Future.delayed(const Duration(seconds: 35), () {
      if (_isInitiating) _isInitiating = false;
    });
  }

  Future<bool> checkUserBusy(String receiverId) async {
    debugPrint('🔍 Checking if user $receiverId is busy...');
    final result = await _service.checkUserBusy(receiverId);
    if (result != null) {
      debugPrint('📨 Busy check response: $result');
      return result['busy'] ?? false;
    }
    return false;
  }

  void cancelIncomingCall() {
    if (_callState != VoiceCallState.ringing && _callState != VoiceCallState.calling) return;
    // Receiver saves incoming — caller cancelled before answer
    _saveCallRecord(status: 'incoming');
    _callState   = VoiceCallState.ended;
    _lastEndTime = DateTime.now();
    _clearCallData();
    _safeNotify();
    Future.delayed(const Duration(seconds: 3), () {
      if (_callState == VoiceCallState.ended) { _callState = VoiceCallState.idle; _safeNotify(); }
    });
  }

  Future<void> rejectVoiceCall() async {
    debugPrint('❌ REJECTING VOICE CALL from $_currentCallerName ($_currentCallerId)');
    if (_currentCallerId == null || _currentUserName == null || _currentUserId == null) {
      _errorMessage = 'Missing call data';
      _safeNotify();
      return;
    }
    // Receiver saves rejected — I declined
    _saveCallRecord(status: 'rejected');
    _service.rejectVoiceCall(
      callerId:      _currentCallerId!,
      receiverName:  _currentUserName!,
      currentUserId: _currentUserId!,
    );
    _callState   = VoiceCallState.ended;
    _lastEndTime = DateTime.now();
    _clearCallData();
    _safeNotify();
    Future.delayed(const Duration(seconds: 1), () {
      if (_callState == VoiceCallState.ended) { _callState = VoiceCallState.idle; _safeNotify(); }
    });
  }

  Future<void> endVoiceCall() async {
    debugPrint('📴 ENDING VOICE CALL');
    if (_currentUserId == null || _currentUserName == null) {
      _callState    = VoiceCallState.idle;
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
      _callState    = VoiceCallState.idle;
      _isInitiating = false;
      _clearCallData();
      _safeNotify();
      return;
    }

    if (_currentRoomName != null) notifyParticipantLeft();

    // ✅ Caller saves outgoing — set flag so onVoiceCallEnded skips saving
    _callAlreadySaved = true;
    _saveCallRecord(status: 'outgoing');

    try {
      _service.endVoiceCall(
        receiverId:   receiverId,
        receiverName: receiverName,
        callerName:   _currentUserName!,
        callerId:     _currentUserId!,
      );
    } catch (e) {
      debugPrint('⚠️ endVoiceCall socket error (ignored): $e');
    }

    _callState      = VoiceCallState.idle;
    _isInitiating   = false;
    _successMessage = 'Call ended';
    _clearCallData();
    debugPrint('📴 Call ended, state → idle');
    _safeNotify();
  }

  Future<void> inviteToVoiceCall({
    required String receiverId,
    required String receiverName,
  }) async {
    if (_currentUserId == null || _currentUserName == null || _currentRoomName == null) {
      _errorMessage = 'Missing required data';
      _safeNotify();
      return;
    }
    _service.inviteToVoiceCall(
      roomName:     _currentRoomName!,
      callerId:     _currentUserId!,
      callerName:   _currentUserName!,
      receiverId:   receiverId,
      receiverName: receiverName,
    );
    _successMessage = 'Invitation sent to $receiverName';
    _safeNotify();
  }

  void notifyParticipantJoined() {
    if (_currentUserId == null || _currentUserName == null || _currentRoomName == null) return;
    _service.participantJoinedVoiceCall(
      participantId:   _currentUserId!,
      participantName: _currentUserName!,
      roomName:        _currentRoomName!,
    );
  }

  void notifyParticipantLeft() {
    if (_currentUserId == null) return;
    _service.participantLeftVoiceCall(participantId: _currentUserId!);
  }

  Future<bool> fetchVoiceToken() async {
    debugPrint('🎫 FETCHING VOICE TOKEN');
    if (_currentUserId == null || _currentUserName == null || _currentRoomName == null) {
      _errorMessage = 'Missing required data for token';
      _safeNotify();
      return false;
    }
    debugPrint('🎫 Generating voice token for room: $_currentRoomName');

    String? freshToken = _authToken;
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString('auth_token');
      if (stored != null && stored.isNotEmpty) freshToken = stored;
    } catch (e) {
      debugPrint('⚠️ Could not read fresh auth token: $e');
    }

    final result = await _service.generateVoiceToken(
      roomName:        _currentRoomName!,
      participantName: _currentUserName!,
      userId:          _currentUserId!,
      authToken:       freshToken,
    );

    if (result['error'] == false && result['token'] != null) {
      _voiceToken = result['token'];
      debugPrint('✅ Voice token received');
      _safeNotify();
      return true;
    } else {
      _errorMessage = result['message'] ?? 'Failed to generate token';
      debugPrint('❌ Failed to get token: $_errorMessage');
      _safeNotify();
      return false;
    }
  }

  void _safeNotify() { if (hasListeners) notifyListeners(); }
  void clearMessages() { _errorMessage = null; _successMessage = null; _safeNotify(); }

  void _clearCallData() {
    _callAlreadySaved    = false; // ✅ reset flag
    _currentRoomName     = null;
    _currentCallerId     = null;
    _currentCallerName   = null;
    _currentReceiverId   = null;
    _currentReceiverName = null;
    _isConference        = false;
    _voiceToken          = null;
    _acceptedViaCallKit  = false;
    _callAcceptEmitted   = false;
    _participants.clear();
    _isMuted     = false;
    _isSpeakerOn = false;
  }

  void resetCallState() {
    _callState    = VoiceCallState.idle;
    _isInitiating = false;
    _clearCallData();
    clearMessages();
    _safeNotify();
  }

  void setIncomingCallFromFCM({
    required String roomName,
    required String callerId,
    required String callerName,
    bool acceptedViaCallKit = false,
  }) {
    _currentRoomName    = roomName;
    _currentCallerId    = callerId;
    _currentCallerName  = callerName;
    _acceptedViaCallKit = acceptedViaCallKit;
    _callAcceptEmitted  = false;
    if (!acceptedViaCallKit) _callState = VoiceCallState.ringing;
    debugPrint('📲 FCM voice call set — room: $roomName | caller: $callerName | '
        'acceptedViaCallKit=$acceptedViaCallKit');
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
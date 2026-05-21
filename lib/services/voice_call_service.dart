import 'dart:async';
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:http/http.dart' as http;
import 'dart:convert';

class VoiceCallService {
  static const String baseUrl = 'https://meet.ixes.ai';
  static const String socketUrl = '$baseUrl/voicecall';
  static const String apiUrl = '$baseUrl/api';

  IO.Socket? _socket;
  IO.Socket? get socket => _socket;
  bool _isRegistered = false;

  // ============================================================================
  // SOCKET CONNECTION
  // FIX: Reuse existing socket if connected; dispose old one before creating new
  // ============================================================================

  void connectSocket() {
    // ✅ FIX: If socket already connected, reuse it
    if (_socket != null && _socket!.connected) {
      debugPrint('✅ Voice socket already connected — reusing');
      return;
    }
    // ✅ FIX: Clean up old socket before creating new one
    if (_socket != null) {
      _clearAllListeners();
      _socket!.dispose();
      _socket = null;
      _isRegistered = false;
    }

    _socket = IO.io(
      socketUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setTimeout(10000)
          .setReconnectionDelay(2000)
          .setReconnectionAttempts(5)
          .enableReconnection()
          .build(),
    );

    _socket?.onConnectError((error) => debugPrint('❌ Voice Socket CONNECT ERROR: $error'));
    _socket?.onError((error) => debugPrint('❌ Voice Socket ERROR: $error'));
    _socket?.onReconnect((attempt) {
      debugPrint('🔄 Voice Socket RECONNECTING (attempt $attempt)');
      _isRegistered = false; // ✅ force re-registration after reconnect
    });
    _socket?.onReconnectError((error) => debugPrint('❌ Voice Socket RECONNECT ERROR: $error'));
    _socket?.onReconnectFailed((_) => debugPrint('❌ Voice Socket RECONNECT FAILED'));

    debugPrint('🎙️ Voice call socket configured');
  }

  void connect() {
    if (_socket == null) {
      debugPrint('⚠️ Socket not initialized, initializing now...');
      connectSocket();
    }
    _socket?.connect();
    debugPrint('🔌 Connecting to voice call socket: $socketUrl');
  }

  void disconnect() {
    _isRegistered = false;
    _socket?.disconnect();
    debugPrint('🔌 Disconnected from voice call socket');
  }

  // ✅ FIX: Clear all event listeners to prevent stacking
  void _clearAllListeners() {
    _socket?.off('connect');
    _socket?.off('disconnect');
    _socket?.off('incoming-voice-call');
    _socket?.off('call-accepted-voice');
    _socket?.off('call-rejected-voice');
    _socket?.off('voice-call-ended');
    _socket?.off('user-offline-voice');
    _socket?.off('new-participant-invited-voice');
    _socket?.off('participant-joined-voice-call');
    _socket?.off('participant-left-voice-call');
  }

  void dispose() {
    _isRegistered = false;
    _clearAllListeners();
    _socket?.dispose();
    _socket = null;
    debugPrint('🗑️ Voice call socket disposed');
  }

  // ============================================================================
  // RELIABLE ensureConnectedAndRegistered
  // ============================================================================
  Future<void> ensureConnectedAndRegistered(String userId) async {
    debugPrint('🔌 ensureConnectedAndRegistered: start | connected=${_socket?.connected} | registered=$_isRegistered');

    if (_socket == null) {
      debugPrint('⚠️ Socket is null — initializing');
      connectSocket();
    }

    if (_socket?.connected != true) {
      debugPrint('🔌 Socket not connected — calling connect()');
      _socket?.connect();
    }

    const pollInterval = Duration(milliseconds: 200);
    const maxWait = Duration(seconds: 10);
    final deadline = DateTime.now().add(maxWait);

    while (_socket?.connected != true) {
      if (DateTime.now().isAfter(deadline)) {
        debugPrint('⏰ ensureConnectedAndRegistered: timeout waiting for connection');
        return;
      }
      debugPrint('⏳ Waiting for socket connection...');
      await Future.delayed(pollInterval);
    }

    debugPrint('✅ ensureConnectedAndRegistered: connected — registering $userId');
    _socket?.emit('register-user', userId);
    _isRegistered = true;

    await Future.delayed(const Duration(milliseconds: 300));
    debugPrint('✅ ensureConnectedAndRegistered: done | socketId=${_socket?.id}');
  }

  // ============================================================================
  // ACCEPT VOICE CALL
  // ============================================================================
  Future<void> acceptVoiceCall({
    required String userId,
    required String receiverId,
    bool isConference = false,
  }) async {
    debugPrint('🔌 acceptVoiceCall: ensuring connected+registered for $userId');
    await ensureConnectedAndRegistered(userId);

    if (_socket?.connected != true) {
      debugPrint('❌ acceptVoiceCall: still not connected — aborting');
      return;
    }

    final data = {'receiverId': receiverId, 'isConference': isConference};
    _socket?.emit('call-accepted-voice', data);
    debugPrint('✅ Emitted call-accepted-voice: $data | socketId=${_socket?.id}');
  }

  // ============================================================================
  // REGISTER USER
  // ============================================================================
  void registerUser(String userId) {
    if (_socket?.connected != true) {
      debugPrint('⚠️ Cannot register: Socket not connected');
      return;
    }
    _socket?.emit('register-user', userId);
    _isRegistered = true;
    debugPrint('📝 Registered user for voice calls: $userId');
    debugPrint('Socket ID after registration: ${_socket?.id}');
  }

  bool get isRegistered => _isRegistered;

  // ============================================================================
  // CHECK USER BUSY
  // ============================================================================
  Future<Map<String, dynamic>?> checkUserBusy(String receiverId) async {
    try {
      if (_socket == null || _socket?.connected != true) return null;

      final completer = Completer<Map<String, dynamic>?>();

      _socket!.emitWithAck(
        'user-busy-voice',
        {'receiverId': receiverId},
        ack: (data) {
          if (completer.isCompleted) return;
          try {
            if (data == null) {
              completer.complete(null);
            } else if (data is Map) {
              completer.complete(Map<String, dynamic>.from(data));
            } else if (data is List && data.isNotEmpty && data[0] is Map) {
              completer.complete(Map<String, dynamic>.from(data[0]));
            } else {
              completer.complete(null);
            }
          } catch (e) {
            if (!completer.isCompleted) completer.completeError(e);
          }
        },
      );

      return await completer.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () => null,
      );
    } catch (e) {
      debugPrint('❌ Error checking user busy: $e');
      return null;
    }
  }

  // ============================================================================
  // CALL OPERATIONS
  // ============================================================================

  Future<void> initiateVoiceCall({
    required String roomName,
    required String callerId,
    required String callerName,
    required String receiverId,
    bool isConference = false,
  }) async {
    await ensureConnectedAndRegistered(callerId);
    if (_socket?.connected != true) {
      debugPrint('⚠️ Cannot initiate call: Socket not connected');
      return;
    }
    final data = {
      'roomName': roomName,
      'callerId': callerId,
      'callerName': callerName,
      'receiverId': receiverId,
      'isConference': isConference,
    };
    _socket?.emit('initiate-voice-call', data);
    debugPrint('📞 Initiating voice call: $data');
    debugPrint('Socket ID: ${_socket?.id}');
  }

  void rejectVoiceCall({
    required String callerId,
    required String receiverName,
    required String currentUserId,
  }) {
    if (_socket?.connected != true) {
      debugPrint('⚠️ Cannot reject call: Socket not connected');
      return;
    }
    final data = {
      'callerId': callerId,
      'receiverName': receiverName,
      'currentUserId': currentUserId,
    };
    _socket?.emit('call-rejected-voice', data);
    debugPrint('❌ Rejecting voice call: $data');
  }

  void endVoiceCall({
    required String receiverId,
    required String receiverName,
    required String callerName,
    required String callerId,
  }) {
    if (_socket?.connected != true) {
      debugPrint('⚠️ Cannot end call: Socket not connected');
      return;
    }
    final data = {
      'receiverId': receiverId,
      'receiverName': receiverName,
      'callerName': callerName,
      'callerId': callerId,
    };
    _socket?.emit('voice-call-ended', data);
    debugPrint('📴 Ending voice call: $data');
  }

  void inviteToVoiceCall({
    required String roomName,
    required String callerId,
    required String callerName,
    required String receiverId,
    required String receiverName,
  }) {
    if (_socket?.connected != true) {
      debugPrint('⚠️ Cannot invite: Socket not connected');
      return;
    }
    final data = {
      'roomName': roomName,
      'callerId': callerId,
      'callerName': callerName,
      'receiverId': receiverId,
      'receiverName': receiverName,
    };
    _socket?.emit('invite-to-voice-call', data);
    debugPrint('📧 Inviting to voice call: $data');
  }

  void participantJoinedVoiceCall({
    required String participantId,
    required String participantName,
    required String roomName,
  }) {
    if (_socket?.connected != true) {
      debugPrint('⚠️ Cannot notify join: Socket not connected');
      return;
    }
    final data = {
      'participantId': participantId,
      'participantName': participantName,
      'roomName': roomName,
    };
    _socket?.emit('participant-joined-voice-call', data);
    debugPrint('👤 Participant joined voice call: $data');
  }

  void participantLeftVoiceCall({required String participantId}) {
    if (_socket?.connected != true) {
      debugPrint('⚠️ Cannot notify leave: Socket not connected');
      return;
    }
    final data = {'participantId': participantId};
    _socket?.emit('participant-left-voice-call', data);
    debugPrint('👋 Participant left voice call: $data');
  }

  // ============================================================================
  // REST API
  // ============================================================================
  Future<Map<String, dynamic>> generateVoiceToken({
    required String roomName,
    required String participantName,
    required String userId,
    String? authToken,
  }) async {
    try {
      final headers = {
        'Content-Type': 'application/json',
        if (authToken != null) 'Authorization': 'Bearer $authToken',
      };
      final body = json.encode({
        'roomName': roomName,
        'participantName': participantName,
        'userId': userId,
        'isVoiceCall': true,
      });

      debugPrint('🎫 Generating voice token for room: $roomName');

      final response = await http.post(
        Uri.parse('$apiUrl/api/voicecall/token'),
        headers: headers,
        body: body,
      );

      debugPrint('📡 Response status: ${response.statusCode}');
      debugPrint('📦 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        debugPrint('✅ Voice token generated successfully');
        return result;
      } else {
        try {
          return json.decode(response.body);
        } catch (e) {
          return {'error': true, 'message': 'Server error: ${response.statusCode}'};
        }
      }
    } catch (e) {
      debugPrint('❌ Error generating voice token: $e');
      return {'error': true, 'message': 'Failed to generate token: $e'};
    }
  }

  // ============================================================================
  // EVENT LISTENERS
  // ✅ FIX: Each on*() call uses off() first to prevent listener stacking
  // ============================================================================
  void onConnect(Function() callback) {
    _socket?.off('connect');
    _socket?.onConnect((_) {
      debugPrint('✅ Voice call socket connected (callback)');
      callback();
    });
  }

  void onDisconnect(Function() callback) {
    _socket?.off('disconnect');
    _socket?.onDisconnect((_) {
      debugPrint('❌ Voice call socket disconnected (callback)');
      _isRegistered = false;
      callback();
    });
  }

  void onIncomingVoiceCall(Function(dynamic) callback) {
    _socket?.off('incoming-voice-call');
    _socket?.on('incoming-voice-call', (data) {
      debugPrint('📞 INCOMING VOICE CALL EVENT RECEIVED: $data');
      callback(data);
    });
    debugPrint('👂 Listening for incoming-voice-call events');
  }

  void onCallAcceptedVoice(Function(dynamic) callback) {
    _socket?.off('call-accepted-voice');
    _socket?.on('call-accepted-voice', (data) {
      debugPrint('✅ CALL ACCEPTED EVENT RECEIVED: $data');
      callback(data);
    });
    debugPrint('👂 Listening for call-accepted-voice events');
  }

  void onCallRejectedVoice(Function(dynamic) callback) {
    _socket?.off('call-rejected-voice');
    _socket?.on('call-rejected-voice', (data) {
      debugPrint('❌ CALL REJECTED EVENT RECEIVED: $data');
      callback(data);
    });
    debugPrint('👂 Listening for call-rejected-voice events');
  }

  void onVoiceCallEnded(Function(dynamic) callback) {
    _socket?.off('voice-call-ended');
    _socket?.on('voice-call-ended', (data) {
      debugPrint('📴 CALL ENDED EVENT RECEIVED: $data');
      callback(data);
    });
    debugPrint('👂 Listening for voice-call-ended events');
  }

  void onUserOfflineVoice(Function(dynamic) callback) {
    _socket?.off('user-offline-voice');
    _socket?.on('user-offline-voice', (data) {
      debugPrint('🔴 USER OFFLINE EVENT RECEIVED: $data');
      callback(data);
    });
    debugPrint('👂 Listening for user-offline-voice events');
  }

  void onNewParticipantInvitedVoice(Function(dynamic) callback) {
    _socket?.off('new-participant-invited-voice');
    _socket?.on('new-participant-invited-voice', (data) {
      debugPrint('📧 NEW PARTICIPANT INVITED EVENT RECEIVED: $data');
      callback(data);
    });
    debugPrint('👂 Listening for new-participant-invited-voice events');
  }

  void onParticipantJoinedVoiceCall(Function(dynamic) callback) {
    _socket?.off('participant-joined-voice-call');
    _socket?.on('participant-joined-voice-call', (data) {
      debugPrint('👤 PARTICIPANT JOINED EVENT RECEIVED: $data');
      callback(data);
    });
    debugPrint('👂 Listening for participant-joined-voice-call events');
  }

  void onParticipantLeftVoiceCall(Function(dynamic) callback) {
    _socket?.off('participant-left-voice-call');
    _socket?.on('participant-left-voice-call', (data) {
      debugPrint('👋 PARTICIPANT LEFT EVENT RECEIVED: $data');
      callback(data);
    });
    debugPrint('👂 Listening for participant-left-voice-call events');
  }

  void offIncomingVoiceCall() => _socket?.off('incoming-voice-call');
  void offCallAcceptedVoice() => _socket?.off('call-accepted-voice');
  void offCallRejectedVoice() => _socket?.off('call-rejected-voice');
  void offVoiceCallEnded() => _socket?.off('voice-call-ended');
  void offUserOfflineVoice() => _socket?.off('user-offline-voice');
  void offNewParticipantInvitedVoice() => _socket?.off('new-participant-invited-voice');
  void offParticipantJoinedVoiceCall() => _socket?.off('participant-joined-voice-call');
  void offParticipantLeftVoiceCall() => _socket?.off('participant-left-voice-call');

  bool get isConnected => _socket?.connected ?? false;
  String? get socketId => _socket?.id;
}
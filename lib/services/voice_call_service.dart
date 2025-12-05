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
  // ============================================================================

  /// Initialize socket connection
  void connectSocket() {
    _socket = IO.io(
      socketUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setTimeout(10000)  // Add timeout
          .setReconnectionDelay(2000)
          .setReconnectionAttempts(5)
          .enableReconnection()  // Enable auto-reconnection
          .build(),
    );

    // Add basic connection listeners for debugging
    _socket?.onConnect((_) {
      debugPrint('✅ Socket CONNECTED to $socketUrl');
      debugPrint('Socket ID: ${_socket?.id}');
    });

    _socket?.onConnecting((_) {
      debugPrint('🔄 Socket CONNECTING...');
    });

    _socket?.onConnectError((error) {
      debugPrint('❌ Socket CONNECT ERROR: $error');
    });

    _socket?.onError((error) {
      debugPrint('❌ Socket ERROR: $error');
    });

    _socket?.onReconnect((attempt) {
      debugPrint('🔄 Socket RECONNECTING (attempt $attempt)');
    });

    _socket?.onReconnectError((error) {
      debugPrint('❌ Socket RECONNECT ERROR: $error');
    });

    _socket?.onReconnectFailed((_) {
      debugPrint('❌ Socket RECONNECT FAILED');
    });

    debugPrint('🎙️ Voice call socket configured');
  }

  /// Connect to socket
  void connect() {
    if (_socket == null) {
      debugPrint('⚠️ Socket not initialized, initializing now...');
      connectSocket();
    }

    _socket?.connect();
    debugPrint('🔌 Connecting to voice call socket: $socketUrl');
  }

  /// Disconnect socket
  void disconnect() {
    _isRegistered = false;
    _socket?.disconnect();
    debugPrint('🔌 Disconnected from voice call socket');
  }

  /// Dispose socket
  void dispose() {
    _isRegistered = false;
    _socket?.dispose();
    debugPrint('🗑️ Voice call socket disposed');
  }

  // ============================================================================
  // SOCKET EMIT METHODS
  // ============================================================================

  /// Register user for receiving voice calls
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

  /// Check registration status
  bool get isRegistered => _isRegistered;

  /// Check if user is busy (in another call)
  Future<Map<String, dynamic>?> checkUserBusy(String receiverId) async {
    try {
      if (_socket == null) {
        debugPrint('⚠️ Socket not initialized');
        return null;
      }

      if (_socket?.connected != true) {
        debugPrint('⚠️ Socket not connected');
        return null;
      }

      final completer = Completer<Map<String, dynamic>?>();

      debugPrint('🔍 Checking if user $receiverId is busy...');

      _socket!.emitWithAck(
        'user-busy-voice',
        {'receiverId': receiverId},
        ack: (data) {
          try {
            debugPrint('📨 Received busy check response: $data');

            if (data == null) {
              completer.complete(null);
              return;
            }

            if (data is Map) {
              completer.complete(Map<String, dynamic>.from(data));
            } else if (data is List && data.isNotEmpty && data[0] is Map) {
              completer.complete(Map<String, dynamic>.from(data[0]));
            } else {
              completer.complete(null);
            }
          } catch (e) {
            debugPrint('❌ Error parsing busy check response: $e');
            completer.completeError(e);
          }
        },
      );

      return await completer.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          debugPrint('⏱️ Check user busy timed out');
          return null;
        },
      );
    } catch (e) {
      debugPrint('❌ Error checking user busy: $e');
      return null;
    }
  }

  /// Initiate voice call
  void initiateVoiceCall({
    required String roomName,
    required String callerId,
    required String callerName,
    required String receiverId,
    bool isConference = false,
  }) {
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

  /// Accept voice call
  void acceptVoiceCall({
    required String receiverId,
    bool isConference = false,
  }) {
    if (_socket?.connected != true) {
      debugPrint('⚠️ Cannot accept call: Socket not connected');
      return;
    }

    final data = {
      'receiverId': receiverId,
      'isConference': isConference,
    };

    _socket?.emit('call-accepted-voice', data);
    debugPrint('✅ Accepting voice call: $data');
  }

  /// Reject voice call
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

  /// End voice call
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

  /// Invite to voice call (conference)
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

  /// Participant joined voice call
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

  /// Participant left voice call
  void participantLeftVoiceCall({
    required String participantId,
  }) {
    if (_socket?.connected != true) {
      debugPrint('⚠️ Cannot notify leave: Socket not connected');
      return;
    }

    final data = {
      'participantId': participantId,
    };

    _socket?.emit('participant-left-voice-call', data);
    debugPrint('👋 Participant left voice call: $data');
  }

  // ============================================================================
  // REST API METHODS
  // ============================================================================

  /// Generate LiveKit voice token
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
          final result = json.decode(response.body);
          debugPrint('❌ Token generation failed: ${result['message']}');
          return result;
        } catch (e) {
          debugPrint('❌ Invalid response: ${response.body}');
          return {
            'error': true,
            'message': 'Server error: ${response.statusCode}',
          };
        }
      }
    } catch (e) {
      debugPrint('❌ Error generating voice token: $e');
      return {
        'error': true,
        'message': 'Failed to generate token: $e',
      };
    }
  }


  void onConnect(Function() callback) {
    _socket?.onConnect((_) {
      debugPrint('✅ Voice call socket connected (callback)');
      callback();
    });
  }

  void onDisconnect(Function() callback) {
    _socket?.onDisconnect((_) {
      debugPrint('❌ Voice call socket disconnected (callback)');
      _isRegistered = false;
      callback();
    });
  }

  void onIncomingVoiceCall(Function(dynamic) callback) {
    _socket?.on('incoming-voice-call', (data) {
      debugPrint('📞 INCOMING VOICE CALL EVENT RECEIVED: $data');
      callback(data);
    });
    debugPrint('👂 Listening for incoming-voice-call events');
  }

  void onCallAcceptedVoice(Function(dynamic) callback) {
    _socket?.on('call-accepted-voice', (data) {
      debugPrint('✅ CALL ACCEPTED EVENT RECEIVED: $data');
      callback(data);
    });
    debugPrint('👂 Listening for call-accepted-voice events');
  }

  void onCallRejectedVoice(Function(dynamic) callback) {
    _socket?.on('call-rejected-voice', (data) {
      debugPrint('❌ CALL REJECTED EVENT RECEIVED: $data');
      callback(data);
    });
    debugPrint('👂 Listening for call-rejected-voice events');
  }

  void onVoiceCallEnded(Function(dynamic) callback) {
    _socket?.on('voice-call-ended', (data) {
      debugPrint('📴 CALL ENDED EVENT RECEIVED: $data');
      callback(data);
    });
    debugPrint('👂 Listening for voice-call-ended events');
  }

  void onUserOfflineVoice(Function(dynamic) callback) {
    _socket?.on('user-offline-voice', (data) {
      debugPrint('🔴 USER OFFLINE EVENT RECEIVED: $data');
      callback(data);
    });
    debugPrint('👂 Listening for user-offline-voice events');
  }

  void onNewParticipantInvitedVoice(Function(dynamic) callback) {
    _socket?.on('new-participant-invited-voice', (data) {
      debugPrint('📧 NEW PARTICIPANT INVITED EVENT RECEIVED: $data');
      callback(data);
    });
    debugPrint('👂 Listening for new-participant-invited-voice events');
  }

  void onParticipantJoinedVoiceCall(Function(dynamic) callback) {
    _socket?.on('participant-joined-voice-call', (data) {
      debugPrint('👤 PARTICIPANT JOINED EVENT RECEIVED: $data');
      callback(data);
    });
    debugPrint('👂 Listening for participant-joined-voice-call events');
  }

  void onParticipantLeftVoiceCall(Function(dynamic) callback) {
    _socket?.on('participant-left-voice-call', (data) {
      debugPrint('👋 PARTICIPANT LEFT EVENT RECEIVED: $data');
      callback(data);
    });
    debugPrint('👂 Listening for participant-left-voice-call events');
  }



  void offIncomingVoiceCall() {
    _socket?.off('incoming-voice-call');
    debugPrint('🔇 Removed incoming-voice-call listener');
  }

  void offCallAcceptedVoice() {
    _socket?.off('call-accepted-voice');
    debugPrint('🔇 Removed call-accepted-voice listener');
  }

  void offCallRejectedVoice() {
    _socket?.off('call-rejected-voice');
    debugPrint('🔇 Removed call-rejected-voice listener');
  }

  void offVoiceCallEnded() {
    _socket?.off('voice-call-ended');
    debugPrint('🔇 Removed voice-call-ended listener');
  }

  void offUserOfflineVoice() {
    _socket?.off('user-offline-voice');
    debugPrint('🔇 Removed user-offline-voice listener');
  }

  void offNewParticipantInvitedVoice() {
    _socket?.off('new-participant-invited-voice');
    debugPrint('🔇 Removed new-participant-invited-voice listener');
  }

  void offParticipantJoinedVoiceCall() {
    _socket?.off('participant-joined-voice-call');
    debugPrint('🔇 Removed participant-joined-voice-call listener');
  }

  void offParticipantLeftVoiceCall() {
    _socket?.off('participant-left-voice-call');
    debugPrint('🔇 Removed participant-left-voice-call listener');
  }



  /// Get current connection status
  bool get isConnected => _socket?.connected ?? false;

  /// Get socket ID
  String? get socketId => _socket?.id;

  /// Print current socket status
  void printStatus() {
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('Socket Status:');
    debugPrint('  Connected: ${_socket?.connected}');
    debugPrint('  Socket ID: ${_socket?.id}');
    debugPrint('  Registered: $_isRegistered');
    debugPrint('  URL: $socketUrl');
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  }
}
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:http/http.dart' as http;
import 'dart:convert';

class VideoCallService {
  static const String socketUrl = 'https://meet.ixes.ai/videocall';

  IO.Socket? _socket;
  IO.Socket? get socket => _socket;
  bool _isRegistered = false;

  bool get isConnected => _socket?.connected ?? false;

  // ============================================================================
  // SOCKET CONNECTION
  // ============================================================================

  void connectSocket() {
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

    _socket?.onConnectError((error) => debugPrint('❌ Video Socket CONNECT ERROR: $error'));
    _socket?.onError((error) => debugPrint('❌ Video Socket ERROR: $error'));
    _socket?.onReconnect((attempt) => debugPrint('🔄 Video Socket RECONNECTING (attempt $attempt)'));
  }

  void connect() {
    _socket?.connect();
  }

  void disconnect() {
    _isRegistered = false;
    _socket?.disconnect();
  }

  void dispose() {
    _isRegistered = false;
    _socket?.dispose();
  }

  // ============================================================================
  // ✅ KEY FIX: RELIABLE ensureConnectedAndRegistered using polling
  // ============================================================================
  Future<void> ensureConnectedAndRegistered(String userId) async {
    debugPrint('🔌 Video ensureConnectedAndRegistered: start | connected=${_socket?.connected} | registered=$_isRegistered');

    // Step 1: Initialize if null
    if (_socket == null) {
      debugPrint('⚠️ Video socket is null — initializing');
      connectSocket();
    }

    // Step 2: Trigger connect if not connected
    if (_socket?.connected != true) {
      debugPrint('🔌 Video socket not connected — calling connect()');
      _socket?.connect();
    }

    // Step 3: Poll until connected (max 10 seconds)
    const pollInterval = Duration(milliseconds: 200);
    const maxWait = Duration(seconds: 10);
    final deadline = DateTime.now().add(maxWait);

    while (_socket?.connected != true) {
      if (DateTime.now().isAfter(deadline)) {
        debugPrint('⏰ Video ensureConnectedAndRegistered: timeout waiting for connection');
        return;
      }
      debugPrint('⏳ Waiting for video socket connection...');
      await Future.delayed(pollInterval);
    }

    // Step 4: Register
    debugPrint('✅ Video ensureConnectedAndRegistered: connected — registering $userId');
    _socket?.emit('register-user', userId);
    _isRegistered = true;

    // Small buffer for server to process registration
    await Future.delayed(const Duration(milliseconds: 300));
    debugPrint('✅ Video ensureConnectedAndRegistered: done | socketId=${_socket?.id}');
  }

  // ============================================================================
  // REGISTER USER
  // ============================================================================
  void registerUser(String userId) {
    _socket?.emit('register-user', userId);
    _isRegistered = true;
    debugPrint('📝 Registered user: $userId');
  }

  // ============================================================================
  // ACCEPT CALL
  // ============================================================================
  Future<void> acceptCall({
    required String userId,
    required String callerId,
  }) async {
    debugPrint('🔌 acceptCall: ensuring connected+registered for $userId');
    await ensureConnectedAndRegistered(userId);

    if (_socket?.connected != true) {
      debugPrint('❌ acceptCall: still not connected — aborting');
      return;
    }

    _socket?.emit('call-accepted', callerId);
    debugPrint('✅ Emitted call-accepted: $callerId | socketId=${_socket?.id}');
  }

  // ============================================================================
  // CALL OPERATIONS
  // ============================================================================

  Future<Map<String, dynamic>?> checkUserBusy(String receiverId) async {
    try {
      if (_socket == null || _socket?.connected != true) return null;

      final completer = Completer<Map<String, dynamic>?>();

      _socket!.emitWithAck('user-busy', {'receiverId': receiverId}, ack: (data) {
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
          completer.completeError(e);
        }
      });

      return await completer.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          debugPrint('Check user busy timed out');
          return null;
        },
      );
    } catch (e) {
      debugPrint('Error checking user busy: $e');
      return null;
    }
  }

  void initiateVideoCall({
    required String roomName,
    required String callerId,
    required String callerName,
    required String receiverId,
  }) {
    final data = {
      'roomName': roomName,
      'callerId': callerId,
      'callerName': callerName,
      'receiverId': receiverId,
    };
    _socket?.emit('initiate-video-call', data);
    debugPrint('📞 Initiating call: $data');
  }

  void rejectCall({
    required String callerId,
    required String receiverName,
  }) {
    final data = {'callerId': callerId, 'receiverName': receiverName};
    _socket?.emit('call-rejected', data);
    debugPrint('❌ Rejecting call: $data');
  }

  void cancelVideoCall({
    required String receiverId,
    required String receiverName,
    required String callerName,
    required String callerId,
  }) {
    final data = {
      'receiverId': receiverId,
      'receiverName': receiverName,
      'callerName': callerName,
      'callerId': callerId,
    };
    _socket?.emit('video-call-canceled', data);
    debugPrint('📴 Canceling call: $data');
  }

  void inviteToCall({
    required String roomName,
    required String callerId,
    required String callerName,
    required String receiverId,
    required String receiverName,
  }) {
    final data = {
      'roomName': roomName,
      'callerId': callerId,
      'callerName': callerName,
      'receiverId': receiverId,
      'receiverName': receiverName,
    };
    _socket?.emit('invite-to-call', data);
    debugPrint('📧 Inviting to call: $data');
  }

  void participantJoinedCall({
    required String userId,
    required String userName,
    required String roomName,
  }) {
    final data = {'userId': userId, 'userName': userName, 'roomName': roomName};
    _socket?.emit('participant-joined-call', data);
    debugPrint('👤 Participant joined: $data');
  }

  void participantLeftCall({
    required String userId,
    required String userName,
    required String roomName,
  }) {
    final data = {'userId': userId, 'userName': userName, 'roomName': roomName};
    _socket?.emit('participant-left-call', data);
    debugPrint('👋 Participant left: $data');
  }

  // ============================================================================
  // REST API
  // ============================================================================
  Future<Map<String, dynamic>> generateLivekitToken({
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
      });

      debugPrint('🎫 Generating LiveKit token for room: $roomName');

      var response = await http.post(
        Uri.parse('https://meet.ixes.ai/api/api/videocall/token'),
        headers: headers,
        body: body,
      );

      debugPrint('📡 Response status: ${response.statusCode}');

      if (response.statusCode == 404) {
        response = await http.post(
          Uri.parse('https://meet.ixes.ai/api/videocall/token'),
          headers: headers,
          body: body,
        );
        debugPrint('📡 Alternative response status: ${response.statusCode}');
      }

      if (response.statusCode == 200) {
        debugPrint('✅ Token generated successfully');
        return json.decode(response.body);
      } else {
        try {
          return json.decode(response.body);
        } catch (e) {
          return {
            'error': true,
            'message': 'Server error: ${response.statusCode}',
          };
        }
      }
    } catch (e) {
      debugPrint('❌ Error generating token: $e');
      return {'error': true, 'message': 'Failed to generate token: $e'};
    }
  }

  // ============================================================================
  // EVENT LISTENERS
  // ============================================================================
  void onConnect(Function() callback) {
    _socket?.onConnect((_) {
      debugPrint('✅ Video socket connected');
      callback();
    });
  }

  void onDisconnect(Function() callback) {
    _socket?.onDisconnect((_) {
      debugPrint('❌ Video socket disconnected');
      _isRegistered = false;
      callback();
    });
  }

  void onIncomingVideoCall(Function(dynamic) callback) => _socket?.on('incoming-video-call', callback);
  void onCallAccepted(Function(dynamic) callback) => _socket?.on('call-accepted', callback);
  void onCallRejected(Function(dynamic) callback) => _socket?.on('call-rejected', callback);
  void onVideoCallEnded(Function(dynamic) callback) => _socket?.on('video-call-ended', callback);
  void onUserOffline(Function(dynamic) callback) => _socket?.on('user-offline', callback);
  void onParticipantJoinedCall(Function(dynamic) callback) => _socket?.on('participant-joined-call', callback);
  void onParticipantLeftCall(Function(dynamic) callback) => _socket?.on('participant-left-call', callback);

  void offIncomingVideoCall() => _socket?.off('incoming-video-call');
  void offCallAccepted() => _socket?.off('call-accepted');
  void offCallRejected() => _socket?.off('call-rejected');
  void offVideoCallEnded() => _socket?.off('video-call-ended');
  void offUserOffline() => _socket?.off('user-offline');
  void offParticipantJoinedCall() => _socket?.off('participant-joined-call');
  void offParticipantLeftCall() => _socket?.off('participant-left-call');
}
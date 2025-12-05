import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ixes.app/constants/apiConstants.dart';

import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:http/http.dart' as http;
import 'dart:convert';


class VideoCallService {
  static const String socketUrl = 'https://meet.ixes.ai/videocall';

  IO.Socket? _socket;
  IO.Socket? get socket => _socket;

  // Initialize socket connection
  void connectSocket() {
    _socket = IO.io(
      socketUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build(),
    );
  }

  // Connect to socket
  void connect() {
    _socket?.connect();
  }

  // Disconnect socket
  void disconnect() {
    _socket?.disconnect();
  }

  // Dispose socket
  void dispose() {
    _socket?.dispose();
  }

  // Register user for receiving calls
  void registerUser(String userId) {
    _socket?.emit('register-user', userId);
    debugPrint('📝 Registered user: $userId');
  }

  // Check if user is busy
  Future<Map<String, dynamic>?> checkUserBusy(String receiverId) async {
    try {
      if (_socket == null) {
        debugPrint('Socket not initialized');
        return null;
      }

      final completer = Completer<Map<String, dynamic>?>();

      _socket!.emitWithAck('user-busy', {'receiverId': receiverId}, ack: (data) {
        try {
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

  // Initiate video call
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

  // Accept call
  void acceptCall(String callerId) {
    _socket?.emit('call-accepted', callerId);
    debugPrint('✅ Accepting call from: $callerId');
  }

  // Reject call
  void rejectCall({
    required String callerId,
    required String receiverName,
  }) {
    final data = {
      'callerId': callerId,
      'receiverName': receiverName,
    };

    _socket?.emit('call-rejected', data);
    debugPrint('❌ Rejecting call: $data');
  }

  // Cancel/End video call
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

  // Invite to call
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

  // Participant joined call
  void participantJoinedCall({
    required String userId,
    required String userName,
    required String roomName,
  }) {
    final data = {
      'userId': userId,
      'userName': userName,
      'roomName': roomName,
    };

    _socket?.emit('participant-joined-call', data);
    debugPrint('👤 Participant joined: $data');
  }

  // Participant left call
  void participantLeftCall({
    required String userId,
    required String userName,
    required String roomName,
  }) {
    final data = {
      'userId': userId,
      'userName': userName,
      'roomName': roomName,
    };

    _socket?.emit('participant-left-call', data);
    debugPrint('👋 Participant left: $data');
  }

  // Generate LiveKit token via REST API
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

      // According to documentation: POST /api/videocall/token
      // Base URL: https://meet.ixes.ai/api
      // So full URL should be: https://meet.ixes.ai/api + /api/videocall/token
      // But that seems redundant, so trying: https://meet.ixes.ai/api/videocall/token

      // Try the documented endpoint first
      String apiUrl = 'https://meet.ixes.ai/api/api/videocall/token';


      debugPrint('🎫 Generating LiveKit token for room: $roomName');
      debugPrint('🔗 API URL: $apiUrl');
      debugPrint('📦 Request body: $body');

      var response = await http.post(
        Uri.parse(apiUrl),
        headers: headers,
        body: body,
      );

      debugPrint('📡 Response status: ${response.statusCode}');
      debugPrint('📦 Response body: ${response.body}');

      // If 404, try alternative endpoint without /api prefix
      if (response.statusCode == 404) {
        debugPrint('⚠️ First endpoint failed, trying alternative...');
        apiUrl = 'https://meet.ixes.ai/api/videocall/token';
        debugPrint('🔗 Alternative API URL: $apiUrl');

        response = await http.post(
          Uri.parse(apiUrl),
          headers: headers,
          body: body,
        );

        debugPrint('📡 Alternative response status: ${response.statusCode}');
        debugPrint('📦 Alternative response body: ${response.body}');
      }

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        debugPrint('✅ Token generated successfully');
        return result;
      } else {
        // Handle non-200 responses
        try {
          final result = json.decode(response.body);
          debugPrint('❌ Token generation failed: ${result['message']}');
          return result;
        } catch (e) {
          // If response is not JSON (like HTML error page)
          debugPrint('❌ Invalid response format: ${response.body.substring(0, 100)}...');
          return {
            'error': true,
            'message': 'Server returned invalid response. Status: ${response.statusCode}. Please check if the API endpoint exists.',
          };
        }
      }
    } catch (e) {
      debugPrint('❌ Error generating token: $e');
      return {
        'error': true,
        'message': 'Failed to generate token: $e',
      };
    }
  }

  // Socket event listeners
  void onConnect(Function() callback) {
    _socket?.onConnect((_) => callback());
  }

  void onDisconnect(Function() callback) {
    _socket?.onDisconnect((_) => callback());
  }

  void onIncomingVideoCall(Function(dynamic) callback) {
    _socket?.on('incoming-video-call', callback);
  }

  void onCallAccepted(Function(dynamic) callback) {
    _socket?.on('call-accepted', callback);
  }

  void onCallRejected(Function(dynamic) callback) {
    _socket?.on('call-rejected', callback);
  }

  void onVideoCallEnded(Function(dynamic) callback) {
    _socket?.on('video-call-ended', callback);
  }

  void onUserOffline(Function(dynamic) callback) {
    _socket?.on('user-offline', callback);
  }

  void onParticipantJoinedCall(Function(dynamic) callback) {
    _socket?.on('participant-joined-call', callback);
  }

  void onParticipantLeftCall(Function(dynamic) callback) {
    _socket?.on('participant-left-call', callback);
  }

  // Remove listeners
  void offIncomingVideoCall() {
    _socket?.off('incoming-video-call');
  }

  void offCallAccepted() {
    _socket?.off('call-accepted');
  }

  void offCallRejected() {
    _socket?.off('call-rejected');
  }

  void offVideoCallEnded() {
    _socket?.off('video-call-ended');
  }

  void offUserOffline() {
    _socket?.off('user-offline');
  }

  void offParticipantJoinedCall() {
    _socket?.off('participant-joined-call');
  }

  void offParticipantLeftCall() {
    _socket?.off('participant-left-call');
  }
}
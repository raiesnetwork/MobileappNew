import 'dart:async';
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:http/http.dart' as http;
import 'dart:convert';

class MeetingService {
  static const String baseUrl = 'https://meet.ixes.ai';
  static const String apiUrl = '$baseUrl/api';

  IO.Socket? _socket;
  IO.Socket? get socket => _socket;


  void connectSocket() {
    _socket = IO.io(
      baseUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setExtraHeaders({'path': '/socket.io'})
          .build(),
    );

    debugPrint('📡 Meeting socket configured');
  }

  /// Connect to socket server
  void connect() {
    _socket?.connect();
    debugPrint('🔌 Connecting to meeting socket...');
  }

  void disconnect() {
    _socket?.disconnect();
    debugPrint('🔌 Disconnected from meeting socket');
  }

  /// Dispose socket
  void dispose() {
    _socket?.dispose();
    debugPrint('🗑️ Meeting socket disposed');
  }

  Future<Map<String, dynamic>> getAccessToken({
    required String name,
    required String meetingId,
    required String userId,
    String? authToken,
  }) async {
    try {
      final queryParams = {
        'name': name,
        'meetingId': meetingId,
        'userId': userId,
      };

      final uri = Uri.parse('$apiUrl/get-token').replace(
        queryParameters: queryParams,
      );

      final headers = {
        'Content-Type': 'application/json',
        if (authToken != null) 'Authorization': 'Bearer $authToken',
      };

      debugPrint('🎫 Requesting access token for meeting: $meetingId');
      debugPrint('🔗 URL: $uri');

      final response = await http.get(uri, headers: headers);

      debugPrint('📡 Response status: ${response.statusCode}');
      debugPrint('📦 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        debugPrint('✅ Access token received');
        return result;
      } else {
        final result = json.decode(response.body);
        debugPrint('❌ Failed to get access token: ${result['message']}');
        return result;
      }
    } catch (e) {
      debugPrint('❌ Error getting access token: $e');
      return {
        'error': true,
        'message': 'Failed to get access token: $e',
      };
    }
  }


  Future<Map<String, dynamic>> requestToJoin({
    required String name,
    required String meetingId,
    required String userId,
    String? authToken,
  }) async {
    try {
      final headers = {
        'Content-Type': 'application/json',
        if (authToken != null) 'Authorization': 'Bearer $authToken',
      };

      final body = json.encode({
        'name': name,
        'meetingId': meetingId,
        'userId': userId,
      });

      debugPrint('📝 Requesting to join meeting: $meetingId');

      final response = await http.post(
        Uri.parse('$apiUrl/request-join'),
        headers: headers,
        body: body,
      );

      debugPrint('📡 Response status: ${response.statusCode}');
      debugPrint('📦 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        debugPrint('✅ Join request response received');
        return result;
      } else {
        final result = json.decode(response.body);
        debugPrint('❌ Join request failed: ${result['message']}');
        return result;
      }
    } catch (e) {
      debugPrint('❌ Error requesting to join: $e');
      return {
        'error': true,
        'message': 'Failed to request join: $e',
      };
    }
  }


  Future<Map<String, dynamic>> kickParticipant({
    required String roomId,
    required String identity,
    String? authToken,
  }) async {
    try {
      final headers = {
        'Content-Type': 'application/json',
        if (authToken != null) 'Authorization': 'Bearer $authToken',
      };

      final body = json.encode({
        'roomId': roomId,
        'identity': identity,
      });

      debugPrint('🚫 Kicking participant: $identity from room: $roomId');

      final response = await http.post(
        Uri.parse('$apiUrl/kick'),
        headers: headers,
        body: body,
      );

      debugPrint('📡 Response status: ${response.statusCode}');
      debugPrint('📦 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        debugPrint('✅ Participant kicked successfully');
        return result;
      } else {
        final result = json.decode(response.body);
        debugPrint('❌ Kick failed: ${result['message']}');
        return result;
      }
    } catch (e) {
      debugPrint('❌ Error kicking participant: $e');
      return {
        'error': true,
        'message': 'Failed to kick participant: $e',
      };
    }
  }
  Future<Map<String, dynamic>> createMeeting({
    required String meetingId,
    required String hostName,
    required String hostUserId,
    String? authToken,
  }) async {
    try {
      final headers = {
        'Content-Type': 'application/json',
        if (authToken != null) 'Authorization': 'Bearer $authToken',
      };

      final body = json.encode({
        'meetingId': meetingId,
        'hostName': hostName,
        'hostUserId': hostUserId,
      });

      debugPrint('🎬 Creating meeting: $meetingId');
      debugPrint('🔗 URL: $apiUrl/create-meeting');

      final response = await http.post(
        Uri.parse('$apiUrl/create-meeting'),
        headers: headers,
        body: body,
      );

      debugPrint('📡 Response status: ${response.statusCode}');
      debugPrint('📦 Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final result = json.decode(response.body);
        debugPrint('✅ Meeting created successfully');
        return result;
      } else {
        final result = json.decode(response.body);
        debugPrint('❌ Failed to create meeting: ${result['message']}');
        return result;
      }
    } catch (e) {
      debugPrint('❌ Error creating meeting: $e');
      return {
        'error': true,
        'message': 'Failed to create meeting: $e',
      };
    }
  }

  // ============================================================================
  // SOCKET EMIT METHODS
  // ============================================================================

  /// Join as user - registers user and joins personal room
  void joinAsUser(String userId) {
    _socket?.emit('join-user', userId);
    debugPrint('👤 Joined as user: $userId');
  }

  /// Join as meeting host
  void joinAsMeetingHost({
    required String meetingId,
    required String userId,
  }) {
    _socket?.emit('join-meeting-host', [meetingId, userId]);
    debugPrint('🎯 Joined as meeting host: $meetingId');
  }

  /// Send join request
  void sendJoinRequest({
    required String name,
    required String meetingId,
    required String userId,
  }) {
    final data = {
      'name': name,
      'meetingId': meetingId,
      'userId': userId,
    };

    _socket?.emit('join-request', data);
    debugPrint('📤 Join request sent: $data');
  }

  /// Approve participant (host only)
  void approveParticipant(String requestId) {
    _socket?.emit('approve-participant', requestId);
    debugPrint('✅ Approved participant: $requestId');
  }

  /// Reject participant (host only)
  void rejectParticipant(String requestId) {
    _socket?.emit('reject-participant', requestId);
    debugPrint('❌ Rejected participant: $requestId');
  }

  /// Cancel join request
  void cancelJoinRequest({
    required String meetingId,
    required String userId,
  }) {
    final data = {
      'meetingId': meetingId,
      'userId': userId,
    };

    _socket?.emit('cancel-join-request', data);
    debugPrint('🚫 Cancelled join request: $data');
  }


  /// Join chat room
  void joinChat({
    required String meetingId,
    required String userId,
    required String username,
  }) {
    final data = {
      'meetingId': meetingId,
      'userId': userId,
      'username': username,
    };

    _socket?.emit('join-chat', data);
    debugPrint('💬 Joined chat: $data');
  }

  /// Send chat message
  void sendMessage({
    required String meetingId,
    required String userId,
    required String username,
    required String message,
  }) {
    final data = {
      'meetingId': meetingId,
      'userId': userId,
      'username': username,
      'message': message,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    _socket?.emit('send-message', data);
    debugPrint('💬 Message sent: $message');
  }

  /// Get chat history
  void getChatHistory(String meetingId) {
    _socket?.emit('get-chat-history', meetingId);
    debugPrint('📜 Requesting chat history for: $meetingId');
  }

  void onConnect(Function() callback) {
    _socket?.onConnect((_) {
      debugPrint('✅ Meeting socket connected');
      callback();
    });
  }

  void onDisconnect(Function() callback) {
    _socket?.onDisconnect((_) {
      debugPrint('❌ Meeting socket disconnected');
      callback();
    });
  }

  void onPendingRequestsUpdate(Function(dynamic) callback) {
    _socket?.on('pending-requests-update', callback);
  }

  void onNewJoinRequest(Function(dynamic) callback) {
    _socket?.on('new-join-request', callback);
  }

  void onJoinApproved(Function(dynamic) callback) {
    _socket?.on('join-approved', callback);
  }

  void onJoinRejected(Function(dynamic) callback) {
    _socket?.on('join-rejected', callback);
  }

  void onParticipantApproved(Function(dynamic) callback) {
    _socket?.on('participant-approved', callback);
  }

  void onParticipantRejected(Function(dynamic) callback) {
    _socket?.on('participant-rejected', callback);
  }

  void onParticipantCancelled(Function(dynamic) callback) {
    _socket?.on('participant-cancelled', callback);
  }

  void onUserJoinedChat(Function(dynamic) callback) {
    _socket?.on('user-joined', callback);
  }

  void onNewMessage(Function(dynamic) callback) {
    _socket?.on('new-message', callback);
  }

  void onChatHistory(Function(dynamic) callback) {
    _socket?.on('chat-history', callback);
  }

  // ============================================================================
  // REMOVE LISTENERS
  // ============================================================================

  void offPendingRequestsUpdate() {
    _socket?.off('pending-requests-update');
  }

  void offNewJoinRequest() {
    _socket?.off('new-join-request');
  }

  void offJoinApproved() {
    _socket?.off('join-approved');
  }

  void offJoinRejected() {
    _socket?.off('join-rejected');
  }

  void offParticipantApproved() {
    _socket?.off('participant-approved');
  }

  void offParticipantRejected() {
    _socket?.off('participant-rejected');
  }

  void offParticipantCancelled() {
    _socket?.off('participant-cancelled');
  }

  void offUserJoinedChat() {
    _socket?.off('user-joined');
  }

  void offNewMessage() {
    _socket?.off('new-message');
  }

  void offChatHistory() {
    _socket?.off('chat-history');
  }
}
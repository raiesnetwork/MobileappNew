import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../services/api_service.dart'; // ✅ import ApiService

class MeetingService {
  static const String baseUrl = 'https://meet.ixes.ai';

  IO.Socket? _socket;
  IO.Socket? get socket => _socket;

  // ════════════════════════════════════════════════════════════════════════
  //  SOCKET
  // ════════════════════════════════════════════════════════════════════════
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

  void connect() {
    _socket?.connect();
    debugPrint('🔌 Connecting to meeting socket...');
  }

  void disconnect() {
    _socket?.disconnect();
    debugPrint('🔌 Disconnected from meeting socket');
  }

  void dispose() {
    _socket?.dispose();
    debugPrint('🗑️ Meeting socket disposed');
  }

  // ════════════════════════════════════════════════════════════════════════
  //  GET ACCESS TOKEN
  // ════════════════════════════════════════════════════════════════════════
  Future<Map<String, dynamic>> getAccessToken({
    required String name,
    required String meetingId,
    required String userId,
    String? authToken,
  }) async {
    try {
      debugPrint('🎫 Requesting access token for meeting: $meetingId');

      final response = await ApiService.getFromUrl(
        '$baseUrl/api/get-token?name=$name&meetingId=$meetingId&userId=$userId',
        authToken: authToken,
      );

      ApiService.checkResponse(response);
      final result = json.decode(response.body);
      debugPrint('📡 getAccessToken status: ${response.statusCode}');
      return result;
    } catch (e) {
      debugPrint('❌ Error getting access token: $e');
      return {'error': true, 'message': 'Failed to get access token: $e'};
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  //  REQUEST TO JOIN
  // ════════════════════════════════════════════════════════════════════════
  Future<Map<String, dynamic>> requestToJoin({
    required String name,
    required String meetingId,
    required String userId,
    String? authToken,
  }) async {
    try {
      debugPrint('📝 Requesting to join meeting: $meetingId');

      final response = await ApiService.postToUrl(
        '$baseUrl/api/request-join',
        {'name': name, 'meetingId': meetingId, 'userId': userId},
        authToken: authToken,
      );

      ApiService.checkResponse(response);
      final result = json.decode(response.body);
      debugPrint('📡 requestToJoin status: ${response.statusCode}');
      return result;
    } catch (e) {
      debugPrint('❌ Error requesting to join: $e');
      return {'error': true, 'message': 'Failed to request join: $e'};
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  //  KICK PARTICIPANT
  // ════════════════════════════════════════════════════════════════════════
  Future<Map<String, dynamic>> kickParticipant({
    required String roomId,
    required String identity,
    String? authToken,
  }) async {
    try {
      debugPrint('🚫 Kicking participant: $identity from room: $roomId');

      final response = await ApiService.postToUrl(
        '$baseUrl/api/kick',
        {'roomId': roomId, 'identity': identity},
        authToken: authToken,
      );

      ApiService.checkResponse(response);
      final result = json.decode(response.body);
      debugPrint('📡 kickParticipant status: ${response.statusCode}');
      return result;
    } catch (e) {
      debugPrint('❌ Error kicking participant: $e');
      return {'error': true, 'message': 'Failed to kick participant: $e'};
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  //  CREATE MEETING
  // ════════════════════════════════════════════════════════════════════════
  Future<Map<String, dynamic>> createMeeting({
    required String meetingId,
    required String hostName,
    required String hostUserId,
    String? authToken,
  }) async {
    try {
      debugPrint('🎬 Creating meeting: $meetingId');

      final response = await ApiService.postToUrl(
        '$baseUrl/api/create-meeting',
        {
          'meetingId': meetingId,
          'hostName': hostName,
          'hostUserId': hostUserId,
        },
        authToken: authToken,
      );

      ApiService.checkResponse(response);
      final result = json.decode(response.body);
      debugPrint('📡 createMeeting status: ${response.statusCode}');
      return result;
    } catch (e) {
      debugPrint('❌ Error creating meeting: $e');
      return {'error': true, 'message': 'Failed to create meeting: $e'};
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  //  SOCKET EMIT METHODS
  // ════════════════════════════════════════════════════════════════════════
  void joinAsUser(String userId) {
    _socket?.emit('join-user', userId);
    debugPrint('👤 Joined as user: $userId');
  }

  void joinAsMeetingHost({required String meetingId, required String userId}) {
    _socket?.emit('join-meeting-host', [meetingId, userId]);
    debugPrint('🎯 Joined as meeting host: $meetingId');
  }

  void sendJoinRequest({
    required String name,
    required String meetingId,
    required String userId,
  }) {
    _socket?.emit('join-request', {
      'name': name,
      'meetingId': meetingId,
      'userId': userId,
    });
    debugPrint('📤 Join request sent');
  }

  void approveParticipant(String requestId) {
    _socket?.emit('approve-participant', requestId);
    debugPrint('✅ Approved participant: $requestId');
  }

  void rejectParticipant(String requestId) {
    _socket?.emit('reject-participant', requestId);
    debugPrint('❌ Rejected participant: $requestId');
  }

  void cancelJoinRequest({required String meetingId, required String userId}) {
    _socket?.emit('cancel-join-request', {
      'meetingId': meetingId,
      'userId': userId,
    });
    debugPrint('🚫 Cancelled join request');
  }

  void joinChat({
    required String meetingId,
    required String userId,
    required String username,
  }) {
    _socket?.emit('join-chat', {
      'meetingId': meetingId,
      'userId': userId,
      'username': username,
    });
    debugPrint('💬 Joined chat');
  }

  void sendMessage({
    required String meetingId,
    required String userId,
    required String username,
    required String message,
  }) {
    _socket?.emit('send-message', {
      'meetingId': meetingId,
      'userId': userId,
      'username': username,
      'message': message,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    debugPrint('💬 Message sent: $message');
  }

  void getChatHistory(String meetingId) {
    _socket?.emit('get-chat-history', meetingId);
    debugPrint('📜 Requesting chat history for: $meetingId');
  }

  // ════════════════════════════════════════════════════════════════════════
  //  SOCKET LISTENERS
  // ════════════════════════════════════════════════════════════════════════
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

  void onPendingRequestsUpdate(Function(dynamic) callback) =>
      _socket?.on('pending-requests-update', callback);

  void onNewJoinRequest(Function(dynamic) callback) =>
      _socket?.on('new-join-request', callback);

  void onJoinApproved(Function(dynamic) callback) =>
      _socket?.on('join-approved', callback);

  void onJoinRejected(Function(dynamic) callback) =>
      _socket?.on('join-rejected', callback);

  void onParticipantApproved(Function(dynamic) callback) =>
      _socket?.on('participant-approved', callback);

  void onParticipantRejected(Function(dynamic) callback) =>
      _socket?.on('participant-rejected', callback);

  void onParticipantCancelled(Function(dynamic) callback) =>
      _socket?.on('participant-cancelled', callback);

  void onUserJoinedChat(Function(dynamic) callback) =>
      _socket?.on('user-joined', callback);

  void onNewMessage(Function(dynamic) callback) =>
      _socket?.on('new-message', callback);

  void onChatHistory(Function(dynamic) callback) =>
      _socket?.on('chat-history', callback);

  // ════════════════════════════════════════════════════════════════════════
  //  REMOVE LISTENERS
  // ════════════════════════════════════════════════════════════════════════
  void offPendingRequestsUpdate() => _socket?.off('pending-requests-update');
  void offNewJoinRequest()        => _socket?.off('new-join-request');
  void offJoinApproved()          => _socket?.off('join-approved');
  void offJoinRejected()          => _socket?.off('join-rejected');
  void offParticipantApproved()   => _socket?.off('participant-approved');
  void offParticipantRejected()   => _socket?.off('participant-rejected');
  void offParticipantCancelled()  => _socket?.off('participant-cancelled');
  void offUserJoinedChat()        => _socket?.off('user-joined');
  void offNewMessage()            => _socket?.off('new-message');
  void offChatHistory()           => _socket?.off('chat-history');
}
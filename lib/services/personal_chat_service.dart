import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

import '../constants/apiConstants.dart';
import 'api_service.dart';
import 'socket_service.dart';

class PersonalChatService {
  final SocketService _socketService = SocketService();

  // ════════════════════════════════════════════════════════════════════════
  //  HELPERS
  // ════════════════════════════════════════════════════════════════════════

  String _mimeTypeForFile(String filePath) {
    final ext = p.extension(filePath).toLowerCase();
    const map = {
      '.jpg':  'image/jpeg',
      '.jpeg': 'image/jpeg',
      '.png':  'image/png',
      '.gif':  'image/gif',
      '.webp': 'image/webp',
      '.heic': 'image/heic',
      '.bmp':  'image/bmp',
      '.pdf':  'application/pdf',
      '.mp4':  'video/mp4',
      '.mov':  'video/quicktime',
      '.m4a':  'audio/mp4',
      '.aac':  'audio/aac',
      '.mp3':  'audio/mpeg',
      '.wav':  'audio/wav',
      '.ogg':  'audio/ogg',
    };
    return map[ext] ?? 'application/octet-stream';
  }

  Map<String, dynamic> _safeJsonDecode(http.Response response) {
    try {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      return {
        'error': true,
        'message': 'Server error (${response.statusCode})',
        'data': null,
      };
    }
  }

  Future<String?> _getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null || token.isEmpty) {
      print('❗ Auth token is missing or empty');
      return null;
    }
    return token;
  }

  // ════════════════════════════════════════════════════════════════════════
  //  SOCKET
  // ════════════════════════════════════════════════════════════════════════

  Future<bool> initializeSocket() async {
    return await _socketService.connect();
  }

  SocketService get socketService => _socketService;

  void joinConversation(String userId, String receiverId) {
    _socketService.joinConversation(userId, receiverId);
  }

  void leaveConversation(String userId, String receiverId) {
    _socketService.leaveConversation(userId, receiverId);
  }

  Future<void> disconnectSocket() async {
    await _socketService.disconnect();
  }

  void dispose() {
    _socketService.dispose();
  }

  // ════════════════════════════════════════════════════════════════════════
  //  GET PERSONAL CHATS
  // ════════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> getPersonalChats() async {
    try {
      final response = await ApiService.get('/api/chat/friends');
      ApiService.checkResponse(response);

      print('📡 Response Status: ${response.statusCode}');
      print('📦 Response Body: ${response.body}');

      final decoded = _safeJsonDecode(response);
      if (response.statusCode == 200) {
        return {
          'error': decoded['error'] ?? false,
          'message': decoded['message'] ?? 'Chats fetched successfully',
          'data': decoded['data'] ?? [],
        };
      } else {
        return {'error': true, 'message': decoded['message'] ?? 'Failed to fetch chats', 'data': []};
      }
    } catch (e) {
      print('💥 Exception occurred: $e');
      return {'error': true, 'message': 'Error fetching chats: ${e.toString()}', 'data': []};
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  //  SEND TEXT MESSAGE
  // ════════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> sendMessage({
    required String receiverId,
    required String text,
    bool readBy = false,
    String? image,
    String? replyTo,
  }) async {
    try {
      final requestBody = <String, dynamic>{
        'receiverId': receiverId,
        'text': text,
        'readBy': readBy,
      };
      if (image != null && image.isNotEmpty) requestBody['image'] = image;
      if (replyTo != null && replyTo.isNotEmpty) requestBody['replyTo'] = replyTo;

      print('📦 Request Body: ${jsonEncode(requestBody)}');

      final response = await ApiService.post('/api/chat/message', requestBody);
      ApiService.checkResponse(response);

      print('📡 Response Status: ${response.statusCode}');
      print('📦 Response Body: ${response.body}');

      final decoded = _safeJsonDecode(response);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'error': decoded['error'] ?? false,
          'message': decoded['message'] ?? 'Message sent successfully',
          'data': decoded,
        };
      } else {
        return {'error': true, 'message': decoded['message'] ?? 'Failed to send message', 'data': null};
      }
    } catch (e) {
      print('💥 Exception occurred while sending message: $e');
      return {'error': true, 'message': 'Error sending message: ${e.toString()}', 'data': null};
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  //  GET MESSAGES
  // ════════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> getMessages({required String userId}) async {
    try {
      final response = await ApiService.get('/api/chat/message/$userId');
      ApiService.checkResponse(response);

      print('📡 Response Status: ${response.statusCode}');
      print('📦 Response Body: ${response.body}');

      final decoded = _safeJsonDecode(response);
      if (response.statusCode == 200) {
        return {
          'error': decoded['error'] ?? false,
          'message': 'Messages fetched successfully',
          'data': decoded['data'],
        };
      } else {
        return {'error': true, 'message': decoded['message'] ?? 'Failed to fetch messages', 'data': null};
      }
    } catch (e) {
      print('💥 Exception occurred while fetching messages: $e');
      return {'error': true, 'message': 'Error fetching messages: ${e.toString()}', 'data': null};
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  //  SEND FILE MESSAGE
  // ════════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> sendFileMessage({
    required File file,
    required String receiverId,
    bool readBy = false,
    String? replyTo,
    bool useSocket = false,
  }) async {
    print('📤 Sending file message via HTTP...');
    return await _sendFileMessageHttp(
      file: file,
      receiverId: receiverId,
      readBy: readBy,
      replyTo: replyTo,
    );
  }
  Future<Map<String, dynamic>> _sendFileMessageHttp({
    required File file,
    required String receiverId,
    bool readBy = false,
    String? replyTo,
  }) async {
    try {
      final fields = {
        'receiverId': receiverId,
        'readBy': readBy.toString(),
        if (replyTo != null && replyTo.isNotEmpty) 'replyTo': replyTo,
      };

      final files = [
        await http.MultipartFile.fromPath(
          'file',
          file.path,
          filename: p.basename(file.path),
          contentType: MediaType.parse(_mimeTypeForFile(file.path)),
        ),
      ];

      final response = await ApiService.multipart(
        endpoint: '/api/chat/filemessage',
        method: 'POST',
        fields: fields,
        files: files,
      );
      ApiService.checkResponse(response);

      final decoded = _safeJsonDecode(response);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'error': decoded['error'] ?? false,
          'message': decoded['message'] ?? 'File message sent successfully',
          'data': decoded,
        };
      } else {
        return {
          'error': true,
          'message': decoded['message'] ?? 'Failed to send file message',
          'data': null,
        };
      }
    } catch (e) {
      return {'error': true, 'message': 'Error sending file message: $e', 'data': null};
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  //  SEND VOICE MESSAGE
  // ════════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> sendVoiceMessage({
    required File audioFile,
    required String receiverId,
    bool readBy = false,
    String? image,
    String? replyTo,
    int? audioDurationMs,
    bool useSocket = false,
  }) async {
    print('📤 Sending voice message via HTTP...');
    return await _sendVoiceMessageHttp(
      audioFile: audioFile,
      receiverId: receiverId,
      readBy: readBy,
      image: image,
      replyTo: replyTo,
      audioDurationMs: audioDurationMs,
    );
  }

  Future<Map<String, dynamic>> _sendVoiceMessageHttp({
    required File audioFile,
    required String receiverId,
    bool readBy = false,
    String? image,
    String? replyTo,
    int? audioDurationMs,
  }) async {
    try {
      final fields = {
        'receiverId': receiverId,
        'readBy': readBy.toString(),
        if (image != null && image.isNotEmpty) 'image': image,
        if (replyTo != null && replyTo.isNotEmpty) 'replyTo': replyTo,
        if (audioDurationMs != null) 'audioDurationMs': audioDurationMs.toString(),
      };

      final files = [
        await http.MultipartFile.fromPath(
          'audio',
          audioFile.path,
          filename: p.basename(audioFile.path),
          contentType: MediaType.parse(_mimeTypeForFile(audioFile.path)),
        ),
      ];

      final response = await ApiService.multipart(
        endpoint: '/api/chat/voicemessage',
        method: 'POST',
        fields: fields,
        files: files,
      );
      ApiService.checkResponse(response);

      final decoded = _safeJsonDecode(response);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'error': decoded['error'] ?? false,
          'message': decoded['message'] ?? 'Voice message sent successfully',
          'data': decoded,
        };
      } else {
        return {
          'error': true,
          'message': decoded['message'] ?? 'Failed to send voice message',
          'data': null,
        };
      }
    } catch (e) {
      return {'error': true, 'message': 'Error sending voice message: $e', 'data': null};
    }
  }
  // ════════════════════════════════════════════════════════════════════════
//  CALL HISTORY
// ════════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> getCallHistory({
    int pageNo = 1,
    int limit = 20,
    String? communityId,
  }) async {
    try {
      String endpoint = '/api/chat/call-history?pageNo=$pageNo&limit=$limit';
      if (communityId != null && communityId.isNotEmpty) {
        endpoint += '&communityId=$communityId';
      }

      print('📞 [CALL HISTORY] GET $endpoint');

      final response = await ApiService.get(endpoint);
      ApiService.checkResponse(response);

      print('📡 [CALL HISTORY] Status: ${response.statusCode}');
      print('📦 [CALL HISTORY] Body: ${response.body}');

      final decoded = _safeJsonDecode(response);
      if (response.statusCode == 200) {
        print('✅ [CALL HISTORY] Fetched ${(decoded['data'] as List?)?.length ?? 0} records');
        return {
          'error': false,
          'data': decoded['data'] ?? [],
          'pagination': decoded['pagination'] ?? {},
        };
      }
      print('❌ [CALL HISTORY] Failed: ${decoded['message']}');
      return {'error': true, 'message': decoded['message'] ?? 'Failed', 'data': []};
    } catch (e) {
      print('💥 [CALL HISTORY] Exception: $e');
      return {'error': true, 'message': 'Error: $e', 'data': []};
    }
  }

  Future<Map<String, dynamic>> saveCallHistory({
    required String receiverId,
    required String type,
    required String status,
    String? callerId,
    int? duration,
    String? communityId,
  }) async {
    try {
      final body = <String, dynamic>{
        'receiverId': receiverId,
        'type': type,
        'status': status,
        if (callerId != null) 'callerId': callerId,
        if (duration != null) 'duration': duration,
        if (communityId != null) 'communityId': communityId,
      };

      print('📞 [SAVE CALL] POST /api/chat/call-history');
      print('📦 [SAVE CALL] Body: $body');

      final response = await ApiService.post('/api/chat/call-history', body);
      ApiService.checkResponse(response);

      print('📡 [SAVE CALL] Status: ${response.statusCode}');
      print('📦 [SAVE CALL] Response: ${response.body}');

      final decoded = _safeJsonDecode(response);
      if (response.statusCode == 201 || response.statusCode == 200) {
        print('✅ [SAVE CALL] Saved successfully');
        return {'error': false, 'data': decoded['data']};
      }
      print('❌ [SAVE CALL] Failed: ${decoded['message']}');
      return {'error': true, 'message': decoded['message'] ?? 'Failed'};
    } catch (e) {
      print('💥 [SAVE CALL] Exception: $e');
      return {'error': true, 'message': 'Error: $e'};
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  //  UPDATE READ STATUS
  // ════════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> updateReadStatus({
    required String senderId,
    required String receiverId,
    bool useSocket = true,
  }) async {
    if (useSocket && _socketService.isConnected) {
      print('👁️ Updating read status via socket...');
      final socketResult = await _socketService.updateReadStatus(
        senderId: senderId,
        receiverId: receiverId,
      );
      if (socketResult['error'] == false) return socketResult;
      print('⚠️ Socket read status failed → falling back to HTTP');
    } else {
      print('👁️ Updating read status via HTTP...');
    }
    return await _updateReadStatusHttp(senderId: senderId, receiverId: receiverId);
  }

  Future<Map<String, dynamic>> _updateReadStatusHttp({
    required String senderId,
    required String receiverId,
  }) async {
    try {
      final response = await ApiService.post(
        '/api/chat/updatereadBy',
        {'senderId': senderId, 'receiverId': receiverId},
      );
      ApiService.checkResponse(response);

      print('📡 Response Status: ${response.statusCode}');
      print('📦 Response Body: ${response.body}');

      final decoded = _safeJsonDecode(response);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'error': decoded['error'] ?? false,
          'message': decoded['message'] ?? 'Read status updated successfully',
          'data': decoded['data'],
        };
      } else {
        return {'error': true, 'message': decoded['message'] ?? 'Failed to update read status', 'data': null};
      }
    } catch (e) {
      print('💥 Exception occurred while updating read status: $e');
      return {'error': true, 'message': 'Error updating read status: ${e.toString()}', 'data': null};
    }
  }

  Future<Map<String, dynamic>> deleteMessage({
    required String messageId,
    required String receiverId,
    bool useSocket = true,
  }) async {
    if (_socketService.isConnected) {
      print('🗑️ Deleting via socket');
      _socketService.socket!.emit('deleteMessage', {
        'messageId': messageId,
        'receiverId': receiverId,
      });
      return {'error': false, 'message': 'Message deleted via socket'};
    }
    return {'error': true, 'message': 'Socket not connected'};
  }

  Future<Map<String, dynamic>> editMessage({
    required String messageId,
    required String newText,
    required String receiverId,
    bool useSocket = true,
  }) async {
    if (_socketService.isConnected) {
      print('✏️ Editing via socket');
      _socketService.socket!.emit('editMessage', {
        'messageId': messageId,
        'newText': newText,
        'receiverId': receiverId,
      });
      return {'error': false, 'message': 'Message edited via socket'};
    }
    return {'error': true, 'message': 'Socket not connected'};
  }}
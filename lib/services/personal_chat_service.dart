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
import 'socket_service.dart';

class PersonalChatService {
  final SocketService _socketService = SocketService();

  // ════════════════════════════════════════════════════════════════════════
  //  HELPERS
  // ════════════════════════════════════════════════════════════════════════

  /// Returns the correct MIME type string for a given file path
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

  /// Safely decodes a JSON response — never throws on HTML error pages
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
      final token = await _getAuthToken();
      if (token == null) {
        return {'error': true, 'message': 'Authentication token is missing', 'data': []};
      }

      final uri = Uri.parse('${apiBaseUrl}api/chat/friends');
      print('🔍 Fetching personal chats from: $uri');

      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      );

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
      final token = await _getAuthToken();
      if (token == null) {
        return {'error': true, 'message': 'Authentication token is missing', 'data': null};
      }

      final uri = Uri.parse('${apiBaseUrl}api/chat/message');
      print('📤 Sending message to: $uri');

      final requestBody = <String, dynamic>{
        'receiverId': receiverId,
        'text': text,
        'readBy': readBy,
      };
      if (image != null && image.isNotEmpty) requestBody['image'] = image;
      if (replyTo != null && replyTo.isNotEmpty) requestBody['replyTo'] = replyTo;

      print('📦 Request Body: ${jsonEncode(requestBody)}');

      final response = await http.post(
        uri,
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

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
      final token = await _getAuthToken();
      if (token == null) {
        return {'error': true, 'message': 'Authentication token is missing', 'data': null};
      }

      final uri = Uri.parse('${apiBaseUrl}api/chat/message/$userId');
      print('📤 Fetching messages from: $uri');

      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      );

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
  //  SEND FILE MESSAGE  ← FIXED: correct MIME type + safe JSON decode
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
      final token = await _getAuthToken();
      if (token == null) {
        return {'error': true, 'message': 'Authentication token is missing', 'data': null};
      }

      final uri = Uri.parse('${apiBaseUrl}api/chat/filemessage');
      print('📤 Sending file message to: $uri');

      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer $token';

      request.fields['receiverId'] = receiverId;
      request.fields['readBy'] = readBy.toString();
      if (replyTo != null && replyTo.isNotEmpty) {
        request.fields['replyTo'] = replyTo;
      }

      // ✅ FIX: explicit MIME type so server knows it's an image, not binary blob
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          file.path,
          filename: p.basename(file.path),
          contentType: MediaType.parse(_mimeTypeForFile(file.path)),
        ),
      );

      print('📦 Request Fields: ${request.fields}');
      print('📦 File: ${file.path}  (${_mimeTypeForFile(file.path)})');

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      print('📡 Response Status: ${response.statusCode}');
      print('📦 Response Body: ${response.body}');

      // ✅ FIX: safe decode — won't crash on HTML 500 pages
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
          'message': decoded['message'] ?? 'Failed to send file message (${response.statusCode})',
          'data': null,
        };
      }
    } catch (e) {
      print('💥 Exception occurred while sending file message: $e');
      return {'error': true, 'message': 'Error sending file message: ${e.toString()}', 'data': null};
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  //  SEND VOICE MESSAGE  ← FIXED: correct MIME type + safe JSON decode
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
      final token = await _getAuthToken();
      if (token == null) {
        return {'error': true, 'message': 'Authentication token is missing', 'data': null};
      }

      final uri = Uri.parse('${apiBaseUrl}api/chat/voicemessage');
      print('📤 Sending voice message to: $uri');

      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer $token';

      request.fields['receiverId'] = receiverId;
      request.fields['readBy'] = readBy.toString();
      if (image != null && image.isNotEmpty) request.fields['image'] = image;
      if (replyTo != null && replyTo.isNotEmpty) request.fields['replyTo'] = replyTo;
      if (audioDurationMs != null) {
        request.fields['audioDurationMs'] = audioDurationMs.toString();
        print('📦 Including audio duration: $audioDurationMs ms');
      }

      // ✅ FIX: explicit MIME type for audio
      request.files.add(
        await http.MultipartFile.fromPath(
          'audio',
          audioFile.path,
          filename: p.basename(audioFile.path),
          contentType: MediaType.parse(_mimeTypeForFile(audioFile.path)),
        ),
      );

      print('📦 Request Fields: ${request.fields}');
      print('📦 Audio File: ${audioFile.path}  (${_mimeTypeForFile(audioFile.path)})');

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      print('📡 Response Status: ${response.statusCode}');
      print('📦 Response Body: ${response.body}');

      // ✅ FIX: safe decode
      final decoded = _safeJsonDecode(response);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final serverDuration = decoded['message']?['audioDurationMs'];
        if (serverDuration != null) {
          print('✅ Server confirmed duration: $serverDuration ms');
        } else {
          print('⚠️ Duration not found in server response — will use local value');
        }

        return {
          'error': decoded['error'] ?? false,
          'message': decoded['message'] ?? 'Voice message sent successfully',
          'data': decoded,
        };
      } else {
        return {
          'error': true,
          'message': decoded['message'] ?? 'Failed to send voice message (${response.statusCode})',
          'data': null,
        };
      }
    } catch (e) {
      print('💥 Exception occurred while sending voice message: $e');
      return {'error': true, 'message': 'Error sending voice message: ${e.toString()}', 'data': null};
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
      final token = await _getAuthToken();
      if (token == null) {
        return {'error': true, 'message': 'Authentication token is missing', 'data': null};
      }

      final uri = Uri.parse('${apiBaseUrl}api/chat/updatereadBy');
      print('📤 Updating read status to: $uri');

      final response = await http.post(
        uri,
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode({'senderId': senderId, 'receiverId': receiverId}),
      );

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

  // ════════════════════════════════════════════════════════════════════════
  //  DELETE MESSAGE
  // ════════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> deleteMessage({
    required String messageId,
    required String receiverId,
    bool useSocket = true,
  }) async {
    if (useSocket && _socketService.isConnected) {
      print('🗑️ Attempting delete via socket...');
      final result = await _socketService.deleteMessage(
        messageId: messageId,
        receiverId: receiverId,
      );
      if (result['error'] == false) return result;
      print('⚠️ Socket delete failed → falling back to HTTP');
    }
    return await _deleteMessageViaHttp(messageId: messageId, receiverId: receiverId);
  }

  Future<Map<String, dynamic>> _deleteMessageViaHttp({
    required String messageId,
    required String receiverId,
  }) async {
    try {
      final token = await _getAuthToken();
      if (token == null) return {'error': true, 'message': 'Authentication token missing'};

      final response = await http.post(
        Uri.parse('${apiBaseUrl}api/chat/deleteMessage'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode({'messageId': messageId, 'receiverId': receiverId}),
      );

      final body = _safeJsonDecode(response);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'error': false, 'message': body['message'] ?? 'Message deleted successfully', 'data': body['data']};
      } else {
        return {'error': true, 'message': body['message'] ?? 'Failed to delete message'};
      }
    } catch (e) {
      print('💥 HTTP delete exception: $e');
      return {'error': true, 'message': 'Network error while deleting message'};
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  //  EDIT MESSAGE
  // ════════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> editMessage({
    required String messageId,
    required String newText,
    required String receiverId,
    bool useSocket = true,
  }) async {
    if (useSocket && _socketService.isConnected) {
      print('✏️ Attempting edit via socket...');
      final result = await _socketService.editMessage(
        messageId: messageId,
        newText: newText,
        receiverId: receiverId,
      );
      if (result['error'] == false) return result;
      print('⚠️ Socket edit failed → falling back to HTTP');
    }
    return await _editMessageViaHttp(messageId: messageId, newText: newText, receiverId: receiverId);
  }

  Future<Map<String, dynamic>> _editMessageViaHttp({
    required String messageId,
    required String newText,
    required String receiverId,
  }) async {
    try {
      final token = await _getAuthToken();
      if (token == null) return {'error': true, 'message': 'Authentication token missing'};

      final response = await http.post(
        Uri.parse('${apiBaseUrl}api/chat/editMessage'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode({'messageId': messageId, 'newText': newText, 'receiverId': receiverId}),
      );

      final body = _safeJsonDecode(response);
      if (response.statusCode == 200) {
        return body;
      } else {
        return {'error': true, 'message': body['message'] ?? 'Failed to edit message (${response.statusCode})'};
      }
    } catch (e) {
      print('💥 HTTP edit exception: $e');
      return {'error': true, 'message': 'Network error while editing message'};
    }
  }
}
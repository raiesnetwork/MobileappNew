import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/apiConstants.dart';
import 'socket_service.dart';

class PersonalChatService {
  final SocketService _socketService = SocketService();

  /// Initialize socket connection
  Future<bool> initializeSocket() async {
    return await _socketService.connect();
  }

  /// Get socket service instance
  SocketService get socketService => _socketService;

  Future<Map<String, dynamic>> getPersonalChats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null || token.isEmpty) {
        print('❗ Auth token is missing.');
        return {
          'error': true,
          'message': 'Authentication token is missing',
          'data': []
        };
      }

      final uri = Uri.parse('${apiBaseUrl}api/chat/friends');
      print('🔍 Fetching personal chats from: $uri');

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('📡 Response Status: ${response.statusCode}');
      print('📦 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return {
          'error': decoded['error'] ?? false,
          'message': decoded['message'] ?? 'Chats fetched successfully',
          'data': decoded['data'] ?? []
        };
      } else {
        final decoded = jsonDecode(response.body);
        print('⚠️ Error from API: ${decoded['message']}');
        return {
          'error': true,
          'message': decoded['message'] ?? 'Failed to fetch chats',
          'data': []
        };
      }
    } catch (e) {
      print('💥 Exception occurred: $e');
      return {
        'error': true,
        'message': 'Error fetching chats: ${e.toString()}',
        'data': []
      };
    }
  }

  /// Send message via socket (preferred) or HTTP fallback

  Future<Map<String, dynamic>> sendMessage({
    required String receiverId,
    required String text,
    bool readBy = false,
    String? image,
    String? replayTo,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null || token.isEmpty) {
        print('❗ Auth token is missing.');
        return {
          'error': true,
          'message': 'Authentication token is missing',
          'data': null
        };
      }

      final uri = Uri.parse('${apiBaseUrl}api/chat/message');
      print('📤 Sending message to: $uri');

      final requestBody = {
        'receiverId': receiverId,
        'text': text,
        'readBy': readBy,
      };

      if (image != null && image.isNotEmpty) {
        requestBody['image'] = image;
      }
      if (replayTo != null && replayTo.isNotEmpty) {
        requestBody['replayTo'] = replayTo;
      }

      print('📦 Request Body: ${jsonEncode(requestBody)}');

      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      print('📡 Response Status: ${response.statusCode}');
      print('📦 Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body);
        return {
          'error': decoded['error'] ?? false,
          'message': decoded['message'] ?? 'Message sent successfully',
          'data': decoded
        };
      } else {
        final decoded = jsonDecode(response.body);
        print('⚠️ Error from API: ${decoded['message']}');
        return {
          'error': true,
          'message': decoded['message'] ?? 'Failed to send message',
          'data': null
        };
      }
    } catch (e) {
      print('💥 Exception occurred while sending message: $e');
      return {
        'error': true,
        'message': 'Error sending message: ${e.toString()}',
        'data': null
      };
    }
  }

  Future<Map<String, dynamic>> getMessages({
    required String userId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null || token.isEmpty) {
        print('❗ Auth token is missing.');
        return {
          'error': true,
          'message': 'Authentication token is missing',
          'data': null
        };
      }

      final uri = Uri.parse('${apiBaseUrl}api/chat/message/$userId');
      print('📤 Fetching messages from: $uri');

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('📡 Response Status: ${response.statusCode}');
      print('📦 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return {
          'error': decoded['error'] ?? false,
          'message': 'Messages fetched successfully',
          'data': decoded['data']
        };
      } else {
        final decoded = jsonDecode(response.body);
        print('⚠️ Error from API: ${decoded['message']}');
        return {
          'error': true,
          'message': decoded['message'] ?? 'Failed to fetch messages',
          'data': null
        };
      }
    } catch (e) {
      print('💥 Exception occurred while fetching messages: $e');
      return {
        'error': true,
        'message': 'Error fetching messages: ${e.toString()}',
        'data': null
      };
    }
  }

  /// Send voice message - ALWAYS use HTTP since socket not implemented
  Future<Map<String, dynamic>> sendVoiceMessage({
    required File audioFile,
    required String receiverId,
    bool readBy = false,
    String? image,
    bool useSocket = false, // Force HTTP for voice messages
  }) async {
    print('📤 Sending voice message via HTTP...');
    return await _sendVoiceMessageHttp(
      audioFile: audioFile,
      receiverId: receiverId,
      readBy: readBy,
      image: image,
    );
  }

  /// HTTP implementation for voice messages
  Future<Map<String, dynamic>> _sendVoiceMessageHttp({
    required File audioFile,
    required String receiverId,
    bool readBy = false,
    String? image,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null || token.isEmpty) {
        print('❗ Auth token is missing.');
        return {
          'error': true,
          'message': 'Authentication token is missing',
          'data': null,
        };
      }

      final uri = Uri.parse('${apiBaseUrl}api/chat/voicemessage');
      print('📤 Sending voice message to: $uri');

      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer $token';

      request.fields['receiverId'] = receiverId;
      request.fields['readBy'] = readBy.toString();
      if (image != null && image.isNotEmpty) {
        request.fields['image'] = image;
      }

      request.files.add(
        await http.MultipartFile.fromPath(
          'audio',
          audioFile.path,
          filename: audioFile.path.split('/').last,
        ),
      );

      print('📦 Request Fields: ${request.fields}');
      print('📦 Audio File: ${audioFile.path}');

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      print('📡 Response Status: ${response.statusCode}');
      print('📦 Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body);
        return {
          'error': decoded['error'] ?? false,
          'message': decoded['message'] ?? 'Voice message sent successfully',
          'data': decoded,
        };
      } else {
        final decoded = jsonDecode(response.body);
        print('⚠️ Error from API: ${decoded['message']}');
        return {
          'error': true,
          'message': decoded['message'] ?? 'Failed to send voice message',
          'data': null,
        };
      }
    } catch (e) {
      print('💥 Exception occurred while sending voice message: $e');
      return {
        'error': true,
        'message': 'Error sending voice message: ${e.toString()}',
        'data': null,
      };
    }
  }

  /// Send file message - ALWAYS use HTTP since socket not implemented
  Future<Map<String, dynamic>> sendFileMessage({
    required File file,
    required String receiverId,
    bool readBy = false,
    bool useSocket = false, // Force HTTP for file messages
  }) async {
    print('📤 Sending file message via HTTP...');
    return await _sendFileMessageHttp(
      file: file,
      receiverId: receiverId,
      readBy: readBy,
    );
  }

  /// HTTP implementation for file messages
  Future<Map<String, dynamic>> _sendFileMessageHttp({
    required File file,
    required String receiverId,
    bool readBy = false,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null || token.isEmpty) {
        print('❗ Auth token is missing.');
        return {
          'error': true,
          'message': 'Authentication token is missing',
          'data': null,
        };
      }

      final uri = Uri.parse('${apiBaseUrl}api/chat/filemessage');
      print('📤 Sending file message to: $uri');

      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer $token';

      request.fields['receiverId'] = receiverId;
      request.fields['readBy'] = readBy.toString();

      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          file.path,
          filename: file.path.split('/').last,
        ),
      );

      print('📦 Request Fields: ${request.fields}');
      print('📦 File: ${file.path}');

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      print('📡 Response Status: ${response.statusCode}');
      print('📦 Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body);
        return {
          'error': decoded['error'] ?? false,
          'message': decoded['message'] ?? 'File message sent successfully',
          'data': decoded,
        };
      } else {
        final decoded = jsonDecode(response.body);
        print('⚠️ Error from API: ${decoded['message']}');
        return {
          'error': true,
          'message': decoded['message'] ?? 'Failed to send file message',
          'data': null,
        };
      }
    } catch (e) {
      print('💥 Exception occurred while sending file message: $e');
      return {
        'error': true,
        'message': 'Error sending file message: ${e.toString()}',
        'data': null,
      };
    }
  }

  /// Update read status via socket (preferred) or HTTP fallback
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

      if (socketResult['error'] == false) {
        return socketResult;
      } else {
        print('⚠️ Socket read status failed: ${socketResult['message']}');
        print('👁️ Falling back to HTTP for read status...');
        return await _updateReadStatusHttp(
          senderId: senderId,
          receiverId: receiverId,
        );
      }
    } else {
      print('👁️ Updating read status via HTTP...');
      return await _updateReadStatusHttp(
        senderId: senderId,
        receiverId: receiverId,
      );
    }
  }

  Future<Map<String, dynamic>> _updateReadStatusHttp({
    required String senderId,
    required String receiverId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null || token.isEmpty) {
        print('❗ Auth token is missing.');
        return {
          'error': true,
          'message': 'Authentication token is missing',
          'data': null,
        };
      }

      final uri = Uri.parse('${apiBaseUrl}api/chat/updatereadBy');
      print('📤 Updating read status to: $uri');

      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'senderId': senderId,
          'receiverId': receiverId,
        }),
      );

      print('📡 Response Status: ${response.statusCode}');
      print('📦 Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body);
        return {
          'error': decoded['error'] ?? false,
          'message': decoded['message'] ?? 'Read status updated successfully',
          'data': decoded['data'],
        };
      } else {
        final decoded = jsonDecode(response.body);
        print('⚠️ Error from API: ${decoded['message']}');
        return {
          'error': true,
          'message': decoded['message'] ?? 'Failed to update read status',
          'data': null,
        };
      }
    } catch (e) {
      print('💥 Exception occurred while updating read status: $e');
      return {
        'error': true,
        'message': 'Error updating read status: ${e.toString()}',
        'data': null,
      };
    }
  }

  /// Delete message via socket (preferred) or HTTP fallback
  Future<Map<String, dynamic>> deleteMessage({
    required String messageId,
    required String receiverId,
    bool useSocket = true,
  }) async {
    if (useSocket && _socketService.isConnected) {
      print('🗑️ Deleting message via socket...');
      final socketResult = await _socketService.deleteMessage(
        messageId: messageId,
        receiverId: receiverId,
      );

      if (socketResult['error'] == false) {
        return socketResult;
      } else {
        print('⚠️ Socket delete failed: ${socketResult['message']}');
        print('🗑️ Falling back to HTTP for delete...');
        return await _deleteMessageHttp(
          messageId: messageId,
          receiverId: receiverId,
        );
      }
    } else {
      print('🗑️ Deleting message via HTTP...');
      return await _deleteMessageHttp(
        messageId: messageId,
        receiverId: receiverId,
      );
    }
  }

  /// HTTP fallback for message deletion
  Future<Map<String, dynamic>> _deleteMessageHttp({
    required String messageId,
    required String receiverId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null || token.isEmpty) {
        print('❗ Auth token is missing.');
        return {
          'error': true,
          'message': 'Authentication token is missing',
        };
      }

      final uri = Uri.parse('${apiBaseUrl}api/chat/deleteMessage');
      print('📤 Deleting message to: $uri');

      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'messageId': messageId,
          'receiverId': receiverId,
        }),
      );

      print('📡 Response Status: ${response.statusCode}');
      print('📦 Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body);
        return {
          'error': decoded['error'] ?? false,
          'message': decoded['message'] ?? 'Message deleted successfully',
          'data': decoded['data'],
        };
      } else {
        final decoded = jsonDecode(response.body);
        print('⚠️ Error from API: ${decoded['message']}');
        return {
          'error': true,
          'message': decoded['message'] ?? 'Failed to delete message',
          'data': null,
        };
      }
    } catch (e) {
      print('💥 Exception occurred while deleting message: $e');
      return {
        'error': true,
        'message': 'Error deleting message: ${e.toString()}',
        'data': null,
      };
    }
  }

  /// Edit message via socket (preferred) or HTTP fallback
  Future<Map<String, dynamic>?> editMessage({
    required String messageId,
    required String newText,
    required String receiverId,
    bool useSocket = true,
  }) async {
    if (useSocket && _socketService.isConnected) {
      print('✏️ Editing message via socket...');
      final socketResult = await _socketService.editMessage(
        messageId: messageId,
        newText: newText,
        receiverId: receiverId,
      );

      if (socketResult['error'] == false) {
        return socketResult;
      } else {
        print('⚠️ Socket edit failed: ${socketResult['message']}');
        print('✏️ Falling back to HTTP for edit...');
        return await _editMessageHttp(
          messageId: messageId,
          newText: newText,
          receiverId: receiverId,
        );
      }
    } else {
      print('✏️ Editing message via HTTP...');
      return await _editMessageHttp(
        messageId: messageId,
        newText: newText,
        receiverId: receiverId,
      );
    }
  }

  /// HTTP fallback for message editing
  Future<Map<String, dynamic>?> _editMessageHttp({
    required String messageId,
    required String newText,
    required String receiverId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      final response = await http.post(
        Uri.parse('${apiBaseUrl}api/chat/editMessage'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'messageId': messageId,
          'newText': newText,
          'receiverId': receiverId,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {
          'error': true,
          'message': 'Failed with status ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'error': true,
        'message': 'Error editing message: $e',
      };
    }
  }

  /// Get file MIME type
  String _getFileType(String path) {
    final extension = path.split('.').last.toLowerCase();
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'ppt':
        return 'application/vnd.ms-powerpoint';
      case 'pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case 'txt':
        return 'text/plain';
      case 'mp3':
        return 'audio/mpeg';
      case 'wav':
        return 'audio/wav';
      case 'mp4':
        return 'video/mp4';
      case 'avi':
        return 'video/avi';
      case 'mov':
        return 'video/quicktime';
      case 'zip':
        return 'application/zip';
      case 'rar':
        return 'application/rar';
      default:
        return 'application/octet-stream';
    }
  }

  /// Join conversation room
  void joinConversation(String userId, String receiverId) {
    _socketService.joinConversation(userId, receiverId);
  }

  /// Leave conversation room
  void leaveConversation(String userId, String receiverId) {
    _socketService.leaveConversation(userId, receiverId);
  }

  /// Disconnect socket
  Future<void> disconnectSocket() async {
    await _socketService.disconnect();
  }

  /// Dispose resources
  void dispose() {
    _socketService.dispose();
  }
}
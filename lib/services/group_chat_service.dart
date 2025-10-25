import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:io';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:ixes.app/constants/apiConstants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class GroupChatService {


  Future<Map<String, dynamic>> getAllGroups({String? searchQuery}) async {
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

      String endpoint = '${apiBaseUrl}api/chat/getallgroups?search=';
      if (searchQuery != null && searchQuery.isNotEmpty) {
        endpoint += '?search=${Uri.encodeQueryComponent(searchQuery)}';
      }

      final uri = Uri.parse(endpoint);
      print('🔍 Fetching groups from: $uri');

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
          'message': decoded['message'] ?? 'Groups fetched successfully',
          'data': decoded['data'] ?? []
        };
      } else {
        final decoded = jsonDecode(response.body);
        print('⚠️ Error from API: ${decoded['message']}');
        return {
          'error': true,
          'message': decoded['message'] ?? 'Failed to fetch groups',
          'data': []
        };
      }
    } catch (e) {
      print('💥 Exception occurred: $e');
      return {
        'error': true,
        'message': 'Error fetching groups: ${e.toString()}',
        'data': []
      };
    }
  }

  Future<Map<String, dynamic>> createGroup({
    required String name,
    required String description,
    String? profileImage,
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

      final uri = Uri.parse('${apiBaseUrl}api/chat/creategroup');
      print('🔍 Creating group at: $uri');

      // Build request body
      Map<String, dynamic> requestBody = {
        'name': name,
        'description': description,
      };

      // Add profile image if provided
      if (profileImage != null && profileImage.isNotEmpty) {
        requestBody['profileImage'] = profileImage;
      }

      // Add empty members array as per API spec
      requestBody['members'] = [];

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

        // Handle successful response
        if (decoded['error'] == false || decoded['error'] == null) {
          return {
            'error': false,
            'message': decoded['message'] ?? 'Group created successfully',
            'data': decoded['data']
          };
        } else {
          // API returned error = true
          return {
            'error': true,
            'message': decoded['message'] ?? 'Failed to create group',
            'data': null
          };
        }
      } else if (response.statusCode == 400) {
        final decoded = jsonDecode(response.body);
        print('⚠️ Bad Request: ${decoded['message']}');
        return {
          'error': true,
          'message': decoded['message'] ?? 'Invalid request. Please check your input.',
          'data': null
        };
      } else if (response.statusCode == 401) {
        print('🔐 Unauthorized request');
        return {
          'error': true,
          'message': 'Authentication failed. Please login again.',
          'data': null
        };
      } else if (response.statusCode == 403) {
        print('🚫 Forbidden request');
        return {
          'error': true,
          'message': 'You don\'t have permission to create groups.',
          'data': null
        };
      } else if (response.statusCode >= 500) {
        print('🔥 Server error: ${response.statusCode}');
        return {
          'error': true,
          'message': 'Server error. Please try again later.',
          'data': null
        };
      } else {
        final decoded = jsonDecode(response.body);
        print('⚠️ Error from API: ${decoded['message']}');
        return {
          'error': true,
          'message': decoded['message'] ?? 'Failed to create group',
          'data': null
        };
      }
    } on SocketException {
      print('🌐 No internet connection');
      return {
        'error': true,
        'message': 'No internet connection. Please check your network.',
        'data': null
      };
    } on TimeoutException {
      print('⏰ Request timeout');
      return {
        'error': true,
        'message': 'Request timeout. Please try again.',
        'data': null
      };
    } on FormatException catch (e) {
      print('📋 Invalid response format: $e');
      return {
        'error': true,
        'message': 'Invalid response from server.',
        'data': null
      };
    } catch (e) {
      print('💥 Exception occurred: $e');
      return {
        'error': true,
        'message': 'An unexpected error occurred: ${e.toString()}',
        'data': null
      };
    }
  }

  /// Get messages for a specific group
  Future<Map<String, dynamic>> getGroupMessages(String groupId) async {
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

      final uri = Uri.parse('${apiBaseUrl}api/chat/groupmessages/$groupId');
      print('🔍 Fetching messages for group $groupId from: $uri');

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
          'message': decoded['message'] ?? 'Messages fetched successfully',
          'data': decoded['data'] ?? []
        };
      } else if (response.statusCode == 401) {
        print('🔐 Unauthorized request');
        return {
          'error': true,
          'message': 'Authentication failed. Please login again.',
          'data': []
        };
      } else if (response.statusCode == 403) {
        print('🚫 Forbidden request');
        return {
          'error': true,
          'message': 'You don\'t have permission to view this group\'s messages.',
          'data': []
        };
      } else if (response.statusCode == 404) {
        print('❓ Group not found');
        return {
          'error': true,
          'message': 'Group not found.',
          'data': []
        };
      } else if (response.statusCode >= 500) {
        print('🔥 Server error: ${response.statusCode}');
        return {
          'error': true,
          'message': 'Server error. Please try again later.',
          'data': []
        };
      } else {
        final decoded = jsonDecode(response.body);
        print('⚠️ Error from API: ${decoded['message']}');
        return {
          'error': true,
          'message': decoded['message'] ?? 'Failed to fetch messages',
          'data': []
        };
      }
    } on SocketException {
      print('🌐 No internet connection');
      return {
        'error': true,
        'message': 'No internet connection. Please check your network.',
        'data': []
      };
    } on TimeoutException {
      print('⏰ Request timeout');
      return {
        'error': true,
        'message': 'Request timeout. Please try again.',
        'data': []
      };
    } on FormatException catch (e) {
      print('📋 Invalid response format: $e');
      return {
        'error': true,
        'message': 'Invalid response from server.',
        'data': []
      };
    } catch (e) {
      print('💥 Exception occurred: $e');
      return {
        'error': true,
        'message': 'Error fetching messages: ${e.toString()}',
        'data': []
      };
    }
  }

  Future<Map<String, dynamic>> sendGroupMessage({
    required String groupId,
    required String text,
    required Map<String, dynamic> communityInfo,
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
          'data': null
        };
      }

      final uri = Uri.parse('${apiBaseUrl}api/chat/groupmessage');
      print('📤 Sending message to group $groupId at: $uri');

      // Prepare request body
      Map<String, dynamic> requestBody = {
        'groupId': groupId,
        'text': text,
        'communityInfo': communityInfo,
      };

      // Add image if provided
      if (image != null && image.isNotEmpty) {
        requestBody['image'] = image;
      }

      print('📦 Request Body: ${jsonEncode(requestBody)}');

      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 30));

      print('📡 Response Status: ${response.statusCode}');
      print('📦 Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body);
        return {
          'error': decoded['error'] ?? false,
          'message': decoded['message'],
          'groupId': decoded['groupId'],
          'data': decoded['message'] // The message object from response
        };
      } else if (response.statusCode == 401) {
        print('🔐 Unauthorized request');
        return {
          'error': true,
          'message': 'Authentication failed. Please login again.',
          'data': null
        };
      } else if (response.statusCode == 403) {
        print('🚫 Forbidden request');
        return {
          'error': true,
          'message': 'You don\'t have permission to send messages to this group.',
          'data': null
        };
      } else if (response.statusCode == 404) {
        print('❓ Group not found');
        return {
          'error': true,
          'message': 'Group not found.',
          'data': null
        };
      } else if (response.statusCode == 400) {
        final decoded = jsonDecode(response.body);
        print('📋 Bad request: ${decoded['message']}');
        return {
          'error': true,
          'message': decoded['message'] ?? 'Invalid request data.',
          'data': null
        };
      } else if (response.statusCode >= 500) {
        print('🔥 Server error: ${response.statusCode}');
        return {
          'error': true,
          'message': 'Server error. Please try again later.',
          'data': null
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
    } on SocketException {
      print('🌐 No internet connection');
      return {
        'error': true,
        'message': 'No internet connection. Please check your network.',
        'data': null
      };
    } on TimeoutException {
      print('⏰ Request timeout');
      return {
        'error': true,
        'message': 'Request timeout. Please try again.',
        'data': null
      };
    } on FormatException catch (e) {
      print('📋 Invalid response format: $e');
      return {
        'error': true,
        'message': 'Invalid response from server.',
        'data': null
      };
    } catch (e) {
      print('💥 Exception occurred: $e');
      return {
        'error': true,
        'message': 'Error sending message: ${e.toString()}',
        'data': null
      };
    }
  }

  /// Send file message to a group
  Future<Map<String, dynamic>> sendGroupFileMessage({
    required String groupId,
    required File file,
    Map<String, dynamic>? communityInfo,
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

      final uri = Uri.parse('${apiBaseUrl}api/chat/groupfilemessage');
      print('📤 Sending file to group $groupId at: $uri');
      print('📄 File path: ${file.path}');
      print('📊 File size: ${await file.length()} bytes');

      // Create multipart request
      var request = http.MultipartRequest('POST', uri);

      // Add headers
      request.headers['Authorization'] = 'Bearer $token';

      // Add file
      var multipartFile = await http.MultipartFile.fromPath(
        'file',
        file.path,
      );
      request.files.add(multipartFile);

      // Add form fields
      request.fields['groupId'] = groupId;

      // Add community info if provided
      if (communityInfo != null) {
        request.fields['communityInfo'] = jsonEncode(communityInfo);
      }

      print('📦 Request fields: ${request.fields}');
      print('📎 File: ${multipartFile.filename} (${multipartFile.length} bytes)');

      // Send request with timeout
      final streamedResponse = await request.send().timeout(
        const Duration(minutes: 2), // Longer timeout for file uploads
      );

      final response = await http.Response.fromStream(streamedResponse);

      print('📡 Response Status: ${response.statusCode}');
      print('📦 Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body);
        return {
          'error': decoded['error'] ?? false,
          'message': decoded['message'],
          'groupId': decoded['groupId'],
          'data': decoded['message'] // The file message object from response
        };
      } else if (response.statusCode == 401) {
        print('🔐 Unauthorized request');
        return {
          'error': true,
          'message': 'Authentication failed. Please login again.',
          'data': null
        };
      } else if (response.statusCode == 403) {
        print('🚫 Forbidden request');
        return {
          'error': true,
          'message': 'You don\'t have permission to send files to this group.',
          'data': null
        };
      } else if (response.statusCode == 404) {
        print('❓ Group not found');
        return {
          'error': true,
          'message': 'Group not found.',
          'data': null
        };
      } else if (response.statusCode == 400) {
        final decoded = jsonDecode(response.body);
        print('📋 Bad request: ${decoded['message']}');
        return {
          'error': true,
          'message': decoded['message'] ?? 'Invalid file or request data.',
          'data': null
        };
      } else if (response.statusCode == 413) {
        print('📏 File too large');
        return {
          'error': true,
          'message': 'File is too large. Please choose a smaller file.',
          'data': null
        };
      } else if (response.statusCode >= 500) {
        print('🔥 Server error: ${response.statusCode}');
        return {
          'error': true,
          'message': 'Server error. Please try again later.',
          'data': null
        };
      } else {
        final decoded = jsonDecode(response.body);
        print('⚠️ Error from API: ${decoded['message']}');
        return {
          'error': true,
          'message': decoded['message'] ?? 'Failed to send file',
          'data': null
        };
      }
    } on SocketException {
      print('🌐 No internet connection');
      return {
        'error': true,
        'message': 'No internet connection. Please check your network.',
        'data': null
      };
    } on TimeoutException {
      print('⏰ Request timeout');
      return {
        'error': true,
        'message': 'File upload timeout. Please try again with a smaller file.',
        'data': null
      };
    } on FormatException catch (e) {
      print('📋 Invalid response format: $e');
      return {
        'error': true,
        'message': 'Invalid response from server.',
        'data': null
      };
    } catch (e) {
      print('💥 Exception occurred: $e');
      return {
        'error': true,
        'message': 'Error sending file: ${e.toString()}',
        'data': null
      };
    }
  }
  Future<Map<String, dynamic>> getGroupRequests(String groupId) async {
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

      final uri = Uri.parse('${apiBaseUrl}api/chat/grouprequest/$groupId');
      print('🔍 Fetching group requests for $groupId from: $uri');

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
          'message': decoded['message'] ?? 'Requests fetched successfully',
          'data': decoded['data'] ?? []
        };
      } else {
        final decoded = jsonDecode(response.body);
        print('⚠️ Error from API: ${decoded['message']}');
        return {
          'error': true,
          'message': decoded['message'] ?? 'Failed to fetch requests',
          'data': []
        };
      }
    } catch (e) {
      print('💥 Exception occurred: $e');
      return {
        'error': true,
        'message': 'Error fetching requests: ${e.toString()}',
        'data': []
      };
    }
  }
  Future<Map<String, dynamic>> getMyGroups({String? communityId}) async {
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

      // Construct the URI with optional communityId query parameter
      final uri = Uri.parse(
        communityId != null
            ? '${apiBaseUrl}api/chat/mygroups?communityId=$communityId'
            : '${apiBaseUrl}api/chat/mygroups',
      );
      print('🔍 Fetching user groups from: $uri');

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
          'message': decoded['message'] ?? 'Groups fetched successfully',
          'data': decoded['data'] ?? []
        };
      } else {
        final decoded = jsonDecode(response.body);
        print('⚠️ Error from API: ${decoded['message']}');
        return {
          'error': true,
          'message': decoded['message'] ?? 'Failed to fetch groups',
          'data': []
        };
      }
    } catch (e) {
      print('💥 Exception occurred: $e');
      return {
        'error': true,
        'message': 'Error fetching groups: ${e.toString()}',
        'data': []
      };
    }
  }
  Future<Map<String, dynamic>> addMembersToGroup({
    required String groupId,
    required List<String> memberIds,
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

      final uri = Uri.parse('${apiBaseUrl}api/chat/addmember');
      print('👥 Adding members to group: $groupId');

      final body = jsonEncode({
        'groupId': groupId,
        'members': memberIds,
      });

      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: body,
      );

      print('📡 Response Status: ${response.statusCode}');
      print('📦 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return {
          'error': decoded['error'] ?? false,
          'message': decoded['message'] ?? 'Member(s) added successfully',
        };
      } else {
        final decoded = jsonDecode(response.body);
        return {
          'error': true,
          'message': decoded['message'] ?? 'Failed to add members',
        };
      }
    } catch (e) {
      print('💥 Exception: $e');
      return {
        'error': true,
        'message': 'Error adding members: ${e.toString()}',
      };
    }
  }

  Future<Map<String, dynamic>> fetchAllUsers({required int page }) async {
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

      final uri = Uri.parse('${apiBaseUrl}api/mobile/all-users?page=$page');
      print('📥 Fetching users from: $uri');

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
          'message': decoded['message'] ?? 'Users fetched successfully',
          'data': decoded['data'] ?? {},
        };
      } else {
        final decoded = jsonDecode(response.body);
        return {
          'error': true,
          'message': decoded['message'] ?? 'Failed to fetch users',
          'data': {}
        };
      }
    } catch (e) {
      print('💥 Exception: $e');
      return {
        'error': true,
        'message': 'Error fetching users: ${e.toString()}',
        'data': {}
      };
    }
  }

  Future<Map<String, dynamic>> requestToJoinGroup({
    required String groupId,
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

      final uri = Uri.parse('${apiBaseUrl}api/chat/grouprequest');
      print('📩 Sending join group request for groupId: $groupId');

      final body = jsonEncode({
        'groupId': groupId,
      });

      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: body,
      );

      print('📡 Response Status: ${response.statusCode}');
      print('📦 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return {
          'error': decoded['error'] ?? false,
          'message': decoded['message'] ?? 'Request sent successfully',
          'data': decoded['data'] ?? false,
        };
      } else {
        final decoded = jsonDecode(response.body);
        return {
          'error': true,
          'message': decoded['message'] ?? 'Failed to request group',
        };
      }
    } catch (e) {
      print('💥 Exception occurred: $e');
      return {
        'error': true,
        'message': 'Error requesting group: ${e.toString()}',
      };
    }
  }


}
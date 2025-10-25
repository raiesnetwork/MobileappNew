import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ixes.app/constants/apiConstants.dart';

class ChatService {
  Future<String> sendMessage(String message, int type,
      {String filePath = ''}) async {
    switch (type) {
      case 0:
        return await _sendToGeneral(message);
      case 1:
        return await sendToBusiness(message);
      case 2:
        final result = await sendPersonalChat(message, filePath);
        return result['reply'] ?? "No reply";
      default:
        return "Invalid type";
    }
  }

  // GENERAL
  Future<String> _sendToGeneral(String msg) async {
    final result = await sendGeneralChat(message: msg);
    return result['reply'] ?? "No reply";
  }

  static Future<Map<String, dynamic>> sendGeneralChat({
    required String message,
  }) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      print("$token");

      if (token == null || token.isEmpty) {
        print("❌ Token missing for general chat");
        return {
          "success": false,
          "message": "Authentication token is missing",
        };
      }

      final Uri url = Uri.parse("${apiBaseUrl}api/ask-newa/chat");

      final Map<String, dynamic> body = {
        "message": message,
      };

      print('📤 Chat URL: $url');
      print('📤 Chat BODY: $body');
      print('🔐 TOKEN: $token');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      print('📥 STATUS: ${response.statusCode}');
      print('📥 RESPONSE: ${response.body}');

      final decoded = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('✅ Chat Sent Successfully');
        return {
          "success": true,
          "reply": decoded['reply'] ?? "",
          "history": decoded['history'],
          "message": decoded['message'] ?? "Chat sent successfully"
        };
      } else {
        print('⚠️ Failed to send chat');
        return {
          "success": false,
          "message": decoded['message'] ?? "Failed to send chat"
        };
      }
    } catch (e) {
      print("❌ Chat Error: $e");
      return {
        "success": false,
        "message": "Error sending chat: ${e.toString()}",
      };
    }
  }

  // BUSINESS
  Future<String> sendToBusiness(String msg) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null || token.isEmpty) {
        return "❌ Authentication token is missing";
      }

      final Uri url = Uri.parse("${apiBaseUrl}api/ask-newa/bussinessChat");
      final Map<String, dynamic> body = {"message": msg};

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      print("📥 BUSINESS STATUS: ${response.statusCode}");
      print("📥 BUSINESS RESPONSE: ${response.body}");

      final decoded = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return decoded['reply'] ?? "[No reply]";
      } else {
        return "❌ ${decoded['message'] ?? 'Failed to send business chat'}";
      }
    } catch (e) {
      return "❌ Error sending business chat: ${e.toString()}";
    }
  }

  // PERSONAL - Fixed to handle both file and text-only messages


  Future<Map<String, dynamic>> sendPersonalChat(
      String question, String filePath) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      print("🔐 Token: $token");

      if (token == null || token.isEmpty) {
        return {
          "success": false,
          "message": "Authentication token is missing",
          "reply": "❌ Authentication token is missing"
        };
      }

      final Uri url = Uri.parse("${apiBaseUrl}api/ask-newa/personal");

      print("📤 Personal Chat URL: $url");
      print("📤 Sending question: $question");
      print("📤 File path: $filePath");

      final request = http.MultipartRequest('POST', url)
        ..headers['Authorization'] = 'Bearer $token'
        ..fields['question'] = question;

      // Only add file if filePath is not empty
      if (filePath.isNotEmpty) {
        final file = File(filePath);
        if (!await file.exists()) {
          print("❌ File does not exist: $filePath");
          return {
            "success": false,
            "message": "File does not exist or is inaccessible",
            "reply": "❌ File does not exist or is inaccessible"
          };
        }

        final extension = filePath.split('.').last.toLowerCase();
        if (!['pdf', 'xls', 'xlsx'].contains(extension)) {
          print("❌ Invalid file extension: $extension");
          return {
            "success": false,
            "message": "Unsupported file format. Only PDF and Excel files are allowed",
            "reply": "❌ Unsupported file format. Only PDF and Excel files are allowed"
          };
        }

        String mimeType;
        if (extension == 'pdf') {
          mimeType = 'application/pdf';
        } else if (extension == 'xls') {
          mimeType = 'application/vnd.ms-excel';
        } else {
          mimeType = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
        }

        print("📎 Adding file to request: $filePath (MIME: $mimeType)");
        request.files.add(
          http.MultipartFile(
            'file',
            file.readAsBytes().asStream(),
            await file.length(),
            filename: filePath.split('/').last,
            contentType: MediaType.parse(mimeType),
          ),
        );
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      print("📥 Personal Chat STATUS: ${response.statusCode}");
      print("📥 Personal Chat RESPONSE: ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body);
        print("✅ Personal Chat Success: $decoded");
        if (decoded['reply'] == 'Unsupported file format.') {
          return {
            "success": false,
            "message": "Unsupported file format",
            "reply": "❌ Unsupported file format. Please ensure the file is a valid PDF or Excel file."
          };
        }
        return {
          "success": true,
          "reply": decoded['reply'] ?? "No reply from AI",
          "message": decoded['message'] ?? "Personal chat sent successfully"
        };
      } else {
        print("⚠️ Personal Chat Failed: ${response.statusCode} - ${response.body}");
        final decoded = jsonDecode(response.body);
        return {
          "success": false,
          "message": decoded['message'] ?? "Failed to send personal chat",
          "reply": "❌ ${decoded['message'] ?? 'Failed to send personal chat'}"
        };
      }
    } catch (e) {
      print("❌ Personal Chat Error: $e");
      return {
        "success": false,
        "message": "Error sending personal chat: ${e.toString()}",
        "reply": "❌ Error sending personal chat: ${e.toString()}"
      };
    }
  }

  // HISTORY
  Future<List<dynamic>> fetchChatHistory() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null || token.isEmpty) {
        throw Exception("❌ Authentication token is missing");
      }

      final Uri url = Uri.parse("${apiBaseUrl}api/ask-newa/history");

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print("📥 HISTORY STATUS: ${response.statusCode}");
      print("📥 HISTORY RESPONSE: ${response.body}");

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return decoded['history'] ?? [];
      } else {
        throw Exception(
            "❌ ${jsonDecode(response.body)['message'] ?? 'Failed to fetch history'}");
      }
    } catch (e) {
      print("❌ Error fetching history: $e");
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> deleteChatHistory(
      String historyId) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null || token.isEmpty) {
        return {
          "success": false,
          "message": "Authentication token is missing",
        };
      }

      final url =
          Uri.parse("https://api.ixes.ai/api/ask-newa/delete/$historyId");

      final response = await http.delete(
        url,
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      final decoded = jsonDecode(response.body);
      if (response.statusCode == 200 && decoded['success'] == true) {
        return {
          "success": true,
          "message": decoded["message"] ?? "Deleted successfully",
        };
      } else {
        return {
          "success": false,
          "message": decoded["message"] ?? "Failed to delete",
        };
      }
    } catch (e) {
      return {
        "success": false,
        "message": "Error deleting: ${e.toString()}",
      };
    }
  }

  Future<Map<String, dynamic>> fetchUserSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    final response = await http.get(
      Uri.parse('https://api.ixes.ai/api/ask-newa/setting'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final jsonData = json.decode(response.body);
      return jsonData['settings'] ?? {};
    } else {
      throw Exception('Failed to load user settings');
    }
  }

  Future<Map<String, dynamic>> saveUserSettings(
      Map<String, String> fields, List<String> filePaths, {required List<String> deletedFiles}) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      final uri = Uri.parse("https://api.ixes.ai/api/ask-newa/setting");
      final request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer $token';

      // Add text fields
      fields.forEach((key, value) {
        request.fields[key] = value;
      });

      // Add files if any
      for (final path in filePaths) {
        print("📎 Attaching file: $path");
        request.files.add(await http.MultipartFile.fromPath('files', path));
      }

      // Print request details
      print("📤 Saving settings to: $uri");
      print("🔐 Authorization: Bearer $token");
      print("📝 Fields: ${request.fields}");
      print("📁 File count: ${request.files.length}");

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      print("📥 Status Code: ${response.statusCode}");
      print("📥 Response Body: ${response.body}");

      final decoded = jsonDecode(response.body);
      return {
        "success": response.statusCode == 200,
        "settings": decoded["settings"] ?? {},
        "message": decoded["message"] ?? "",
      };
    } catch (e) {
      print("❌ Error saving settings: $e");
      return {
        "success": false,
        "message": "Error saving settings: ${e.toString()}",
      };
    }
  }
}

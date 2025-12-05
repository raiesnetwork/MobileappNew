import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/apiConstants.dart';

class MeetService {


  /// Creates a new meeting link
  Future<Map<String, dynamic>> createMeetLink({
    required String linkId,
    required String type, // 'personal' | 'groups' | 'mail'
    required String dateAndTime,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      print('Retrieved token: $token');

      if (token == null || token.isEmpty) {
        print('Token is missing');
        return {
          'error': true,
          'message': 'Authentication token is missing',
          'data': null
        };
      }

      final url = '${apiBaseUrl}api/meet/create';
      print('Requesting URL: $url');

      final requestBody = {
        'linkId': linkId,
        'type': type,
        'dateAndTime': dateAndTime,
      };

      print('Request body: $requestBody');

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      print('Response status code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body);
        print('Decoded response: $decoded');

        return {
          'error': false,
          'message': decoded['message'] ?? 'Meeting link created successfully',
          'data': decoded
        };
      } else if (response.statusCode == 401) {
        return {
          'error': true,
          'message': 'Unauthorized - Please log in again',
          'data': null
        };
      } else if (response.statusCode == 500) {
        return {
          'error': true,
          'message': 'Server error - Please try again later',
          'data': null
        };
      } else {
        return {
          'error': true,
          'message': 'Failed to create meeting link (${response.statusCode})',
          'data': null
        };
      }
    } catch (e) {
      print('Exception caught: $e');
      return {
        'error': true,
        'message': 'Network error: ${e.toString()}',
        'data': null
      };
    }
  }

  /// Shares a meeting link with users, groups, or via email
  Future<Map<String, dynamic>> shareMeetLink({
    required String meetLink,
    required String dateAndTimeFrom,
    required String dateAndTimeTo,
    required String description,
    required String type, // 'personal' | 'groups' | 'mail'
    List<Map<String, String>>? members,
    List<Map<String, String>>? mail,
    Map<String, dynamic>? recurrenceSettings,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      print('Retrieved token: $token');

      if (token == null || token.isEmpty) {
        print('Token is missing');
        return {
          'error': true,
          'message': 'Authentication token is missing',
          'data': null
        };
      }

      final url = '${apiBaseUrl}api/meet/share';
      print('Requesting URL: $url');

      final requestBody = {
        'meetLink': meetLink,
        'dateAndTimeFrom': dateAndTimeFrom,
        'dateAndTimeTo': dateAndTimeTo,
        'description': description,
        'type': type,
        if (members != null && members.isNotEmpty) 'members': members,
        if (mail != null && mail.isNotEmpty) 'mail': mail,
        if (recurrenceSettings != null) 'recurrenceSettings': recurrenceSettings,
      };

      print('Request body: $requestBody');

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      print('Response status code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body);
        print('Decoded response: $decoded');

        return {
          'error': false,
          'message': decoded['message'] ?? 'Meeting invitation sent successfully',
          'data': decoded
        };
      } else if (response.statusCode == 401) {
        return {
          'error': true,
          'message': 'Unauthorized - Please log in again',
          'data': null
        };
      } else if (response.statusCode == 500) {
        return {
          'error': true,
          'message': 'Server error - Please try again later',
          'data': null
        };
      } else {
        return {
          'error': true,
          'message': 'Failed to share meeting link (${response.statusCode})',
          'data': null
        };
      }
    } catch (e) {
      print('Exception caught: $e');
      return {
        'error': true,
        'message': 'Network error: ${e.toString()}',
        'data': null
      };
    }
  }

  /// Validates a meeting link
  Future<Map<String, dynamic>> validateMeetLink({
    required String linkId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      print('Retrieved token: $token');

      if (token == null || token.isEmpty) {
        print('Token is missing');
        return {
          'error': true,
          'message': 'Authentication token is missing',
          'data': null,
          'isValid': false
        };
      }

      final url = '${apiBaseUrl}api/meet/validate?linkId=$linkId';
      print('Requesting URL: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('Response status code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        print('Decoded response: $decoded');

        return {
          'error': false,
          'message': decoded['message'] ?? 'Validation successful',
          'data': decoded,
          'isValid': decoded['isValid'] ?? false
        };
      } else if (response.statusCode == 401) {
        return {
          'error': true,
          'message': 'Unauthorized - Please log in again',
          'data': null,
          'isValid': false
        };
      } else if (response.statusCode == 500) {
        return {
          'error': true,
          'message': 'Server error - Please try again later',
          'data': null,
          'isValid': false
        };
      } else {
        return {
          'error': true,
          'message': 'Failed to validate meeting link (${response.statusCode})',
          'data': null,
          'isValid': false
        };
      }
    } catch (e) {
      print('Exception caught: $e');
      return {
        'error': true,
        'message': 'Network error: ${e.toString()}',
        'data': null,
        'isValid': false
      };
    }
  }
}
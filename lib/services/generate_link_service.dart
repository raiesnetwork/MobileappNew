import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/apiConstants.dart';
import 'api_service.dart';

class MeetService {

  Future<Map<String, dynamic>> createMeetLink({
    required String linkId,
    required String type,
    required String dateAndTime,
  }) async {
    try {
      final requestBody = {
        'linkId': linkId,
        'type': type,
        'dateAndTime': dateAndTime,
      };

      print('Request body: $requestBody');

      final response = await ApiService.post('/api/meet/create', requestBody);
      ApiService.checkResponse(response);

      print('Response status code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body);
        return {
          'error': false,
          'message': decoded['message'] ?? 'Meeting link created successfully',
          'data': decoded
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

  Future<Map<String, dynamic>> shareMeetLink({
    required String meetLink,
    required String dateAndTimeFrom,
    required String dateAndTimeTo,
    required String description,
    required String type,
    List<Map<String, String>>? members,
    List<Map<String, String>>? mail,
    Map<String, dynamic>? recurrenceSettings,
  }) async {
    try {
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

      final response = await ApiService.post('/api/meet/share', requestBody);
      ApiService.checkResponse(response);

      print('Response status code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body);
        return {
          'error': false,
          'message': decoded['message'] ?? 'Meeting invitation sent successfully',
          'data': decoded
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

  Future<Map<String, dynamic>> validateMeetLink({
    required String linkId,
  }) async {
    try {
      final response = await ApiService.get('/api/meet/validate?linkId=$linkId');
      ApiService.checkResponse(response);

      print('Response status code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return {
          'error': false,
          'message': decoded['message'] ?? 'Validation successful',
          'data': decoded,
          'isValid': decoded['isValid'] ?? false
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
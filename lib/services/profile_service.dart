import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/apiConstants.dart';

class ProfileService {
  // Get User Profile
  Future<Map<String, dynamic>> getUserProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null || token.isEmpty) {
        print("token $token");
        return {
          'error': true,
          'message': 'Authentication token is missing',
          'data': null
        };
      }

      final response = await http.get(
        Uri.parse('${apiBaseUrl}api/profile'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('getUserProfile - Status Code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return {
          'error': false,
          'message': 'Profile fetched successfully',
          'data': decoded
        };
      } else {
        final decoded = _safeJsonDecode(response.body);
        return {
          'error': true,
          'message': decoded['message'] ?? 'Failed to fetch profile',
          'data': null
        };
      }
    } catch (e) {
      print('Error in getUserProfile: $e');
      return {
        'error': true,
        'message': 'Error fetching profile: ${e.toString()}',
        'data': null
      };
    }
  }

  // Get Dashboard Data
  Future<Map<String, dynamic>> getDashboardData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null || token.isEmpty) {
        print("token $token");
        return {
          'error': true,
          'message': 'Authentication token is missing',
          'data': null
        };
      }

      final response = await http.get(
        Uri.parse('${apiBaseUrl}api/profile/dashboard'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('getDashboardData - Status Code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return {
          'error': false,
          'message': 'Dashboard data fetched successfully',
          'data': decoded
        };
      } else {
        final decoded = _safeJsonDecode(response.body);
        return {
          'error': true,
          'message': decoded['message'] ?? 'Failed to fetch dashboard data',
          'data': null
        };
      }
    } catch (e) {
      print('Error in getDashboardData: $e');
      return {
        'error': true,
        'message': 'Error fetching dashboard data: ${e.toString()}',
        'data': null
      };
    }
  }

  // Update User Profile
  Future<Map<String, dynamic>> updateUserProfile(
      Map<String, dynamic> profileData) async {
    try {
      print('updateUserProfile - Starting with data: $profileData');

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null || token.isEmpty) {
        print('updateUserProfile - Error: Authentication token is missing');
        return {
          'error': true,
          'message': 'Authentication token is missing',
          'data': null
        };
      }

      // Process the profile data to handle base64 image
      final processedData = Map<String, dynamic>.from(profileData);

      // Handle base64 profile image properly
      if (processedData['profileImageBase64'] != null &&
          processedData['profileImageBase64'].toString().isNotEmpty) {
        String base64Image = processedData['profileImageBase64'].toString();

        // Remove data URL prefix if it exists (data:image/jpeg;base64,)
        if (base64Image.contains('data:image')) {
          final parts = base64Image.split(',');
          if (parts.length > 1) {
            base64Image = parts.last;
          }
        }

        // Ensure the base64 string is clean
        base64Image = base64Image.replaceAll(RegExp(r'\s+'), '');
        processedData['profileImageBase64'] = base64Image;
        print('updateUserProfile - Processed base64 image length: ${base64Image.length}');
      } else {
        // Remove the field if it's empty to avoid server issues
        processedData.remove('profileImageBase64');
      }

      print('updateUserProfile - Sending data: ${processedData.keys}');

      final response = await http.put(
        Uri.parse('${apiBaseUrl}api/profile'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(processedData),
      );

      print('updateUserProfile - Status Code: ${response.statusCode}');
      print('updateUserProfile - Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = _safeJsonDecode(response.body);
        return {
          'error': false,
          'message': decoded['message'] ?? 'User profile updated successfully',
          'data': decoded
        };
      } else {
        final decoded = _safeJsonDecode(response.body);
        print('updateUserProfile - Error: ${decoded['message'] ?? 'Failed to update profile'}');
        return {
          'error': true,
          'message': decoded['message'] ?? 'Failed to update profile',
          'data': null
        };
      }
    } catch (e) {
      print('updateUserProfile - Exception: $e');
      return {
        'error': true,
        'message': 'Error updating profile: ${e.toString()}',
        'data': null
      };
    }
  }

  // Fetch Events
  Future<Map<String, dynamic>> fetchEvents() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null || token.isEmpty) {
        print("token $token");
        return {
          'error': true,
          'message': 'Authentication token is missing',
          'events': []
        };
      }

      final response = await http.get(
        Uri.parse('${apiBaseUrl}api/profile/event/fetch'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('fetchEvents - Status Code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        List<dynamic> eventsList = [];

        if (decoded is List) {
          eventsList = decoded;
        } else if (decoded is Map && decoded.containsKey('events')) {
          eventsList = decoded['events'] ?? [];
        } else if (decoded is Map && decoded.containsKey('data')) {
          eventsList = decoded['data'] ?? [];
        }

        return {
          'error': false,
          'message': 'Events fetched successfully',
          'events': eventsList
        };
      } else {
        final decoded = _safeJsonDecode(response.body);
        return {
          'error': true,
          'message': decoded['message'] ?? 'Failed to fetch events',
          'events': []
        };
      }
    } catch (e) {
      print('Error in fetchEvents: $e');
      return {
        'error': true,
        'message': 'Error fetching events: ${e.toString()}',
        'events': []
      };
    }
  }

  // Create Event
  Future<Map<String, dynamic>> createEvent(
      Map<String, dynamic> eventData) async {
    try {
      print('createEvent - Starting with data: $eventData');

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null || token.isEmpty) {
        print('createEvent - Error: Authentication token is missing');
        return {
          'error': true,
          'message': 'Authentication token is missing',
          'event': null
        };
      }

      final response = await http.post(
        Uri.parse('${apiBaseUrl}api/profile/event'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(eventData),
      );

      print('createEvent - Status Code: ${response.statusCode}');
      print('createEvent - Response Body: ${response.body}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        final decoded = _safeJsonDecode(response.body);

        // Handle different response structures
        Map<String, dynamic>? event;
        if (decoded.containsKey('event')) {
          event = decoded['event'];
        } else if (decoded.containsKey('data')) {
          event = decoded['data'];
        } else if (decoded.containsKey('result')) {
          event = decoded['result'];
        } else {
          // If the response itself is the event object
          event = decoded;
        }

        print('createEvent - Extracted event: $event');

        return {
          'error': false,
          'message': decoded['message'] ?? 'Event created successfully',
          'event': event
        };
      } else {
        final decoded = _safeJsonDecode(response.body);
        print('createEvent - Error: ${decoded['message'] ?? 'Failed to create event'}');
        return {
          'error': true,
          'message': decoded['message'] ?? 'Failed to create event',
          'event': null
        };
      }
    } catch (e) {
      print('createEvent - Exception: $e');
      return {
        'error': true,
        'message': 'Error creating event: ${e.toString()}',
        'event': null
      };
    }
  }

  // Helper method for safe JSON decoding
  Map<String, dynamic> _safeJsonDecode(String body) {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (e) {
      print('Error decoding JSON: $e');
      return {'message': 'Failed to parse response'};
    }
  }
}
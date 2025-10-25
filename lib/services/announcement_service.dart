import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/apiConstants.dart';

class AnnouncementService {
  // Helper method for safe JSON decoding
  Map<String, dynamic> _safeJsonDecode(String body) {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (e) {
      return {'error': true, 'message': 'Invalid response format'};
    }
  }

  Future<Map<String, dynamic>> createAnnouncement({
    required String communityId,
    required String description,
    String? templateType,
    String? title,
    String? contactInfo,
    String? endDate,
    String? image,
    String? startDate,
    String? time,
    String? location,
    String? endTime,
    String? company,
    String? experience,
    String? employmentType,
    String? salaryRange,
    String? url,
    String? currency,
  }) async {
    try {
      print('createAnnouncement - Community ID: $communityId');
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null || token.isEmpty) {
        print('createAnnouncement - Error: Authentication token is missing');
        return {
          'error': true,
          'message': 'Authentication token is missing',
        };
      }
      print(
          'createAnnouncement - Token: ${token.length > 20 ? '${token.substring(0, 10)}...${token.substring(token.length - 10)}' : token}');

      final requestBody = {
        'communityId': communityId,
        'description': description,
        'templateType': templateType ?? '',
        'title': title ?? '',
        'contactInfo': contactInfo ?? '',
        'endDate': endDate ?? '',
        'image': image ?? '',
        'startDate': startDate ?? '',
        'time': time ?? '',
        'location': location ?? '',
        'endTime': endTime ?? '',
        'company': company ?? '',
        'experience': experience ?? '',
        'employmentType': employmentType ?? '',
        'salaryRange': salaryRange ?? '',
        'url': url ?? '',
        'currency': currency ?? '',
      };
      print('createAnnouncement - Request Body: ${jsonEncode(requestBody)}');
      print('createAnnouncement - URL: ${apiBaseUrl}api/announcement/create');
      print(
          'createAnnouncement - Headers: {Authorization: Bearer [masked], Content-Type: application/json, Accept: application/json}');

      final response = await http.post(
        Uri.parse('${apiBaseUrl}api/announcement/create'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      print('createAnnouncement - Status Code: ${response.statusCode}');
      print('createAnnouncement - Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = _safeJsonDecode(response.body);
        print(
            'createAnnouncement - Response: ${decoded['message'] ?? 'Announcement created successfully'}');
        return {
          'error': false,
          'message': decoded['message'] ?? 'Announcement created successfully',
        };
      } else {
        final decoded = _safeJsonDecode(response.body);
        print(
            'createAnnouncement - Error: ${decoded['message'] ?? 'Failed to create announcement'}');
        return {
          'error': true,
          'message': decoded['message'] ?? 'Failed to create announcement',
        };
      }
    } catch (e) {
      print(
          'createAnnouncement - Exception: Error creating announcement: ${e.toString()}');
      return {
        'error': true,
        'message': 'Error creating announcement: ${e.toString()}',
      };
    }
  }

  // Get All Announcements
  Future<Map<String, dynamic>> getAllAnnouncements({
    required String communityId,
    int page = 1,
    int limit = 10,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null || token.isEmpty) {
        return {
          'error': true,
          'message': 'Authentication token is missing',
          'announcements': [],
        };
      }

      final response = await http.get(
        Uri.parse(
            '${apiBaseUrl}api/announcement/get/$communityId?page=$page&limit=$limit'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final decoded = _safeJsonDecode(response.body);
        return {
          'error': false,
          'message': decoded['message'] ?? 'Announcements fetched successfully',
          'announcements': decoded['data'] ?? [],
        };
      } else {
        final decoded = _safeJsonDecode(response.body);
        return {
          'error': true,
          'message': decoded['message'] ?? 'Failed to fetch announcements',
          'announcements': [],
        };
      }
    } catch (e) {
      return {
        'error': true,
        'message': 'Error fetching announcements: ${e.toString()}',
        'announcements': [],
      };
    }
  }

  // Update Announcement
  Future<Map<String, dynamic>> updateAnnouncement({
    required String id,
    required String communityId,
    String? templateType,
    String? title,
    String? contactInfo,
    String? endDate,
    String? image,
    String? startDate,
    String? time,
    String? description,
    String? location,
    String? endTime,
    String? company,
    String? experience,
    String? employmentType,
    String? salaryRange,
    String? url,
    String? currency,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null || token.isEmpty) {
        return {
          'error': true,
          'message': 'Authentication token is missing',
        };
      }

      final response = await http.put(
        Uri.parse('${apiBaseUrl}api/announcement/update'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          '_id': id,
          'communityId': communityId,
          if (description != null) 'description': description,
          if (templateType != null) 'templateType': templateType,
          if (title != null) 'title': title,
          if (contactInfo != null) 'contactInfo': contactInfo,
          if (endDate != null) 'endDate': endDate,
          if (image != null) 'image': image,
          if (startDate != null) 'startDate': startDate,
          if (time != null) 'time': time,
          if (location != null) 'location': location,
          if (endTime != null) 'endTime': endTime,
          if (company != null) 'company': company,
          if (experience != null) 'experience': experience,
          if (employmentType != null) 'employmentType': employmentType,
          if (salaryRange != null) 'salaryRange': salaryRange,
          if (url != null) 'url': url,
          if (currency != null) 'currency': currency,
        }),
      );

      if (response.statusCode == 200) {
        final decoded = _safeJsonDecode(response.body);
        return {
          'error': false,
          'message': decoded['message'] ?? 'Announcement updated successfully',
        };
      } else {
        final decoded = _safeJsonDecode(response.body);
        return {
          'error': true,
          'message': decoded['message'] ?? 'Failed to update announcement',
        };
      }
    } catch (e) {
      return {
        'error': true,
        'message': 'Error updating announcement: ${e.toString()}',
      };
    }
  }

  // Delete Announcement
  Future<Map<String, dynamic>> deleteAnnouncement({
    required String id,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null || token.isEmpty) {
        return {
          'error': true,
          'message': 'Authentication token is missing',
        };
      }

      final response = await http.delete(
        Uri.parse('${apiBaseUrl}api/announcement/delete/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final decoded = _safeJsonDecode(response.body);
        return {
          'error': false,
          'message': decoded['message'] ?? 'Announcement deleted successfully',
        };
      } else {
        final decoded = _safeJsonDecode(response.body);
        return {
          'error': true,
          'message': decoded['message'] ?? 'Failed to delete announcement',
        };
      }
    } catch (e) {
      return {
        'error': true,
        'message': 'Error deleting announcement: ${e.toString()}',
      };
    }
  }
  Future<Map<String, dynamic>> getDashboardCounts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null || token.isEmpty) {
        return {
          'error': true,
          'message': 'Authentication token is missing',
          'totalCommunities': 0,
          'totalCampaigns': 0,
          'totalServices': 0,
        };
      }

      final response = await http.get(
        Uri.parse('${apiBaseUrl}api/profile/dashboard'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'error': false,
          'totalCommunities': data['totalCommunities'] ?? 0,
          'totalCampaigns': data['totalCampaigns'] ?? 0,
          'totalServices': data['totalServices'] ?? 0,
        };
      } else {
        return {
          'error': true,
          'message': 'Failed to fetch dashboard counts',
          'totalCommunities': 0,
          'totalCampaigns': 0,
          'totalServices': 0,
        };
      }
    } catch (e) {
      return {
        'error': true,
        'message': 'Error: ${e.toString()}',
        'totalCommunities': 0,
        'totalCampaigns': 0,
        'totalServices': 0,
      };
    }
  }

}

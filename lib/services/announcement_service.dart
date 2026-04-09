import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/apiConstants.dart';
import 'api_service.dart';

class AnnouncementService {
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

      final response = await ApiService.post(
          '/api/announcement/create', requestBody);
      ApiService.checkResponse(response);

      print('createAnnouncement - Status Code: ${response.statusCode}');
      print('createAnnouncement - Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = _safeJsonDecode(response.body);
        return {
          'error': false,
          'message': decoded['message'] ?? 'Announcement created successfully',
        };
      } else {
        final decoded = _safeJsonDecode(response.body);
        return {
          'error': true,
          'message': decoded['message'] ?? 'Failed to create announcement',
        };
      }
    } catch (e) {
      print('createAnnouncement - Exception: ${e.toString()}');
      return {
        'error': true,
        'message': 'Error creating announcement: ${e.toString()}',
      };
    }
  }

  Future<Map<String, dynamic>> getAllAnnouncements({
    required String communityId,
    int page = 1,
    int limit = 10,
  }) async {
    try {
      final response = await ApiService.get(
          '/api/announcement/get/$communityId?page=$page&limit=$limit');
      ApiService.checkResponse(response);

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
      final body = {
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
      };

      final response = await ApiService.put('/api/announcement/update', body);
      ApiService.checkResponse(response);

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

  Future<Map<String, dynamic>> deleteAnnouncement({
    required String id,
  }) async {
    try {
      final response = await ApiService.delete('/api/announcement/delete/$id');
      ApiService.checkResponse(response);

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
      final response = await ApiService.get('/api/profile/dashboard');
      ApiService.checkResponse(response);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'error': false,
          'totalCommunities': data['totalCommunities'] ?? 0,
          'totalCampaigns': data['totalCampaigns'] ?? 0,
          'totalServices': data['totalServices'] ?? 0,
          'communities': data['communities'] ?? [],
          'campaigns': data['campaigns'] ?? [],
        };
      } else {
        return {
          'error': true,
          'message': 'Failed to fetch dashboard counts',
          'totalCommunities': 0,
          'totalCampaigns': 0,
          'totalServices': 0,
          'communities': [],
          'campaigns': [],
        };
      }
    } catch (e) {
      return {
        'error': true,
        'message': 'Error: ${e.toString()}',
        'totalCommunities': 0,
        'totalCampaigns': 0,
        'totalServices': 0,
        'communities': [],
        'campaigns': [],
      };
    }
  }
}
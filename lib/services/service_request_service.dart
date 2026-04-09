import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ixes.app/constants/apiConstants.dart';
import 'package:ixes.app/services/api_service.dart';

class ServiceRequestService {
  Future<Map<String, dynamic>> getAllServiceRequests({
    String? status,
    String? communityId,
    String? userId,
  }) async {
    try {
      final queryParams = <String, String>{
        if (status != null) 'status': status,
        if (communityId != null) 'communityId': communityId,
        if (userId != null) 'userId': userId,
      };

      final queryString = queryParams.entries
          .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
          .join('&');

      final endpoint = queryString.isEmpty
          ? '/api/service-requests'
          : '/api/service-requests?$queryString';

      final response = await ApiService.get(endpoint);
      ApiService.checkResponse(response);

      print('getAllServiceRequests - Status Code: ${response.statusCode}');
      print('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return {
          'error': false,
          'message': decoded['message'] ?? 'Success',
          'data': decoded['data'],
        };
      } else {
        final decoded = jsonDecode(response.body);
        return {
          'error': true,
          'message': decoded['message'] ?? 'Failed to fetch service requests',
          'data': null,
        };
      }
    } catch (e) {
      print('Error in getAllServiceRequests: $e');
      return {
        'error': true,
        'message': 'Error: ${e.toString()}',
        'data': null,
      };
    }
  }

  Future<Map<String, dynamic>> createServiceRequest({
    required String subject,
    required String description,
    required String category,
    required String priority,
    String? communityId,
    String? assignedTo,
  }) async {
    try {
      final body = {
        'subject': subject,
        'description': description,
        'category': category,
        'priority': priority,
        if (communityId != null) 'communityId': communityId,
        if (assignedTo != null && assignedTo.isNotEmpty) 'assignedTo': assignedTo,
      };

      final response = await ApiService.post('/api/service-requests', body);
      ApiService.checkResponse(response);

      print('createServiceRequest - Status Code: ${response.statusCode}');
      print('Response Body: ${response.body}');

      if (response.statusCode == 201) {
        final decoded = jsonDecode(response.body);
        return {
          'error': false,
          'message': decoded['message'] ?? 'Service request created successfully',
          'data': decoded['data'],
        };
      } else {
        final decoded = jsonDecode(response.body);
        return {
          'error': true,
          'message': decoded['message'] ?? 'Failed to create service request',
          'data': null,
        };
      }
    } catch (e) {
      print('Error in createServiceRequest: $e');
      return {
        'error': true,
        'message': 'Error: ${e.toString()}',
        'data': null,
      };
    }
  }

  Future<Map<String, dynamic>> getServiceRequestById(String requestId) async {
    try {
      final response = await ApiService.get('/api/service-requests/$requestId');
      ApiService.checkResponse(response);

      print('getServiceRequestById - Status Code: ${response.statusCode}');
      print('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return {
          'error': false,
          'message': 'Service request retrieved successfully',
          'data': decoded['data'],
        };
      } else {
        final decoded = jsonDecode(response.body);
        return {
          'error': true,
          'message': decoded['message'] ?? 'Failed to get service request',
          'data': null,
        };
      }
    } catch (e) {
      print('Error in getServiceRequestById: $e');
      return {
        'error': true,
        'message': 'Error: ${e.toString()}',
        'data': null,
      };
    }
  }

  Future<Map<String, dynamic>> updateServiceRequest({
    required String requestId,
    String? subject,
    String? description,
    String? category,
    String? priority,
    String? status,
    String? assignedTo,
    String? completedBy,
  }) async {
    try {
      final body = {
        if (subject != null) 'subject': subject,
        if (description != null) 'description': description,
        if (category != null) 'category': category,
        if (priority != null) 'priority': priority,
        if (status != null) 'status': status,
        if (assignedTo != null) 'assignedTo': assignedTo,
        if (completedBy != null) 'completedBy': completedBy,
      };

      final response = await ApiService.put(
          '/api/service-requests/$requestId', body);
      ApiService.checkResponse(response);

      print('updateServiceRequest - Status Code: ${response.statusCode}');
      print('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return {
          'error': false,
          'message': decoded['message'] ?? 'Service request updated successfully',
          'data': decoded['data'],
        };
      } else {
        final decoded = jsonDecode(response.body);
        return {
          'error': true,
          'message': decoded['message'] ?? 'Failed to update service request',
          'data': null,
        };
      }
    } catch (e) {
      print('Error in updateServiceRequest: $e');
      return {
        'error': true,
        'message': 'Error: ${e.toString()}',
        'data': null,
      };
    }
  }

  Future<Map<String, dynamic>> deleteServiceRequest(String requestId) async {
    try {
      final response = await ApiService.delete(
          '/api/service-requests/$requestId');
      ApiService.checkResponse(response);

      print('deleteServiceRequest - Status Code: ${response.statusCode}');
      print('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return {
          'error': false,
          'message': decoded['message'] ?? 'Service request deleted successfully',
          'data': null,
        };
      } else {
        final decoded = jsonDecode(response.body);
        return {
          'error': true,
          'message': decoded['message'] ?? 'Failed to delete service request',
          'data': null,
        };
      }
    } catch (e) {
      print('Error in deleteServiceRequest: $e');
      return {
        'error': true,
        'message': 'Error: ${e.toString()}',
        'data': null,
      };
    }
  }
}
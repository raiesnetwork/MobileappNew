import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ixes.app/constants/apiConstants.dart';

class ServiceRequestService {
  Future<Map<String, dynamic>> getAllServiceRequests({
    String? status,
    String? communityId,
    String? userId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null || token.isEmpty) {
        return {
          'error': true,
          'message': 'Authentication token is missing',
          'data': null,
        };
      }

      final queryParams = {
        if (status != null) 'status': status,
        if (communityId != null) 'communityId': communityId,
        if (userId != null) 'userId': userId,
      };

      final uri = Uri.parse('${apiBaseUrl}api/service-requests').replace(queryParameters: queryParams);
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

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
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null || token.isEmpty) {
        return {
          'error': true,
          'message': 'Authentication token is missing',
          'data': null,
        };
      }

      final body = {
        'subject': subject,
        'description': description,
        'category': category,
        'priority': priority,
        if (communityId != null) 'communityId': communityId,
      };

      final uri = Uri.parse('${apiBaseUrl}api/service-requests');
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

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
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null || token.isEmpty) {
        return {
          'error': true,
          'message': 'Authentication token is missing',
          'data': null,
        };
      }

      final uri = Uri.parse('${apiBaseUrl}api/service-requests/$requestId');
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

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
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null || token.isEmpty) {
        return {
          'error': true,
          'message': 'Authentication token is missing',
          'data': null,
        };
      }

      final body = {
        if (subject != null) 'subject': subject,
        if (description != null) 'description': description,
        if (category != null) 'category': category,
        if (priority != null) 'priority': priority,
        if (status != null) 'status': status,
        if (assignedTo != null) 'assignedTo': assignedTo,
        if (completedBy != null) 'completedBy': completedBy,
      };

      final uri = Uri.parse('${apiBaseUrl}api/service-requests/$requestId');
      final response = await http.put(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

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
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null || token.isEmpty) {
        return {
          'error': true,
          'message': 'Authentication token is missing',
          'data': null,
        };
      }

      final uri = Uri.parse('${apiBaseUrl}api/service-requests/$requestId');
      final response = await http.delete(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

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
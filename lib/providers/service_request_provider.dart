import 'package:flutter/material.dart';
import '../services/service_request_service.dart';

class ServiceRequestProvider extends ChangeNotifier {
  final ServiceRequestService _service = ServiceRequestService();

  List<Map<String, dynamic>> _requests = [];
  bool _isLoading = false;
  String? _error;
  Map<String, dynamic>? _currentRequest;

  List<Map<String, dynamic>> get requests => _requests;
  bool get isLoading => _isLoading;
  String? get error => _error;
  Map<String, dynamic>? get currentRequest => _currentRequest;

  Future<void> fetchServiceRequests({
    String? status,
    String? communityId,
    String? userId,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _service.getAllServiceRequests(
        status: status,
        communityId: communityId,
        userId: userId,
      );

      if (response['error'] == false) {
        _requests = List<Map<String, dynamic>>.from(response['data'] ?? []);
        _error = null;
      } else {
        _error = response['message'] ?? 'Unknown error occurred';
        _requests = [];
      }
    } catch (e) {
      _error = 'Failed to fetch service requests: ${e.toString()}';
      _requests = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<Map<String, dynamic>> createServiceRequest({
    required String subject,
    required String description,
    required String category,
    required String priority,
    String? communityId,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _service.createServiceRequest(
        subject: subject,
        description: description,
        category: category,
        priority: priority,
        communityId: communityId,
      );

      if (response['error'] == false) {
        _error = null;
        await fetchServiceRequests(communityId: communityId);
        return {
          'error': false,
          'message': response['message'] ?? 'Service request created successfully',
          'data': response['data'],
        };
      } else {
        _error = response['message'] ?? 'Failed to create service request';
        return {
          'error': true,
          'message': _error,
          'data': null,
        };
      }
    } catch (e) {
      _error = 'Failed to create service request: ${e.toString()}';
      return {
        'error': true,
        'message': _error,
        'data': null,
      };
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> getServiceRequestById(String requestId) async {
    _isLoading = true;
    _error = null;
    _currentRequest = null;
    notifyListeners();

    try {
      final response = await _service.getServiceRequestById(requestId);

      if (response['error'] == false) {
        _currentRequest = response['data'];
        _error = null;
        return {
          'error': false,
          'message': response['message'] ?? 'Service request retrieved successfully',
          'data': response['data'],
        };
      } else {
        _error = response['message'] ?? 'Failed to get service request';
        return {
          'error': true,
          'message': _error,
          'data': null,
        };
      }
    } catch (e) {
      _error = 'Failed to get service request: ${e.toString()}';
      return {
        'error': true,
        'message': _error,
        'data': null,
      };
    } finally {
      _isLoading = false;
      notifyListeners();
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
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _service.updateServiceRequest(
        requestId: requestId,
        subject: subject,
        description: description,
        category: category,
        priority: priority,
        status: status,
        assignedTo: assignedTo,
        completedBy: completedBy,
      );

      if (response['error'] == false) {
        _error = null;
        await fetchServiceRequests(); // Refresh the requests list
        return {
          'error': false,
          'message': response['message'] ?? 'Service request updated successfully',
          'data': response['data'],
        };
      } else {
        _error = response['message'] ?? 'Failed to update service request';
        return {
          'error': true,
          'message': _error,
          'data': null,
        };
      }
    } catch (e) {
      _error = 'Failed to update service request: ${e.toString()}';
      return {
        'error': true,
        'message': _error,
        'data': null,
      };
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> deleteServiceRequest(String requestId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _service.deleteServiceRequest(requestId);

      if (response['error'] == false) {
        _error = null;
        await fetchServiceRequests(); // Refresh the requests list
        return {
          'error': false,
          'message': response['message'] ?? 'Service request deleted successfully',
          'data': null,
        };
      } else {
        _error = response['message'] ?? 'Failed to delete service request';
        return {
          'error': true,
          'message': _error,
          'data': null,
        };
      }
    } catch (e) {
      _error = 'Failed to delete service request: ${e.toString()}';
      return {
        'error': true,
        'message': _error,
        'data': null,
      };
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void clearCurrentRequest() {
    _currentRequest = null;
    notifyListeners();
  }
}
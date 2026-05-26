import 'dart:io';
import 'package:flutter/material.dart';
import '../services/service_request_service.dart';

class ServiceRequestProvider extends ChangeNotifier {
  final ServiceRequestService _service = ServiceRequestService();

  List<Map<String, dynamic>> _requests = [];
  List<Map<String, dynamic>> _assignedRequests = [];
  bool _isLoading = false;
  String? _error;
  Map<String, dynamic>? _currentRequest;

  List<Map<String, dynamic>> get requests => _requests;
  List<Map<String, dynamic>> get assignedRequests => _assignedRequests;
  bool get isLoading => _isLoading;
  String? get error => _error;
  Map<String, dynamic>? get currentRequest => _currentRequest;

  // ─────────────────────────────────────────────
  // FETCH ALL
  // ─────────────────────────────────────────────
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
        _assignedRequests = List<Map<String, dynamic>>.from(
            response['userAssignedRequests'] ?? []);
        _error = null;
      } else {
        _error = response['message'] ?? 'Unknown error occurred';
        _requests = [];
        _assignedRequests = [];
      }
    } catch (e) {
      _error = 'Failed to fetch service requests: ${e.toString()}';
      _requests = [];
      _assignedRequests = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  // ─────────────────────────────────────────────
  // CREATE
  // ─────────────────────────────────────────────
  Future<Map<String, dynamic>> createServiceRequest({
    required String subject,
    required String description,
    required String category,
    required String priority,
    String? communityId,
    String? assignedTo,
    String? dueDate,
    String? source,
    String? email,
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
        assignedTo: assignedTo,
        dueDate: dueDate,
        source: source,
        email: email,
      );

      if (response['error'] == false) {
        _error = null;
        await fetchServiceRequests(communityId: communityId);
        return {
          'error': false,
          'message':
          response['message'] ?? 'Service request created successfully',
          'data': response['data'],
        };
      } else {
        _error = response['message'] ?? 'Failed to create service request';
        return {'error': true, 'message': _error, 'data': null};
      }
    } catch (e) {
      _error = 'Failed to create service request: ${e.toString()}';
      return {'error': true, 'message': _error, 'data': null};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  int _assignedToMeCount = 0;
  int get assignedToMeCount => _assignedToMeCount;

  Future<void> fetchAssignedToMeCount(String userId) async {
    try {
      final response = await _service.getAllServiceRequests(userId: userId);
      if (response['error'] == false) {
        _assignedToMeCount =
            (response['userAssignedRequests'] as List?)?.length ?? 0;
        notifyListeners();
      }
    } catch (_) {}
  }

  // ─────────────────────────────────────────────
  // GET BY ID
  // ─────────────────────────────────────────────
  Future<Map<String, dynamic>> getServiceRequestById(String requestId) async {
    _isLoading = true;
    _error = null;
    _currentRequest = null;
    notifyListeners();

    try {
      final response = await _service.getServiceRequestById(requestId);

      if (response['error'] == false) {
        _currentRequest = response['data'] != null
            ? Map<String, dynamic>.from(
            response['data'] as Map<String, dynamic>)
            : null;
        _error = null;
        return {
          'error': false,
          'message': response['message'] ?? 'Retrieved successfully',
          'data': response['data'],
        };
      } else {
        _error = response['message'] ?? 'Failed to get service request';
        return {'error': true, 'message': _error, 'data': null};
      }
    } catch (e) {
      _error = 'Failed to get service request: ${e.toString()}';
      return {'error': true, 'message': _error, 'data': null};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ─────────────────────────────────────────────
  // UPDATE (status / notes / files)
  //
  // FIX 1: Always update _currentRequest immediately from the
  //         response data so the UI reflects new files, status,
  //         and working notes without a separate API call.
  //
  // FIX 2: Call notifyListeners() right after setting
  //         _currentRequest so the screen re-renders instantly
  //         before the background fetchServiceRequests completes.
  // ─────────────────────────────────────────────
  Future<Map<String, dynamic>> updateServiceRequest({
    required String requestId,
    String? subject,
    String? description,
    String? category,
    String? priority,
    String? status,
    String? assignedTo,
    String? completedBy,
    String? nextAction,
    String? dueDate,
    List<File>? files,
    String? communityId,
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
        nextAction: nextAction,
        dueDate: dueDate,
        files: files,
      );

      if (response['data'] != null) {
        final newData = Map<String, dynamic>.from(
            response['data'] as Map<String, dynamic>);

        // ✅ Backend doesn't return files on PUT — preserve existing ones
        if (newData['files'] == null && _currentRequest?['files'] != null) {
          newData['files'] = _currentRequest!['files'];
        }

        _currentRequest = newData;
      }

      _isLoading = false;
      notifyListeners();

      await fetchServiceRequests(communityId: communityId);

// ✅ Always refresh from server to get real file URLs after upload
      if (files != null && files.isNotEmpty) {
        await getServiceRequestById(requestId);


        return {
          'error': false,
          'message':
          response['message'] ?? 'Service request updated successfully',
          'data': response['data'],
        };
      } else {
        _error = response['message'] ?? 'Failed to update service request';
        return {'error': true, 'message': _error, 'data': null};
      }
    } catch (e) {
      _error = 'Failed to update service request: ${e.toString()}';
      return {'error': true, 'message': _error, 'data': null};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ─────────────────────────────────────────────
  // DELETE
  // ─────────────────────────────────────────────
  Future<Map<String, dynamic>> deleteServiceRequest(
      String requestId, {
        String? communityId,
      }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _service.deleteServiceRequest(requestId);

      if (response['error'] == false) {
        _error = null;
        // Clear currentRequest if it was the deleted one
        if (_currentRequest != null &&
            _currentRequest!['_id'] == requestId) {
          _currentRequest = null;
        }
        await fetchServiceRequests(communityId: communityId);
        return {
          'error': false,
          'message':
          response['message'] ?? 'Service request deleted successfully',
          'data': null,
        };
      } else {
        _error = response['message'] ?? 'Failed to delete service request';
        return {'error': true, 'message': _error, 'data': null};
      }
    } catch (e) {
      _error = 'Failed to delete service request: ${e.toString()}';
      return {'error': true, 'message': _error, 'data': null};
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
  void injectFiles(List<Map<String, dynamic>> files) {
    if (_currentRequest != null) {
      _currentRequest!['files'] = files;
      notifyListeners();
    }
  }
}
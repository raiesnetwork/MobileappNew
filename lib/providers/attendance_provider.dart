import 'package:flutter/material.dart';
import '../services/attendance_service.dart';

class AttendanceProvider extends ChangeNotifier {
  final AttendanceService _service = AttendanceService();

  List<Map<String, dynamic>> _history = [];
  Map<String, dynamic>? _todayAttendance;
  bool _isLoading = false;
  bool _isMarking = false;
  String? _error;
  String? _successMessage;

  List<Map<String, dynamic>> get history => _history;
  Map<String, dynamic>? get todayAttendance => _todayAttendance;
  bool get isLoading => _isLoading;
  bool get isMarking => _isMarking;
  String? get error => _error;
  String? get successMessage => _successMessage;

  // ✅ Has marked today already
  bool get hasMarkedToday => _todayAttendance != null;

  // ─────────────────────────────────────────────
  // MARK ATTENDANCE
  // ─────────────────────────────────────────────
  Future<Map<String, dynamic>> markAttendance({
    required String studentId,
    required String tenantId,
    required String status,
    required double latitude,
    required double longitude,
    required String address,
    String? remark,
  }) async {
    _isMarking = true;
    _error = null;
    _successMessage = null;
    notifyListeners();

    try {
      final response = await _service.markAttendance(
        studentId: studentId,
        tenantId: tenantId,
        status: status,
        latitude: latitude,
        longitude: longitude,
        address: address,
        remark: remark,
      );

      if (response['error'] == false) {
        _successMessage = response['message'];
        // Refresh today's attendance after marking
        await getTodayAttendance(
          studentId: studentId,
          tenantId: tenantId,
        );
        return {'error': false, 'message': _successMessage};
      } else {
        _error = response['message'];
        return {'error': true, 'message': _error};
      }
    } catch (e) {
      _error = e.toString();
      return {'error': true, 'message': _error};
    } finally {
      _isMarking = false;
      notifyListeners();
    }
  }

  // ─────────────────────────────────────────────
  // GET HISTORY
  // ─────────────────────────────────────────────
  Future<void> getAttendanceHistory({
    required String studentId,
    required String tenantId,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _service.getAttendanceHistory(
        studentId: studentId,
        tenantId: tenantId,
      );

      if (response['error'] == false) {
        _history = List<Map<String, dynamic>>.from(response['data'] ?? []);
        _error = null;
      } else {
        _error = response['message'];
        _history = [];
      }
    } catch (e) {
      _error = e.toString();
      _history = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ─────────────────────────────────────────────
  // GET TODAY
  // ─────────────────────────────────────────────
  Future<void> getTodayAttendance({
    required String studentId,
    required String tenantId,
  }) async {
    try {
      final response = await _service.getTodayAttendance(
        studentId: studentId,
        tenantId: tenantId,
      );

      if (response['error'] == false) {
        _todayAttendance = response['data'] != null
            ? Map<String, dynamic>.from(response['data'])
            : null;
      } else {
        _todayAttendance = null;
      }
      notifyListeners();
    } catch (e) {
      _todayAttendance = null;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void reset() {
    _history = [];
    _todayAttendance = null;
    _error = null;
    _successMessage = null;
    _isLoading = false;
    _isMarking = false;
    notifyListeners();
  }
}
import 'package:flutter/material.dart';
import '../services/attendance_service.dart';

class AttendanceProvider extends ChangeNotifier {
  final AttendanceService _service = AttendanceService();

  List<Map<String, dynamic>> _history        = [];
  Map<String, dynamic>?      _todayAttendance;
  bool    _isLoading = false;
  bool    _isMarking = false;
  String? _error;
  String? _successMessage;

  List<Map<String, dynamic>> get history         => _history;
  Map<String, dynamic>?      get todayAttendance => _todayAttendance;
  bool    get isLoading      => _isLoading;
  bool    get isMarking      => _isMarking;
  String? get error          => _error;
  String? get successMessage => _successMessage;

  /// True when attendance is already marked for today
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
    if (hasMarkedToday) {
      return {
        'error': true,
        'message': 'Attendance already marked for today',
      };
    }

    _isMarking = true;
    _error = null;
    _successMessage = null;
    notifyListeners();

    try {
      final response = await _service.markAttendance(
        studentId: studentId,
        tenantId:  tenantId,
        status:    status,
        latitude:  latitude,
        longitude: longitude,
        address:   address,
        remark:    remark,
      );

      if (response['error'] == false) {
        _successMessage = response['message'];

        final data = response['data'];
        if (data != null) {
          _todayAttendance = Map<String, dynamic>.from(data);
        } else {
          _todayAttendance = {
            'status':    status,
            'remark':    remark ?? '',
            'createdAt': DateTime.now().toUtc().toIso8601String(),
            'location': {
              'latitude':  latitude,
              'longitude': longitude,
              'address':   address,
            },
          };
        }

        notifyListeners();

        _refreshTodayInBackground(studentId: studentId, tenantId: tenantId);

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

  Future<void> _refreshTodayInBackground({
    required String studentId,
    required String tenantId,
  }) async {
    try {
      final response = await _service.getTodayAttendance(
        studentId: studentId,
        tenantId:  tenantId,
      );
      if (response['error'] == false && response['data'] != null) {
        _todayAttendance = Map<String, dynamic>.from(response['data']);
        notifyListeners();
      }
    } catch (_) {}
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
        tenantId:  tenantId,
      );

      if (response['error'] == false) {
        _history = List<Map<String, dynamic>>.from(response['data'] ?? []);
        _error   = null;
      } else {
        _error   = response['message'];
        _history = [];
      }
    } catch (e) {
      _error   = e.toString();
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
    // FIX: do NOT reset _todayAttendance to null before the async call.
    // The old code did `_todayAttendance = null` here which caused the
    // "Already Marked" view to flash back to the form every time the
    // screen was opened, because hasMarkedToday briefly became false
    // while the network request was in flight.
    //
    // Instead: only update if the server returns a valid record.
    // If we already have a local record (from markAttendance), keep it
    // until the server confirms otherwise.

    try {
      final response = await _service.getTodayAttendance(
        studentId: studentId,
        tenantId:  tenantId,
      );

      if (response['error'] == false) {
        if (response['data'] != null) {
          // Server found a record — use it (may have more fields than local)
          _todayAttendance = Map<String, dynamic>.from(response['data']);
        } else {
          // Server says no record today — only clear if we don't already
          // have a freshly-marked local record (avoid race with mark API)
          if (!hasMarkedToday) {
            _todayAttendance = null;
          }
        }
      }
      notifyListeners();
    } catch (e) {
      // On error keep whatever we have — don't clear a valid local record
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void reset() {
    _history         = [];
    _todayAttendance = null;
    _error           = null;
    _successMessage  = null;
    _isLoading       = false;
    _isMarking       = false;
    notifyListeners();
  }
}
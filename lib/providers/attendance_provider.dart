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
    // Guard: never mark twice in the same session
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

        // ✅ KEY FIX: set _todayAttendance directly from the mark response
        // so hasMarkedToday becomes true immediately — don't depend on
        //
        // dayAttendance API which may return null right after marking.
        final data = response['data'];
        if (data != null) {
          _todayAttendance = Map<String, dynamic>.from(data);
        } else {
          // Fallback: construct a minimal record so hasMarkedToday is true
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

        // Also try to refresh from server in background (non-blocking)
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

  /// Quietly refresh today's record from server in background.
  /// If server returns a valid record it replaces the local one.
  /// If it returns null we keep what we already have.
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
      // If data is null, keep the locally-set record — don't overwrite with null
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
    _todayAttendance = null; // reset without notifying

    try {
      final response = await _service.getTodayAttendance(
        studentId: studentId,
        tenantId:  tenantId,
      );

      if (response['error'] == false) {
        if (response['data'] != null) {
          _todayAttendance = Map<String, dynamic>.from(response['data']);
        } else {
          _todayAttendance = null;
        }
      }
      notifyListeners(); // only notify AFTER the async call completes
    } catch (e) {
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
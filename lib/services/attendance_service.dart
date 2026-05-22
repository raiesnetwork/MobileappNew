import 'dart:convert';
import 'package:ixes.app/services/api_service.dart';

class AttendanceService {

  static Map<String, dynamic>? _safeJsonDecode(String body) {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

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
    try {
      final body = {
        'studentId': studentId,
        'tenantId': tenantId,
        'status': status,
        if (remark != null && remark.isNotEmpty) 'remark': remark,
        'location': {
          'latitude': latitude,
          'longitude': longitude,
          'address': address,
        },
      };

      print('📤 [MARK ATTENDANCE] Sending request...');
      print('📤 [MARK ATTENDANCE] studentId: $studentId');
      print('📤 [MARK ATTENDANCE] tenantId: $tenantId');
      print('📤 [MARK ATTENDANCE] status: $status');
      print('📤 [MARK ATTENDANCE] remark: $remark');
      print('📤 [MARK ATTENDANCE] location: { lat: $latitude, lng: $longitude, address: $address }');
      print('📤 [MARK ATTENDANCE] Full body: ${jsonEncode(body)}');

      final response = await ApiService.post(
        '/api/communities/attendance/mark',
        body,
      );

      print('📥 [MARK ATTENDANCE] Status code: ${response.statusCode}');
      print('📥 [MARK ATTENDANCE] Response body: ${response.body}');

      ApiService.checkResponse(response);

      final decoded = _safeJsonDecode(response.body);

      if (decoded == null) {
        print('❌ [MARK ATTENDANCE] Failed to decode response JSON');
        return {
          'error': true,
          'message': 'Invalid response from server',
          'data': null,
        };
      }

      if (response.statusCode == 201) {
        print('✅ [MARK ATTENDANCE] Success: ${decoded['message']}');
        return {
          'error': false,
          'message': decoded['message'] ?? 'Attendance marked successfully',
          'data': decoded['data'],
        };
      }

      print('❌ [MARK ATTENDANCE] Failed with status ${response.statusCode}: ${decoded['message']}');
      return {
        'error': true,
        'message': decoded['message'] ?? 'Failed to mark attendance',
        'data': null,
      };
    } catch (e, stackTrace) {
      print('💥 [MARK ATTENDANCE] Exception: $e');
      print('💥 [MARK ATTENDANCE] StackTrace: $stackTrace');
      return {
        'error': true,
        'message': 'Error: ${e.toString()}',
        'data': null,
      };
    }
  }

  // ─────────────────────────────────────────────
  // GET ATTENDANCE HISTORY
  // ─────────────────────────────────────────────
  Future<Map<String, dynamic>> getAttendanceHistory({
    required String studentId,
    required String tenantId,
  }) async {
    try {
      print('📤 [ATTENDANCE HISTORY] Fetching for studentId: $studentId, tenantId: $tenantId');

      final response = await ApiService.get(
        '/api/communities/attendance/history/$studentId/$tenantId',
      );

      print('📥 [ATTENDANCE HISTORY] Status code: ${response.statusCode}');
      print('📥 [ATTENDANCE HISTORY] Response body: ${response.body}');

      ApiService.checkResponse(response);

      final decoded = _safeJsonDecode(response.body);

      if (decoded == null) {
        print('❌ [ATTENDANCE HISTORY] Failed to decode JSON');
        return {
          'error': true,
          'message': 'Invalid response from server',
          'data': [],
        };
      }

      if (response.statusCode == 200) {
        final data = decoded['data'] ?? [];
        print('✅ [ATTENDANCE HISTORY] Success — ${(data as List).length} records found');
        return {
          'error': false,
          'message': 'History fetched successfully',
          'data': data,
        };
      }

      print('❌ [ATTENDANCE HISTORY] Failed: ${decoded['message']}');
      return {
        'error': true,
        'message': decoded['message'] ?? 'Failed to fetch attendance history',
        'data': [],
      };
    } catch (e, stackTrace) {
      print('💥 [ATTENDANCE HISTORY] Exception: $e');
      print('💥 [ATTENDANCE HISTORY] StackTrace: $stackTrace');
      return {
        'error': true,
        'message': 'Error: ${e.toString()}',
        'data': [],
      };
    }
  }

  // ─────────────────────────────────────────────
  // GET TODAY ATTENDANCE
  // ─────────────────────────────────────────────
  Future<Map<String, dynamic>> getTodayAttendance({
    required String studentId,
    required String tenantId,
  }) async {
    try {
      print('📤 [TODAY ATTENDANCE] Fetching for studentId: $studentId, tenantId: $tenantId');

      final response = await ApiService.get(
        '/api/communities/attendance/today/$studentId/$tenantId',
      );

      print('📥 [TODAY ATTENDANCE] Status code: ${response.statusCode}');
      print('📥 [TODAY ATTENDANCE] Response body: ${response.body}');

      ApiService.checkResponse(response);

      final decoded = _safeJsonDecode(response.body);

      if (decoded == null) {
        print('❌ [TODAY ATTENDANCE] Failed to decode JSON');
        return {
          'error': true,
          'message': 'Invalid response from server',
          'data': null,
        };
      }

      if (response.statusCode == 200) {
        print('✅ [TODAY ATTENDANCE] Success — data: ${decoded['data']}');
        return {
          'error': false,
          'message': "Today's attendance fetched",
          'data': decoded['data'],
        };
      }

      print('❌ [TODAY ATTENDANCE] Failed: ${decoded['message']}');
      return {
        'error': true,
        'message': decoded?['message'] ?? 'Failed to fetch today attendance',
        'data': null,
      };
    } catch (e, stackTrace) {
      print('💥 [TODAY ATTENDANCE] Exception: $e');
      print('💥 [TODAY ATTENDANCE] StackTrace: $stackTrace');
      return {
        'error': true,
        'message': 'Error: ${e.toString()}',
        'data': null,
      };
    }
  }
}
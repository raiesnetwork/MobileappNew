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
    final stopwatch = Stopwatch()..start();
    final requestId = DateTime.now().millisecondsSinceEpoch.toString().substring(7);

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

      print('');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('📤 [MARK#$requestId] STARTING MARK ATTENDANCE REQUEST');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('📤 [MARK#$requestId] Time: ${DateTime.now().toIso8601String()}');
      print('📤 [MARK#$requestId] studentId: $studentId  (len: ${studentId.length})');
      print('📤 [MARK#$requestId] tenantId : $tenantId  (len: ${tenantId.length})');
      print('📤 [MARK#$requestId] status   : $status');
      print('📤 [MARK#$requestId] remark   : ${remark ?? "(empty)"}');
      print('📤 [MARK#$requestId] location : lat=$latitude  lng=$longitude');
      print('📤 [MARK#$requestId] address  : $address');
      print('📤 [MARK#$requestId] Body size: ${jsonEncode(body).length} bytes');
      print('📤 [MARK#$requestId] Full body: ${jsonEncode(body)}');

      // ── Sanity checks BEFORE sending ───────────────────────────────
      if (studentId.length != 24) {
        print('⚠️ [MARK#$requestId] studentId is NOT a valid 24-char ObjectId');
      }
      if (tenantId.length != 24) {
        print('⚠️ [MARK#$requestId] tenantId is NOT a valid 24-char ObjectId');
      }
      if (latitude == 0.0 && longitude == 0.0) {
        print('⚠️ [MARK#$requestId] Location is (0,0) — GPS may not be ready');
      }

      final response = await ApiService.post(
        '/api/communities/attendance/mark',
        body,
      );

      stopwatch.stop();

      print('');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('📥 [MARK#$requestId] RESPONSE RECEIVED in ${stopwatch.elapsedMilliseconds}ms');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('📥 [MARK#$requestId] Status code: ${response.statusCode}');
      print('📥 [MARK#$requestId] Response headers: ${response.headers}');
      print('📥 [MARK#$requestId] Response body: ${response.body}');
      print('📥 [MARK#$requestId] Body length: ${response.body.length} bytes');

      ApiService.checkResponse(response);

      final decoded = _safeJsonDecode(response.body);

      if (decoded == null) {
        print('❌ [MARK#$requestId] Backend returned non-JSON response — likely a crash page');
        return {
          'error': true,
          'message': 'Invalid response from server',
          'data': null,
          'statusCode': response.statusCode,
          'rawBody': response.body,
        };
      }

      print('📥 [MARK#$requestId] Decoded keys: ${decoded.keys.toList()}');
      print('📥 [MARK#$requestId] Decoded success: ${decoded['success']}');
      print('📥 [MARK#$requestId] Decoded message: ${decoded['message']}');
      print('📥 [MARK#$requestId] Decoded data   : ${decoded['data']}');
      if (decoded.containsKey('error')) {
        print('📥 [MARK#$requestId] Decoded error  : ${decoded['error']}');
      }
      if (decoded.containsKey('stack')) {
        print('📥 [MARK#$requestId] Backend stack  : ${decoded['stack']}');
      }

      if (response.statusCode == 201) {
        print('✅ [MARK#$requestId] SUCCESS');
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        return {
          'error': false,
          'message': decoded['message'] ?? 'Attendance marked successfully',
          'data': decoded['data'],
        };
      }

      print('❌ [MARK#$requestId] FAILED — status ${response.statusCode}');
      print('❌ [MARK#$requestId] Backend message: ${decoded['message']}');

      // ── Diagnose what likely went wrong ─────────────────────────────
      if (response.statusCode == 500) {
        print('🔍 [MARK#$requestId] DIAGNOSIS: Server-side exception. The backend');
        print('🔍 [MARK#$requestId]            caught an error but did not return it.');
        print('🔍 [MARK#$requestId]            Check backend logs (PM2 / CloudWatch / console)');
        print('🔍 [MARK#$requestId]            for the actual stack trace.');
        print('🔍 [MARK#$requestId]            Most likely cause: date-format duplicate-key');
        print('🔍 [MARK#$requestId]            error in markAttendance controller.');
      } else if (response.statusCode == 400) {
        print('🔍 [MARK#$requestId] DIAGNOSIS: Validation error from backend.');
      } else if (response.statusCode == 401) {
        print('🔍 [MARK#$requestId] DIAGNOSIS: Auth token expired or invalid.');
      } else if (response.statusCode == 403) {
        print('🔍 [MARK#$requestId] DIAGNOSIS: User not authorized for this resource.');
      } else if (response.statusCode == 404) {
        print('🔍 [MARK#$requestId] DIAGNOSIS: Endpoint or resource not found.');
      }
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      return {
        'error': true,
        'message': decoded['message'] ?? 'Failed to mark attendance',
        'data': null,
        'statusCode': response.statusCode,
      };
    } catch (e, stackTrace) {
      stopwatch.stop();
      print('');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('💥 [MARK#$requestId] EXCEPTION THROWN (after ${stopwatch.elapsedMilliseconds}ms)');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('💥 [MARK#$requestId] Error type: ${e.runtimeType}');
      print('💥 [MARK#$requestId] Error: $e');
      print('💥 [MARK#$requestId] StackTrace:');
      print('$stackTrace');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
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
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'package:ixes.app/constants/apiConstants.dart';
import 'package:ixes.app/services/api_service.dart';

class ServiceRequestService {

  // ─────────────────────────────────────────────
  // SAFE JSON DECODE
  // Prevents the "FormatException: <!DOCTYPE html>" crash
  // when the server returns an error page instead of JSON.
  // ─────────────────────────────────────────────
  static Map<String, dynamic>? _safeJsonDecode(String body) {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  // ─────────────────────────────────────────────
  // BUILD BASE URL
  // Ensures exactly one slash between base and path
  // regardless of whether apiBaseUrl has a trailing slash.
  // ─────────────────────────────────────────────
  static String _buildUrl(String path) {
    final base = apiBaseUrl.endsWith('/')
        ? apiBaseUrl.substring(0, apiBaseUrl.length - 1)
        : apiBaseUrl;
    final cleanPath = path.startsWith('/') ? path : '/$path';
    return '$base$cleanPath';
  }

  // ─────────────────────────────────────────────
  // GET ALL
  // ─────────────────────────────────────────────
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

      final decoded = _safeJsonDecode(response.body);
      if (response.statusCode == 200 && decoded != null) {
        return {
          'error': false,
          'message': decoded['message'] ?? 'Success',
          'data': decoded['data'],
          'userAssignedRequests': decoded['userAssignedRequests'] ?? [],
        };
      }
      return {
        'error': true,
        'message': decoded?['message'] ?? 'Failed to fetch service requests',
        'data': null,
        'userAssignedRequests': [],
      };
    } catch (e) {
      return {
        'error': true,
        'message': 'Error: ${e.toString()}',
        'data': null,
        'userAssignedRequests': [],
      };
    }
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
    try {
      final body = {
        'subject': subject,
        'description': description,
        'category': category,
        'priority': priority,
        if (communityId != null) 'communityId': communityId,
        if (assignedTo != null && assignedTo.isNotEmpty)
          'assignedTo': assignedTo,
        if (dueDate != null && dueDate.isNotEmpty) 'dueDate': dueDate,
        if (source != null && source.isNotEmpty) 'source': source,
        if (email != null && email.isNotEmpty) 'email': email,
      };

      final response = await ApiService.post('/api/service-requests', body);
      ApiService.checkResponse(response);

      final decoded = _safeJsonDecode(response.body);
      if (response.statusCode == 201 && decoded != null) {
        return {
          'error': false,
          'message':
          decoded['message'] ?? 'Service request created successfully',
          'data': decoded['data'],
        };
      }
      return {
        'error': true,
        'message': decoded?['message'] ?? 'Failed to create service request',
        'data': null,
      };
    } catch (e) {
      return {
        'error': true,
        'message': 'Error: ${e.toString()}',
        'data': null,
      };
    }
  }

  // ─────────────────────────────────────────────
  // GET BY ID
  // ─────────────────────────────────────────────
  Future<Map<String, dynamic>> getServiceRequestById(String requestId) async {
    try {
      final response =
      await ApiService.get('/api/service-requests/$requestId');
      ApiService.checkResponse(response);

      final decoded = _safeJsonDecode(response.body);
      if (response.statusCode == 200 && decoded != null) {
        return {
          'error': false,
          'message': 'Service request retrieved successfully',
          'data': decoded['data'],
        };
      }
      return {
        'error': true,
        'message': decoded?['message'] ?? 'Failed to get service request',
        'data': null,
      };
    } catch (e) {
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
    String? nextAction,
    String? dueDate,
    List<File>? files,
  }) async {
    try {
      final hasFiles = files != null && files.isNotEmpty;

      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('📤 [UPDATE SR] START');
      debugPrint('📤 [UPDATE SR] requestId = $requestId');
      debugPrint('📤 [UPDATE SR] hasFiles  = $hasFiles');
      debugPrint('📤 [UPDATE SR] fileCount = ${files?.length ?? 0}');
      debugPrint('📤 [UPDATE SR] status    = $status');
      debugPrint('📤 [UPDATE SR] nextAction= $nextAction');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      if (!hasFiles) {
        // ── JSON path ──────────────────────────────────────────────────
        final body = <String, dynamic>{};
        if (subject     != null && subject.isNotEmpty)     body['subject']     = subject;
        if (description != null && description.isNotEmpty) body['description'] = description;
        if (category    != null && category.isNotEmpty)    body['category']    = category;
        if (priority    != null && priority.isNotEmpty)    body['priority']    = priority;
        if (status      != null && status.isNotEmpty)      body['status']      = status;
        if (assignedTo  != null && assignedTo.isNotEmpty)  body['assignedTo']  = assignedTo;
        if (completedBy != null && completedBy.isNotEmpty) body['completedBy'] = completedBy;
        if (nextAction  != null && nextAction.isNotEmpty)  body['nextAction']  = nextAction;
        if (dueDate     != null && dueDate.isNotEmpty)     body['dueDate']     = dueDate;

        debugPrint('📤 [JSON PATH] body = $body');

        final response = await ApiService.put(
          '/api/service-requests/$requestId',
          body,
        );

        debugPrint('📥 [JSON PATH] statusCode = ${response.statusCode}');
        debugPrint('📥 [JSON PATH] full body:');
        final jBody = response.body;
        for (int i = 0; i < jBody.length; i += 800) {
          debugPrint('   ${jBody.substring(i, (i + 800).clamp(0, jBody.length))}');
        }

        final decoded = _safeJsonDecode(response.body);
        debugPrint('📥 [JSON PATH] decoded = $decoded');
        debugPrint('📥 [JSON PATH] decoded[data] = ${decoded?['data']}');
        debugPrint('📥 [JSON PATH] decoded[data][files] = ${decoded?['data']?['files']}');

        if (response.statusCode == 200 && decoded != null) {
          return {
            'error': false,
            'message': decoded['message'] ?? 'Service request updated successfully',
            'data': decoded['data'],
          };
        }
        return {
          'error': true,
          'message': decoded?['message'] ?? 'Failed to update (${response.statusCode})',
          'data': null,
        };

      } else {
        // ── Multipart path ─────────────────────────────────────────────
        final token = await ApiService.getValidToken();
        final url   = _buildUrl('/api/service-requests/$requestId');

        debugPrint('📤 [MULTIPART] url   = $url');
        debugPrint('📤 [MULTIPART] token = ${token?.substring(0, 20)}...');

        final request = http.MultipartRequest('PUT', Uri.parse(url))
          ..headers['Authorization'] = 'Bearer $token'
          ..headers['x-platform']    = 'mobile';

        // Text fields
        void addField(String key, String? value) {
          if (value != null && value.isNotEmpty) {
            request.fields[key] = value;
            debugPrint('📤 [MULTIPART] field: $key = $value');
          }
        }

        addField('subject',     subject);
        addField('description', description);
        addField('category',    category);
        addField('priority',    priority);
        addField('status',      status);
        addField('assignedTo',  assignedTo);
        addField('completedBy', completedBy);
        addField('nextAction',  nextAction);
        addField('dueDate',     dueDate);

        debugPrint('📤 [MULTIPART] total fields = ${request.fields.length}');

        // Files
        for (int i = 0; i < files.length; i++) {
          final file     = files[i];
          final mimeType = lookupMimeType(file.path) ?? 'application/octet-stream';
          final mimeParts = mimeType.split('/');
          final fileSize = await file.length();

          debugPrint('📎 [MULTIPART] file[$i] path     = ${file.path}');
          debugPrint('📎 [MULTIPART] file[$i] mimeType = $mimeType');
          debugPrint('📎 [MULTIPART] file[$i] size     = $fileSize bytes');
          debugPrint('📎 [MULTIPART] file[$i] exists   = ${await file.exists()}');

          request.files.add(await http.MultipartFile.fromPath(
            'files',
            file.path,
            contentType: MediaType(mimeParts[0], mimeParts[1]),
          ));

          debugPrint('📎 [MULTIPART] file[$i] added to request ✅');
        }

        debugPrint('📤 [MULTIPART] total files in request = ${request.files.length}');
        debugPrint('📤 [MULTIPART] sending request...');

        final streamed  = await request.send();
        final response  = await http.Response.fromStream(streamed);

        debugPrint('📥 [MULTIPART] statusCode        = ${response.statusCode}');
        debugPrint('📥 [MULTIPART] contentType       = ${response.headers['content-type']}');
        debugPrint('📥 [MULTIPART] response body length = ${response.body.length}');
        debugPrint('📥 [MULTIPART] full body:');
        final mBody = response.body;
        for (int i = 0; i < mBody.length; i += 800) {
          debugPrint('   ${mBody.substring(i, (i + 800).clamp(0, mBody.length))}');
        }

        final decoded = _safeJsonDecode(response.body);
        debugPrint('📥 [MULTIPART] decoded           = ${decoded != null ? "✅ valid JSON" : "❌ null (not JSON)"}');
        debugPrint('📥 [MULTIPART] decoded[data]     = ${decoded?['data']}');
        debugPrint('📥 [MULTIPART] decoded[data] keys= ${(decoded?['data'] as Map?)?.keys.toList()}');
        debugPrint('📥 [MULTIPART] decoded[data][files] = ${decoded?['data']?['files']}');
        debugPrint('📥 [MULTIPART] files count       = ${(decoded?['data']?['files'] as List?)?.length}');

        if (decoded?['data']?['files'] != null) {
          final filesList = decoded!['data']['files'] as List;
          for (int i = 0; i < filesList.length; i++) {
            debugPrint('📥 [MULTIPART] file[$i] = ${filesList[i]}');
            debugPrint('📥 [MULTIPART] file[$i] keys = ${(filesList[i] as Map?)?.keys.toList()}');
            debugPrint('📥 [MULTIPART] file[$i] fileName = ${filesList[i]['fileName']}');
            debugPrint('📥 [MULTIPART] file[$i] fileUrl  = ${filesList[i]['fileUrl']}');
          }
        } else {
          debugPrint('⚠️ [MULTIPART] files key is NULL in response — backend not returning files');
        }

        debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

        if (response.statusCode == 200 && decoded != null) {
          return {
            'error': false,
            'message': decoded['message'] ?? 'Files uploaded successfully',
            'data':    decoded['data'],
          };
        }
        return {
          'error': true,
          'message': decoded?['message'] ?? 'Upload failed (${response.statusCode})',
          'data': null,
        };
      }
    } catch (e, stack) {
      debugPrint('❌ [UPDATE SR] Exception: $e');
      debugPrint('❌ [UPDATE SR] Stack: $stack');
      return {
        'error': true,
        'message': 'Error: ${e.toString()}',
        'data': null,
      };
    }
  }

  // ─────────────────────────────────────────────
  // DELETE
  // ─────────────────────────────────────────────
  Future<Map<String, dynamic>> deleteServiceRequest(String requestId) async {
    try {
      final response =
      await ApiService.delete('/api/service-requests/$requestId');
      ApiService.checkResponse(response);

      final decoded = _safeJsonDecode(response.body);
      if (response.statusCode == 200 && decoded != null) {
        return {
          'error': false,
          'message':
          decoded['message'] ?? 'Service request deleted successfully',
          'data': null,
        };
      }
      return {
        'error': true,
        'message': decoded?['message'] ?? 'Failed to delete service request',
        'data': null,
      };
    } catch (e) {
      return {
        'error': true,
        'message': 'Error: ${e.toString()}',
        'data': null,
      };
    }
  }
}
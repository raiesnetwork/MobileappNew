import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ixes.app/services/socket_service.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ixes.app/constants/apiConstants.dart';

// ═══════════════════════════════════════════════════════════════════════════
// GroupChatService — pure HTTP only.
// Socket events are handled entirely in GroupChatProvider, NOT here.
// ═══════════════════════════════════════════════════════════════════════════
class GroupChatService {
  bool get isSocketConnected => SocketService().isConnected;

  // ── Log helpers ────────────────────────────────────────────────────────
  void _logRequest(String method, String endpoint,
      {Map<String, dynamic>? body}) {
    print('┌──────────────────────────────────────────────');
    print('│ 🚀 [$method] $endpoint');
    if (body != null) {
      final s = jsonEncode(body);
      print('│ 📦 ${s.length > 300 ? '${s.substring(0, 300)}...' : s}');
    }
    print('└──────────────────────────────────────────────');
  }

  void _logResponse(int code, String body, {String? label}) {
    final ok = code >= 200 && code < 300;
    final preview = body.length > 500 ? '${body.substring(0, 500)}…' : body;
    print('┌──────────────────────────────────────────────');
    print('│ ${ok ? '✅' : '❌'} [$label] $code');
    print('│ 📩 $preview');
    print('└──────────────────────────────────────────────');
  }

  void _logError(String label, dynamic e) {
    print('┌──────────────────────────────────────────────');
    print('│ 💥 EXCEPTION [$label]: $e');
    print('└──────────────────────────────────────────────');
  }

  // ── Auth ───────────────────────────────────────────────────────────────
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final t = prefs.getString('auth_token');
    if (t == null || t.isEmpty) {
      print('❗ [AUTH] Token missing!');
      return null;
    }
    print('🔑 [AUTH] ${t.substring(0, 12)}...');
    return t;
  }

  Map<String, String> _jsonHeaders(String token) => {
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json',
  };

  // ── Standard error returns ─────────────────────────────────────────────
  Map<String, dynamic> _noToken() =>
      {'error': true, 'message': 'Auth token missing', 'data': null};

  Map<String, dynamic> _noInternet(String l) {
    print('🌐 [$l] No internet');
    return {'error': true, 'message': 'No internet connection.', 'data': null};
  }

  Map<String, dynamic> _timeout(String l) {
    print('⏰ [$l] Timeout');
    return {'error': true, 'message': 'Request timed out. Try again.', 'data': null};
  }

  Map<String, dynamic> _exception(dynamic e) =>
      {'error': true, 'message': 'Error: ${e.toString()}', 'data': null};

  Map<String, dynamic> _apiError(http.Response r, String l) {
    final d = _safeJsonDecode(r);
    print('❌ [$l] HTTP ${r.statusCode}: ${d['message']}');
    return {
      'error': true,
      'message': d['message'] ?? 'Failed (${r.statusCode})',
      'data': null,
    };
  }

  // ── Safe JSON decode — guards against HTML 500 pages ──────────────────
  Map<String, dynamic> _safeJsonDecode(http.Response res) {
    try {
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      return {'error': true, 'message': 'Server error (${res.statusCode})'};
    }
  }

  // ── MIME type helper ───────────────────────────────────────────────────
  String _mimeTypeForFile(String path) {
    final ext = p.extension(path).toLowerCase().replaceFirst('.', '');
    const map = {
      'jpg': 'image/jpeg', 'jpeg': 'image/jpeg',
      'png':  'image/png',
      'gif':  'image/gif',
      'webp': 'image/webp',
      'pdf':  'application/pdf',
      'doc':  'application/msword',
      'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'xls':  'application/vnd.ms-excel',
      'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'ppt':  'application/vnd.ms-powerpoint',
      'pptx': 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      'txt':  'text/plain',
      'zip':  'application/zip',
      'rar':  'application/x-rar-compressed',
      'mp4':  'video/mp4',
      'mov':  'video/quicktime',
      'avi':  'video/x-msvideo',
      'mp3':  'audio/mpeg',
      'wav':  'audio/wav',
      'aac':  'audio/aac',
      'm4a':  'audio/mp4',
    };
    return map[ext] ?? 'application/octet-stream';
  }

  // ════════════════════════════════════════════════════════════════════════
  // 1. GET ALL GROUPS — GET /getallgroups?search=&pageNo=&limit=
  // ════════════════════════════════════════════════════════════════════════
  Future<Map<String, dynamic>> getAllGroups({
    String? searchQuery,
    int pageNo = 1,
    int limit = 20,
  }) async {
    const l = 'getAllGroups';
    try {
      final token = await _getToken();
      if (token == null) return _noToken();

      final params = {'pageNo': '$pageNo', 'limit': '$limit'};
      if (searchQuery != null && searchQuery.isNotEmpty) {
        params['search'] = searchQuery;
      }
      final uri = Uri.parse('${apiBaseUrl}api/chat/getallgroups')
          .replace(queryParameters: params);
      _logRequest('GET', uri.toString());

      final res = await http.get(uri, headers: _jsonHeaders(token))
          .timeout(const Duration(seconds: 30));
      _logResponse(res.statusCode, res.body, label: l);

      if (res.statusCode == 200) {
        final d = jsonDecode(res.body);
        final groups = d['data'] ?? [];
        print('📊 [$l] ${(groups as List).length} groups');
        return {'error': false, 'message': 'OK', 'data': groups};
      }
      return _apiError(res, l);
    } on SocketException { return _noInternet(l); }
    on TimeoutException  { return _timeout(l); }
    catch (e) { _logError(l, e); return _exception(e); }
  }

  // ════════════════════════════════════════════════════════════════════════
  // 2. GET MY GROUPS — GET /mygroups?communityId=&pageNo=&limit=
  // ════════════════════════════════════════════════════════════════════════
  Future<Map<String, dynamic>> getMyGroups({
    String? communityId,
    int pageNo = 1,
    int limit = 20,
  }) async {
    const l = 'getMyGroups';
    try {
      final token = await _getToken();
      if (token == null) return _noToken();

      final params = {'pageNo': '$pageNo', 'limit': '$limit'};
      if (communityId != null && communityId.isNotEmpty) {
        params['communityId'] = communityId;
      }
      final uri = Uri.parse('${apiBaseUrl}api/chat/mygroups')
          .replace(queryParameters: params);
      _logRequest('GET', uri.toString());

      final res = await http.get(uri, headers: _jsonHeaders(token))
          .timeout(const Duration(seconds: 30));
      _logResponse(res.statusCode, res.body, label: l);

      if (res.statusCode == 200) {
        final d = jsonDecode(res.body);
        final groups = d['data'] ?? [];
        print('📊 [$l] ${(groups as List).length} my groups');
        return {'error': false, 'message': 'OK', 'data': groups};
      }
      return _apiError(res, l);
    } on SocketException { return _noInternet(l); }
    on TimeoutException  { return _timeout(l); }
    catch (e) { _logError(l, e); return _exception(e); }
  }

  // ════════════════════════════════════════════════════════════════════════
  // 3. CREATE GROUP — POST /creategroup
  // ════════════════════════════════════════════════════════════════════════
  Future<Map<String, dynamic>> createGroup({
    required String name,
    required String description,
    String? profileImage,
    List<String> members = const [],
  }) async {
    const l = 'createGroup';
    try {
      final token = await _getToken();
      if (token == null) return _noToken();

      final body = {
        'name': name,
        'description': description,
        'members': members,
        if (profileImage != null && profileImage.isNotEmpty)
          'profileImage': profileImage,
      };
      _logRequest('POST', '${apiBaseUrl}api/chat/creategroup',
          body: {'name': name, 'description': description});

      final res = await http.post(
        Uri.parse('${apiBaseUrl}api/chat/creategroup'),
        headers: _jsonHeaders(token),
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 30));
      _logResponse(res.statusCode, res.body, label: l);

      if (res.statusCode == 200 || res.statusCode == 201) {
        final d = _safeJsonDecode(res);
        if (d['error'] == false || d['error'] == null) {
          print('✅ [$l] Created: ${d['data']?['_id']}');
          return {
            'error': false,
            'message': d['message'] ?? 'Group created',
            'data': d['data'],
          };
        }
        return {'error': true, 'message': d['message'] ?? 'Failed', 'data': null};
      }
      return _apiError(res, l);
    } on SocketException { return _noInternet(l); }
    on TimeoutException  { return _timeout(l); }
    catch (e) { _logError(l, e); return _exception(e); }
  }

  // ════════════════════════════════════════════════════════════════════════
  // 4. GET GROUP MESSAGES — GET /groupmessages/:id?pageNo=&limit=
  // ════════════════════════════════════════════════════════════════════════
  Future<Map<String, dynamic>> getGroupMessages(String groupId,
      {int pageNo = 1, int limit = 30}) async {
    const l = 'getGroupMessages';
    try {
      final token = await _getToken();
      if (token == null) return _noToken();

      final uri = Uri.parse('${apiBaseUrl}api/chat/groupmessages/$groupId')
          .replace(queryParameters: {
        'pageNo': '$pageNo',
        'limit': '$limit',
      });
      _logRequest('GET', uri.toString());

      final res = await http.get(uri, headers: _jsonHeaders(token))
          .timeout(const Duration(seconds: 30));
      _logResponse(res.statusCode, res.body, label: l);

      if (res.statusCode == 200) {
        final d = jsonDecode(res.body);
        final msgs = d['data'] ?? [];
        print('📨 [$l] ${(msgs as List).length} messages for $groupId');
        return {'error': false, 'message': 'OK', 'data': msgs};
      }
      return _apiError(res, l);
    } on SocketException { return _noInternet(l); }
    on TimeoutException  { return _timeout(l); }
    catch (e) { _logError(l, e); return _exception(e); }
  }

  // ════════════════════════════════════════════════════════════════════════
  // 5. SEND TEXT MESSAGE — POST /groupmessage
  // ════════════════════════════════════════════════════════════════════════
  Future<Map<String, dynamic>> sendGroupMessage({
    required String groupId,
    required String text,
    required Map<String, dynamic> communityInfo,
    String? image,
  }) async {
    const l = 'sendGroupMessage';
    try {
      final token = await _getToken();
      if (token == null) return _noToken();

      final body = {
        'groupId': groupId,
        'text': text,
        'communityInfo': communityInfo,
        if (image != null && image.isNotEmpty) 'image': image,
      };
      _logRequest('POST', '${apiBaseUrl}api/chat/groupmessage', body: {
        'groupId': groupId,
        'text': text.length > 60 ? '${text.substring(0, 60)}...' : text,
      });

      final res = await http.post(
        Uri.parse('${apiBaseUrl}api/chat/groupmessage'),
        headers: _jsonHeaders(token),
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 30));
      _logResponse(res.statusCode, res.body, label: l);

      if (res.statusCode == 200 || res.statusCode == 201) {
        final d = _safeJsonDecode(res);
        print('✅ [$l] msgId: ${d['message']?['_id']}');
        return {
          'error': d['error'] ?? false,
          'message': d['message'],
          'groupId': d['groupId'],
          'data': d['message'],
        };
      }
      return _apiError(res, l);
    } on SocketException { return _noInternet(l); }
    on TimeoutException  { return _timeout(l); }
    catch (e) { _logError(l, e); return _exception(e); }
  }

  // ════════════════════════════════════════════════════════════════════════
  // 6. SEND FILE MESSAGE — POST /groupfilemessage  (multipart)
  // ════════════════════════════════════════════════════════════════════════
  Future<Map<String, dynamic>> sendGroupFileMessage({
    required String groupId,
    required File file,
    Map<String, dynamic>? communityInfo,
  }) async {
    const l = 'sendGroupFileMessage';
    try {
      final token = await _getToken();
      if (token == null) return _noToken();

      final fileName = p.basename(file.path);
      final fileSize = await file.length();
      final mime    = _mimeTypeForFile(file.path);
      print('📤 [$l] $fileName — ${(fileSize / 1024).toStringAsFixed(1)} KB — $mime');
      _logRequest('POST multipart', '${apiBaseUrl}api/chat/groupfilemessage',
          body: {'groupId': groupId, 'file': fileName});

      final req = http.MultipartRequest(
          'POST', Uri.parse('${apiBaseUrl}api/chat/groupfilemessage'));
      req.headers['Authorization'] = 'Bearer $token';
      req.files.add(await http.MultipartFile.fromPath(
        'file',
        file.path,
        filename: fileName,
        contentType: MediaType.parse(mime),
      ));
      req.fields['groupId'] = groupId;
      if (communityInfo != null) {
        req.fields['communityInfo'] = jsonEncode(communityInfo);
      }

      final streamed = await req.send().timeout(const Duration(minutes: 2));
      final res = await http.Response.fromStream(streamed);
      _logResponse(res.statusCode, res.body, label: l);

      if (res.statusCode == 200 || res.statusCode == 201) {
        final d = _safeJsonDecode(res);
        print('✅ [$l] fileUrl: ${d['message']?['fileUrl']}');
        return {
          'error': d['error'] ?? false,
          'message': d['message'],
          'groupId': d['groupId'],
          'data': d['message'],
        };
      }
      return _apiError(res, l);
    } on SocketException { return _noInternet(l); }
    on TimeoutException  { return _timeout(l); }
    catch (e) { _logError(l, e); return _exception(e); }
  }

  // ════════════════════════════════════════════════════════════════════════
  // 7. SEND VOICE MESSAGE — POST /groupvoicemessage  (multipart)
  // ════════════════════════════════════════════════════════════════════════
  Future<Map<String, dynamic>> sendGroupVoiceMessage({
    required String groupId,
    required File audioFile,
    Map<String, dynamic>? communityInfo,
    int? audioDurationMs,
  }) async {
    const l = 'sendGroupVoiceMessage';
    try {
      final token = await _getToken();
      if (token == null) return _noToken();

      final fileSize = await audioFile.length();
      final mime     = _mimeTypeForFile(audioFile.path);
      print('🎤 [$l] ${audioFile.path.split('/').last} — '
          '${(fileSize / 1024).toStringAsFixed(1)} KB — $mime');
      _logRequest('POST multipart', '${apiBaseUrl}api/chat/groupvoicemessage',
          body: {'groupId': groupId});

      final req = http.MultipartRequest(
          'POST', Uri.parse('${apiBaseUrl}api/chat/groupvoicemessage'));
      req.headers['Authorization'] = 'Bearer $token';
      req.files.add(await http.MultipartFile.fromPath(
        'audio',
        audioFile.path,
        contentType: MediaType.parse(mime),
      ));
      req.fields['groupId'] = groupId;

      if (audioDurationMs != null) {
        req.fields['audioDurationMs'] = audioDurationMs.toString();
        print('📦 [$l] audioDurationMs: $audioDurationMs');
      }
      if (communityInfo != null) {
        req.fields['communityInfo'] = jsonEncode(communityInfo);
      }

      print('📡 [$l] Uploading voice...');
      final streamed = await req.send().timeout(const Duration(minutes: 2));
      final res = await http.Response.fromStream(streamed);
      _logResponse(res.statusCode, res.body, label: l);

      if (res.statusCode == 200 || res.statusCode == 201) {
        final d = _safeJsonDecode(res);
        print('✅ [$l] audioUrl: ${d['message']?['audioUrl']}');
        return {
          'error': d['error'] ?? false,
          'message': d['message'],
          'groupId': d['groupId'],
          'data': d['message'],
        };
      }
      return _apiError(res, l);
    } on SocketException { return _noInternet(l); }
    on TimeoutException  { return _timeout(l); }
    catch (e) { _logError(l, e); return _exception(e); }
  }

  // ════════════════════════════════════════════════════════════════════════
  // 8. SEND CAMERA PHOTO — opens camera then reuses /groupfilemessage
  // ════════════════════════════════════════════════════════════════════════
  Future<Map<String, dynamic>> sendGroupCameraPhoto({
    required String groupId,
    Map<String, dynamic>? communityInfo,
  }) async {
    const l = 'sendGroupCameraPhoto';
    try {
      print('📸 [$l] Opening camera...');
      final XFile? photo = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );

      if (photo == null) {
        print('⚠️ [$l] User cancelled');
        return {
          'error': false,
          'message': 'No photo taken',
          'data': null,
          'cancelled': true,
        };
      }

      final file = File(photo.path);
      final size = await file.length();
      print('📸 [$l] Captured: ${photo.path.split('/').last} — '
          '${(size / 1024).toStringAsFixed(1)} KB');

      return await sendGroupFileMessage(
          groupId: groupId, file: file, communityInfo: communityInfo);
    } catch (e) {
      _logError(l, e);
      return {'error': true, 'message': 'Camera error: ${e.toString()}', 'data': null};
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  // 9. REQUEST TO JOIN — POST /grouprequest
  // ════════════════════════════════════════════════════════════════════════
  Future<Map<String, dynamic>> requestToJoinGroup(
      {required String groupId}) async {
    const l = 'requestToJoinGroup';
    try {
      final token = await _getToken();
      if (token == null) return _noToken();

      _logRequest('POST', '${apiBaseUrl}api/chat/grouprequest',
          body: {'groupId': groupId});
      final res = await http.post(
        Uri.parse('${apiBaseUrl}api/chat/grouprequest'),
        headers: _jsonHeaders(token),
        body: jsonEncode({'groupId': groupId}),
      ).timeout(const Duration(seconds: 30));
      _logResponse(res.statusCode, res.body, label: l);

      if (res.statusCode == 200) {
        final d = _safeJsonDecode(res);
        return {
          'error': d['error'] ?? false,
          'message': d['message'] ?? 'Successfully Requested',
          'data': d['data'],
        };
      }
      return _apiError(res, l);
    } on SocketException { return _noInternet(l); }
    on TimeoutException  { return _timeout(l); }
    catch (e) { _logError(l, e); return _exception(e); }
  }

  // ════════════════════════════════════════════════════════════════════════
  // 10. CANCEL JOIN REQUEST — DELETE /grouprequest/:id
  // ════════════════════════════════════════════════════════════════════════
  Future<Map<String, dynamic>> cancelGroupRequest(
      {required String groupId}) async {
    const l = 'cancelGroupRequest';
    try {
      final token = await _getToken();
      if (token == null) return _noToken();

      final endpoint = '${apiBaseUrl}api/chat/grouprequest/$groupId';
      _logRequest('DELETE', endpoint);
      final res = await http.delete(Uri.parse(endpoint),
          headers: _jsonHeaders(token))
          .timeout(const Duration(seconds: 30));
      _logResponse(res.statusCode, res.body, label: l);

      if (res.statusCode == 200) {
        final d = _safeJsonDecode(res);
        return {
          'error': false,
          'message': d['message'] ?? 'Request Deleted Successfully',
        };
      }
      return _apiError(res, l);
    } on SocketException { return _noInternet(l); }
    on TimeoutException  { return _timeout(l); }
    catch (e) { _logError(l, e); return _exception(e); }
  }

  // ════════════════════════════════════════════════════════════════════════
  // 11. GET GROUP REQUESTS — GET /grouprequest/:id  (admin only)
  // ════════════════════════════════════════════════════════════════════════
  Future<Map<String, dynamic>> getGroupRequests(String groupId) async {
    const l = 'getGroupRequests';
    try {
      final token = await _getToken();
      if (token == null) return _noToken();

      final endpoint = '${apiBaseUrl}api/chat/grouprequest/$groupId';
      _logRequest('GET', endpoint);
      final res = await http.get(Uri.parse(endpoint),
          headers: _jsonHeaders(token))
          .timeout(const Duration(seconds: 30));
      _logResponse(res.statusCode, res.body, label: l);

      if (res.statusCode == 200) {
        final d = jsonDecode(res.body);
        final reqs = d['data'] ?? [];
        print('📋 [$l] ${(reqs as List).length} requests');
        return {'error': false, 'message': 'OK', 'data': reqs};
      }
      return _apiError(res, l);
    } on SocketException { return _noInternet(l); }
    on TimeoutException  { return _timeout(l); }
    catch (e) { _logError(l, e); return _exception(e); }
  }

  // ════════════════════════════════════════════════════════════════════════
  // 12. UPDATE GROUP REQUEST — PUT /grouprequest/
  // ════════════════════════════════════════════════════════════════════════
  Future<Map<String, dynamic>> updateGroupRequest({
    required String requestId,
    required String status, // "approved" | "rejected"
  }) async {
    const l = 'updateGroupRequest';
    try {
      final token = await _getToken();
      if (token == null) return _noToken();

      _logRequest('PUT', '${apiBaseUrl}api/chat/grouprequest/',
          body: {'requestId': requestId, 'status': status});
      final res = await http.put(
        Uri.parse('${apiBaseUrl}api/chat/grouprequest/'),
        headers: _jsonHeaders(token),
        body: jsonEncode({'requestId': requestId, 'status': status}),
      ).timeout(const Duration(seconds: 30));
      _logResponse(res.statusCode, res.body, label: l);

      if (res.statusCode == 200) {
        final d = _safeJsonDecode(res);
        return {
          'error': false,
          'message': d['message'] ?? 'Updated',
          'data': d['data'],
        };
      }
      return _apiError(res, l);
    } on SocketException { return _noInternet(l); }
    on TimeoutException  { return _timeout(l); }
    catch (e) { _logError(l, e); return _exception(e); }
  }

  // ════════════════════════════════════════════════════════════════════════
  // 13. ADD MEMBERS — POST /addmember
  // ════════════════════════════════════════════════════════════════════════
  Future<Map<String, dynamic>> addMembersToGroup({
    required String groupId,
    required List<String> memberIds,
  }) async {
    const l = 'addMembersToGroup';
    try {
      final token = await _getToken();
      if (token == null) return _noToken();

      _logRequest('POST', '${apiBaseUrl}api/chat/addmember',
          body: {'groupId': groupId, 'members': memberIds});
      final res = await http.post(
        Uri.parse('${apiBaseUrl}api/chat/addmember'),
        headers: _jsonHeaders(token),
        body: jsonEncode({'groupId': groupId, 'members': memberIds}),
      ).timeout(const Duration(seconds: 30));
      _logResponse(res.statusCode, res.body, label: l);

      if (res.statusCode == 200) {
        final d = _safeJsonDecode(res);
        return {'error': false, 'message': d['message'] ?? 'Members added'};
      }
      return _apiError(res, l);
    } on SocketException { return _noInternet(l); }
    on TimeoutException  { return _timeout(l); }
    catch (e) { _logError(l, e); return _exception(e); }
  }

  // ════════════════════════════════════════════════════════════════════════
  // 14. REMOVE MEMBER — DELETE /removemember/:groupId/:userId
  // ════════════════════════════════════════════════════════════════════════
  Future<Map<String, dynamic>> removeMemberFromGroup({
    required String groupId,
    required String userId,
  }) async {
    const l = 'removeMemberFromGroup';
    try {
      final token = await _getToken();
      if (token == null) return _noToken();

      final endpoint =
          '${apiBaseUrl}api/chat/removemember/$groupId/$userId';
      _logRequest('DELETE', endpoint);
      final res = await http.delete(Uri.parse(endpoint),
          headers: _jsonHeaders(token))
          .timeout(const Duration(seconds: 30));
      _logResponse(res.statusCode, res.body, label: l);

      if (res.statusCode == 200) {
        final d = _safeJsonDecode(res);
        return {'error': false, 'message': d['message'] ?? 'Member removed'};
      }
      return _apiError(res, l);
    } on SocketException { return _noInternet(l); }
    on TimeoutException  { return _timeout(l); }
    catch (e) { _logError(l, e); return _exception(e); }
  }

  // ════════════════════════════════════════════════════════════════════════
  // 15. FETCH ALL USERS — GET /api/mobile/all-users
  // ════════════════════════════════════════════════════════════════════════
  Future<Map<String, dynamic>> fetchAllUsers({
    int page = 1,
    int limit = 20,
    String? search,
  }) async {
    const l = 'fetchAllUsers';
    try {
      final token = await _getToken();
      if (token == null) return _noToken();

      final params = {'pageNo': '$page', 'limit': '$limit'};
      if (search != null && search.isNotEmpty) params['search'] = search;
      final uri = Uri.parse('${apiBaseUrl}api/mobile/all-users')
          .replace(queryParameters: params);
      _logRequest('GET', uri.toString());

      final res = await http.get(uri, headers: _jsonHeaders(token))
          .timeout(const Duration(seconds: 30));
      _logResponse(res.statusCode, res.body, label: l);

      if (res.statusCode == 200) {
        final d = jsonDecode(res.body);
        final users = d['data']?['allUsers'] ?? [];
        print('👥 [$l] Page $page — ${(users as List).length} users');
        return {
          'error': false,
          'message': 'OK',
          'data': d['data'] ?? {},
          'totalPage': d['data']?['totalPage'] ?? 1,
          'currentPage': d['data']?['currentPage'] ?? 1,
        };
      }
      return _apiError(res, l);
    } on SocketException { return _noInternet(l); }
    on TimeoutException  { return _timeout(l); }
    catch (e) { _logError(l, e); return _exception(e); }
  }

// ════════════════════════════════════════════════════════════════════════
// 16. EDIT GROUP MESSAGE — socket only (no HTTP route exists)
// ════════════════════════════════════════════════════════════════════════
  void editGroupMessage({
    required String messageId,
    required String newText,
    required String groupId,
  }) {
    print('✏️ [Service] editGroupMessage emitting via socket');
    SocketService().socket?.emit('editGroupMessage', {
      'messageId': messageId,
      'newText': newText,
      'groupId': groupId,
    });
  }

// ════════════════════════════════════════════════════════════════════════
// 17. DELETE GROUP MESSAGE — socket only (no HTTP route exists)
// ════════════════════════════════════════════════════════════════════════
  void deleteGroupMessage({
    required String messageId,
    required String groupId,
  }) {
    print('🗑️ [Service] deleteGroupMessage emitting via socket');
    SocketService().socket?.emit('deleteGroupMessage', {
      'messageId': messageId,
      'groupId': groupId,
    });
  }
}
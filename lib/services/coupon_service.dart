import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/apiConstants.dart';
import 'api_service.dart';

class CouponService {

  // ─────────────────────────────────────────────────────────────────────────────
  // 1. GET ALL COUPONS
  // ─────────────────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getUserCoupons() async {
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('📋 [getUserCoupons] Fetching all coupons...');
    try {
      final response = await ApiService.get('/api/coupon/getAll-coupon');
      ApiService.checkResponse(response);

      print('📥 [getUserCoupons] Status: ${response.statusCode}');
      print('📥 [getUserCoupons] Body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final created = decoded['createdCoupons'] ?? [];
        final received = decoded['receivedCoupons'] ?? [];
        print('✅ [getUserCoupons] createdCoupons count: ${created.length}');
        print('✅ [getUserCoupons] receivedCoupons count: ${received.length}');
        return {
          'error': false,
          'createdCoupons': created,
          'receivedCoupons': received,
        };
      }
      print('❌ [getUserCoupons] Non-200 status: ${response.statusCode}');
      return _parseError(response.body, {'createdCoupons': [], 'receivedCoupons': []});
    } catch (e) {
      print('🔥 [getUserCoupons] Exception: $e');
      return _exception(e, {'createdCoupons': [], 'receivedCoupons': []});
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 2. CREATE COUPON (multipart)
  // ─────────────────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> createCoupon({
    required String name,
    required String details,
    required String type,
    required String expiry,
    required String code,
    String? couponType,
    File? imageFile,
    String? link,
    Map<String, dynamic>? discountAmount,
    double? discountPercentage,
    int? coinAmount,
    String? rewardType,
  }) async {
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('➡️ [createCoupon] Creating coupon...');
    print('📝 [createCoupon] name=$name, type=$type, couponType=$couponType, code=$code');
    print('📝 [createCoupon] expiry=$expiry, link=$link');
    print('📝 [createCoupon] discountAmount=$discountAmount, discountPercentage=$discountPercentage');
    print('📝 [createCoupon] coinAmount=$coinAmount, rewardType=$rewardType');
    print('📝 [createCoupon] hasImage=${imageFile != null}');

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null || token.isEmpty) {
        print('❌ [createCoupon] No auth token found');
        return _authError(['coupon']);
      }
      print('🔑 [createCoupon] Token found: ${token.substring(0, 20)}...');

      final uri = Uri.parse('${apiBaseUrl}api/coupon/create-coupon');
      print('🌐 [createCoupon] URL: $uri');

      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer $token'
        ..fields['name'] = name
        ..fields['details'] = details
        ..fields['type'] = type
        ..fields['expiry'] = expiry
        ..fields['code'] = code;

      if (couponType != null) request.fields['couponType'] = couponType;
      request.fields['link'] = (link != null && link.isNotEmpty) ? link : '';

      if (type == 'coupon') {
        if (couponType == 'discount-amount' && discountAmount != null) {
          request.fields['discountAmount'] = jsonEncode(discountAmount);
          print('💰 [createCoupon] discountAmount field: ${jsonEncode(discountAmount)}');
        } else if (couponType == 'discount-in-percentage') {
          request.fields['discountPercentage'] = (discountPercentage ?? 0).toString();
          print('💰 [createCoupon] discountPercentage field: ${discountPercentage}');
        }
      } else if (type == 'coins' && coinAmount != null) {
        request.fields['coinAmount'] = coinAmount.toString();
        print('🪙 [createCoupon] coinAmount field: $coinAmount');
      } else if (type == 'rewards' && rewardType != null) {
        request.fields['rewardType'] = rewardType;
        print('🎁 [createCoupon] rewardType field: $rewardType');
      }

      print('📦 [createCoupon] All fields: ${request.fields}');

      if (imageFile != null) {
        print('🖼️ [createCoupon] Attaching image: ${imageFile.path}');
        request.files.add(await http.MultipartFile.fromPath(
          'image',
          imageFile.path,
          contentType: MediaType('image', imageFile.path.split('.').last),
        ));
      }

      print('🚀 [createCoupon] Sending request...');
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      ApiService.checkResponse(response);

      print('📥 [createCoupon] Status Code: ${response.statusCode}');
      print('📥 [createCoupon] Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('✅ [createCoupon] Coupon created successfully');
        return {
          'error': false,
          'message': 'Coupon created successfully',
          'coupon': jsonDecode(response.body)
        };
      }

      print('❌ [createCoupon] Failed with status: ${response.statusCode}');
      return _parseError(response.body, {'coupon': null});
    } catch (e) {
      print('🔥 [createCoupon] Exception: $e');
      return _exception(e, {'coupon': null});
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 3. SEND COUPON TO USER
  // ─────────────────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> sendCouponToUser({
    required String couponId,
    required String receiverId,
  }) async {
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('📤 [sendCouponToUser] Called');
    print('📤 [sendCouponToUser] couponId: $couponId');
    print('📤 [sendCouponToUser] receiverId: $receiverId');
    print('📤 [sendCouponToUser] couponId isEmpty: ${couponId.isEmpty}');
    print('📤 [sendCouponToUser] receiverId isEmpty: ${receiverId.isEmpty}');

    final result = await _post('/api/coupon/send-coupon', {
      'couponId': couponId,
      'receiverId': receiverId,
    });

    print('📥 [sendCouponToUser] Result: $result');
    return result;
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 4. SEND COUPON TO GROUP/COMMUNITY
  // ─────────────────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> sendCouponToGroup({
    required String couponId,
    required String groupId,
  }) async {
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('📤 [sendCouponToGroup] Called');
    print('📤 [sendCouponToGroup] couponId: $couponId');
    print('📤 [sendCouponToGroup] groupId (communityId): $groupId');
    print('📤 [sendCouponToGroup] couponId isEmpty: ${couponId.isEmpty}');
    print('📤 [sendCouponToGroup] groupId isEmpty: ${groupId.isEmpty}');
    print('📤 [sendCouponToGroup] Request body will be: ${{ 'couponId': couponId, 'communityId': groupId }}');

    final result = await _post('/api/coupon/send-community', {
      'couponId': couponId,
      'communityId': groupId,
    });

    print('📥 [sendCouponToGroup] Result: $result');
    print('📥 [sendCouponToGroup] error: ${result['error']}');
    print('📥 [sendCouponToGroup] message: ${result['message']}');
    return result;
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 5. ADD COUPON CODE TO SERVICE
  // ─────────────────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> addCouponToService({
    required String couponCode,
    required String serviceId,
  }) async {
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('📤 [addCouponToService] couponCode: $couponCode');
    print('📤 [addCouponToService] serviceId: $serviceId');

    final result = await _post('/api/coupon/add-to-service', {
      'couponCode': couponCode,
      'serviceId': serviceId,
    });

    print('📥 [addCouponToService] Result: $result');
    return result;
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 6. VERIFY COUPON
  // ─────────────────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> verifyCoupon({
    required String code,
    String? store,
  }) async {
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('🔍 [verifyCoupon] code: $code, store: $store');

    final body = <String, dynamic>{'code': code};
    if (store != null) body['store'] = store;

    final result = await _post('/api/coupon/verify', body);
    print('📥 [verifyCoupon] Result: $result');
    return result;
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 7. VERIFY iXES SUBSCRIPTION COUPON
  // ─────────────────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> verifyIxesCoupon({required String code}) async {
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('🔍 [verifyIxesCoupon] code: $code');

    final result = await _post('/api/coupon/verify-ixes-coupon', {'code': code});
    print('📥 [verifyIxesCoupon] Result: $result');
    return result;
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 8. GET USER LIST
  // ─────────────────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getUserList() async {
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('👥 [getUserList] Fetching user list...');
    try {
      final response = await ApiService.get('/api/coupon/get-users');
      ApiService.checkResponse(response);

      print('📥 [getUserList] Status: ${response.statusCode}');
      print('📥 [getUserList] Body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final users = decoded['users'] ?? [];
        print('✅ [getUserList] users count: ${users.length}');
        return {'error': false, 'users': users};
      }
      print('❌ [getUserList] Failed with status: ${response.statusCode}');
      return _parseError(response.body, {'users': []});
    } catch (e) {
      print('🔥 [getUserList] Exception: $e');
      return _exception(e, {'users': []});
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // PRIVATE HELPERS
  // ─────────────────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    print('🌐 [_post] PATH: $path');
    print('🌐 [_post] BODY: $body');
    try {
      final response = await ApiService.post(path, body);
      ApiService.checkResponse(response);

      print('📥 [_post] Status: ${response.statusCode}');
      print('📥 [_post] Response: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        print('✅ [_post] Success: $decoded');
        return {'error': false, ...decoded};
      }
      print('❌ [_post] Failed status: ${response.statusCode}');
      return _parseError(response.body, {});
    } catch (e) {
      print('🔥 [_post] Exception: $e');
      return _exception(e, {});
    }
  }

  Map<String, dynamic> _authError(List<String> emptyKeys) {
    print('🔐 [_authError] Authentication token missing!');
    return {
      'error': true,
      'message': 'Authentication token is missing',
      for (final k in emptyKeys) k: k.endsWith('s') ? [] : null,
    };
  }

  Map<String, dynamic> _parseError(String body, Map<String, dynamic> defaults) {
    print('⚠️ [_parseError] Parsing error from body: $body');
    try {
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      final message = decoded['message'] ?? decoded['error'] ?? 'Request failed';
      print('⚠️ [_parseError] Extracted message: $message');
      return {'error': true, 'message': message, ...defaults};
    } catch (_) {
      print('⚠️ [_parseError] Could not parse error body');
      return {'error': true, 'message': 'Request failed', ...defaults};
    }
  }

  Map<String, dynamic> _exception(Object e, Map<String, dynamic> defaults) {
    print('🔥 [_exception] Network/unexpected error: $e');
    return {'error': true, 'message': 'Network error: ${e.toString()}', ...defaults};
  }
}
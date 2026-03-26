import 'dart:io';
import 'package:flutter/foundation.dart';
import '../services/coupon_service.dart';

class CouponProvider with ChangeNotifier {
  final CouponService _service = CouponService();

  // ── Coupon list state ──────────────────────────────────────────────────────
  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _createdCoupons = [];
  List<Map<String, dynamic>> _receivedCoupons = [];

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<Map<String, dynamic>> get createdCoupons => _createdCoupons;
  List<Map<String, dynamic>> get receivedCoupons => _receivedCoupons;

  // ── Create coupon state ────────────────────────────────────────────────────
  bool _isCreating = false;
  String? _createErrorMessage;

  bool get isCreating => _isCreating;
  String? get createErrorMessage => _createErrorMessage;

  // ── Send coupon state ──────────────────────────────────────────────────────
  bool _isSending = false;
  String? _sendErrorMessage;
  String? _sendSuccessMessage;
  List<Map<String, dynamic>> _userList = [];

  bool get isSending => _isSending;
  String? get sendErrorMessage => _sendErrorMessage;
  String? get sendSuccessMessage => _sendSuccessMessage;
  List<Map<String, dynamic>> get userList => _userList;

  // ── Verify coupon state ────────────────────────────────────────────────────
  bool _isVerifying = false;
  String? _verifyErrorMessage;
  Map<String, dynamic>? _verifiedCoupon;

  bool get isVerifying => _isVerifying;
  String? get verifyErrorMessage => _verifyErrorMessage;
  Map<String, dynamic>? get verifiedCoupon => _verifiedCoupon;

  // ─────────────────────────────────────────────────────────────────────────────
  // 1. FETCH ALL COUPONS
  // ─────────────────────────────────────────────────────────────────────────────
  Future<void> fetchUserCoupons() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _service.getUserCoupons();

    if (!result['error']) {
      _createdCoupons = List<Map<String, dynamic>>.from(result['createdCoupons']);
      _receivedCoupons = List<Map<String, dynamic>>.from(result['receivedCoupons']);
    } else {
      _errorMessage = result['message'];
      _createdCoupons = [];
      _receivedCoupons = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 2. CREATE COUPON (supports image upload)
  // ─────────────────────────────────────────────────────────────────────────────
  Future<bool> createCoupon({
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
    _isCreating = true;
    _createErrorMessage = null;
    notifyListeners();

    final result = await _service.createCoupon(
      name: name,
      details: details,
      type: type,
      expiry: expiry,
      code: code,
      couponType: couponType,
      imageFile: imageFile,
      link: link,
      discountAmount: discountAmount,
      discountPercentage: discountPercentage,
      coinAmount: coinAmount,
      rewardType: rewardType,
    );

    _isCreating = false;

    if (!result['error']) {
      await fetchUserCoupons(); // refresh list
      notifyListeners();
      return true;
    } else {
      _createErrorMessage = result['message'];
      notifyListeners();
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 3. SEND COUPON TO A USER
  // ─────────────────────────────────────────────────────────────────────────────
  Future<bool> sendCouponToUser({
    required String couponId,
    required String receiverId,
  }) async {
    _isSending = true;
    _sendErrorMessage = null;
    _sendSuccessMessage = null;
    notifyListeners();

    final result = await _service.sendCouponToUser(
      couponId: couponId,
      receiverId: receiverId,
    );

    _isSending = false;

    if (!result['error']) {
      _sendSuccessMessage = result['message'] ?? 'Coupon sent successfully!';
      notifyListeners();
      return true;
    } else {
      _sendErrorMessage = result['message'];
      notifyListeners();
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 4. SEND COUPON TO GROUP
  // ─────────────────────────────────────────────────────────────────────────────
  Future<bool> sendCouponToGroup({
    required String couponId,
    required String groupId,
  }) async {
    _isSending = true;
    _sendErrorMessage = null;
    _sendSuccessMessage = null;
    notifyListeners();

    final result = await _service.sendCouponToGroup(
      couponId: couponId,
      groupId: groupId,
    );

    _isSending = false;

    if (!result['error']) {
      _sendSuccessMessage = result['message'] ?? 'Coupon sent to group!';
      notifyListeners();
      return true;
    } else {
      _sendErrorMessage = result['message'];
      notifyListeners();
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 5. ADD COUPON TO SERVICE
  // ─────────────────────────────────────────────────────────────────────────────
  Future<bool> addCouponToService({
    required String couponCode,
    required String serviceId,
  }) async {
    _isSending = true;
    _sendErrorMessage = null;
    notifyListeners();

    final result = await _service.addCouponToService(
      couponCode: couponCode,
      serviceId: serviceId,
    );

    _isSending = false;

    if (!result['error']) {
      notifyListeners();
      return true;
    } else {
      _sendErrorMessage = result['message'];
      notifyListeners();
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 6. VERIFY COUPON  — use at checkout / payment screens
  // ─────────────────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> verifyCoupon({
    required String code,
    String? store,
  }) async {
    _isVerifying = true;
    _verifyErrorMessage = null;
    _verifiedCoupon = null;
    notifyListeners();

    final result = await _service.verifyCoupon(code: code, store: store);

    _isVerifying = false;

    if (!result['error']) {
      _verifiedCoupon = result['coupon'];
      notifyListeners();
      return {'success': true, 'coupon': _verifiedCoupon};
    } else {
      _verifyErrorMessage = result['message'];
      notifyListeners();
      return {'success': false, 'message': _verifyErrorMessage};
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 7. VERIFY iXES SUBSCRIPTION COUPON
  // ─────────────────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> verifyIxesCoupon({required String code}) async {
    _isVerifying = true;
    _verifyErrorMessage = null;
    notifyListeners();

    final result = await _service.verifyIxesCoupon(code: code);

    _isVerifying = false;

    if (!result['error']) {
      notifyListeners();
      return {'success': true, 'data': result['data']};
    } else {
      _verifyErrorMessage = result['message'];
      notifyListeners();
      return {'success': false, 'message': _verifyErrorMessage};
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 8. FETCH USER LIST (for Send Coupon sheet)
  // ─────────────────────────────────────────────────────────────────────────────
  Future<void> fetchUserList() async {
    final result = await _service.getUserList();
    if (!result['error']) {
      _userList = List<Map<String, dynamic>>.from(result['users']);
      notifyListeners();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────────────────────
  void clearVerifyState() {
    _verifiedCoupon = null;
    _verifyErrorMessage = null;
    notifyListeners();
  }

  void clearSendState() {
    _sendErrorMessage = null;
    _sendSuccessMessage = null;
    notifyListeners();
  }
}
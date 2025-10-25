import 'package:flutter/foundation.dart';
import '../services/coupon_service.dart';

class CouponProvider with ChangeNotifier {
  final CouponService _couponService = CouponService();

  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _createdCoupons = [];
  List<Map<String, dynamic>> _receivedCoupons = [];

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<Map<String, dynamic>> get createdCoupons => _createdCoupons;
  List<Map<String, dynamic>> get receivedCoupons => _receivedCoupons;
  bool _isCreating = false;
  String? _createErrorMessage;

  bool get isCreating => _isCreating;
  String? get createErrorMessage => _createErrorMessage;

  /// Fetch user coupons from API
  Future<void> fetchUserCoupons() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _couponService.getUserCoupons();

    if (result['error'] == false) {
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
  Future<bool> createCoupon({
    required String name,
    required String details,
    required String type,
    required String expiry,
    required String code,
    String? couponType,
    String? image,
    String? link,
    Map<String, dynamic>? discountAmount,
    double? discountPercentage,
    int? coinAmount,
    String? rewardType,
  }) async {
    _isCreating = true;
    _createErrorMessage = null;
    notifyListeners();

    final result = await _couponService.createCoupon(
      name: name,
      details: details,
      type: type,
      expiry: expiry,
      code: code,
      couponType: couponType,
      image: image,
      link: link,
      discountAmount: discountAmount,
      discountPercentage: discountPercentage,
      coinAmount: coinAmount,
      rewardType: rewardType,
    );

    _isCreating = false;

    if (result['error'] == false) {
      // Refresh the coupons list after successful creation
      await fetchUserCoupons();
      notifyListeners();
      return true;
    } else {
      _createErrorMessage = result['message'];
      notifyListeners();
      return false;
    }
  }
}

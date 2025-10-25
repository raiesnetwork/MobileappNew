import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:ixes.app/services/services_service.dart';

class ServicesProvider with ChangeNotifier {
  final ServicesService _service = ServicesService();

  // Separate loading states
  bool _isLoading = false;
  bool _isMyServicesLoading = false;
  bool _isCommunityServicesLoading = false;
  bool _isServiceActionLoading = false;
  bool _isServiceDetailsLoading = false;
  bool _isMyProductsLoading = false; // Added for products

  // Separate error states
  bool _hasError = false;
  bool _hasMyServicesError = false;
  bool _hasCommunityServicesError = false;
  bool _hasServiceActionError = false;
  bool _hasServiceDetailsError = false;
  bool _hasMyProductsError = false; // Added for products

  // Separate messages
  String _message = '';
  String _myServicesMessage = '';
  String _communityServicesMessage = '';
  String _serviceActionMessage = '';
  String _serviceDetailsMessage = '';
  String _myProductsMessage = ''; // Added for products

  // Separate data lists
  List<dynamic> _services = [];
  List<dynamic> _myServices = [];
  List<dynamic> _communityServices = [];
  Map<String, dynamic> _serviceDetails = {};
  List<dynamic> _myProducts = []; // Added for products

  int _currentTabIndex = 0;

  // Getters for All Services
  bool get isLoading => _isLoading;
  bool get hasError => _hasError;
  String get message => _message;
  List<dynamic> get services => _services;

  // Getters for My Services
  bool get isMyServicesLoading => _isMyServicesLoading;
  bool get hasMyServicesError => _hasMyServicesError;
  String get myServicesMessage => _myServicesMessage;
  List<dynamic> get myServices => _myServices;

  // Getters for Community Services
  bool get isCommunityServicesLoading => _isCommunityServicesLoading;
  bool get hasCommunityServicesError => _hasCommunityServicesError;
  String get communityServicesMessage => _communityServicesMessage;
  List<dynamic> get communityServices => _communityServices;

  // Getters for Service Actions (activate/deactivate)
  bool get isServiceActionLoading => _isServiceActionLoading;
  bool get hasServiceActionError => _hasServiceActionError;
  String get serviceActionMessage => _serviceActionMessage;

  // Getters for Service Details
  bool get isServiceDetailsLoading => _isServiceDetailsLoading;
  bool get hasServiceDetailsError => _hasServiceDetailsError;
  String get serviceDetailsMessage => _serviceDetailsMessage;
  Map<String, dynamic> get serviceDetails => _serviceDetails;

  // Getters for My Products
  bool get isMyProductsLoading => _isMyProductsLoading;
  bool get hasMyProductsError => _hasMyProductsError;
  String get myProductsMessage => _myProductsMessage;
  List<dynamic> get myProducts => _myProducts;

  int get currentTabIndex => _currentTabIndex;

  void setTabIndex(int index) {
    _currentTabIndex = index;
    notifyListeners();
  }

  Future<void> fetchServices() async {
    _isLoading = true;
    _hasError = false;
    _services = [];
    notifyListeners();

    final response = await _service.getAllServices();
    if (!response['error']) {
      _services = response['data'];
      _message = response['message'];
    } else {
      _hasError = true;
      _message = response['message'];
      _services = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchMyServices() async {
    _isMyServicesLoading = true;
    _hasMyServicesError = false;
    _myServices = [];
    notifyListeners();

    final response = await _service.getMyServices();
    if (!response['error']) {
      _myServices = response['myServices'] ?? [];
      _myServicesMessage =
          response['message'] ?? 'My services fetched successfully';
    } else {
      _hasMyServicesError = true;
      _myServicesMessage = response['message'] ?? 'Failed to fetch my services';
      _myServices = [];
    }

    _isMyServicesLoading = false;
    notifyListeners();
  }

  Future<void> fetchCommunityServices({String? communityId}) async {
    print('🚀 Starting fetchCommunityServices with communityId: $communityId');

    _isCommunityServicesLoading = true;
    _hasCommunityServicesError = false;
    _communityServices = [];
    _communityServicesMessage = 'Loading...';
    notifyListeners();

    try {
      final response = await _service.getAllCommunityServices(communityId: communityId);

      print('📨 Provider received response: $response');
      print('📊 Response error: ${response['error']}');
      print('📝 Response message: ${response['message']}');
      print('📦 Response data length: ${response['data']?.length ?? 0}');

      if (!response['error']) {
        _communityServices = List<dynamic>.from(response['data'] ?? []);
        _communityServicesMessage = response['message'] ?? 'Success';
        _hasCommunityServicesError = false;
        print('✅ Services loaded successfully: ${_communityServices.length} services');
      } else {
        _hasCommunityServicesError = true;
        _communityServicesMessage = response['message'] ?? 'Unknown error occurred';
        _communityServices = [];
        print('❌ Error loading services: $_communityServicesMessage');
      }
    } catch (e) {
      print('💥 Provider exception: $e');
      _hasCommunityServicesError = true;
      _communityServicesMessage = 'Failed to load services: ${e.toString()}';
      _communityServices = [];
    }

    _isCommunityServicesLoading = false;
    notifyListeners();

    print('🏁 fetchCommunityServices completed. Loading: $_isCommunityServicesLoading, Error: $_hasCommunityServicesError, Services count: ${_communityServices.length}');
  }

  Future<void> createService({
    required String name,
    required String description,
    required String location,
    String? communityId,
    required String category,
    required String subCategory,
    required String openHourFrom,
    required String openHourEnd,
    required String cost,
    required String slots,
    required String currency,
    required String costPer,
    required String serviceProvider,
    required List<String> availableDays,
    File? image,
  }) async {
    _isLoading = true;
    _hasError = false;
    notifyListeners();

    final response = await _service.createService(
      name: name,
      description: description,
      location: location,
      communityId: communityId,
      category: category,
      subCategory: subCategory,
      openHourFrom: openHourFrom,
      openHourEnd: openHourEnd,
      cost: cost,
      slots: slots,
      currency: currency,
      costPer: costPer,
      serviceProvider: serviceProvider,
      availableDays: availableDays,
      image: image,
    );

    if (!response['error']) {
      _message = response['message'];
      if (communityId != null && communityId.isNotEmpty) {
        await fetchCommunityServices(communityId: communityId);
      }
      await fetchMyServices();
    } else {
      _hasError = true;
      _message = response['message'];
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> editService({
    required String id,
    String? name,
    String? description,
    List<String>? image,
    String? location,
    String? communityId,
    String? category,
    String? subCategory,
    num? cost,
    num? slots,
    String? currency,
    List<String>? availableDays,
    String? costPer,
    String? openHourFrom,
    String? openHourEnd,
    String? serviceProvider,
  }) async {
    _isMyServicesLoading = true;
    _hasMyServicesError = false;
    notifyListeners();

    final response = await _service.editService(
      id: id,
      name: name,
      description: description,
      image: image,
      location: location,
      communityId: communityId,
      category: category,
      subCategory: subCategory,
      cost: cost,
      slots: slots,
      currency: currency,
      availableDays: availableDays,
      costPer: costPer,
      openHourFrom: openHourFrom,
      openHourEnd: openHourEnd,
      serviceProvider: serviceProvider,
    );

    if (!response['error']) {
      _myServicesMessage = response['message'];
      await fetchMyServices();
      if (communityId != null && communityId.isNotEmpty) {
        await fetchCommunityServices(communityId: communityId);
      }
    } else {
      _hasMyServicesError = true;
      _myServicesMessage = response['message'];
    }

    _isMyServicesLoading = false;
    notifyListeners();
  }

  Future<void> deleteService({
    required String serviceId,
    String? communityId,
  }) async {
    final serviceIndex =
        _myServices.indexWhere((service) => service['_id'] == serviceId);
    dynamic removedService;

    if (serviceIndex != -1) {
      removedService = _myServices.removeAt(serviceIndex);
      notifyListeners();
    }

    final response = await _service.deleteService(serviceId: serviceId);

    if (!response['err']) {
      _myServicesMessage =
          response['message'] ?? 'Service deleted successfully';
      _hasMyServicesError = false;
    } else {
      if (removedService != null && serviceIndex != -1) {
        _myServices.insert(serviceIndex, removedService);
      }
      _hasMyServicesError = true;
      _myServicesMessage = response['message'] ?? 'Failed to delete service';
    }

    if (communityId != null && communityId.isNotEmpty) {
      await fetchCommunityServices(communityId: communityId);
    }

    notifyListeners();
  }

  Future<void> activateMyService(String serviceId) async {
    _isServiceActionLoading = true;
    _hasServiceActionError = false;
    _serviceActionMessage = '';
    notifyListeners();

    final response = await _service.activateService(serviceId);
    if (!response['err']) {
      _serviceActionMessage =
          response['message'] ?? 'Service activated successfully';
      _myServices = _myServices.map((service) {
        if (service['_id'] == serviceId) {
          return response['service'] ?? service;
        }
        return service;
      }).toList();
      final service = _myServices.firstWhere(
        (service) => service['_id'] == serviceId,
        orElse: () => null,
      );
      if (service != null &&
          service['communityId'] != null &&
          service['communityId'].isNotEmpty) {
        await fetchCommunityServices(communityId: service['communityId']);
      }
    } else {
      _hasServiceActionError = true;
      _serviceActionMessage =
          response['message'] ?? 'Failed to activate service';
    }

    _isServiceActionLoading = false;
    notifyListeners();
  }

  Future<void> deactivateMyService(String serviceId) async {
    _isServiceActionLoading = true;
    _hasServiceActionError = false;
    _serviceActionMessage = '';
    notifyListeners();

    final response = await _service.deactivateService(serviceId);
    if (!response['err']) {
      _serviceActionMessage =
          response['message'] ?? 'Service deactivated successfully';
      _myServices = _myServices.map((service) {
        if (service['_id'] == serviceId) {
          return response['service'] ?? service;
        }
        return service;
      }).toList();
      final service = _myServices.firstWhere(
        (service) => service['_id'] == serviceId,
        orElse: () => null,
      );
      if (service != null &&
          service['communityId'] != null &&
          service['communityId'].isNotEmpty) {
        await fetchCommunityServices(communityId: service['communityId']);
      }
    } else {
      _hasServiceActionError = true;
      _serviceActionMessage =
          response['message'] ?? 'Failed to deactivate service';
    }

    _isServiceActionLoading = false;
    notifyListeners();
  }

  Future<void> fetchServiceDetails(String id) async {
    _isLoading = true;
    _hasError = false;
    _message = '';
    notifyListeners();

    final response = await _service.getServiceDetails(id);
    if (!response['error']) {
      _services = [response['data']];
      _message = response['message'] ?? 'Service details fetched successfully';
    } else {
      _hasError = true;
      _message = response['message'] ?? 'Failed to fetch service details';
      _services = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchServiceDetailsSeparate(String id) async {
    _isServiceDetailsLoading = true;
    _hasServiceDetailsError = false;
    _serviceDetailsMessage = '';
    _serviceDetails = {};
    notifyListeners();

    final response = await _service.getServiceDetails(id);
    if (!response['error']) {
      _serviceDetails = response['data'] ?? {};
      _serviceDetailsMessage =
          response['message'] ?? 'Service details fetched successfully';
    } else {
      _hasServiceDetailsError = true;
      _serviceDetailsMessage =
          response['message'] ?? 'Failed to fetch service details';
      _serviceDetails = {};
    }

    _isServiceDetailsLoading = false;
    notifyListeners();
  }

  Future<void> fetchMyProducts() async {
    _isMyProductsLoading = true;
    _hasMyProductsError = false;
    _myProductsMessage = '';
    _myProducts = [];
    notifyListeners();

    final response = await _service.getMyProducts();
    if (!response['error']) {
      _myProducts = response['data'] ?? [];
      _myProductsMessage =
          response['message'] ?? 'Products fetched successfully';
    } else {
      _hasMyProductsError = true;
      _myProductsMessage = response['message'] ?? 'Failed to fetch products';
      _myProducts = [];
    }

    _isMyProductsLoading = false;
    notifyListeners();
  }
}

import 'package:flutter/foundation.dart';
import '../services/generate_link_service.dart';


class MeetProvider with ChangeNotifier {
  final MeetService _meetService = MeetService();

  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  // Meeting link data
  String? _createdMeetLink;
  bool _isLinkValid = false;
  Map<String, dynamic>? _meetLinkData;

  // Getters
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;
  String? get createdMeetLink => _createdMeetLink;
  bool get isLinkValid => _isLinkValid;
  Map<String, dynamic>? get meetLinkData => _meetLinkData;

  /// Creates a new meeting link
  Future<bool> createMeetLink({
    required String linkId,
    required String type,
    required String dateAndTime,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      final result = await _meetService.createMeetLink(
        linkId: linkId,
        type: type,
        dateAndTime: dateAndTime,
      );

      _isLoading = false;

      if (result['error'] == false) {
        _successMessage = result['message'];
        _meetLinkData = result['data'];
        _errorMessage = null;
        notifyListeners();
        return true;
      } else {
        _errorMessage = result['message'];
        _successMessage = null;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'An unexpected error occurred: ${e.toString()}';
      _successMessage = null;
      notifyListeners();
      return false;
    }
  }

  /// Shares a meeting link
  Future<bool> shareMeetLink({
    required String meetLink,
    required String dateAndTimeFrom,
    required String dateAndTimeTo,
    required String description,
    required String type,
    List<Map<String, String>>? members,
    List<Map<String, String>>? mail,
    Map<String, dynamic>? recurrenceSettings,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      final result = await _meetService.shareMeetLink(
        meetLink: meetLink,
        dateAndTimeFrom: dateAndTimeFrom,
        dateAndTimeTo: dateAndTimeTo,
        description: description,
        type: type,
        members: members,
        mail: mail,
        recurrenceSettings: recurrenceSettings,
      );

      _isLoading = false;

      if (result['error'] == false) {
        _successMessage = result['message'];
        _errorMessage = null;
        notifyListeners();
        return true;
      } else {
        _errorMessage = result['message'];
        _successMessage = null;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'An unexpected error occurred: ${e.toString()}';
      _successMessage = null;
      notifyListeners();
      return false;
    }
  }

  /// Validates a meeting link
  Future<bool> validateMeetLink({
    required String linkId,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      final result = await _meetService.validateMeetLink(
        linkId: linkId,
      );

      _isLoading = false;

      if (result['error'] == false) {
        _successMessage = result['message'];
        _isLinkValid = result['isValid'] ?? false;
        _meetLinkData = result['data'];
        _errorMessage = null;
        notifyListeners();
        return true;
      } else {
        _errorMessage = result['message'];
        _isLinkValid = false;
        _successMessage = null;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'An unexpected error occurred: ${e.toString()}';
      _isLinkValid = false;
      _successMessage = null;
      notifyListeners();
      return false;
    }
  }

  /// Clears error and success messages
  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  /// Resets all state
  void reset() {
    _isLoading = false;
    _errorMessage = null;
    _successMessage = null;
    _createdMeetLink = null;
    _isLinkValid = false;
    _meetLinkData = null;
    notifyListeners();
  }
}
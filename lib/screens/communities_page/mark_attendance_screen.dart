import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:provider/provider.dart';
import '../../providers/attendance_provider.dart';
import 'attendance_history.dart';

// ── Cached location (persists across screen visits this session) ───────────
double?   _cachedLatitude;
double?   _cachedLongitude;
String?   _cachedAddress;
DateTime? _cachedAt;
const Duration _locationCacheTTL = Duration(minutes: 10);

bool get _hasFreshCachedLocation {
  if (_cachedAt == null || _cachedLatitude == null) return false;
  return DateTime.now().difference(_cachedAt!) < _locationCacheTTL;
}

/// Call this once, early — e.g. right after login in main.dart's
/// _requestLocationPermission() — to warm the cache in the background.
/// By the time the user actually opens MarkAttendanceScreen, the location
/// is already sitting here ready to go, so the screen opens instantly
/// with no "Fetching location…" spinner and no permission dialog.
///
/// This is silent and non-blocking on failure: if permission isn't granted
/// yet, GPS is off, or anything else goes wrong, it just returns quietly.
/// MarkAttendanceScreen's own dialogs still handle those cases properly
/// when the user actually visits the screen.
Future<void> prefetchAttendanceLocation() async {
  try {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    final perm = await Geolocator.checkPermission();
    if (perm != LocationPermission.always &&
        perm != LocationPermission.whileInUse) {
      return; // not granted yet — don't prompt from here, just skip silently
    }

    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.medium,
      timeLimit: const Duration(seconds: 10),
    );

    String addr =
        '${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}';
    try {
      final marks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
      final p = marks.first;
      final parts = [
        p.subLocality ?? '',
        p.locality ?? '',
        p.administrativeArea ?? '',
      ].where((s) => s.isNotEmpty).toList();
      if (parts.isNotEmpty) addr = parts.join(', ');
    } catch (_) {}

    _cachedLatitude  = pos.latitude;
    _cachedLongitude = pos.longitude;
    _cachedAddress   = addr;
    _cachedAt        = DateTime.now();

    debugPrint('📍 [ATTENDANCE] Location prefetched and cached: $addr');
  } catch (e) {
    debugPrint('⚠️ [ATTENDANCE] Prefetch failed (will fetch normally on screen open): $e');
  }
}

// ── Design tokens ────────────────────────────────────────────────────────────
const _accent   = Color(0xFF6C5CE7);
const _bg       = Color(0xFFF7F7FB);
const _dark     = Color(0xFF1A1A2E);
const _surface  = Color(0xFFFFFFFF);
const _muted    = Color(0xFF8E8EA0);

const _green    = Color(0xFF00C48C);
const _red      = Color(0xFFFF4D6A);
const _orange   = Color(0xFFFF9A3C);

class MarkAttendanceScreen extends StatefulWidget {
  final String communityId;
  final String communityName;
  final String studentId;

  const MarkAttendanceScreen({
    super.key,
    required this.communityId,
    required this.communityName,
    required this.studentId,
  });

  @override
  State<MarkAttendanceScreen> createState() => _MarkAttendanceScreenState();
}

class _MarkAttendanceScreenState extends State<MarkAttendanceScreen> {
  String _selectedStatus = 'present';
  final _remarkController = TextEditingController();

  double _latitude  = 0.0;
  double _longitude = 0.0;
  String _address   = 'Fetching location…';
  bool   _locationFetched = false;
  bool   _locationLoading = false;

  @override
  void initState() {
    super.initState();
    _loadTodayAttendance();

    if (_hasFreshCachedLocation) {
      // Already have a recent fix — use it instantly, no dialog, no fetch
      _latitude        = _cachedLatitude!;
      _longitude       = _cachedLongitude!;
      _address         = _cachedAddress!;
      _locationFetched = true;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showLocationPermissionDialog();
      });
    }
  }

  @override
  void dispose() {
    _remarkController.dispose();
    super.dispose();
  }

  // ── Location Permission Dialog ────────────────────────────────────────────
  Future<void> _showLocationPermissionDialog() async {
    final perm = await Geolocator.checkPermission();
    // If already granted, just fetch silently
    if (perm == LocationPermission.always ||
        perm == LocationPermission.whileInUse) {
      _fetchLocation();
      return;
    }

    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: _surface,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [_accent, Color(0xFF8E7CF8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                        color: _accent.withOpacity(0.30),
                        blurRadius: 20,
                        offset: const Offset(0, 6)),
                  ],
                ),
                child: const Icon(Icons.location_on_rounded,
                    color: Colors.white, size: 36),
              ),
              const SizedBox(height: 20),

              // Title
              const Text(
                'Allow Location Access',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _dark,
                    letterSpacing: -0.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),

              // Body
              Text(
                'Your location is recorded with attendance to verify you were present at the right place.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13,
                    color: _muted,
                    height: 1.55),
              ),
              const SizedBox(height: 28),

              // Allow button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    await _fetchLocation();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Allow Location',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 10),

              // Deny button
              SizedBox(
                width: double.infinity,
                height: 44,
                child: TextButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    setState(() {
                      _address = 'Location not provided';
                      _locationLoading = false;
                    });
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: _muted,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Not Now',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w500)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Show Location Fetching Dialog (Full Screen) ────────────────────────────
  void _showLocationFetchingDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Center(
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.symmetric(vertical: 32),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Animated spinner (smaller)
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: _accent,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Fetching Location',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _dark,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Just a moment…',
                    style: TextStyle(
                      fontSize: 13,
                      color: _muted,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Location ─────────────────────────────────────────────────────────────
  Future<void> _fetchLocation() async {
    if (!mounted) return;

    // Show full-screen loading dialog
    _showLocationFetchingDialog();
    setState(() => _locationLoading = true);

    try {
      // ── Step 1: Check if GPS/Location service is ON ──────────────────────
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) Navigator.pop(context); // Dismiss loading dialog
        if (!mounted) return;
        setState(() { _address = 'Turn on device location'; _locationLoading = false; });
        // Ask user to enable location service
        _showEnableLocationServiceDialog();
        return;
      }

      // ── Step 2: Check / request permission ──────────────────────────────
      var perm = await Geolocator.checkPermission();

      if (perm == LocationPermission.deniedForever) {
        if (mounted) Navigator.pop(context); // Dismiss loading dialog
        if (!mounted) return;
        setState(() { _address = 'Location permission blocked'; _locationLoading = false; });
        _showOpenSettingsDialog();
        return;
      }

      if (perm == LocationPermission.denied) {
        // This triggers the real OS permission popup
        perm = await Geolocator.requestPermission();
      }

      if (perm == LocationPermission.denied) {
        if (mounted) Navigator.pop(context); // Dismiss loading dialog
        if (!mounted) return;
        setState(() { _address = 'Location permission denied'; _locationLoading = false; });
        return;
      }

      if (perm == LocationPermission.deniedForever) {
        if (mounted) Navigator.pop(context); // Dismiss loading dialog
        if (!mounted) return;
        setState(() { _address = 'Location permission blocked'; _locationLoading = false; });
        _showOpenSettingsDialog();
        return;
      }

      // ── Step 3: Get coordinates ──────────────────────────────────────────
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 10),
      );

      // ── Step 4: Reverse geocode ──────────────────────────────────────────
      String addr = '${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}';
      try {
        final marks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
        final p = marks.first;
        final parts = [
          p.subLocality ?? '',
          p.locality ?? '',
          p.administrativeArea ?? '',
        ].where((s) => s.isNotEmpty).toList();
        if (parts.isNotEmpty) addr = parts.join(', ');
      } catch (_) {}

      // Save to cache so future screen visits (and other entry points)
      // can skip re-fetching for a while
      _cachedLatitude  = pos.latitude;
      _cachedLongitude = pos.longitude;
      _cachedAddress   = addr;
      _cachedAt        = DateTime.now();

      if (mounted) {
        Navigator.pop(context); // Dismiss loading dialog
        setState(() {
          _latitude        = pos.latitude;
          _longitude       = pos.longitude;
          _address         = addr;
          _locationFetched = true;
          _locationLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Dismiss loading dialog
        setState(() { _address = 'Could not get location'; _locationLoading = false; });
      }
    }
  }

  /// Shown when device GPS is toggled OFF
  void _showEnableLocationServiceDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: _surface,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 68, height: 68,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _orange.withOpacity(0.12),
              ),
              child: const Icon(Icons.location_off_rounded, color: _orange, size: 34),
            ),
            const SizedBox(height: 18),
            const Text('Location is Off',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _dark),
                textAlign: TextAlign.center),
            const SizedBox(height: 10),
            Text(
              'Please turn on your device location (GPS) to record attendance with your location.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: _muted, height: 1.55),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity, height: 50,
              child: ElevatedButton(
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  await Geolocator.openLocationSettings();
                  // Try again after user comes back
                  await Future.delayed(const Duration(seconds: 1));
                  _fetchLocation();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _orange,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Open Location Settings',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                setState(() { _address = 'Location not provided'; _locationLoading = false; });
              },
              child: const Text('Skip', style: TextStyle(color: _muted, fontSize: 14)),
            ),
          ]),
        ),
      ),
    );
  }

  /// Shown when permission is permanently denied — must open app settings
  void _showOpenSettingsDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: _surface,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 68, height: 68,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _red.withOpacity(0.10),
              ),
              child: const Icon(Icons.lock_outline_rounded, color: _red, size: 34),
            ),
            const SizedBox(height: 18),
            const Text('Permission Blocked',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _dark),
                textAlign: TextAlign.center),
            const SizedBox(height: 10),
            Text(
              'Location access was blocked. Please open App Settings and allow location permission manually.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: _muted, height: 1.55),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity, height: 50,
              child: ElevatedButton(
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  await Geolocator.openAppSettings();
                  await Future.delayed(const Duration(seconds: 1));
                  _fetchLocation();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Open App Settings',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                setState(() { _address = 'Location not provided'; _locationLoading = false; });
              },
              child: const Text('Skip', style: TextStyle(color: _muted, fontSize: 14)),
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _loadTodayAttendance() async {
    await context.read<AttendanceProvider>().getTodayAttendance(
      studentId: widget.studentId,
      tenantId:  widget.communityId,
    );
  }

  // ── Mark Attendance ───────────────────────────────────────────────────────
  Future<void> _markAttendance() async {
    // Guard: if already marked this session, do not submit again
    if (context.read<AttendanceProvider>().hasMarkedToday) return;

    // If location not yet fetched, try once more before submitting
    if (!_locationFetched && !_locationLoading) {
      await _fetchLocation();
    }

    final result = await context.read<AttendanceProvider>().markAttendance(
      studentId: widget.studentId,
      tenantId:  widget.communityId,
      status:    _selectedStatus,
      latitude:  _latitude,
      longitude: _longitude,
      address:   _address,
      remark:    _remarkController.text.trim(),
    );
    if (!mounted) return;
    if (result['error'] == false) {
      _showSuccessSheet();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result['message'] ?? 'Failed to mark attendance'),
        backgroundColor: _red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ));
    }
  }

  void _showSuccessSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        child: Container(
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(28),
          ),
          padding: const EdgeInsets.fromLTRB(28, 36, 28, 28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFF00C48C), Color(0xFF00A676)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Icon(Icons.check_rounded, color: Colors.white, size: 40),
            ),
            const SizedBox(height: 20),
            const Text('Attendance Marked',
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w800,
                    color: _dark, letterSpacing: -0.5)),
            const SizedBox(height: 8),
            Text(
              'Your attendance is recorded for today.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: _muted, height: 1.4),
            ),
            if (_locationFetched) ...[
              const SizedBox(height: 14),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.location_on_rounded, size: 14, color: _muted),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(_address,
                      style: const TextStyle(fontSize: 12, color: _muted),
                      overflow: TextOverflow.ellipsis),
                ),
              ]),
            ],
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _navigateToHistory();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('View History',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  void _navigateToHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AttendanceHistoryScreen(
          communityId:   widget.communityId,
          communityName: widget.communityName,
          studentId:     widget.studentId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AttendanceProvider>(
      builder: (context, provider, _) {
        final alreadyMarked = provider.hasMarkedToday;
        final todayRecord   = provider.todayAttendance;

        return Scaffold(
          backgroundColor: _bg,
          appBar: _buildAppBar(),
          body: alreadyMarked && todayRecord != null
              ? _AlreadyMarkedView(
            record:        todayRecord,
            onViewHistory: _navigateToHistory,
          )
              : _buildForm(provider),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _surface,
      foregroundColor: _dark,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      titleSpacing: 0,
      title: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Mark Attendance',
              style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w800,
                  color: _dark, letterSpacing: -0.3)),
          Text(widget.communityName,
              style: const TextStyle(fontSize: 11, color: _muted)),
        ]),
      ),
      actions: [
        GestureDetector(
          onTap: _navigateToHistory,
          child: Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _accent.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.history_rounded, size: 15, color: _accent),
              const SizedBox(width: 5),
              const Text('History',
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600, color: _accent)),
            ]),
          ),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: const Color(0xFFF0F0F5)),
      ),
    );
  }

  Widget _buildForm(AttendanceProvider provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Status label
        const Text('Status',
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600,
                color: _muted, letterSpacing: 0.3)),
        const SizedBox(height: 12),

        // ── Status cards
        Row(children: [
          _StatusCard(
            label: 'Present',
            icon:  Icons.check_circle_rounded,
            color: _green,
            isSelected: _selectedStatus == 'present',
            onTap: () => setState(() => _selectedStatus = 'present'),
          ),
          const SizedBox(width: 10),
          _StatusCard(
            label: 'Absent',
            icon:  Icons.cancel_rounded,
            color: _red,
            isSelected: _selectedStatus == 'absent',
            onTap: () => setState(() => _selectedStatus = 'absent'),
          ),
          const SizedBox(width: 10),
          _StatusCard(
            label: 'Late',
            icon:  Icons.access_time_rounded,
            color: _orange,
            isSelected: _selectedStatus == 'late',
            onTap: () => setState(() => _selectedStatus = 'late'),
          ),
        ]),
        const SizedBox(height: 16),

        // ── Location row ─────────────────────────────────────────────────
        _LocationRow(
          address:  _address,
          isLoading: false, // Always false now — loading handled by dialog
          onRefresh: _locationFetched ? _fetchLocation : _showLocationPermissionDialog,
        ),
        const SizedBox(height: 28),

        // ── Remark label
        const Text('Remark',
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600,
                color: _muted, letterSpacing: 0.3)),
        const SizedBox(height: 12),

        // ── Remark field
        Container(
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 2)),
            ],
          ),
          child: TextField(
            controller: _remarkController,
            maxLines: 3,
            style: const TextStyle(fontSize: 14, color: _dark, height: 1.5),
            decoration: InputDecoration(
              hintText: 'Optional note…',
              hintStyle: TextStyle(color: _muted.withOpacity(0.7), fontSize: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.transparent,
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ),
        const SizedBox(height: 32),

        // ── Submit button
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: provider.isMarking ? null : _markAttendance,
            style: ElevatedButton.styleFrom(
              backgroundColor: _accent,
              disabledBackgroundColor: _muted.withOpacity(0.15),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            child: provider.isMarking
                ? const SizedBox(
                width: 22, height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: Colors.white))
                : Text(
                'Mark as ${_selectedStatus[0].toUpperCase()}${_selectedStatus.substring(1)}',
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700,
                    letterSpacing: 0.2)),
          ),
        ),
        const SizedBox(height: 12),

        // ── History ghost button
        SizedBox(
          width: double.infinity,
          height: 50,
          child: TextButton(
            onPressed: _navigateToHistory,
            style: TextButton.styleFrom(
              foregroundColor: _accent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text('View Attendance History',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ),
        ),
      ]),
    );
  }
}

// ── Location Row ──────────────────────────────────────────────────────────────
class _LocationRow extends StatelessWidget {
  final String address;
  final bool isLoading;
  final VoidCallback onRefresh;

  const _LocationRow({
    required this.address,
    required this.isLoading,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: _accent.withOpacity(0.10),
            shape: BoxShape.circle,
          ),
          child: isLoading
              ? const Padding(
              padding: EdgeInsets.all(7),
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: _accent))
              : const Icon(Icons.location_on_rounded, size: 18, color: _accent),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Location',
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600,
                    color: _muted, letterSpacing: 0.3)),
            const SizedBox(height: 2),
            Text(address,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600, color: _dark),
                overflow: TextOverflow.ellipsis),
          ]),
        ),
        if (!isLoading)
          GestureDetector(
            onTap: onRefresh,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.refresh_rounded, size: 18,
                  color: _muted.withOpacity(0.7)),
            ),
          ),
      ]),
    );
  }
}

// ── Status Card ───────────────────────────────────────────────────────────────
class _StatusCard extends StatelessWidget {
  final String  label;
  final IconData icon;
  final Color   color;
  final bool    isSelected;
  final VoidCallback onTap;

  const _StatusCard({
    required this.label,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            color: isSelected ? color : _surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: isSelected
                ? [BoxShadow(
                color: color.withOpacity(0.35),
                blurRadius: 16,
                offset: const Offset(0, 6))]
                : [BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 12,
                offset: const Offset(0, 2))],
          ),
          child: Column(children: [
            Icon(icon, size: 28, color: isSelected ? Colors.white : color),
            const SizedBox(height: 8),
            Text(label,
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : const Color(0xFF8E8EA0),
                    letterSpacing: 0.2)),
          ]),
        ),
      ),
    );
  }
}

// ── Already Marked ────────────────────────────────────────────────────────────
class _AlreadyMarkedView extends StatelessWidget {
  final Map<String, dynamic> record;
  final VoidCallback onViewHistory;

  const _AlreadyMarkedView({
    required this.record,
    required this.onViewHistory,
  });

  @override
  Widget build(BuildContext context) {
    final status  = (record['status'] ?? 'present').toString().toLowerCase();
    final remark  = (record['remark'] ?? '').toString().trim();
    final address = (record['location']?['address'] ?? '').toString().trim();

    final Color color;
    final IconData icon;
    final String label;
    final List<Color> gradient;

    switch (status) {
      case 'absent':
        color    = _red;
        icon     = Icons.cancel_rounded;
        label    = 'Absent';
        gradient = [const Color(0xFFFF4D6A), const Color(0xFFE03057)];
        break;
      case 'late':
        color    = _orange;
        icon     = Icons.access_time_rounded;
        label    = 'Late';
        gradient = [const Color(0xFFFF9A3C), const Color(0xFFE07B20)];
        break;
      default:
        color    = _green;
        icon     = Icons.check_circle_rounded;
        label    = 'Present';
        gradient = [const Color(0xFF00C48C), const Color(0xFF00A676)];
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: gradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                    color: color.withOpacity(0.35),
                    blurRadius: 24,
                    offset: const Offset(0, 8)),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 50),
          ),
          const SizedBox(height: 24),

          const Text('Already Marked',
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w800,
                  color: _dark, letterSpacing: -0.5)),
          const SizedBox(height: 8),
          Text(
            "You've already marked attendance for today.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: _muted, height: 1.5),
          ),
          const SizedBox(height: 20),

          // Status pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 7),
              Text(label,
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700, color: color)),
            ]),
          ),

          // ── Location under status pill
          if (address.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.location_on_rounded, size: 13, color: _muted),
              const SizedBox(width: 4),
              Flexible(
                child: Text(address,
                    style: const TextStyle(fontSize: 12, color: _muted),
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center),
              ),
            ]),
          ],

          if (remark.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 2)),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.notes_rounded, size: 15, color: _muted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(remark,
                        style: const TextStyle(
                            fontSize: 13, color: _dark, height: 1.4)),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 32),

          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: onViewHistory,
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('View Attendance History',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
      ),
    );
  }
}

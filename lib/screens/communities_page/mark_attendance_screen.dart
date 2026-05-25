import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:provider/provider.dart';
import '../../providers/attendance_provider.dart';
import 'attendance_history.dart';

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
  String _address   = 'Unknown';

  @override
  void initState() {
    super.initState();
    _fetchLocationSilently();
    _loadTodayAttendance();
  }

  @override
  void dispose() {
    _remarkController.dispose();
    super.dispose();
  }

  Future<void> _fetchLocationSilently() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
        if (perm == LocationPermission.denied) return;
      }
      if (perm == LocationPermission.deniedForever) return;
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.low);
      try {
        final marks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
        final p = marks.first;
        final addr = '${p.locality ?? ''}, ${p.administrativeArea ?? ''}'
            .trim()
            .replaceAll(RegExp(r'^,\s*|,\s*$'), '');
        _address = addr.isEmpty ? 'Unknown' : addr;
      } catch (_) {}
      _latitude  = pos.latitude;
      _longitude = pos.longitude;
    } catch (_) {}
  }

  Future<void> _loadTodayAttendance() async {
    await context.read<AttendanceProvider>().getTodayAttendance(
      studentId: widget.studentId,
      tenantId:  widget.communityId,
    );
  }

  Future<void> _markAttendance() async {
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
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: _dark,
                    letterSpacing: -0.5)),
            const SizedBox(height: 8),
            Text(
              'Your attendance is recorded for today.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: _muted, height: 1.4),
            ),
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
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
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
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: _dark,
                  letterSpacing: -0.3)),
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
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _accent)),
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
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _muted,
                letterSpacing: 0.3)),
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
        const SizedBox(height: 28),

        // ── Remark label
        const Text('Remark',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _muted,
                letterSpacing: 0.3)),
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
            style: const TextStyle(
                fontSize: 14, color: _dark, height: 1.5),
            decoration: InputDecoration(
              hintText: 'Optional note...',
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
                width: 22,
                height: 22,
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
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600)),
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
                ? [
              BoxShadow(
                  color: color.withOpacity(0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6))
            ]
                : [
              BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 2))
            ],
          ),
          child: Column(children: [
            Icon(icon,
                size: 28,
                color: isSelected ? Colors.white : color),
            const SizedBox(height: 8),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
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
    final status = (record['status'] ?? 'present').toString().toLowerCase();
    final remark = (record['remark'] ?? '').toString().trim();

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
          // Big gradient icon
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
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: _dark,
                  letterSpacing: -0.5)),
          const SizedBox(height: 8),

          Text(
            "You've already marked attendance for today.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: _muted, height: 1.5),
          ),
          const SizedBox(height: 20),


          // Status pill
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 7),
              Text(label,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: color)),
            ]),
          ),

          if (remark.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
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
                            fontSize: 13,
                            color: _dark,
                            height: 1.4)),
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
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/attendance_provider.dart';

// ── Design tokens ────────────────────────────────────────────────────────────
const _accent  = Color(0xFF6C5CE7);
const _bg      = Color(0xFFF7F7FB);
const _dark    = Color(0xFF1A1A2E);
const _surface = Color(0xFFFFFFFF);
const _muted   = Color(0xFF8E8EA0);

const _green   = Color(0xFF00C48C);
const _red     = Color(0xFFFF4D6A);
const _orange  = Color(0xFFFF9A3C);

class AttendanceHistoryScreen extends StatefulWidget {
  final String communityId;
  final String communityName;
  final String studentId;

  const AttendanceHistoryScreen({
    super.key,
    required this.communityId,
    required this.communityName,
    required this.studentId,
  });

  @override
  State<AttendanceHistoryScreen> createState() =>
      _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AttendanceProvider>().getAttendanceHistory(
        studentId: widget.studentId,
        tenantId:  widget.communityId,
      );
    });
  }

  Map<String, int> _stats(List<Map<String, dynamic>> records) {
    final c = {'present': 0, 'absent': 0, 'late': 0};
    for (final r in records) {
      final s = (r['status'] ?? '').toString().toLowerCase();
      if (c.containsKey(s)) c[s] = c[s]! + 1;
    }
    return c;
  }

  List<Map<String, dynamic>> _filtered(List<Map<String, dynamic>> records) {
    if (_filter == 'all') return records;
    return records
        .where((r) => (r['status'] ?? '').toString().toLowerCase() == _filter)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AttendanceProvider>(
      builder: (context, provider, _) {
        final stats    = _stats(provider.history);
        final filtered = _filtered(provider.history);

        return Scaffold(
          backgroundColor: _bg,
          appBar: AppBar(
            backgroundColor: _surface,
            foregroundColor: _dark,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            titleSpacing: 0,
            title: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('History',
                      style: TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w800,
                          color: _dark, letterSpacing: -0.3)),
                  Text(widget.communityName,
                      style: const TextStyle(fontSize: 11, color: _muted)),
                ],
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(height: 1, color: const Color(0xFFF0F0F5)),
            ),
          ),
          body: provider.isLoading
              ? const Center(
              child: CircularProgressIndicator(color: _accent))
              : provider.error != null
              ? _ErrorView(
            message: provider.error!,
            onRetry: () => context
                .read<AttendanceProvider>()
                .getAttendanceHistory(
              studentId: widget.studentId,
              tenantId:  widget.communityId,
            ),
          )
              : RefreshIndicator(
            color: _accent,
            onRefresh: () => context
                .read<AttendanceProvider>()
                .getAttendanceHistory(
              studentId: widget.studentId,
              tenantId:  widget.communityId,
            ),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              children: [
                _StatsRow(stats: stats),
                const SizedBox(height: 24),
                _FilterChips(
                  selected:  _filter,
                  onChanged: (v) => setState(() => _filter = v),
                ),
                const SizedBox(height: 16),
                filtered.isEmpty
                    ? _EmptyState(filter: _filter)
                    : _RecordList(records: filtered),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Stats Row ─────────────────────────────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  final Map<String, int> stats;
  const _StatsRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    final present = stats['present'] ?? 0;
    final absent  = stats['absent']  ?? 0;
    final late    = stats['late']    ?? 0;
    final total   = present + absent + late;
    final rate    = total > 0 ? present / total : 0.0;
    final rateStr = '${(rate * 100).toStringAsFixed(0)}%';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 16,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(children: [
        Row(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(rateStr,
                style: const TextStyle(
                    fontSize: 36, fontWeight: FontWeight.w800,
                    color: _dark, letterSpacing: -1)),
            const Text('Attendance Rate',
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w500, color: _muted)),
          ]),
          const Spacer(),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            _MiniPill(label: 'Present', count: present, color: _green),
            const SizedBox(height: 5),
            _MiniPill(label: 'Absent',  count: absent,  color: _red),
            const SizedBox(height: 5),
            _MiniPill(label: 'Late',    count: late,    color: _orange),
          ]),
        ]),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: rate,
            minHeight: 8,
            backgroundColor: const Color(0xFFF0F0F5),
            valueColor: AlwaysStoppedAnimation<Color>(
              rate >= 0.8 ? _green : rate >= 0.5 ? _orange : _red,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('$total total days',
                style: const TextStyle(fontSize: 11, color: _muted)),
            Text('$present present',
                style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600, color: _green)),
          ],
        ),
      ]),
    );
  }
}

class _MiniPill extends StatelessWidget {
  final String label;
  final int    count;
  final Color  color;
  const _MiniPill({required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text('$count',
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, color: color)),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w500,
                color: color.withOpacity(0.8))),
      ]),
    );
  }
}

// ── Filter Chips ──────────────────────────────────────────────────────────────
class _FilterChips extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  const _FilterChips({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const filters = [
      ('all',     'All'),
      ('present', 'Present'),
      ('absent',  'Absent'),
      ('late',    'Late'),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((f) {
          final isSelected = selected == f.$1;
          return GestureDetector(
            onTap: () => onChanged(f.$1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
              decoration: BoxDecoration(
                color: isSelected ? _accent : _surface,
                borderRadius: BorderRadius.circular(30),
                boxShadow: isSelected
                    ? [BoxShadow(
                    color: _accent.withOpacity(0.30),
                    blurRadius: 12,
                    offset: const Offset(0, 4))]
                    : [BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2))],
              ),
              child: Text(f.$2,
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : _muted)),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Record List ───────────────────────────────────────────────────────────────
class _RecordList extends StatelessWidget {
  final List<Map<String, dynamic>> records;
  const _RecordList({required this.records});

  /// Resolves the timestamp from the record — tries multiple field names.
  static String? _resolveTimestamp(Map<String, dynamic> r) {
    for (final key in ['markedAt', 'date', 'createdAt', 'updatedAt']) {
      final v = r[key];
      if (v != null && v.toString().isNotEmpty) return v.toString();
    }
    return null;
  }

  /// Parses ANY timestamp the API returns into a UTC DateTime.
  ///
  /// Handles:
  ///   • ISO 8601  → "2026-05-27T08:22:37.876Z"
  ///   • JS Date   → "Wed May 27 2026 08:22:37 GMT+0000 (Coordinated Universal Time)"
  static DateTime? _parseToUtc(String? raw) {
    if (raw == null || raw.isEmpty) return null;

    // 1. Try standard ISO parse first (covers createdAt / updatedAt)
    try {
      return DateTime.parse(raw).toUtc();
    } catch (_) {}

    // 2. Handle JS Date string: "Wed May 27 2026 08:22:37 GMT+0000 (...)"
    //    Extract just the part before the parenthesis, e.g. "Wed May 27 2026 08:22:37 GMT+0000"
    try {
      final cleaned = raw.replaceAll(RegExp(r'\(.*\)'), '').trim();
      // Replace "GMT+0000" / "GMT+0530" with a proper offset for parsing
      final normalized = cleaned.replaceFirstMapped(
        RegExp(r'GMT([+-]\d{4})'),
            (m) => m.group(1)!, // turns "GMT+0000" → "+0000"
      );
      // Now looks like: "Wed May 27 2026 08:22:37 +0000"
      // Dart can't parse this directly, so do it manually:
      const months = {
        'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4,
        'May': 5, 'Jun': 6, 'Jul': 7, 'Aug': 8,
        'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12,
      };
      // Regex: weekday  month   day   year    HH  MM  SS   ±HHMM
      final re = RegExp(
          r'\w+\s+(\w+)\s+(\d+)\s+(\d{4})\s+(\d{2}):(\d{2}):(\d{2})\s+([+-])(\d{2})(\d{2})');
      final match = re.firstMatch(normalized);
      if (match != null) {
        final month  = months[match.group(1)] ?? 1;
        final day    = int.parse(match.group(2)!);
        final year   = int.parse(match.group(3)!);
        final hour   = int.parse(match.group(4)!);
        final minute = int.parse(match.group(5)!);
        final second = int.parse(match.group(6)!);
        final sign   = match.group(7) == '+' ? 1 : -1;
        final offH   = int.parse(match.group(8)!);
        final offM   = int.parse(match.group(9)!);
        final offsetMinutes = sign * (offH * 60 + offM);
        final utc = DateTime.utc(year, month, day, hour, minute, second)
            .subtract(Duration(minutes: offsetMinutes));
        return utc;
      }
    } catch (_) {}

    return null;
  }

  /// Converts UTC DateTime → IST (UTC+5:30)
  static DateTime _toIST(DateTime utc) =>
      utc.add(const Duration(hours: 5, minutes: 30));

  static String _formatDate(String? raw) {
    final utc = _parseToUtc(raw);
    if (utc == null) return 'Unknown';

    final dt = _toIST(utc);
    const m  = ['Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'];

    // Compare date in IST
    final nowIST   = _toIST(DateTime.now().toUtc());
    final todayIST = DateTime(nowIST.year, nowIST.month, nowIST.day);
    final dIST     = DateTime(dt.year, dt.month, dt.day);

    if (dIST == todayIST) return 'Today';
    if (dIST == todayIST.subtract(const Duration(days: 1))) return 'Yesterday';
    return '${m[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  static String _formatTime(String? raw) {
    final utc = _parseToUtc(raw);
    if (utc == null) return '';

    final dt     = _toIST(utc);
    final h      = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final min    = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour < 12 ? 'AM' : 'PM';
    return '$h:$min $period';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: records.map((r) {
        final status   = (r['status'] ?? 'present').toString().toLowerCase();
        final remark   = (r['remark'] ?? '').toString().trim();
        final address  = (r['location']?['address'] ?? '').toString().trim();
        final ts       = _resolveTimestamp(r);
        final dateStr  = _formatDate(ts);
        final timeStr  = _formatTime(ts);

        final Color color;
        final IconData icon;
        final String label;
        switch (status) {
          case 'absent':
            color = _red;    icon = Icons.cancel_rounded;       label = 'Absent';  break;
          case 'late':
            color = _orange; icon = Icons.access_time_rounded;  label = 'Late';    break;
          default:
            color = _green;  icon = Icons.check_circle_rounded; label = 'Present';
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
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
          child: Row(children: [
            // Status icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),

            // Info column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date
                  Text(dateStr,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700, color: _dark)),
                  const SizedBox(height: 3),

                  // Time row
                  if (timeStr.isNotEmpty)
                    Row(children: [
                      const Icon(Icons.access_time_rounded, size: 11, color: _muted),
                      const SizedBox(width: 3),
                      Text(timeStr,
                          style: const TextStyle(fontSize: 12, color: _muted)),
                    ]),

                  // Location row
                  if (address.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Row(children: [
                      const Icon(Icons.location_on_rounded, size: 11, color: _muted),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(address,
                            style: const TextStyle(fontSize: 12, color: _muted),
                            overflow: TextOverflow.ellipsis),
                      ),
                    ]),
                  ],

                  // Remark row
                  if (remark.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Row(children: [
                      const Icon(Icons.notes_rounded, size: 11, color: _muted),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(remark,
                            style: const TextStyle(fontSize: 12, color: _muted),
                            overflow: TextOverflow.ellipsis),
                      ),
                    ]),
                  ],
                ],
              ),
            ),

            // Status chip — right
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: color.withOpacity(0.10),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(label,
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700, color: color)),
            ),
          ]),
        );
      }).toList(),
    );
  }
}

// ── Empty State ───────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final String filter;
  const _EmptyState({required this.filter});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: _accent.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.event_note_outlined,
                size: 32, color: _accent.withOpacity(0.5)),
          ),
          const SizedBox(height: 16),
          Text(
              filter == 'all' ? 'No records yet' : 'No $filter records',
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700, color: _dark)),
          const SizedBox(height: 6),
          Text(
              filter == 'all'
                  ? 'Start marking attendance to see records here.'
                  : 'Try a different filter.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: _muted)),
        ]),
      ),
    );
  }
}

// ── Error View ────────────────────────────────────────────────────────────────
class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: _red.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.error_outline_rounded, size: 32, color: _red),
          ),
          const SizedBox(height: 16),
          const Text('Something went wrong',
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700, color: _dark)),
          const SizedBox(height: 6),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: _muted)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Try Again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _accent,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ]),
      ),
    );
  }
}
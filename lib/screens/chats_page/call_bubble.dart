import 'package:flutter/material.dart';
import '../../constants/constants.dart';

class CallBubble extends StatelessWidget {
  final Map<String, dynamic> call;
  final bool isMe;
  final String? currentUserId;

  const CallBubble({
    Key? key,
    required this.call,
    required this.isMe,
    this.currentUserId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final rawStatus = call['callStatus'] ?? call['status'] ?? 'unknown';
    final type      = call['callType']   ?? call['type']   ?? 'voice';
    final duration  = call['duration']   ?? 0;
    final createdAt = call['createdAt']  ?? '';

    final String displayStatus = _resolveDisplayStatus(
      rawStatus: rawStatus,
      isMe: isMe,
    );

    final statusConfig = _getStatusConfig(displayStatus);
    final isVideo      = type == 'video';

    // ── Always green for incoming/outgoing, red for missed/rejected ──
    final Color statusColor = statusConfig['color'] as Color;

    final Color iconColor   = statusColor; // ✅ always based on status
    final Color iconBgColor = statusColor.withOpacity(0.12); // ✅ always based on status

    final Color titleColor    = isMe ? Colors.white : Colors.black87;
    final Color subtitleColor = statusColor; // ✅ always status color
    final Color timeColor     = isMe ? Colors.white60 : Colors.grey[500]!;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.65,
        ),
        decoration: BoxDecoration(
          color: isMe ? Primary : Colors.white,
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomRight: isMe  ? const Radius.circular(4) : null,
            bottomLeft:  !isMe ? const Radius.circular(4) : null,
          ),
          boxShadow: [
            BoxShadow(
              color:      Colors.black.withOpacity(0.08),
              blurRadius: 6,
              offset:     const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [

              // ── Circle icon ────────────────────────────────────────────
              Container(
                width:  44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  shape: BoxShape.circle,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      isVideo ? Icons.videocam_rounded : Icons.call_rounded,
                      color: iconColor,
                      size:  22,
                    ),
                    Positioned(
                      right:  0,
                      bottom: 0,
                      child: Container(
                        width:  16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: isMe
                              ? Colors.white.withOpacity(0.25)
                              : statusColor.withOpacity(0.18),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          statusConfig['icon'] as IconData,
                          size:  10,
                          color: iconColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 10),

              // ── Text column ────────────────────────────────────────────
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize:       MainAxisSize.min,
                  children: [
                    Text(
                      isVideo ? 'Video Call' : 'Voice Call',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize:   14,
                        color:      titleColor,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          statusConfig['label'] as String,
                          style: TextStyle(
                            fontSize:   12,
                            color:      subtitleColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (duration > 0) ...[
                          Text(
                            ' · ${_formatDuration(duration)}',
                            style: TextStyle(fontSize: 12, color: timeColor),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // ── Timestamp ──────────────────────────────────────────────
              Text(
                _formatTime(createdAt),
                style: TextStyle(fontSize: 11, color: timeColor),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  //  STATUS RESOLUTION
  //
  //  The rawStatus is always stored from the CALLER's perspective:
  //    'outgoing' = caller sent the call
  //    'incoming' = same call, but stored again from receiver side  ← BUG SOURCE
  //    'missed'   = receiver never picked up
  //    'rejected' = receiver declined
  //
  //  Fix: store only ONE record per call. isMe tells us which side we are.
  //  If rawStatus == 'outgoing':
  //    → isMe (I placed it)   → show "Outgoing" (green)
  //    → !isMe (I received it) → show "Incoming" (green)
  //  If rawStatus == 'missed' or 'rejected': always red, label unchanged.
  // ══════════════════════════════════════════════════════════════════════

  String _resolveDisplayStatus({
    required String rawStatus,
    required bool isMe,
  }) {
    switch (rawStatus) {
      case 'outgoing':
        return isMe ? 'outgoing' : 'incoming';
      case 'incoming':
        return isMe ? 'incoming' : 'outgoing';
      case 'missed':
        return 'missed';
      case 'rejected':
        return 'rejected';
      default:
        return rawStatus;
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  //  STATUS CONFIG — colors are fixed:
  //    missed / rejected → RED
  //    incoming / outgoing → GREEN
  // ══════════════════════════════════════════════════════════════════════

  Map<String, dynamic> _getStatusConfig(String status) {
    switch (status) {
      case 'missed':
        return {
          'icon':  Icons.call_missed_rounded,
          'color': Colors.red[400]!,     // 🔴 red
          'label': 'Missed',
        };
      case 'rejected':
        return {
          'icon':  Icons.call_end_rounded,
          'color': Colors.red[400]!,     // 🔴 red
          'label': 'Declined',
        };
      case 'outgoing':
        return {
          'icon':  Icons.call_made_rounded,
          'color': Colors.green[500]!,   // 🟢 green
          'label': 'Outgoing',
        };
      case 'incoming':
        return {
          'icon':  Icons.call_received_rounded,
          'color': Colors.green[500]!,   // 🟢 green
          'label': 'Incoming',
        };
      default:
        return {
          'icon':  Icons.call_rounded,
          'color': Colors.grey[500]!,
          'label': 'Call',
        };
    }
  }

  String _formatDuration(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m}m ${s}s';
  }

  String _formatTime(String timestamp) {
    if (timestamp.isEmpty) return '';
    try {
      final dt     = DateTime.parse(timestamp).toLocal();
      final h      = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final m      = dt.minute.toString().padLeft(2, '0');
      final period = dt.hour >= 12 ? 'PM' : 'AM';
      return '$h:$m $period';
    } catch (_) {
      return '';
    }
  }
}
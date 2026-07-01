import 'package:shared_preferences/shared_preferences.dart';

/// Persists ended call roomNames across isolates (background FCM isolate
/// vs main app isolate) so a call that already ended can never be
/// resurrected by CallKit or a replayed socket event.
///
/// Usage:
///   await CallEndTracker.markEnded(roomName);   // call died
///   final dead = await CallEndTracker.isEnded(roomName); // check before resurfacing
class CallEndTracker {
  static const _key = 'ended_call_rooms';
  static const _maxAgeMs = 5 * 60 * 1000; // 5 minutes

  static Future<void> markEnded(String roomName) async {
    if (roomName.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_key) ?? [];
      final now = DateTime.now().millisecondsSinceEpoch;
      raw.add('$roomName|$now');
      final pruned = _prune(raw, now);
      await prefs.setStringList(_key, pruned);
    } catch (_) {
      // best effort — never let tracking failures break call flow
    }
  }

  static Future<bool> isEnded(String roomName) async {
    if (roomName.isEmpty) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_key) ?? [];
      final now = DateTime.now().millisecondsSinceEpoch;
      for (final e in raw) {
        final parts = e.split('|');
        if (parts.length != 2) continue;
        final ts = int.tryParse(parts[1]) ?? 0;
        if (parts[0] == roomName && now - ts < _maxAgeMs) return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  static List<String> _prune(List<String> raw, int now) {
    return raw.where((e) {
      final parts = e.split('|');
      if (parts.length != 2) return false;
      final ts = int.tryParse(parts[1]) ?? 0;
      return now - ts < _maxAgeMs;
    }).toList();
  }
}
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../../constants/constants.dart';
import '../../providers/personal_chat_provider.dart';

class CallHistoryScreen extends StatefulWidget {
  const CallHistoryScreen({Key? key}) : super(key: key);

  @override
  State<CallHistoryScreen> createState() => _CallHistoryScreenState();
}

class _CallHistoryScreenState extends State<CallHistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PersonalChatProvider>().fetchCallHistory(pageNo: 1);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1A2E),
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Call History',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: Color(0xFF1A1A2E),
            letterSpacing: -0.3,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFF0F2F8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: Primary,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Primary.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.grey[500],
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
                tabs: const [
                  Tab(text: 'All Calls'),
                  Tab(text: 'Missed'),
                ],
              ),
            ),
          ),
        ),
      ),
      // FIX: Use separate widgets per tab so each has its own
      // ScrollController and load-more state — they don't interfere.
      body: TabBarView(
        controller: _tabController,
        children: const [
          _CallListTab(filter: 'all'),
          _CallListTab(filter: 'missed'),
        ],
      ),
    );
  }
}

// ── Per-tab widget with its own scroll + pagination state ─────────────────────

class _CallListTab extends StatefulWidget {
  final String filter; // 'all' or 'missed'
  const _CallListTab({required this.filter});

  @override
  State<_CallListTab> createState() => _CallListTabState();
}

class _CallListTabState extends State<_CallListTab>
    with AutomaticKeepAliveClientMixin {
  // Keep alive so switching tabs doesn't destroy + re-create the list
  @override
  bool get wantKeepAlive => true;

  final ScrollController _scrollController = ScrollController();
  int  _currentPage   = 1;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore) return;
    final provider = context.read<PersonalChatProvider>();
    final pagination = provider.callPagination;
    final totalPages = pagination['totalPages'] ?? 1;
    if (_currentPage >= totalPages) return;

    setState(() => _isLoadingMore = true);
    _currentPage++;
    await provider.fetchCallHistory(pageNo: _currentPage);
    if (mounted) setState(() => _isLoadingMore = false);
  }

  Future<void> _refresh(PersonalChatProvider provider) async {
    _currentPage = 1;
    await provider.fetchCallHistory(pageNo: 1);
  }

  List<dynamic> _filtered(List<dynamic> all) {
    if (widget.filter == 'missed') {
      return all.where((c) => c['status'] == 'missed').toList();
    }
    return all;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // required for AutomaticKeepAliveClientMixin

    return Consumer<PersonalChatProvider>(
      builder: (context, provider, _) {
        // Show full-screen loader only on first load
        if (provider.isCallHistoryLoading && provider.callHistory.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(color: Primary),
          );
        }

        final calls = _filtered(provider.callHistory);

        if (calls.isEmpty) {
          return _buildEmptyState();
        }

        return RefreshIndicator(
          color: Primary,
          onRefresh: () => _refresh(provider),
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: calls.length + (_isLoadingMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == calls.length) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                      child: CircularProgressIndicator(color: Primary)),
                );
              }

              final call = calls[index];
              final createdAt = call['createdAt'] ?? '';
              final showHeader = index == 0 ||
                  !_isSameDay(createdAt, calls[index - 1]['createdAt'] ?? '');

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showHeader) _buildDateHeader(createdAt),
                  _buildCallItem(call, provider.currentUserId),
                ],
              );
            },
          ),
        );
      },
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  bool _isSameDay(String a, String b) {
    try {
      final da = DateTime.parse(a).toLocal();
      final db = DateTime.parse(b).toLocal();
      return da.year == db.year && da.month == db.month && da.day == db.day;
    } catch (_) {
      return false;
    }
  }

  Widget _buildDateHeader(String timestamp) {
    String label = '';
    try {
      final dt  = DateTime.parse(timestamp).toLocal();
      final now = DateTime.now();
      final diff = DateTime(now.year, now.month, now.day)
          .difference(DateTime(dt.year, dt.month, dt.day))
          .inDays;
      if (diff == 0) {
        label = 'Today';
      } else if (diff == 1) {
        label = 'Yesterday';
      } else if (diff < 7) {
        const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday',
          'Friday', 'Saturday', 'Sunday'];
        label = days[dt.weekday - 1];
      } else {
        label = '${dt.day} ${_monthName(dt.month)} ${dt.year}';
      }
    } catch (_) {}

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 6),
      child: Row(
        children: [
          Expanded(child: Divider(color: Colors.grey[300], height: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
          Expanded(child: Divider(color: Colors.grey[300], height: 1)),
        ],
      ),
    );
  }

  String _monthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  Widget _buildCallItem(Map<String, dynamic> call, String? currentUserId) {
    final status    = call['status'] ?? 'unknown';
    final type      = call['type']   ?? 'voice';
    final duration  = call['duration'] ?? 0;
    final createdAt = call['createdAt'] ?? '';

    final caller   = call['callerId']   as Map<String, dynamic>?;
    final receiver = call['receiverId'] as Map<String, dynamic>?;

    final callerId   = caller?['_id']?.toString()   ?? caller?['id']?.toString()   ?? '';
    final receiverId = receiver?['_id']?.toString() ?? receiver?['id']?.toString() ?? '';

    // Show the OTHER person — not the current user
    final Map<String, dynamic>? otherPerson =
    (callerId == currentUserId) ? receiver : caller;

    final name         = otherPerson?['profile']?['name']         ?? 'Unknown';
    final profileImage = otherPerson?['profile']?['profileImage'] ?? '';

    final statusConfig = _getStatusConfig(status);
    final isVideo  = type == 'video';
    final isMissed = status == 'missed';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isMissed
            ? Border.all(color: Colors.red.withOpacity(0.15), width: 1)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {},
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Avatar with call-type badge
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: (statusConfig['color'] as Color).withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 24,
                        backgroundColor: Primary.withOpacity(0.08),
                        backgroundImage: profileImage.isNotEmpty
                            ? (profileImage.startsWith('data:image/')
                            ? MemoryImage(
                            base64Decode(profileImage.split(',')[1]))
                            : NetworkImage(profileImage) as ImageProvider)
                            : null,
                        child: profileImage.isEmpty
                            ? Text(
                          name.isNotEmpty ? name[0].toUpperCase() : 'U',
                          style: const TextStyle(
                            color: Primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        )
                            : null,
                      ),
                    ),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: isVideo
                              ? const Color(0xFF6C5CE7)
                              : const Color(0xFF00B894),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: Icon(
                          isVideo
                              ? Icons.videocam_rounded
                              : Icons.call_rounded,
                          size: 11,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 14),

                // Name + status row
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: isMissed
                              ? Colors.red[700]
                              : const Color(0xFF1A1A2E),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Icon(
                            statusConfig['icon'] as IconData,
                            size: 14,
                            color: statusConfig['color'] as Color,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            statusConfig['label'] as String,
                            style: TextStyle(
                              fontSize: 12,
                              color: statusConfig['color'] as Color,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            width: 3, height: 3,
                            decoration: BoxDecoration(
                              color: Colors.grey[400],
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isVideo ? 'Video' : 'Voice',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (duration > 0) ...[
                            const SizedBox(width: 6),
                            Container(
                              width: 3, height: 3,
                              decoration: BoxDecoration(
                                color: Colors.grey[400],
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _formatDuration(duration),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // Time + call-back button
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatTime(createdAt),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[400],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () {
                        // TODO: initiate call back
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isVideo
                              ? const Color(0xFF6C5CE7).withOpacity(0.1)
                              : Primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          isVideo
                              ? Icons.videocam_rounded
                              : Icons.call_rounded,
                          size: 18,
                          color:
                          isVideo ? const Color(0xFF6C5CE7) : Primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final isMissed = widget.filter == 'missed';
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: isMissed
                  ? Colors.red.withOpacity(0.08)
                  : Primary.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isMissed ? Icons.call_missed_rounded : Icons.call_outlined,
              size: 48,
              color: isMissed ? Colors.red[400] : Primary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            isMissed ? 'No missed calls' : 'No call history yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.grey[700],
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isMissed
                ? 'All your missed calls will appear here'
                : 'Your voice & video calls will appear here',
            style: TextStyle(
                fontSize: 14, color: Colors.grey[500], height: 1.5),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _getStatusConfig(String status) {
    switch (status) {
      case 'missed':
        return {
          'icon': Icons.call_missed_rounded,
          'color': Colors.red[400]!,
          'label': 'Missed',
        };
      case 'rejected':
        return {
          'icon': Icons.call_end_rounded,
          'color': Colors.orange[400]!,
          'label': 'Declined',
        };
      case 'incoming':
        return {
          'icon': Icons.call_received_rounded,
          'color': Colors.green[500]!,
          'label': 'Incoming',
        };
      case 'outgoing':
        return {
          'icon': Icons.call_made_rounded,
          'color': Primary,
          'label': 'Outgoing',
        };
      default:
        return {
          'icon': Icons.call_rounded,
          'color': Colors.grey[500]!,
          'label': status,
        };
    }
  }

  String _formatDuration(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (s == 0) return '${m}m';
    return '${m}m ${s}s';
  }

  String _formatTime(String timestamp) {
    if (timestamp.isEmpty) return '';
    try {
      final dt  = DateTime.parse(timestamp).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inDays == 0) {
        final h      = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
        final m      = dt.minute.toString().padLeft(2, '0');
        final period = dt.hour >= 12 ? 'PM' : 'AM';
        return '$h:$m $period';
      } else if (diff.inDays == 1) {
        return 'Yesterday';
      } else if (diff.inDays < 7) {
        const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        return days[dt.weekday - 1];
      } else {
        return '${dt.day}/${dt.month}/${dt.year}';
      }
    } catch (_) {
      return '';
    }
  }
}

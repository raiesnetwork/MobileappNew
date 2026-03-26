import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/communities_provider.dart';

class CommunityEventsScreen extends StatefulWidget {
  final String communityId;
  final String communityName;

  const CommunityEventsScreen({
    Key? key,
    required this.communityId,
    required this.communityName,
  }) : super(key: key);

  @override
  State<CommunityEventsScreen> createState() => _CommunityEventsScreenState();
}

class _CommunityEventsScreenState extends State<CommunityEventsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;

  // ── Theme tokens ──────────────────────────────────────────────────────────
  static const _bg = Color(0xFFF6F7FB);
  static const _surface = Colors.white;
  static const _accent = Color(0xFF4F6EF7);
  static const _accentLight = Color(0xFFEEF1FE);
  static const _textPrimary = Color(0xFF1A1D2E);
  static const _textSecondary = Color(0xFF7B8099);
  static const _green = Color(0xFF22C55E);
  static const _greenLight = Color(0xFFDCFCE7);
  static const _orange = Color(0xFFF97316);
  static const _orangeLight = Color(0xFFFFEDD5);
  static const _grey = Color(0xFF9CA3AF);
  static const _greyLight = Color(0xFFF3F4F6);

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadEvents();
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadEvents() async {
    final provider = Provider.of<CommunityProvider>(context, listen: false);
    await provider.fetchCommunityEvents(widget.communityId);
    _animController.forward(from: 0);
  }

  void _showEventDetails(BuildContext context, Map<String, dynamic> event) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EventDetailsBottomSheet(event: event),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: _buildAppBar(),
      body: Consumer<CommunityProvider>(
        builder: (context, provider, child) {
          if (provider.isLoadingEvents) return _buildLoader();
          if (provider.eventsError != null) return _buildError(provider);

          final events =
              provider.communityEvents['data'] as List<dynamic>? ?? [];
          final email = provider.eventEmail;
          final password = provider.eventPassword;

          if (events.isEmpty) return _buildEmpty();

          return RefreshIndicator(
            onRefresh: _loadEvents,
            color: _accent,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                if (email != null || password != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: _CredentialsCard(
                        email: email,
                        password: password,
                        accent: _accent,
                        accentLight: _accentLight,
                        textPrimary: _textPrimary,
                        textSecondary: _textSecondary,
                      ),
                    ),
                  ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                          (context, index) {
                        final event =
                        events[index] as Map<String, dynamic>;
                        final delay = index * 80;
                        return TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: 1),
                          duration: Duration(
                              milliseconds: 400 + delay),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, child) => Opacity(
                            opacity: value,
                            child: Transform.translate(
                              offset: Offset(0, 20 * (1 - value)),
                              child: child,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _EventCard(
                              event: event,
                              accent: _accent,
                              accentLight: _accentLight,
                              green: _green,
                              greenLight: _greenLight,
                              orange: _orange,
                              orangeLight: _orangeLight,
                              grey: _grey,
                              greyLight: _greyLight,
                              surface: _surface,
                              textPrimary: _textPrimary,
                              textSecondary: _textSecondary,
                              onTap: () =>
                                  _showEventDetails(context, event),
                            ),
                          ),
                        );
                      },
                      childCount: events.length,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    // Shorten the community name if it's too long
    final shortName = widget.communityName.length > 20
        ? '${widget.communityName.substring(0, 18)}…'
        : widget.communityName;

    return AppBar(
      backgroundColor: _surface,
      foregroundColor: _textPrimary,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      titleSpacing: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        onPressed: () => Navigator.pop(context),
        color: _textPrimary,
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Events',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: _textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          Text(
            shortName,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: _textSecondary,
            ),
          ),
        ],
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: const Color(0xFFEEEFF3), height: 1),
      ),
    );
  }

  Widget _buildLoader() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: _accent,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading events…',
            style: TextStyle(
              color: _textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(CommunityProvider provider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.red[50],
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.wifi_off_rounded,
                  size: 32, color: Colors.red[400]),
            ),
            const SizedBox(height: 20),
            Text(
              'Couldn\'t load events',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              provider.eventsError ?? 'Something went wrong.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: _textSecondary),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: 140,
              child: ElevatedButton.icon(
                onPressed: _loadEvents,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Try again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: _accentLight,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.event_rounded, size: 36, color: _accent),
          ),
          const SizedBox(height: 20),
          Text(
            'No events yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Check back later for upcoming events',
            style: TextStyle(fontSize: 14, color: _textSecondary),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Credentials card
// ─────────────────────────────────────────────────────────────────────────────
class _CredentialsCard extends StatelessWidget {
  final String? email;
  final String? password;
  final Color accent;
  final Color accentLight;
  final Color textPrimary;
  final Color textSecondary;

  const _CredentialsCard({
    required this.email,
    required this.password,
    required this.accent,
    required this.accentLight,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accentLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.vpn_key_rounded,
                    color: Colors.white, size: 14),
              ),
              const SizedBox(width: 10),
              Text(
                'Meeting Credentials',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: textPrimary,
                ),
              ),
            ],
          ),
          if (email != null) ...[
            const SizedBox(height: 12),
            _CredRow(
              icon: Icons.email_outlined,
              label: 'Email',
              value: email!,
              accent: accent,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),
          ],
          if (password != null) ...[
            const SizedBox(height: 8),
            _CredRow(
              icon: Icons.lock_outline_rounded,
              label: 'Password',
              value: password!,
              accent: accent,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),
          ],
        ],
      ),
    );
  }
}

class _CredRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color accent;
  final Color textPrimary;
  final Color textSecondary;

  const _CredRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: accent),
        const SizedBox(width: 8),
        Text(
          '$label:',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: textSecondary,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              color: textPrimary,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        GestureDetector(
          onTap: () {
            Clipboard.setData(ClipboardData(text: value));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('$label copied'),
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
                backgroundColor: const Color(0xFF1A1D2E),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(Icons.copy_rounded, size: 14, color: accent),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Event card
// ─────────────────────────────────────────────────────────────────────────────
class _EventCard extends StatelessWidget {
  final Map<String, dynamic> event;
  final VoidCallback onTap;
  final Color accent, accentLight, green, greenLight, orange, orangeLight;
  final Color grey, greyLight, surface, textPrimary, textSecondary;

  const _EventCard({
    required this.event,
    required this.onTap,
    required this.accent,
    required this.accentLight,
    required this.green,
    required this.greenLight,
    required this.orange,
    required this.orangeLight,
    required this.grey,
    required this.greyLight,
    required this.surface,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    final title = event['title'] ?? 'Untitled Event';
    final description = (event['description'] ?? '').toString();
    final startDate = event['start'] != null
        ? DateTime.parse(event['start'])
        : DateTime.now();
    final endDate = event['end'] != null
        ? DateTime.parse(event['end'])
        : startDate.add(const Duration(hours: 1));

    final now = DateTime.now();
    final isOngoing = startDate.isBefore(now) && endDate.isAfter(now);
    final isUpcoming = startDate.isAfter(now);

    final statusColor = isOngoing ? green : isUpcoming ? accent : grey;
    final statusBg = isOngoing ? greenLight : isUpcoming ? accentLight : greyLight;
    final statusLabel = isOngoing ? 'Live' : isUpcoming ? 'Upcoming' : 'Past';
    final statusIcon = isOngoing
        ? Icons.circle
        : isUpcoming
        ? Icons.schedule_rounded
        : Icons.check_circle_outline_rounded;

    return Material(
      color: surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFEEEFF3)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title row + badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon,
                              size: isOngoing ? 8 : 12,
                              color: statusColor),
                          const SizedBox(width: 4),
                          Text(
                            statusLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                if (description.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],

                const SizedBox(height: 12),

                // Date / time row
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6F7FB),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today_rounded,
                          size: 13, color: accent),
                      const SizedBox(width: 5),
                      Text(
                        DateFormat('MMM dd, yyyy').format(startDate),
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: textPrimary),
                      ),
                      Container(
                        margin:
                        const EdgeInsets.symmetric(horizontal: 8),
                        width: 3,
                        height: 3,
                        decoration: BoxDecoration(
                          color: textSecondary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Icon(Icons.access_time_rounded,
                          size: 13, color: accent),
                      const SizedBox(width: 5),
                      Text(
                        '${DateFormat('HH:mm').format(startDate)} – ${DateFormat('HH:mm').format(endDate)}',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Event details bottom sheet
// ─────────────────────────────────────────────────────────────────────────────
class EventDetailsBottomSheet extends StatelessWidget {
  final Map<String, dynamic> event;

  static const _bg = Color(0xFFF6F7FB);
  static const _surface = Colors.white;
  static const _accent = Color(0xFF4F6EF7);
  static const _accentLight = Color(0xFFEEF1FE);
  static const _textPrimary = Color(0xFF1A1D2E);
  static const _textSecondary = Color(0xFF7B8099);

  const EventDetailsBottomSheet({Key? key, required this.event})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final title = event['title'] ?? 'Untitled Event';
    final description =
    (event['description'] ?? 'No description provided.').toString();
    final userEmail = event['userEmail']?.toString();
    final password = event['password']?.toString();
    final mailcowEventId = event['mailcowEventId']?.toString();
    final startDate = event['start'] != null
        ? DateTime.parse(event['start'])
        : DateTime.now();
    final endDate = event['end'] != null
        ? DateTime.parse(event['end'])
        : startDate.add(const Duration(hours: 1));

    final durationMins = endDate.difference(startDate).inMinutes;

    return Container(
      decoration: const BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.62,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        expand: false,
        builder: (context, scrollController) {
          return ListView(
            controller: scrollController,
            padding: EdgeInsets.zero,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDDE0EA),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header band
              Container(
                margin: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: _accentLight,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _accent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.event_rounded,
                          color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: _textPrimary,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            DateFormat('EEE, MMM dd · HH:mm')
                                .format(startDate),
                            style: const TextStyle(
                              fontSize: 12,
                              color: _textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Info tiles
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Time block
                    _SectionLabel(label: 'Schedule'),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _InfoTile(
                            icon: Icons.play_arrow_rounded,
                            label: 'Starts',
                            value: DateFormat('hh:mm a')
                                .format(startDate),
                            iconColor: const Color(0xFF22C55E),
                            iconBg: const Color(0xFFDCFCE7),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _InfoTile(
                            icon: Icons.stop_rounded,
                            label: 'Ends',
                            value:
                            DateFormat('hh:mm a').format(endDate),
                            iconColor: const Color(0xFFF97316),
                            iconBg: const Color(0xFFFFEDD5),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _InfoTile(
                            icon: Icons.timelapse_rounded,
                            label: 'Duration',
                            value: '$durationMins min',
                            iconColor: _accent,
                            iconBg: _accentLight,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Description
                    _SectionLabel(label: 'About'),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _bg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        description,
                        style: const TextStyle(
                          fontSize: 14,
                          color: _textSecondary,
                          height: 1.55,
                        ),
                      ),
                    ),

                    // Meeting credentials
                    if (userEmail != null || password != null) ...[
                      const SizedBox(height: 20),
                      _SectionLabel(label: 'Meeting Details'),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _bg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: const Color(0xFFEEEFF3)),
                        ),
                        child: Column(
                          children: [
                            if (userEmail != null)
                              _CopyTile(
                                icon: Icons.email_outlined,
                                label: 'Email',
                                value: userEmail,
                                accent: _accent,
                                textPrimary: _textPrimary,
                                textSecondary: _textSecondary,
                              ),
                            if (userEmail != null && password != null)
                              Divider(
                                  height: 20,
                                  color: const Color(0xFFEEEFF3)),
                            if (password != null)
                              _CopyTile(
                                icon: Icons.lock_outline_rounded,
                                label: 'Password',
                                value: password,
                                accent: _accent,
                                textPrimary: _textPrimary,
                                textSecondary: _textSecondary,
                              ),
                          ],
                        ),
                      ),
                    ],

                    if (mailcowEventId != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: _bg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.tag_rounded,
                                size: 15, color: _textSecondary),
                            const SizedBox(width: 8),
                            Text(
                              'ID: ',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: _textSecondary,
                                  fontWeight: FontWeight.w600),
                            ),
                            Text(
                              mailcowEventId,
                              style: const TextStyle(
                                  fontSize: 13, color: _textPrimary),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 28),

                    // Close button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _accent,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding:
                          const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Close',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small reusable widgets
// ─────────────────────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: Color(0xFF7B8099),
        letterSpacing: 0.8,
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color iconColor;
  final Color iconBg;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.iconColor,
    required this.iconBg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEEEFF3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 14, color: iconColor),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF7B8099),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1D2E),
            ),
          ),
        ],
      ),
    );
  }
}

class _CopyTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color accent;
  final Color textPrimary;
  final Color textSecondary;

  const _CopyTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: accent),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                color: textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const Spacer(),
        GestureDetector(
          onTap: () {
            Clipboard.setData(ClipboardData(text: value));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('$label copied'),
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
                backgroundColor: const Color(0xFF1A1D2E),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFEEEFF3)),
            ),
            child: Icon(Icons.copy_rounded, size: 14, color: accent),
          ),
        ),
      ],
    );
  }
}
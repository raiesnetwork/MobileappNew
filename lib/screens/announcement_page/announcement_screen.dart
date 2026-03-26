import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ixes.app/constants/constants.dart';
import 'package:provider/provider.dart';
import '../../providers/announcement_provider.dart';
import 'package:intl/intl.dart';
import 'create_announcement_screen.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────
class _T {
  static const bg = Color(0xFFF7F8FC);
  static const surface = Colors.white;
  static const accent = Color(0xFF6366F1);
  static const accentLight = Color(0xFFEEF0FD);
  static const accentMid = Color(0xFFD4D7FB);
  static const textPrimary = Color(0xFF111827);
  static const textSecondary = Color(0xFF6B7280);
  static const textTertiary = Color(0xFF9CA3AF);
  static const divider = Color(0xFFF0F1F5);
  static const red = Color(0xFFEF4444);
  static const redLight = Color(0xFFFEE2E2);
  static const green = Color(0xFF10B981);
  static const shadow = Color(0x0A000000);
}

_AnnouncementMeta _metaFor(Map<String, dynamic> a) {
  final t = (a['title'] ?? '').toString().toLowerCase();
  final type = (a['templateType'] ?? '').toString().toLowerCase();
  if (type == 'job' || t.contains('job') || t.contains('hiring'))
    return _AnnouncementMeta(
        Icons.work_rounded, const Color(0xFF6366F1), const Color(0xFFEEF0FD));
  if (type == 'event' || t.contains('event') || t.contains('meeting'))
    return _AnnouncementMeta(
        Icons.event_rounded, const Color(0xFF10B981), const Color(0xFFD1FAE5));
  if (type == 'sale' || t.contains('sale') || t.contains('offer'))
    return _AnnouncementMeta(Icons.local_offer_rounded, const Color(0xFFF59E0B),
        const Color(0xFFFEF3C7));
  if (t.contains('news') || t.contains('update'))
    return _AnnouncementMeta(Icons.newspaper_rounded, const Color(0xFF3B82F6),
        const Color(0xFFDBEAFE));
  return _AnnouncementMeta(
      Icons.campaign_rounded, const Color(0xFF8B5CF6), const Color(0xFFEDE9FE));
}

class _AnnouncementMeta {
  final IconData icon;
  final Color color;
  final Color bg;
  const _AnnouncementMeta(this.icon, this.color, this.bg);
}

class AnnouncementScreen extends StatefulWidget {
  final String communityId;
  const AnnouncementScreen({super.key, required this.communityId});

  @override
  State<AnnouncementScreen> createState() => _AnnouncementScreenState();
}

class _AnnouncementScreenState extends State<AnnouncementScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AnnouncementProvider>(context, listen: false)
          .fetchAnnouncements(communityId: widget.communityId);
    });
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<dynamic> _filtered(List<dynamic> list) {
    if (_searchQuery.isEmpty) return list;
    return list.where((a) {
      final m = a as Map<String, dynamic>;
      return [
        'title',
        'description',
        'location',
        'contactInfo',
        'createUserName'
      ].any(
          (k) => (m[k] ?? '').toString().toLowerCase().contains(_searchQuery));
    }).toList();
  }

  Future<void> _goCreate({Map<String, dynamic>? a}) async {
    final ok = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateAnnouncementScreen(
          communityId: widget.communityId,
          announcement: a,
        ),
      ),
    );
    if (ok == true && mounted) {
      Provider.of<AnnouncementProvider>(context, listen: false)
          .fetchAnnouncements(communityId: widget.communityId);
    }
  }

  void _showDetails(Map<String, dynamic> a) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AnnouncementDetailSheet(announcement: a),
    );
  }

  void _confirmDelete(String id) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Announcement',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
        content: const Text(
          'This will permanently remove this announcement.',
          style: TextStyle(color: _T.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                const Text('Cancel', style: TextStyle(color: _T.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _T.red,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final provider =
                  Provider.of<AnnouncementProvider>(context, listen: false);
              final result = await provider.deleteAnnouncement(
                  id: id, communityId: widget.communityId);
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(result['message']),
                  backgroundColor: result['error'] ? _T.red : _T.green,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ));
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _T.bg,
      appBar: AppBar(
        backgroundColor: _T.surface,
        foregroundColor: _T.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Announcements',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: _T.textPrimary,
                letterSpacing: -0.3)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton.icon(
              onPressed: () => _goCreate(),
              icon: const Icon(Icons.add_rounded, size: 18, color: _T.accent),
              label: const Text('New',
                  style: TextStyle(
                      color: _T.accent,
                      fontWeight: FontWeight.w600,
                      fontSize: 14)),
              style: TextButton.styleFrom(
                backgroundColor: _T.accentLight,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: _T.divider, height: 1),
        ),
      ),
      body: Column(
        children: [
          Container(
            color: _T.surface,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(fontSize: 14, color: _T.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search announcements…',
                hintStyle:
                    const TextStyle(color: _T.textTertiary, fontSize: 14),
                prefixIcon: const Icon(Icons.search_rounded,
                    color: _T.textTertiary, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded,
                            color: _T.textTertiary, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: _T.bg,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _T.divider)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: _T.accentMid, width: 1.5)),
              ),
            ),
          ),
          Expanded(
            child: Consumer<AnnouncementProvider>(
              builder: (context, provider, _) {
                if (provider.isLoading) {
                  return const Center(
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: _T.accent));
                }
                if (provider.errorMessage != null) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                                width: 64,
                                height: 64,
                                decoration: const BoxDecoration(
                                    color: _T.redLight, shape: BoxShape.circle),
                                child: const Icon(Icons.wifi_off_rounded,
                                    color: _T.red, size: 28)),
                            const SizedBox(height: 16),
                            const Text('Couldn\'t load',
                                style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: _T.textPrimary)),
                            const SizedBox(height: 6),
                            Text(provider.errorMessage ?? '',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontSize: 13, color: _T.textSecondary)),
                            const SizedBox(height: 20),
                            ElevatedButton(
                              onPressed: () => provider.fetchAnnouncements(
                                  communityId: widget.communityId),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: _T.accent,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 28, vertical: 12)),
                              child: const Text('Retry'),
                            ),
                          ]),
                    ),
                  );
                }
                final items = _filtered(provider.announcements);
                if (items.isEmpty) {
                  return Center(
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                              width: 72,
                              height: 72,
                              decoration: const BoxDecoration(
                                  color: _T.accentLight,
                                  shape: BoxShape.circle),
                              child: const Icon(Icons.campaign_rounded,
                                  color: _T.accent, size: 32)),
                          const SizedBox(height: 16),
                          Text(
                              _searchQuery.isNotEmpty
                                  ? 'No results for "$_searchQuery"'
                                  : 'No announcements yet',
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: _T.textPrimary)),
                          const SizedBox(height: 6),
                          const Text('Check back later or create one',
                              style: TextStyle(
                                  fontSize: 13, color: _T.textSecondary)),
                          if (_searchQuery.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            TextButton(
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                              child: const Text('Clear search',
                                  style: TextStyle(color: _T.accent)),
                            ),
                          ],
                        ]),
                  );
                }
                return RefreshIndicator(
                  color: _T.accent,
                  onRefresh: () => provider.fetchAnnouncements(
                      communityId: widget.communityId),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
                    itemCount: items.length,
                    itemBuilder: (context, i) {
                      final a = items[i] as Map<String, dynamic>;
                      return TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: Duration(milliseconds: 350 + i * 60),
                        curve: Curves.easeOutCubic,
                        builder: (_, v, child) => Opacity(
                            opacity: v,
                            child: Transform.translate(
                                offset: Offset(0, 16 * (1 - v)), child: child)),
                        child: _AnnouncementCard(
                          announcement: a,
                          onTap: () => _showDetails(a),
                          onEdit: () => _goCreate(a: a),
                          onDelete: () => _confirmDelete(a['_id']),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  final Map<String, dynamic> announcement;
  final VoidCallback onTap, onEdit, onDelete;
  const _AnnouncementCard(
      {required this.announcement,
      required this.onTap,
      required this.onEdit,
      required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final meta = _metaFor(announcement);
    final title = announcement['title'] ?? 'Untitled';
    final description = announcement['description'] ?? '';
    final location = announcement['location'] ?? '';
    final startDate = announcement['startDate'] ?? '';
    final creator = announcement['createUserName'] ?? '';
    String? dateStr;
    if (startDate.isNotEmpty) {
      try {
        dateStr = DateFormat('MMM dd, yyyy').format(DateTime.parse(startDate));
      } catch (_) {}
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _T.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _T.divider),
        boxShadow: const [
          BoxShadow(color: _T.shadow, blurRadius: 8, offset: Offset(0, 2))
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                      color: meta.bg, borderRadius: BorderRadius.circular(11)),
                  child: Icon(meta.icon, color: meta.color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: _T.textPrimary,
                              letterSpacing: -0.2,
                              height: 1.3),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      if (creator.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text('by $creator',
                            style: const TextStyle(
                                fontSize: 12,
                                color: _T.textTertiary,
                                fontWeight: FontWeight.w500)),
                      ],
                    ])),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_horiz_rounded,
                      color: _T.textTertiary, size: 20),
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 4,
                  onSelected: (v) {
                    if (v == 'edit') onEdit();
                    if (v == 'delete') onDelete();
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                        value: 'edit',
                        height: 42,
                        child: Row(children: const [
                          Icon(Icons.edit_outlined, color: _T.accent, size: 18),
                          SizedBox(width: 10),
                          Text('Edit', style: TextStyle(fontSize: 14))
                        ])),
                    PopupMenuItem(
                        value: 'delete',
                        height: 42,
                        child: Row(children: const [
                          Icon(Icons.delete_outline_rounded,
                              color: _T.red, size: 18),
                          SizedBox(width: 10),
                          Text('Delete',
                              style: TextStyle(fontSize: 14, color: _T.red))
                        ])),
                  ],
                ),
              ]),
              if (description.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, color: _T.textSecondary, height: 1.45)),
              ],
              if (location.isNotEmpty || dateStr != null) ...[
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 6, children: [
                  if (location.isNotEmpty)
                    _Chip(
                        icon: Icons.location_on_rounded,
                        label: location,
                        color: _T.textSecondary),
                  if (dateStr != null)
                    _Chip(
                        icon: Icons.calendar_today_rounded,
                        label: dateStr,
                        color: meta.color,
                        bg: meta.bg),
                ]),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color? bg;
  const _Chip(
      {required this.icon, required this.label, required this.color, this.bg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: bg ?? _T.bg, borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                fontSize: 12, color: color, fontWeight: FontWeight.w500)),
      ]),
    );
  }
}

class AnnouncementDetailSheet extends StatelessWidget {
  final Map<String, dynamic> announcement;
  const AnnouncementDetailSheet({super.key, required this.announcement});

  String _fmtDate(String? s, {String fmt = 'EEE, MMM dd, yyyy'}) {
    if (s == null || s.isEmpty) return 'N/A';
    try {
      return DateFormat(fmt).format(DateTime.parse(s));
    } catch (_) {
      return s;
    }
  }

  bool _has(String k) {
    final v = announcement[k];
    return v != null && v.toString().isNotEmpty;
  }

  String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  @override
  Widget build(BuildContext context) {
    final meta = _metaFor(announcement);
    final title = announcement['title'] ?? 'Untitled';
    final created =
        _fmtDate(announcement['createdAt'], fmt: 'MMM dd, yyyy · hh:mm a');

    return Container(
      decoration: const BoxDecoration(
          color: _T.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.93,
        expand: false,
        builder: (context, scroll) {
          return Column(children: [
            Center(
                child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                        color: const Color(0xFFDDE0EA),
                        borderRadius: BorderRadius.circular(2)))),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 16, 16),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                        color: meta.bg,
                        borderRadius: BorderRadius.circular(13)),
                    child: Icon(meta.icon, color: meta.color, size: 22)),
                const SizedBox(width: 14),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: _T.textPrimary,
                              letterSpacing: -0.3)),
                      const SizedBox(height: 3),
                      Text('Posted $created',
                          style: const TextStyle(
                              fontSize: 12, color: _T.textTertiary)),
                    ])),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded,
                      color: _T.textTertiary, size: 20),
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ]),
            ),
            const Divider(height: 1, color: _T.divider),
            Expanded(
              child: ListView(
                  controller: scroll,
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
                  children: [
                    _Section(
                        label: 'Description',
                        value: announcement['description'] ?? 'No description.',
                        icon: Icons.notes_rounded),
                    if (_has('createUserName'))
                      _Section(
                          label: 'Posted By',
                          value: announcement['createUserName'],
                          icon: Icons.person_outline_rounded),
                    if (_has('startDate'))
                      _Section(
                          label: 'Start Date',
                          value: _fmtDate(announcement['startDate']),
                          icon: Icons.calendar_today_rounded,
                          color: meta.color),
                    if (_has('endDate'))
                      _Section(
                          label: 'End Date',
                          value: _fmtDate(announcement['endDate']),
                          icon: Icons.calendar_month_rounded),
                    if (_has('time') || _has('endTime'))
                      _TimeRow(
                          start: announcement['time'],
                          end: announcement['endTime'],
                          color: meta.color,
                          bg: meta.bg),
                    if (_has('location'))
                      _Section(
                          label: 'Location',
                          value: announcement['location'],
                          icon: Icons.location_on_rounded),
                    if (_has('contactInfo'))
                      _Section(
                          label: 'Contact',
                          value: announcement['contactInfo'],
                          icon: Icons.contact_mail_outlined),
                    if (_has('company'))
                      _Section(
                          label: 'Company',
                          value: announcement['company'],
                          icon: Icons.business_rounded),
                    if (_has('experience'))
                      _Section(
                          label: 'Experience',
                          value: announcement['experience'],
                          icon: Icons.work_history_rounded),
                    if (_has('employmentType'))
                      _Section(
                          label: 'Employment Type',
                          value: announcement['employmentType'],
                          icon: Icons.badge_rounded),
                    if (_has('salaryRange'))
                      _Section(
                          label: 'Salary Range',
                          value:
                              '${announcement['currency'] ?? ''} ${announcement['salaryRange']}'
                                  .trim(),
                          icon: Icons.payments_rounded,
                          color: _T.green),
                    if (_has('url'))
                      _Section(
                          label: 'Link',
                          value: announcement['url'],
                          icon: Icons.link_rounded,
                          isUrl: true,
                          color: _T.accent),
                    _Section(
                        label: 'Category',
                        value: _cap(announcement['templateType'] ?? 'event'),
                        icon: Icons.category_rounded),
                  ]),
            ),
          ]);
        },
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  final bool isUrl;
  const _Section(
      {required this.label,
      required this.value,
      required this.icon,
      this.color = _T.textSecondary,
      this.isUrl = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: _T.bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _T.divider)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 17, color: color),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _T.textTertiary,
                  letterSpacing: 0.3)),
          const SizedBox(height: 3),
          Text(value,
              style: TextStyle(
                  fontSize: 14,
                  color: isUrl ? _T.accent : _T.textPrimary,
                  height: 1.45,
                  decoration: isUrl ? TextDecoration.underline : null,
                  decorationColor: _T.accent)),
        ])),
      ]),
    );
  }
}

class _TimeRow extends StatelessWidget {
  final String? start, end;
  final Color color, bg;
  const _TimeRow(
      {required this.start,
      required this.end,
      required this.color,
      required this.bg});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: _T.bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _T.divider)),
      child: Row(children: [
        if (start != null && start!.isNotEmpty)
          Expanded(
              child:
                  _TimeTile(label: 'Start Time', value: start!, color: color)),
        if (start != null &&
            start!.isNotEmpty &&
            end != null &&
            end!.isNotEmpty)
          Container(
              width: 1,
              height: 36,
              color: _T.divider,
              margin: const EdgeInsets.symmetric(horizontal: 12)),
        if (end != null && end!.isNotEmpty)
          Expanded(
              child: _TimeTile(
                  label: 'End Time', value: end!, color: _T.textSecondary)),
      ]),
    );
  }
}

class _TimeTile extends StatelessWidget {
  final String label, value;
  final Color color;
  const _TimeTile(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: const TextStyle(
              fontSize: 11,
              color: _T.textTertiary,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3)),
      const SizedBox(height: 4),
      Text(value,
          style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w600, color: color)),
    ]);
  }
}

extension StringExtension on String {
  String capitalize() =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}

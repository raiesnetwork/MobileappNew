import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/comment_provider.dart';
import '../../providers/generate_link_provider.dart';
import '../../providers/group_provider.dart';

class ShareMeetScreen extends StatefulWidget {
  final String meetLink;
  final String linkId;
  final String description;
  final DateTime startDateTime;
  final DateTime endDateTime;

  const ShareMeetScreen({
    Key? key,
    required this.meetLink,
    required this.linkId,
    required this.description,
    required this.startDateTime,
    required this.endDateTime,
  }) : super(key: key);

  @override
  State<ShareMeetScreen> createState() => _ShareMeetScreenState();
}

class _ShareMeetScreenState extends State<ShareMeetScreen> {
  final _formKey = GlobalKey<FormState>();

  String _shareType = 'personal';
  List<Map<String, String>> _memberList = [];

  // ── User search state ─────────────────────────────────────────────────
  final TextEditingController _userSearchController = TextEditingController();
  String _userSearchQuery = '';
  int _currentUserPage = 1;
  final ScrollController _userScrollController = ScrollController();

  // ── Group search state ────────────────────────────────────────────────
  final TextEditingController _groupSearchController = TextEditingController();
  String _groupSearchQuery = '';

  bool _showRecurrence = false;
  String _frequency = 'weekly';
  int _interval = 1;
  List<int> _daysOfWeek = [];
  DateTime? _recurrenceEndDate;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUsers();
      _loadGroups();
    });
    _userScrollController.addListener(_onUserScroll);
  }

  @override
  void dispose() {
    _userSearchController.dispose();
    _groupSearchController.dispose();
    _userScrollController.dispose();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<CommentProvider>(context, listen: false).clearUsersList();
      }
    });
    super.dispose();
  }

  // ── Users ─────────────────────────────────────────────────────────────
  void _loadUsers({bool isLoadMore = false}) {
    final provider = Provider.of<CommentProvider>(context, listen: false);
    if (isLoadMore) {
      if (_currentUserPage < provider.totalUserPages) {
        _currentUserPage++;
        provider.fetchAllUsers(
          search: _userSearchQuery.isEmpty ? null : _userSearchQuery,
          pageNo: _currentUserPage,
          isLoadMore: true,
        );
      }
    } else {
      _currentUserPage = 1;
      provider.fetchAllUsers(
        search: _userSearchQuery.isEmpty ? null : _userSearchQuery,
        pageNo: _currentUserPage,
      );
    }
  }

  void _onUserScroll() {
    if (_userScrollController.position.pixels >=
        _userScrollController.position.maxScrollExtent - 200) {
      final provider = Provider.of<CommentProvider>(context, listen: false);
      if (!provider.isLoadingUsers &&
          _currentUserPage < provider.totalUserPages) {
        _loadUsers(isLoadMore: true);
      }
    }
  }

  void _onUserSearchChanged(String value) {
    setState(() => _userSearchQuery = value);
    Future.delayed(const Duration(milliseconds: 500), () {
      if (_userSearchQuery == value) _loadUsers();
    });
  }

  // ── Groups ────────────────────────────────────────────────────────────
  void _loadGroups() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<GroupChatProvider>(context, listen: false);
      provider.fetchMyGroups();
    });
  }

  // ── Helpers ───────────────────────────────────────────────────────────
  bool _isSelected(String id) => _memberList.any((m) => m['value'] == id);

  void _toggleMember(String id, String name) {
    setState(() {
      if (_isSelected(id)) {
        _memberList.removeWhere((m) => m['value'] == id);
      } else {
        _memberList.add({'value': id, 'name': name});
      }
    });
  }

  void _copyLink() {
    Clipboard.setData(ClipboardData(text: widget.meetLink));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 12),
            Text('Link copied to clipboard!'),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _shareMeeting() async {
    if (_memberList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_shareType == 'personal'
              ? 'Please select at least one person'
              : 'Please select at least one group'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final provider = Provider.of<MeetProvider>(context, listen: false);

    // ── Create Rich Message with Link (This is the key change) ──
    final String richMessage = '''
📅 Meeting Invitation

${widget.description}

🕒 Start: ${DateFormat('EEE, MMM dd, yyyy • hh:mm a').format(widget.startDateTime)}
🕒 End: ${DateFormat('EEE, MMM dd, yyyy • hh:mm a').format(widget.endDateTime)}

🔗 Join Meeting: ${widget.meetLink}
'''.trim();

    Map<String, dynamic>? recurrenceSettings;
    if (_showRecurrence) {
      recurrenceSettings = {
        'frequency': _frequency,
        'interval': _interval,
        if (_daysOfWeek.isNotEmpty) 'daysOfWeek': _daysOfWeek,
        if (_recurrenceEndDate != null)
          'endDate': _recurrenceEndDate!.toIso8601String(),
      };
    }

    final success = await provider.shareMeetLink(
      meetLink: widget.meetLink,
      dateAndTimeFrom: widget.startDateTime.toUtc().toIso8601String(),
      dateAndTimeTo: widget.endDateTime.toUtc().toIso8601String(),
      description: widget.description,
      type: _shareType,
      members: _memberList,
      mail: null,
      recurrenceSettings: recurrenceSettings,

      // ✅ This is the most important line
      message: richMessage,
    );

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Text('Meeting invitation sent successfully!'),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context, 'shared');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage ?? 'Failed to share meeting'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Share Meeting',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Consumer<MeetProvider>(
        builder: (context, provider, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Meeting Link Display Card ──────────────────────────
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6366F1).withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.link_rounded,
                            size: 40, color: Colors.white),
                        const SizedBox(height: 12),
                        const Text(
                          'Your Meeting Link',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            widget.meetLink,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _copyLink,
                          icon: const Icon(Icons.copy_rounded, size: 18),
                          label: const Text('Copy Link'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF6366F1),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Meeting Details ───────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Meeting Details',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87)),
                        const SizedBox(height: 16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.description_rounded,
                                size: 20, color: Colors.grey.shade600),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Description',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                          fontWeight: FontWeight.w500)),
                                  const SizedBox(height: 4),
                                  Text(widget.description,
                                      style: const TextStyle(
                                          fontSize: 14,
                                          color: Colors.black87)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Icon(Icons.play_circle_outline_rounded,
                                size: 20, color: Colors.grey.shade600),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Start Time',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                        fontWeight: FontWeight.w500)),
                                const SizedBox(height: 4),
                                Text(
                                  DateFormat('MMM dd, yyyy • hh:mm a')
                                      .format(widget.startDateTime),
                                  style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.black87,
                                      fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Icon(Icons.stop_circle_outlined,
                                size: 20, color: Colors.grey.shade600),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('End Time',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                        fontWeight: FontWeight.w500)),
                                const SizedBox(height: 4),
                                Text(
                                  DateFormat('MMM dd, yyyy • hh:mm a')
                                      .format(widget.endDateTime),
                                  style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.black87,
                                      fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Share Type Selection ──────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Share With',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87)),
                        const SizedBox(height: 16),
                        _buildShareTypeOption(
                            'personal', 'Personal Chats', Icons.person_rounded),
                        const SizedBox(height: 12),
                        _buildShareTypeOption(
                            'groups', 'Groups', Icons.group_rounded),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Selected chips ────────────────────────────────────
                  if (_memberList.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _memberList.map((m) {
                          return Chip(
                            label: Text(m['name'] ?? m['value']!),
                            deleteIcon: const Icon(Icons.close, size: 18),
                            onDeleted: () {
                              setState(() => _memberList
                                  .removeWhere((x) => x['value'] == m['value']));
                            },
                            backgroundColor:
                            const Color(0xFF6366F1).withOpacity(0.1),
                            deleteIconColor: const Color(0xFF6366F1),
                            labelStyle: const TextStyle(
                                color: Color(0xFF6366F1),
                                fontWeight: FontWeight.w500),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ── Personal Chats List ───────────────────────────────
                  if (_shareType == 'personal') ...[
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Select People',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87)),
                          const SizedBox(height: 12),
                          // Search field
                          TextField(
                            controller: _userSearchController,
                            onChanged: _onUserSearchChanged,
                            decoration: InputDecoration(
                              hintText: 'Search people...',
                              prefixIcon:
                              const Icon(Icons.search, color: Colors.grey),
                              suffixIcon: _userSearchController.text.isNotEmpty
                                  ? IconButton(
                                icon: const Icon(Icons.clear,
                                    color: Colors.grey),
                                onPressed: () {
                                  _userSearchController.clear();
                                  _onUserSearchChanged('');
                                },
                              )
                                  : null,
                              filled: true,
                              fillColor: Colors.grey[100],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Consumer<CommentProvider>(
                            builder: (context, userProvider, _) {
                              if (userProvider.isLoadingUsers &&
                                  userProvider.allUsers.isEmpty) {
                                return const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(16),
                                      child: CircularProgressIndicator(),
                                    ));
                              }
                              if (userProvider.allUsers.isEmpty) {
                                return Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Text('No people found',
                                        style: TextStyle(
                                            color: Colors.grey[600])),
                                  ),
                                );
                              }
                              return SizedBox(
                                height: 300,
                                child: ListView.separated(
                                  controller: _userScrollController,
                                  shrinkWrap: true,
                                  itemCount: userProvider.allUsers.length +
                                      (userProvider.isLoadingUsers ? 1 : 0),
                                  separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                                  itemBuilder: (context, index) {
                                    if (index ==
                                        userProvider.allUsers.length) {
                                      return const Padding(
                                        padding: EdgeInsets.all(8),
                                        child: Center(
                                            child:
                                            CircularProgressIndicator()),
                                      );
                                    }
                                    final user = userProvider.allUsers[index];
                                    final profile = user['profile']
                                    as Map<String, dynamic>?;
                                    final userName =
                                        profile?['name'] ?? 'Unknown User';
                                    final profileImage =
                                    profile?['profileImage'] as String?;
                                    final email = user['email'] ?? '';
                                    final userId = user['_id'] ?? '';
                                    final selected = _isSelected(userId);

                                    return ListTile(
                                      contentPadding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 0, vertical: 4),
                                      leading: CircleAvatar(
                                        radius: 22,
                                        backgroundColor: Colors.grey[300],
                                        backgroundImage: profileImage != null &&
                                            profileImage.isNotEmpty
                                            ? NetworkImage(profileImage)
                                            : null,
                                        child: profileImage == null ||
                                            profileImage.isEmpty
                                            ? Text(
                                          userName.isNotEmpty
                                              ? userName[0].toUpperCase()
                                              : 'U',
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight:
                                              FontWeight.bold),
                                        )
                                            : null,
                                      ),
                                      title: Text(userName,
                                          style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600)),
                                      subtitle: email.isNotEmpty
                                          ? Text(email,
                                          style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey[600]))
                                          : null,
                                      trailing: GestureDetector(
                                        onTap: () =>
                                            _toggleMember(userId, userName),
                                        child: Container(
                                          width: 32,
                                          height: 32,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: selected
                                                ? const Color(0xFF6366F1)
                                                : Colors.transparent,
                                            border: Border.all(
                                              color: selected
                                                  ? const Color(0xFF6366F1)
                                                  : Colors.grey.shade400,
                                              width: 2,
                                            ),
                                          ),
                                          child: selected
                                              ? const Icon(Icons.check,
                                              color: Colors.white,
                                              size: 18)
                                              : null,
                                        ),
                                      ),
                                      onTap: () =>
                                          _toggleMember(userId, userName),
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ── Groups List ───────────────────────────────────────
                  if (_shareType == 'groups') ...[
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Select Groups',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87)),
                          const SizedBox(height: 12),
                          // Search field
                          TextField(
                            controller: _groupSearchController,
                            onChanged: (v) =>
                                setState(() => _groupSearchQuery = v),
                            decoration: InputDecoration(
                              hintText: 'Search groups...',
                              prefixIcon:
                              const Icon(Icons.search, color: Colors.grey),
                              suffixIcon:
                              _groupSearchController.text.isNotEmpty
                                  ? IconButton(
                                icon: const Icon(Icons.clear,
                                    color: Colors.grey),
                                onPressed: () {
                                  _groupSearchController.clear();
                                  setState(
                                          () => _groupSearchQuery = '');
                                },
                              )
                                  : null,
                              filled: true,
                              fillColor: Colors.grey[100],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Consumer<GroupChatProvider>(
                            builder: (context, groupProvider, _) {
                              if (groupProvider.isLoadingMyGroups &&
                                  groupProvider.myGroups.isEmpty) {
                                return const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(16),
                                      child: CircularProgressIndicator(),
                                    ));
                              }

                              final groups = _groupSearchQuery.isEmpty
                                  ? groupProvider.myGroups
                                  : groupProvider.myGroups.where((g) {
                                final name = (g['name'] ?? '')
                                    .toString()
                                    .toLowerCase();
                                return name.contains(
                                    _groupSearchQuery.toLowerCase());
                              }).toList();

                              if (groups.isEmpty) {
                                return Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Text('No groups found',
                                        style: TextStyle(
                                            color: Colors.grey[600])),
                                  ),
                                );
                              }

                              return SizedBox(
                                height: 300,
                                child: ListView.separated(
                                  shrinkWrap: true,
                                  itemCount: groups.length,
                                  separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                                  itemBuilder: (context, index) {
                                    final group = groups[index];
                                    final groupName =
                                        group['name'] ?? 'Unnamed Group';
                                    final groupId = group['_id'] ?? '';
                                    final profileImage =
                                    group['profileImage'] as String?;
                                    final members =
                                        (group['members'] as List<dynamic>?)
                                            ?.length ??
                                            0;
                                    final selected = _isSelected(groupId);
                                    final hasImage = profileImage != null &&
                                        profileImage.isNotEmpty;

                                    return ListTile(
                                      contentPadding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 0, vertical: 4),
                                      leading: CircleAvatar(
                                        radius: 22,
                                        backgroundColor:
                                        const Color(0xFF8A2BE2),
                                        backgroundImage: hasImage
                                            ? NetworkImage(profileImage!)
                                            : null,
                                        child: !hasImage
                                            ? const Icon(Icons.group,
                                            color: Colors.white, size: 22)
                                            : null,
                                      ),
                                      title: Text(groupName,
                                          style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600)),
                                      subtitle: Text('$members members',
                                          style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey[600])),
                                      trailing: GestureDetector(
                                        onTap: () =>
                                            _toggleMember(groupId, groupName),
                                        child: Container(
                                          width: 32,
                                          height: 32,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: selected
                                                ? const Color(0xFF6366F1)
                                                : Colors.transparent,
                                            border: Border.all(
                                              color: selected
                                                  ? const Color(0xFF6366F1)
                                                  : Colors.grey.shade400,
                                              width: 2,
                                            ),
                                          ),
                                          child: selected
                                              ? const Icon(Icons.check,
                                              color: Colors.white,
                                              size: 18)
                                              : null,
                                        ),
                                      ),
                                      onTap: () =>
                                          _toggleMember(groupId, groupName),
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ── Recurrence Settings ───────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Recurring Meeting',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87)),
                            Switch(
                              value: _showRecurrence,
                              onChanged: (value) =>
                                  setState(() => _showRecurrence = value),
                              activeColor: const Color(0xFF6366F1),
                            ),
                          ],
                        ),
                        if (_showRecurrence) ...[
                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 16),
                          const Text('Frequency',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black87)),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _buildFrequencyChip('daily', 'Daily'),
                              const SizedBox(width: 8),
                              _buildFrequencyChip('weekly', 'Weekly'),
                              const SizedBox(width: 8),
                              _buildFrequencyChip('monthly', 'Monthly'),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (_frequency == 'weekly') ...[
                            const Text('Repeat On',
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black87)),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _buildDayChip(1, 'Mon'),
                                _buildDayChip(2, 'Tue'),
                                _buildDayChip(3, 'Wed'),
                                _buildDayChip(4, 'Thu'),
                                _buildDayChip(5, 'Fri'),
                                _buildDayChip(6, 'Sat'),
                                _buildDayChip(7, 'Sun'),
                              ],
                            ),
                            const SizedBox(height: 16),
                          ],
                          Row(
                            children: [
                              const Text('Repeat every',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.black87)),
                              const SizedBox(width: 12),
                              Container(
                                width: 60,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8F9FA),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: DropdownButton<int>(
                                    value: _interval,
                                    underline: const SizedBox(),
                                    items: List.generate(
                                        10, (index) => index + 1)
                                        .map((i) => DropdownMenuItem(
                                        value: i, child: Text('$i')))
                                        .toList(),
                                    onChanged: (value) {
                                      if (value != null) {
                                        setState(() => _interval = value);
                                      }
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _frequency == 'daily'
                                    ? 'day(s)'
                                    : _frequency == 'weekly'
                                    ? 'week(s)'
                                    : 'month(s)',
                                style: const TextStyle(
                                    fontSize: 14, color: Colors.black87),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ── Send Invitation Button ─────────────────────────────
                  ElevatedButton(
                    onPressed: provider.isLoading ? null : _shareMeeting,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                      shadowColor: const Color(0xFF6366F1).withOpacity(0.3),
                    ),
                    child: provider.isLoading
                        ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                        AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                        : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.send_rounded),
                        SizedBox(width: 8),
                        Text('Send Invitation',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildShareTypeOption(String value, String label, IconData icon) {
    final isSelected = _shareType == value;
    return InkWell(
      onTap: () => setState(() {
        _shareType = value;
        _memberList.clear();
      }),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF6366F1).withOpacity(0.1)
              : const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF6366F1) : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: isSelected ? const Color(0xFF6366F1) : Colors.grey),
            const SizedBox(width: 12),
            Text(label,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight:
                    isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected
                        ? const Color(0xFF6366F1)
                        : Colors.black87)),
            const Spacer(),
            if (isSelected)
              const Icon(Icons.check_circle_rounded,
                  color: Color(0xFF6366F1)),
          ],
        ),
      ),
    );
  }

  Widget _buildFrequencyChip(String value, String label) {
    final isSelected = _frequency == value;
    return InkWell(
      onTap: () => setState(() => _frequency = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color:
          isSelected ? const Color(0xFF6366F1) : const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF6366F1)
                : Colors.grey.shade300,
          ),
        ),
        child: Text(label,
            style: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontSize: 13,
                fontWeight:
                isSelected ? FontWeight.w600 : FontWeight.normal)),
      ),
    );
  }

  Widget _buildDayChip(int day, String label) {
    final isSelected = _daysOfWeek.contains(day);
    return InkWell(
      onTap: () {
        setState(() {
          if (isSelected) {
            _daysOfWeek.remove(day);
          } else {
            _daysOfWeek.add(day);
          }
        });
      },
      child: Container(
        width: 45,
        height: 45,
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF6366F1)
              : const Color(0xFFF8F9FA),
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected
                ? const Color(0xFF6366F1)
                : Colors.grey.shade300,
          ),
        ),
        child: Center(
          child: Text(label,
              style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black87,
                  fontSize: 12,
                  fontWeight:
                  isSelected ? FontWeight.w600 : FontWeight.normal)),
        ),
      ),
    );
  }
}
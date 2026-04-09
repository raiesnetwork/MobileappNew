import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../../constants/constants.dart';
import '../../../providers/auth_provider.dart';

class ForwardMessageScreen extends StatefulWidget {
  final Map<String, dynamic> message;

  const ForwardMessageScreen({Key? key, required this.message})
      : super(key: key);

  @override
  State<ForwardMessageScreen> createState() => _ForwardMessageScreenState();
}

class _ForwardMessageScreenState extends State<ForwardMessageScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<Map<String, dynamic>> _friends = [];
  List<Map<String, dynamic>> _groups = [];

  bool _loadingFriends = true;
  bool _loadingGroups = true;
  bool _isSending = false;

  final Set<String> _selectedFriendIds = {};
  final Set<String> _selectedGroupIds = {};

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  static const Color _purple = Color(0xFF6C5CE7);
  static const Color _purpleLight = Color(0xFFF3EAFD);
  static const Color _bg = Color(0xFFF8F6FC);
  static const Color _textDark = Color(0xFF1A1025);
  static const Color _textMid = Color(0xFF6B6080);
  static const Color _border = Color(0xFFEDE8F5);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchFriends();
    _fetchGroups();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String get _token {
    try {
      final auth = context.read<AuthProvider>();
      return auth.user?.token ?? '';   // ✅ correct path
    } catch (_) {
      return '';
    }
  }

  Future<void> _fetchFriends() async {
    try {
      final res = await http.get(
        Uri.parse('https://api.ixes.ai/api/chat/friends'),
        headers: {'Authorization': 'Bearer $_token'},
      );
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final data = body['data'] as List? ?? [];
        if (mounted) {
          setState(() {
            _friends =
                data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
            _loadingFriends = false;
          });
        }
      } else {
        if (mounted) setState(() => _loadingFriends = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loadingFriends = false);
    }
  }

  Future<void> _fetchGroups() async {
    try {
      final res = await http.get(
        Uri.parse('https://api.ixes.ai/api/chat/mygroups'),
        headers: {'Authorization': 'Bearer $_token'},
      );
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final data = body['data'] as List? ?? [];
        if (mounted) {
          setState(() {
            _groups =
                data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
            _loadingGroups = false;
          });
        }
      } else {
        if (mounted) setState(() => _loadingGroups = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loadingGroups = false);
    }
  }

  bool get _isSharedPost =>
      widget.message['isSharedPost'] == true;




  Future<void> _sendForwards() async {
    if (_selectedFriendIds.isEmpty && _selectedGroupIds.isEmpty) return;

    final messageId = widget.message['_id']?.toString() ?? '';
    if (messageId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Cannot forward: message ID missing'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    setState(() => _isSending = true);

    try {
      final body = jsonEncode({
        'messageIds': [messageId],
        'receiverIds': _selectedFriendIds.toList(),
        'groupIds': _selectedGroupIds.toList(),
      });

      print('📤 Forwarding: $body'); // debug — remove later

      final res = await http.post(
        Uri.parse('https://api.ixes.ai/api/chat/forwardMessage'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
        },
        body: body,
      );

      print('📥 Response: ${res.statusCode} ${res.body}'); // debug — remove later

      if (!mounted) return;
      setState(() => _isSending = false);

      final total = _selectedFriendIds.length + _selectedGroupIds.length;
      final success = res.statusCode == 200 || res.statusCode == 201;

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(success
            ? 'Forwarded to $total ${total == 1 ? 'chat' : 'chats'}'
            : 'Forward failed (${res.statusCode})'),
        backgroundColor: success ? Colors.green : Colors.orange,
        behavior: SnackBarBehavior.floating,
      ));

      if (success) Navigator.pop(context);

    } catch (e) {
      if (!mounted) return;
      setState(() => _isSending = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: $e'),
        backgroundColor: Colors.red,
      ));
    }
  }

  List<Map<String, dynamic>> get _filteredFriends {
    if (_searchQuery.isEmpty) return _friends;
    return _friends.where((f) {
      final name = (f['pairedUser']?['profile']?['name'] ?? '')
          .toString()
          .toLowerCase();
      return name.contains(_searchQuery);
    }).toList();
  }

  List<Map<String, dynamic>> get _filteredGroups {
    if (_searchQuery.isEmpty) return _groups;
    return _groups.where((g) {
      final name = (g['name'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery);
    }).toList();
  }

  int get _totalSelected =>
      _selectedFriendIds.length + _selectedGroupIds.length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: _textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Forward Message',
            style: TextStyle(
                color: _textDark,
                fontSize: 18,
                fontWeight: FontWeight.w700)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(49),
          child: TabBar(
            controller: _tabController,
            labelColor: _purple,
            unselectedLabelColor: _textMid,
            indicatorColor: _purple,
            indicatorWeight: 2.5,
            labelStyle: const TextStyle(
                fontWeight: FontWeight.w700, fontSize: 14),
            unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w500, fontSize: 14),
            tabs: [
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.person_outline_rounded, size: 18),
                    const SizedBox(width: 6),
                    Text('Friends'
                        '${_selectedFriendIds.isNotEmpty ? ' (${_selectedFriendIds.length})' : ''}'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.group_outlined, size: 18),
                    const SizedBox(width: 6),
                    Text('Groups'
                        '${_selectedGroupIds.isNotEmpty ? ' (${_selectedGroupIds.length})' : ''}'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: Column(children: [
        // Search
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: TextField(
            controller: _searchController,
            style: const TextStyle(fontSize: 14, color: _textDark),
            decoration: InputDecoration(
              hintText: 'Search...',
              hintStyle: const TextStyle(color: Color(0xFFB0A8C0)),
              prefixIcon:
              const Icon(Icons.search_rounded, color: _purple, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                  icon: const Icon(Icons.close_rounded,
                      size: 18, color: Color(0xFFB0A8C0)),
                  onPressed: () => _searchController.clear())
                  : null,
              filled: true,
              fillColor: _bg,
              contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _border)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                  const BorderSide(color: _purple, width: 1.5)),
            ),
          ),
        ),

        _buildMessagePreview(),

        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [_buildFriendsTab(), _buildGroupsTab()],
          ),
        ),
      ]),
      bottomNavigationBar: _totalSelected > 0
          ? Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
                color: Color(0x12000000),
                blurRadius: 12,
                offset: Offset(0, -4))
          ],
        ),
        child: SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: _isSending ? null : _sendForwards,
            style: ElevatedButton.styleFrom(
                backgroundColor: _purple,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14))),
            child: _isSending
                ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor:
                    AlwaysStoppedAnimation(Colors.white)))
                : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.send_rounded, size: 20),
                const SizedBox(width: 10),
                Text(
                  'Forward to $_totalSelected'
                      ' ${_totalSelected == 1 ? 'chat' : 'chats'}',
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      )
          : null,
    );
  }

  Widget _buildMessagePreview() {
    final msg = widget.message;
    String preview;
    IconData icon;

    if (_isSharedPost) {
      preview = msg['sharedPost']?['text']?.toString() ??
          msg['text']?.toString() ??
          msg['forwerdMessage']?.toString() ??
          'Shared Post';
      if (preview.length > 80) preview = '${preview.substring(0, 80)}…';
      icon = Icons.share_rounded;
    } else if (msg['isAudio'] == true) {
      preview = 'Voice message';
      icon = Icons.mic_rounded;
    } else if (msg['isFile'] == true) {
      preview = msg['fileName']?.toString() ?? 'File';
      icon = Icons.attach_file_rounded;
    } else {
      final text = msg['text']?.toString() ?? '';
      preview = text.length > 80 ? '${text.substring(0, 80)}…' : text;
      icon = Icons.format_quote_rounded;
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _purpleLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _purple.withOpacity(0.2)),
      ),
      child: Row(children: [
        Icon(icon, color: _purple, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(preview,
              style:
              const TextStyle(color: _textMid, fontSize: 13, height: 1.3),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
        ),
      ]),
    );
  }

  Widget _buildFriendsTab() {
    if (_loadingFriends) return _buildLoader();
    final list = _filteredFriends;
    if (list.isEmpty) {
      return _buildEmpty(
          _searchQuery.isNotEmpty ? 'No friends found' : 'No friends yet');
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: list.length,
      separatorBuilder: (_, __) =>
      const Divider(height: 1, indent: 76, color: _border),
      itemBuilder: (_, i) {
        final friend = list[i];
        final user = friend['pairedUser'] as Map<String, dynamic>? ?? {};
        final userId = user['_id']?.toString() ?? '';
        final name = user['profile']?['name']?.toString() ?? 'Unknown';
        final image = user['profile']?['profileImage']?.toString();
        final selected = _selectedFriendIds.contains(userId);
        return _SelectableTile(
          name: name,
          subtitle: user['email']?.toString() ?? '',
          imageUrl: image,
          selected: selected,
          color: _purple,
          onTap: () => setState(() => selected
              ? _selectedFriendIds.remove(userId)
              : _selectedFriendIds.add(userId)),
        );
      },
    );
  }

  Widget _buildGroupsTab() {
    if (_loadingGroups) return _buildLoader();
    final list = _filteredGroups;
    if (list.isEmpty) {
      return _buildEmpty(
          _searchQuery.isNotEmpty ? 'No groups found' : 'No groups yet');
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: list.length,
      separatorBuilder: (_, __) =>
      const Divider(height: 1, indent: 76, color: _border),
      itemBuilder: (_, i) {
        final group = list[i];
        final groupId = group['_id']?.toString() ?? '';
        final name = group['name']?.toString() ?? 'Unknown Group';
        final image = group['profileImage']?.toString();
        final members = (group['members'] as List?)?.length ?? 0;
        final selected = _selectedGroupIds.contains(groupId);
        return _SelectableTile(
          name: name,
          subtitle: '$members members',
          imageUrl: image,
          selected: selected,
          color: _purple,
          isGroup: true,
          onTap: () => setState(() => selected
              ? _selectedGroupIds.remove(groupId)
              : _selectedGroupIds.add(groupId)),
        );
      },
    );
  }

  Widget _buildLoader() => const Center(
    child: CircularProgressIndicator(
        strokeWidth: 2.5,
        valueColor: AlwaysStoppedAnimation(_purple)),
  );

  Widget _buildEmpty(String msg) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.search_off_rounded, size: 48, color: Colors.grey[350]),
      const SizedBox(height: 12),
      Text(msg,
          style: const TextStyle(
              color: _textMid,
              fontSize: 15,
              fontWeight: FontWeight.w500)),
    ]),
  );
}

// ════════════════════════════════════════════════════════════════════════════
class _SelectableTile extends StatelessWidget {
  final String name;
  final String subtitle;
  final String? imageUrl;
  final bool selected;
  final Color color;
  final bool isGroup;
  final VoidCallback onTap;

  const _SelectableTile({
    required this.name,
    required this.subtitle,
    required this.selected,
    required this.color,
    required this.onTap,
    this.imageUrl,
    this.isGroup = false,
  });

  ImageProvider? _imageProvider(String? src) {
    if (src == null || src.isEmpty || src == 'null') return null;
    try {
      if (src.startsWith('data:image') ||
          src.startsWith('/9j/') ||
          src.startsWith('iVBORw0KGgo')) {
        return MemoryImage(base64Decode(
            src.startsWith('data:image') ? src.split(',')[1] : src));
      }
      return NetworkImage(src);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final imgProv = _imageProvider(imageUrl);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          Stack(children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: selected ? color : color.withOpacity(0.15),
              backgroundImage: imgProv,
              child: imgProv == null
                  ? Icon(
                  isGroup ? Icons.group_rounded : Icons.person_rounded,
                  color: selected ? Colors.white : color,
                  size: 22)
                  : null,
            ),
            if (selected)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border:
                      Border.all(color: Colors.white, width: 1.5)),
                  child: const Icon(Icons.check_rounded,
                      size: 10, color: Colors.white),
                ),
              ),
          ]),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: selected
                              ? color
                              : const Color(0xFF1A1025)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF6B6080)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ]),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: selected ? color : Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(
                  color: selected ? color : const Color(0xFFB0A8C0),
                  width: 2),
            ),
            child: selected
                ? const Icon(Icons.check_rounded,
                size: 14, color: Colors.white)
                : null,
          ),
        ]),
      ),
    );
  }
}
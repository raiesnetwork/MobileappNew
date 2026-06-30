import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ixes.app/constants/constants.dart';
import 'package:ixes.app/constants/imageConstant.dart';
import 'package:ixes.app/screens/notification/notification.dart';
import 'package:ixes.app/screens/services_page/services_screen.dart';
import 'package:ixes.app/screens/home/feedpage/feed_screen.dart';
import 'package:ixes.app/screens/newa_page/newa_screen.dart';
import 'package:ixes.app/screens/profilePage/profile_screen.dart';
import 'package:ixes.app/screens/communities_page/communities_screen.dart';
import 'package:ixes.app/screens/widgets/dash_board_screen.dart';
import 'package:provider/provider.dart';
import 'package:ixes.app/providers/communities_provider.dart';
import 'package:ixes.app/providers/notification_provider.dart';

import 'auth/launguage_selection_page.dart';
import 'chats_page/personal_chat_screen.dart';
import 'communities_page/my_community_screen.dart';
import 'coupon_page/coupon_screens.dart';

const _tabPostTypes = [
  'post',
  'like',
  'comment',
  'PostLike',
  'PostComment',
  'PostShare',
  'Post',
  'Announcement',
];
const _tabChatTypes = [
  'chat',
  'message',
  'directMessage',
  'ChatMessage',
  'Conversation',
  'GroupChat',
];
const _tabCommunityTypes = ['community', 'GroupRequest'];
const _tabDashTypes = [
  'campaign',
  'Service',
  'Invoice',
  'StoreSubscription',
  'SubDomain',
  'AddProduct',
  'ServiceReq',
  'assignedServiceReq',
];

final GlobalKey<_MainScreenState> mainScreenKey = GlobalKey<_MainScreenState>();

class MainScreen extends StatefulWidget {
  final int initialIndex;
  const MainScreen({super.key, this.initialIndex = 0});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  late int _currentIndex;
  String? _pendingPostId;
  bool _isInitialized = false;
  bool _snackbarShown = false;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  static const _kIconSize = 22.0;
  static const _kIconPadding = EdgeInsets.symmetric(horizontal: 5);
  static const _kIconConstraints = BoxConstraints();

  // ── Public API used by NotificationScreen ─────────────────────────────────

  void navigateToTab(int tab, {String? postId}) {
    if (!mounted) return;
    setState(() {
      _currentIndex = tab;
      if (tab == 0 && postId != null) _pendingPostId = postId;
    });
    _doClear(tab);
  }

  // ─────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationProvider>().initializeNotifications().then((_) {
        if (!mounted) return;
        _isInitialized = true;
        // FIX: Clear the active tab immediately. For all other tabs the badges
        // will naturally show until the user visits them — that is correct
        // behaviour. What we must NOT do is clear every tab on startup,
        // because that would wipe unread counts the user hasn't seen yet.
        _doClear(_currentIndex);
      });
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed && _isInitialized && mounted) {
      context.read<NotificationProvider>().loadNotifications();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args =
    ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (!_snackbarShown && args != null && args['showSnackbar'] == true) {
      _snackbarShown = true;
      if (args['goToTab'] != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _onTabTapped(args['goToTab'] as int);
        });
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(args['message'] ?? 'Action completed.'),
          backgroundColor: args['deleted'] == true ? Colors.green : Colors.red,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ));
      });
    }
    final cp = Provider.of<CommunityProvider>(context, listen: false);
    if (cp.myCommunities['message'] == 'Not loaded') {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => cp.fetchMyCommunities());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  // ── Tab switching (user taps bottom nav) ──────────────────────────────────

  void _onTabTapped(int index) {
    if (_currentIndex == index) return;
    setState(() => _currentIndex = index);
    _doClear(index);
  }

  void _doClear(int tab) {
    if (!_isInitialized || !mounted) return;
    final List<String> types;
    switch (tab) {
      case 0:
        types = _tabPostTypes;
        break;
      case 2:
        types = _tabChatTypes;
        break;
      case 3:
        types = _tabCommunityTypes;
        break;
      case 4:
        types = _tabDashTypes;
        break;
      default:
        return;
    }
    context.read<NotificationProvider>().markTypesAsRead(types);
  }

  void _onDrawerChanged(bool opened) {
    if (opened) {
      context.read<CommunityProvider>().fetchMyCommunities();
    } else {
      _searchController.clear();
      _searchFocusNode.unfocus();
    }
  }

  // ── Badge helpers ─────────────────────────────────────────────────────────

  Widget _appBarBadge(int count) {
    if (count == 0) return const SizedBox.shrink();
    return Positioned(
      right: 0,
      top: 0,
      child: Container(
        padding: const EdgeInsets.all(4),
        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
        decoration:
        const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
        child: Text(count > 99 ? '99+' : '$count',
            style: const TextStyle(
                color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center),
      ),
    );
  }

  Widget _navBadge(int count) {
    if (count == 0) return const SizedBox.shrink();
    return Positioned(
      right: -6,
      top: -6,
      child: Container(
        padding: const EdgeInsets.all(3),
        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
        decoration:
        const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
        child: Text(count > 99 ? '99+' : '$count',
            style: const TextStyle(
                color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        scrolledUnderElevation: 0,
        elevation: 0,
        backgroundColor: Colors.white,
        titleSpacing: 0,
        leadingWidth: 0,
        leading: const SizedBox(),
        title: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.menu, color: Primary),
              iconSize: _kIconSize,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            ),
            const SizedBox(width: 2),
            GestureDetector(
              onTap: () {},
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.asset('assets/icons/IXES_X.webp',
                    width: 24, height: 24, fit: BoxFit.cover),
              ),
            ),
            const Spacer(),
          ],
        ),
        actions: [
          Consumer<NotificationProvider>(
            builder: (_, p, __) => Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  icon:
                  const Icon(Icons.notifications_outlined, color: Primary),
                  iconSize: _kIconSize,
                  padding: _kIconPadding,
                  constraints: _kIconConstraints,
                  onPressed: () async {
                    await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const NotificationScreen()));
                    if (mounted) {
                      context.read<NotificationProvider>().loadNotifications();
                    }
                  },
                ),
                _appBarBadge(p.totalUnreadCount),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.local_offer_outlined, color: Primary),
            iconSize: _kIconSize,
            padding: _kIconPadding,
            constraints: _kIconConstraints,
            tooltip: 'My Coupons',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const CouponListScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.store, color: Primary),
            iconSize: _kIconSize,
            padding: _kIconPadding,
            constraints: _kIconConstraints,
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ServicesScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.person, color: Primary),
            iconSize: _kIconSize,
            padding: _kIconPadding,
            constraints: _kIconConstraints,
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ProfileScreen())),
          ),
          const SizedBox(width: 4),
        ],
      ),
      drawer: Drawer(
        backgroundColor: Colors.black,
        child: SafeArea(
          child: Column(
            children: [
              Container(
                height: 180,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.grey[900]!, Colors.black],
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24, width: 2),
                        boxShadow: const [
                          BoxShadow(
                              color: Colors.black26,
                              blurRadius: 10,
                              offset: Offset(0, 4))
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 45,
                        backgroundColor: Colors.grey[800],
                        child: ClipOval(
                            child: Image.asset(Images.Logo,
                                fit: BoxFit.cover, width: 90, height: 90)),
                      ),
                    ),
                    const SizedBox(height: 15),
                    const Text('IXES',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2)),
                    const Text('Connect • Share • Grow',
                        style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            letterSpacing: 1)),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  color: Colors.black,
                  child: CommunitiesListWidget(
                    searchController: _searchController,
                    searchFocusNode: _searchFocusNode,
                    onCommunityTapped: () => Navigator.pop(context),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      onDrawerChanged: _onDrawerChanged,
      body: IndexedStack(
        index: _currentIndex,
        children: [
          FeedScreen(postId: _pendingPostId, showBackButton: false),
          const NewaScreen(),
          const PersonalChatScreen(),
          const CommunitiesScreen(),
          const DashboardScreen(),
        ],
      ),
      bottomNavigationBar: Consumer<NotificationProvider>(
        builder: (_, p, __) {
          final homeCount = p.getUnreadCountForTypes(_tabPostTypes);
          final chatCount = p.getUnreadCountForTypes(_tabChatTypes);
          final communityCount = p.getUnreadCountForTypes(_tabCommunityTypes);
          final dashCount = p.getUnreadCountForTypes(_tabDashTypes);

          return BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: _onTabTapped,
            type: BottomNavigationBarType.fixed,
            selectedItemColor: Primary,
            unselectedItemColor: Colors.grey,
            items: [
              BottomNavigationBarItem(
                icon: Stack(
                    clipBehavior: Clip.none,
                    children: [const Icon(Icons.home), _navBadge(homeCount)]),
                label: 'Home',
              ),
              const BottomNavigationBarItem(
                  icon: Icon(Icons.add_circle), label: 'Ask Newa'),
              BottomNavigationBarItem(
                icon: Stack(
                    clipBehavior: Clip.none,
                    children: [const Icon(Icons.chat), _navBadge(chatCount)]),
                label: 'Chats',
              ),
              BottomNavigationBarItem(
                icon: Stack(clipBehavior: Clip.none, children: [
                  const Icon(Icons.group),
                  _navBadge(communityCount)
                ]),
                label: 'Communities',
              ),
              BottomNavigationBarItem(
                icon: Stack(clipBehavior: Clip.none, children: [
                  const Icon(Icons.dashboard),
                  _navBadge(dashCount)
                ]),
                label: 'Dashboard',
              ),
            ],
          );
        },
      ),
    );
  }
}
import 'dart:convert';
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
import 'package:shared_preferences/shared_preferences.dart';

import 'chats_page/personal_chat_screen.dart';
import 'communities_page/my_community_screen.dart';
import 'my_products/my_products_screen.dart';

class MainScreen extends StatefulWidget {
  final int initialIndex;

  const MainScreen({super.key, this.initialIndex = 0});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  late int _currentIndex;
  bool _snackbarShown = false;
  late PageController _pageController;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);

    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notifProvider = context.read<NotificationProvider>();
      notifProvider.initializeNotifications().then((_) {
        _isInitialized = true;
        _clearTabNotifications(_currentIndex);
      });
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed && _isInitialized) {
      context.read<NotificationProvider>().loadNotifications().then((_) {
        _clearTabNotifications(_currentIndex);
      });
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
        final targetTab = args['goToTab'] as int;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _onTabTapped(targetTab);
        });
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(args['message'] ?? 'Action completed.'),
            backgroundColor:
            args['deleted'] == true ? Colors.green : Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      });
    }

    final communityProvider =
    Provider.of<CommunityProvider>(context, listen: false);
    if (communityProvider.myCommunities['message'] == 'Not loaded') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        communityProvider.fetchMyCommunities();
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );

    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) {
        _clearTabNotifications(index);
      }
    });
  }

  Future<void> _clearTabNotifications(int tabIndex) async {
    if (!_isInitialized || !mounted) return;

    try {
      final notifProvider = context.read<NotificationProvider>();

      List<String> types = [];

      switch (tabIndex) {
        case 0:
          types = ['Post', 'Announcement'];
          break;
        case 2:
          types = ['chat', 'GroupChat', 'Conversation'];
          break;
        case 3:
          types = ['community', 'GroupRequest'];
          break;
        case 4:
          types = [
            'campaign',
            'Service',
            'Invoice',
            'StoreSubscription',
            'SubDomain',
            'AddProduct',
            'ServiceReq',
          ];
          break;
        default:
          return;
      }

      if (types.isEmpty) return;

      print('🧹 Clearing notifications for tab $tabIndex with types: $types');

      await notifProvider.markTypesAsRead(types);

      print('✅ Successfully cleared all notifications for tab $tabIndex');
    } catch (e) {
      print('💥 Error clearing tab notifications: $e');
    }
  }

  void _onDrawerChanged(bool isOpened) {
    if (!isOpened) {
      _searchController.clear();
      _searchFocusNode.unfocus();
    }
  }

  void _onCommunityTapped() {
    Navigator.pop(context);
  }

  // Updated badge for AppBar notification icon
  Widget _buildBadge(int count) {
    if (count == 0) return const SizedBox.shrink();

    return Positioned(
      right: 0,
      top: 0,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: const BoxDecoration(
          color: Colors.red,
          shape: BoxShape.circle,
        ),
        constraints: const BoxConstraints(
          minWidth: 18,
          minHeight: 18,
        ),
        child: Text(
          count > 99 ? '99+' : count.toString(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  // New badge specifically for bottom navigation bar icons
  Widget _buildBottomNavBadge(int count) {
    if (count == 0) return const SizedBox.shrink();

    return Positioned(
      right: -6,
      top: -6,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: const BoxDecoration(
          color: Colors.red,
          shape: BoxShape.circle,
        ),
        constraints: const BoxConstraints(
          minWidth: 16,
          minHeight: 16,
        ),
        child: Text(
          count > 99 ? '99+' : count.toString(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        scrolledUnderElevation: 0.0,
        elevation: 0,
        backgroundColor: Colors.white,
        title: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.menu, color: Primary),
              onPressed: () {
                _scaffoldKey.currentState?.openDrawer();
              },
            ),
            Container(
              height: 30,
              width: 30,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                image: DecorationImage(
                  image: AssetImage(Images.Logo),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ],
        ),
        actions: [
          Consumer<NotificationProvider>(
            builder: (context, notifProvider, child) {
              final unreadCount = notifProvider.totalUnreadCount;

              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined, color: Primary),
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const NotificationScreen(),
                        ),
                      );

                      if (mounted) {
                        await context.read<NotificationProvider>().loadNotifications();
                        await Future.delayed(const Duration(milliseconds: 300));
                        _clearTabNotifications(_currentIndex);
                      }
                    },
                  ),
                  _buildBadge(unreadCount),
                ],
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.store, color: Primary),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ServicesScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.person, color: Primary),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ProfileScreen(),
                ),
              );
            },
          ),
          const SizedBox(width: 12),
        ],
      ),
      drawer: Drawer(
        backgroundColor: Colors.black,
        child: Column(
          children: [
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.grey[900]!,
                    Colors.black,
                  ],
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white24,
                            width: 2,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 45,
                          backgroundColor: Colors.grey[800],
                          child: ClipOval(
                            child: Image.asset(
                              Images.Logo,
                              fit: BoxFit.cover,
                              width: 90,
                              height: 90,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),
                      const Text(
                        'IXES',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                      const Text(
                        'Connect • Share • Grow',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: Container(
                color: Colors.black,
                child: CommunitiesListWidget(
                  searchController: _searchController,
                  searchFocusNode: _searchFocusNode,
                  onCommunityTapped: _onCommunityTapped,
                ),
              ),
            ),
          ],
        ),
      ),
      body: Consumer<CommunityProvider>(
        builder: (context, provider, child) {
          final communityList = provider.myCommunities['data'] as List? ?? [];
          final communityId = communityList.isNotEmpty
              ? communityList.first['_id']?.toString() ?? ''
              : '';

          return PageView(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
              Future.delayed(const Duration(milliseconds: 400), () {
                if (mounted) {
                  _clearTabNotifications(index);
                }
              });
            },
            children: const [
              FeedScreen(),
              NewaScreen(),
              PersonalChatScreen(),
              CommunitiesScreen(),
              DashboardScreen(),
            ],
          );
        },
      ),
      bottomNavigationBar: Consumer<NotificationProvider>(
        builder: (context, notifProvider, child) {
          final homeCount = notifProvider.getUnreadCountForTypes(['Post', 'Announcement']);
          final chatCount = notifProvider.getUnreadCountForTypes(['chat', 'GroupChat', 'Conversation']);
          final communityCount = notifProvider.getUnreadCountForTypes(['community', 'GroupRequest']);
          final dashboardCount = notifProvider.getUnreadCountForTypes([
            'campaign',
            'Service',
            'Invoice',
            'StoreSubscription',
            'SubDomain',
            'AddProduct',
            'ServiceReq',
          ]);

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
                  children: [
                    const Icon(Icons.home),
                    _buildBottomNavBadge(homeCount),
                  ],
                ),
                label: 'Home',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.add_circle),
                label: 'Ask Newa',
              ),
              BottomNavigationBarItem(
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.chat),
                    _buildBottomNavBadge(chatCount),
                  ],
                ),
                label: 'Chats',
              ),
              BottomNavigationBarItem(
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.group),
                    _buildBottomNavBadge(communityCount),
                  ],
                ),
                label: 'Communities',
              ),
              BottomNavigationBarItem(
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.dashboard),
                    _buildBottomNavBadge(dashboardCount),
                  ],
                ),
                label: 'Dashboard',
              ),
            ],
          );
        },
      ),
      onDrawerChanged: _onDrawerChanged,
    );
  }
}
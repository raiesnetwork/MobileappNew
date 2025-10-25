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

import 'chats_page/personal_chat_screen.dart';
import 'communities_page/my_community_screen.dart';
import 'my_products/my_products_screen.dart';

class MainScreen extends StatefulWidget {
  final int initialIndex;

  const MainScreen({super.key, this.initialIndex = 0});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late int _currentIndex;
  bool _snackbarShown = false;
  late PageController _pageController;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
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

    // Fix: Use myCommunities instead of communities for the drawer
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
  }

  void _onDrawerChanged(bool isOpened) {
    if (!isOpened) {
      _searchController.clear();
      _searchFocusNode.unfocus();
    }
  }

  void _onCommunityTapped() {
    Navigator.pop(context); // Close drawer
  }

  String _getCommunityId(BuildContext context) {
    final communityProvider =
        Provider.of<CommunityProvider>(context, listen: false);
    final communityList =
        communityProvider.myCommunities['data'] as List? ?? [];

    if (communityList.isNotEmpty) {
      return communityList.first['_id']?.toString() ?? '';
    }
    return '';
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
          IconButton(
            icon: Icon(Icons.notifications_outlined, color: Primary),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.store, color: Primary),
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
            icon: Icon(Icons.person, color: Primary),
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
            // Custom Header with gradient
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
                          boxShadow: [
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
                      Text(
                        'IXES',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                      Text(
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

            // Communities Section - Now using the extracted widget
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
          // Use myCommunities for getting community ID instead of allCommunities
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
            },
            children: [
              FeedScreen(),
              NewaScreen(),
              PersonalChatScreen(),
              CommunitiesScreen(),
              DashboardScreen(),
            ],
          );
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Primary,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle),
            label: 'Ask Newa',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat),
            label: 'Chats',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.group),
            label: 'Communities',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
        ],
      ),
      onDrawerChanged: _onDrawerChanged,
    );
  }
}

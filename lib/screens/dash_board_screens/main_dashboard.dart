import 'package:flutter/material.dart';
import 'package:ixes.app/screens/dash_board_screens/placement_cell_dashboard.dart';
import 'package:ixes.app/screens/dash_board_screens/student_dashboard.dart';
import 'package:provider/provider.dart';
import '../../constants/constants.dart';
import 'admin_dashboard.dart';
import 'hod_dashboard.dart';


class DashboardScreen extends StatefulWidget {
  final String communityId;
  final String userRole; // 'Student', 'Head of Department (HOD)', 'Principal / Director', 'Placement Officer'

  const DashboardScreen({
    super.key,
    required this.communityId,
    required this.userRole,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToDashboard();
  }

  void _navigateToDashboard() {
    // Small delay to ensure the widget is built
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted) return;

      Widget targetScreen;

      switch (widget.userRole) {
        case 'Student':
          targetScreen = StudentDashboardScreen(communityId: widget.communityId);
          break;
        case 'Head of Department (HOD)':
          targetScreen = HODDashboardScreen(communityId: widget.communityId);
          break;
        case 'Principal / Director':
          targetScreen = AdminDashboardScreen(communityId: widget.communityId);
          break;
        case 'Placement Officer':
          targetScreen = PlacementDashboardScreen(communityId: widget.communityId);
          break;
        default:
        // Default to student dashboard if role is not recognized
          targetScreen = StudentDashboardScreen(communityId: widget.communityId);
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => targetScreen),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Primary),
              strokeWidth: 3,
            ),
            const SizedBox(height: 24),
            Text(
              'Loading ${widget.userRole} Dashboard...',
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
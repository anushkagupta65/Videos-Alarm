import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:videos_alarm_app/screens/check_subs_controller.dart';
import 'package:videos_alarm_app/screens/live_videos.dart';
import 'package:videos_alarm_app/screens/news_screen.dart';
import 'package:videos_alarm_app/screens/search_screen.dart';
import 'package:videos_alarm_app/screens/settings.dart';
import 'package:videos_alarm_app/screens/home.dart';
import '../components/app_style.dart';

class BottomBarTabs extends StatefulWidget {
  int initialIndex;
  BottomBarTabs({super.key, this.initialIndex = 0});

  @override
  BottomBarTabsState createState() => BottomBarTabsState();
}

class BottomBarTabsState extends State<BottomBarTabs> {
  static final List<Widget> _widgetOptions = [
    Home(),
    const SearchScreen(),
    const LiveVideos(),
    const NewsScreen(),
    const Settings(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      widget.initialIndex = index;
    });
  }

  void goToTab(int index) {
    SubscriptionService().checkSubscriptionStatus();

    setState(() {
      widget.initialIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: blackColor,
      appBar: AppBar(
        backgroundColor: blackColor,
        elevation: 3,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: Text(
          "VideosAlarm",
          style: TextStyle(
            color: whiteColor,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: IndexedStack(index: widget.initialIndex, children: _widgetOptions),
      bottomNavigationBar: _buildCustomBottomNavBar(),
    );
  }

  Widget _buildCustomBottomNavBar() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(
          colors: [Colors.deepPurpleAccent, Colors.blueAccent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BottomNavigationBar(
          backgroundColor: Colors.transparent,
          currentIndex: widget.initialIndex,
          onTap: _onItemTapped,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
          unselectedLabelStyle: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.normal,
          ),
          selectedItemColor: whiteColor,
          unselectedItemColor: whiteColor.withOpacity(0.7),
          items: [
            _buildBottomNavBarItem(Icons.home, "Home"),
            _buildBottomNavBarItem(Icons.search, "Search"),
            _buildBottomNavBarItem(Icons.live_tv, "Live"),
            _buildBottomNavBarItem(Icons.connected_tv, "News"),
            _buildBottomNavBarItem(Icons.settings, "Settings"),
          ],
        ),
      ),
    );
  }

  BottomNavigationBarItem _buildBottomNavBarItem(IconData icon, String label) {
    return BottomNavigationBarItem(
      icon: AnimatedSwitcher(
        duration: Duration(milliseconds: 300),
        transitionBuilder: (Widget child, Animation<double> animation) {
          return ScaleTransition(scale: animation, child: child);
        },
        child: Icon(
          icon,
          key: ValueKey(label),
          size: widget.initialIndex ==
                  _widgetOptions.indexOf(
                      _widgetOptions.firstWhere((element) => element is Home))
              ? 28
              : 24,
        ),
      ),
      label: label,
    );
  }
}

import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:facebook_app_events/facebook_app_events.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:videos_alarm_app/screens/check_subs_controller.dart';
import 'package:videos_alarm_app/screens/live_videos.dart';
import 'package:videos_alarm_app/screens/news_screen.dart';
import 'package:videos_alarm_app/screens/search_screen.dart';
import 'package:videos_alarm_app/screens/settings.dart';
import 'package:videos_alarm_app/screens/home.dart';
import 'package:videos_alarm_app/screens/support_screen.dart';
import 'package:videos_alarm_app/screens/view_video.dart';
import '../components/app_style.dart';
import 'package:get/get.dart';
import 'package:videos_alarm_app/Controller/Sub_controller.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';

class BottomBarTabs extends StatefulWidget {
  int initialIndex;
  BottomBarTabs({super.key, this.initialIndex = 0});

  @override
  BottomBarTabsState createState() => BottomBarTabsState();
}

class BottomBarTabsState extends State<BottomBarTabs> {
  static final List<Widget> _widgetOptions = [
    Home(),
    const LiveVideos(),
    const NewsScreen(),
    const SupportPage(),
    const SettingsPage(),
  ];

  late SubscriptionController subscriptionController;
  bool _hasRestoredPurchases = false;

  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;
  final _analytics = FirebaseAnalytics.instance;
  final _facebookAppEvents = FacebookAppEvents();
  final HomeController controller = Get.put(HomeController());

  @override
  void initState() {
    super.initState();
    subscriptionController = Get.put(SubscriptionController());
    _checkRestoredPurchases();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeDeepLinks();
    });
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeDeepLinks() async {
    try {
      _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
        debugPrint('🔗 Got a link while running: $uri');
        _handleDeepLink(uri);
      });

      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        debugPrint('🔗 Launched with initial link: $initialUri');
        Future.delayed(const Duration(milliseconds: 500), () {
          _handleDeepLink(initialUri);
        });
      }
    } catch (e) {
      debugPrint('❌ Deep link error: $e');
    }
  }

  Future<void> _handleDeepLink(Uri deepLink) async {
    debugPrint('➡️ Handling deep link: $deepLink');

    if (!mounted) return;

    try {
      await _analytics.logEvent(
        name: 'deep_link_received',
        parameters: {'link': deepLink.toString()},
      );

      _facebookAppEvents.logEvent(
        name: 'deep_link_received',
        parameters: {'link': deepLink.toString()},
      );

      if (deepLink.scheme == 'videosalarm' &&
          deepLink.host == 'video' &&
          deepLink.pathSegments.isNotEmpty) {
        final videoId = deepLink.pathSegments.first;

        try {
          final docSnapshot = await FirebaseFirestore.instance
              .collection('bunny')
              .doc(videoId)
              .get();

          if (!mounted) return;

          if (docSnapshot.exists) {
            final data = docSnapshot.data()!;

            Get.to(() => ViewVideo(
                  releaseYear: data['releaseYear'],
                  starcast: data['starcast'],
                  cbfc: data['cbfc'],
                  myList: data['myList'],
                  duration: data['duration'],
                  director: data['director'],
                  videoTitle: data['title'],
                  description: data['description'],
                  videoLink: data['videoUrl'],
                  category: data['category'],
                  videoId: videoId,
                ));
          } else {
            if (mounted) {
              Get.snackbar('Error', 'Video not found in database.');
            }
          }
        } catch (e) {
          debugPrint('❌ Firestore error: $e');
          if (mounted) {
            Get.snackbar('Error', 'Could not process video link.');
          }
        }
      } else {
        debugPrint('⚠️ Invalid link format: $deepLink');
      }
    } catch (e) {
      debugPrint('❌ Analytics error: $e');
    }
  }

  Future<void> _checkRestoredPurchases() async {
    if (!mounted) return;

    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool hasRestored = prefs.getBool('hasRestoredPurchases') ?? false;
    if (!hasRestored) {
      await _restoreSubscriptionStatus();
      await prefs.setBool('hasRestoredPurchases', true);
      if (mounted) {
        setState(() {
          _hasRestoredPurchases = true;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _hasRestoredPurchases = true;
        });
      }
    }
  }

  Future<void> _restoreSubscriptionStatus() async {
    try {
      await subscriptionController.restorePurchases();
      await subscriptionController.getDetails();
      SharedPreferences prefs = await SharedPreferences.getInstance();
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      String currentVersion = packageInfo.version;
      String? lastPopupVersion = prefs.getString('lastPopupVersion');

      if (lastPopupVersion != currentVersion) {
        await prefs.setString('lastPopupVersion', currentVersion);
      }
    } catch (e) {
      commToast("Error restoring subscription: $e");
    }
  }

  void commToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 1,
      backgroundColor: Colors.grey[800],
      textColor: Colors.white,
      fontSize: 16.0,
    );
  }

  void _onItemTapped(int index) {
    if (mounted) {
      setState(() {
        widget.initialIndex = index;
      });
    }
  }

  void goToTab(int index) {
    SubscriptionService().checkSubscriptionStatus();

    if (mounted) {
      setState(() {
        widget.initialIndex = index;
      });
    }
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
        actions: widget.initialIndex == 0
            ? [
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, color: whiteColor),
                  color: Colors.blueAccent.shade100,
                  elevation: 10,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Colors.grey.shade800, width: 1),
                  ),
                  itemBuilder: (BuildContext context) =>
                      <PopupMenuEntry<String>>[
                    PopupMenuItem<String>(
                      value: 'search',
                      child: Row(
                        children: [
                          Icon(Icons.search, color: Colors.white),
                          SizedBox(width: 10),
                          Text(
                            'Search',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'refresh',
                      child: Row(
                        children: [
                          Icon(Icons.refresh, color: Colors.white),
                          SizedBox(width: 10),
                          Text(
                            'Refresh',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  onSelected: (String value) {
                    if (value == 'search') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => SearchScreen()),
                      );
                      print("this was called after search");
                    } else if (value == 'refresh') {
                      controller.onRefresh();
                    }
                  },
                ),
              ]
            : null,
      ),
      body: IndexedStack(index: widget.initialIndex, children: _widgetOptions),
      bottomNavigationBar: _buildCustomBottomNavBar(),
    );
  }

  Widget _buildCustomBottomNavBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          colors: [Colors.deepPurpleAccent, Colors.blueAccent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
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
          selectedLabelStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.normal,
          ),
          selectedItemColor: whiteColor,
          unselectedItemColor: whiteColor.withOpacity(0.7),
          items: [
            _buildBottomNavBarItem(Icons.home, "Home", 0),
            _buildBottomNavBarItem(Icons.live_tv, "Live", 1),
            _buildBottomNavBarItem(Icons.connected_tv, "News", 2),
            _buildBottomNavBarItem(Icons.chat_rounded, "Support", 3),
            _buildBottomNavBarItem(Icons.settings, "Settings", 4),
          ],
        ),
      ),
    );
  }

  BottomNavigationBarItem _buildBottomNavBarItem(
      IconData icon, String label, int index) {
    return BottomNavigationBarItem(
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (Widget child, Animation<double> animation) {
          return ScaleTransition(scale: animation, child: child);
        },
        child: Icon(
          icon,
          key: ValueKey('$label-$index'),
          size: widget.initialIndex == index ? 28 : 24,
        ),
      ),
      label: label,
    );
  }
}

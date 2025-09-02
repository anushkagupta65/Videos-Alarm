// ignore_for_file: unused_field

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:videos_alarm_app/tv_screens/tv_home.dart';
import 'package:videos_alarm_app/tv_screens/tv_live_videos.dart';
import 'package:videos_alarm_app/tv_screens/tv_news_screen.dart';
import 'package:videos_alarm_app/tv_screens/tv_my_list.dart';
import 'package:videos_alarm_app/tv_screens/tv_settings.dart';

class TVBottomBarTabs extends StatefulWidget {
  final int initialIndex;
  const TVBottomBarTabs({super.key, this.initialIndex = 0});

  @override
  TVBottomBarTabsState createState() => TVBottomBarTabsState();
}

class TVBottomBarTabsState extends State<TVBottomBarTabs> {
  static final List<Widget> _widgetOptions = [
    TVHome(key: GlobalKey()),
    const TVLiveVideos(),
    const TVNewsScreen(),
    WatchLaterPageTV([]),
  ];

  static final List<Map<String, dynamic>> _navItems = [
    {'icon': Icons.home, 'label': 'Home'},
    {'icon': Icons.live_tv, 'label': 'Live'},
    {'icon': Icons.connected_tv, 'label': 'News'},
    {'icon': Icons.watch_later_outlined, 'label': 'My List'}
  ];

  late int _currentIndex;
  bool _isNavBarFocused = true;
  final TVHomeController controller = Get.put(TVHomeController());
  final TVLiveVideosController liveController =
      Get.put(TVLiveVideosController());
  List<String> _watchlist = [];

  final List<FocusNode> _navFocusNodes = List.generate(_navItems.length,
      (index) => FocusNode(debugLabel: 'NavFocusNode_$index'));
  final FocusNode _menuFocusNode = FocusNode(debugLabel: 'MenuFocusNode');
  final List<FocusNode> _contentFocusNodes = List.generate(_navItems.length,
      (index) => FocusNode(debugLabel: 'ContentFocusNode_$index'));
  final FocusNode _searchFocusNode = FocusNode(debugLabel: 'SearchFocusNode');
  final FocusNode _settingsFocusNode =
      FocusNode(debugLabel: 'SettingsFocusNode');
  final List<FocusNode> _settingsItemFocusNodes = List.generate(
      4, (index) => FocusNode(debugLabel: 'SettingsItemFocusNode_$index'));
  bool _isSearchExpanded = false;
  bool _isSettingsDrawerOpen = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _fetchWatchlist();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_navFocusNodes[_currentIndex]);
      print('Initial focus set to nav tab: $_currentIndex');
    });
  }

  @override
  void dispose() {
    for (var node in _navFocusNodes) {
      node.dispose();
    }
    for (var node in _contentFocusNodes) {
      node.dispose();
    }
    for (var node in _settingsItemFocusNodes) {
      node.dispose();
    }
    _menuFocusNode.dispose();
    _searchFocusNode.dispose();
    _settingsFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchWatchlist() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      return;
    }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      final watchlist = List<String>.from(userDoc.data()?['watchlist'] ?? []);
      if (mounted) {
        setState(() {
          _watchlist = watchlist;
          _widgetOptions[3] = WatchLaterPageTV(_watchlist);
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading watchlist: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load watchlist: $e')),
        );
      }
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
        _currentIndex = index;
        _isNavBarFocused = false;
      });
      _contentFocusNodes[index].requestFocus();
      print('Tab selected: $index, content focus requested');

      if (index == 3 && FirebaseAuth.instance.currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Please log in to view your watchlist.')),
        );
      }
    }
  }

  void goToTab(int index) {
    if (mounted) {
      setState(() {
        _currentIndex = index;
      });
      _navFocusNodes[index].requestFocus();
      print('Navigated to tab: $index');
    }
  }

  void requestNavBarFocus() {
    if (mounted) {
      setState(() {
        _currentIndex = 0;
        _isNavBarFocused = true;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _navFocusNodes[0].requestFocus();
        print('Navbar focus requested for Home tab');
      });
    }
  }

  void _toggleSearch() {
    setState(() {
      _isSearchExpanded = !_isSearchExpanded;
    });
    if (_isSearchExpanded) {
      _searchFocusNode.requestFocus();
      print('Search expanded, focus on search field');
    } else {
      print('Search collapsed');
    }
  }

  void _toggleSettingsDrawer() {
    setState(() {
      _isSettingsDrawerOpen = !_isSettingsDrawerOpen;
      print('Settings drawer toggled: $_isSettingsDrawerOpen');
    });
    if (_isSettingsDrawerOpen) {
      _settingsItemFocusNodes[0].requestFocus();
      print('Focus requested on first settings item');
    } else {
      _settingsFocusNode.requestFocus();
      print('Focus requested on settings icon');
    }
  }

  Future<bool> _onWillPop() async {
    print(
        'WillPopScope triggered - isSearchExpanded: $_isSearchExpanded, isSettingsDrawerOpen: $_isSettingsDrawerOpen');
    if (_isSearchExpanded) {
      setState(() {
        _isSearchExpanded = false;
        _searchController.clear();
      });
      _searchFocusNode.requestFocus();
      print('Search unexpanded, focus returned to search icon');
      return false;
    } else if (_isSettingsDrawerOpen) {
      setState(() {
        _isSettingsDrawerOpen = false;
      });
      _settingsFocusNode.requestFocus();
      print('Settings drawer closed, focus returned to settings icon');
      return false;
    }
    print('No expansion, allowing back navigation');
    return true;
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final bool isNavTabFocused = _navFocusNodes.any((node) => node.hasFocus);
    final bool isSearchFocused = _searchFocusNode.hasFocus;
    final bool isSettingsFocused = _settingsFocusNode.hasFocus;
    final bool isMenuFocused = _menuFocusNode.hasFocus;
    final bool isContentFocused =
        _contentFocusNodes.any((node) => node.hasFocus);
    final bool isSettingsItemFocused =
        _settingsItemFocusNodes.any((node) => node.hasFocus);

    print('Key event: ${event.logicalKey}, isNavTabFocused: $isNavTabFocused, '
        'isSearchFocused: $isSearchFocused, isSettingsFocused: $isSettingsFocused, '
        'isMenuFocused: $isMenuFocused, isContentFocused: $isContentFocused, '
        'isSettingsItemFocused: $isSettingsItemFocused');

    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      if (isNavTabFocused) {
        if (_currentIndex < _navItems.length - 1) {
          final newIndex = _currentIndex + 1;
          _navFocusNodes[newIndex].requestFocus();
          setState(() {
            _currentIndex = newIndex;
          });
          print('Navigated right to tab: $_currentIndex');
          return KeyEventResult.handled;
        } else if (_currentIndex == _navItems.length - 1) {
          _settingsFocusNode.requestFocus();
          setState(() {});
          print('Focus moved from My List to settings icon');
          return KeyEventResult.handled;
        }
      } else if (isSearchFocused && _isSearchExpanded) {
        setState(() {
          _isSearchExpanded = false;
          _searchController.clear();
        });
        _searchFocusNode.requestFocus();
        print('Search collapsed');
        return KeyEventResult.handled;
      } else if (isSearchFocused && !_isSearchExpanded) {
        _settingsFocusNode.requestFocus();
        setState(() {});
        print('Focus moved to settings icon');
        return KeyEventResult.handled;
      }
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      if (isSettingsFocused) {
        _navFocusNodes.last.requestFocus();
        setState(() {
          _currentIndex = _navItems.length - 1;
        });
        print('Focus moved from settings to My List');
        return KeyEventResult.handled;
      }
      if (isSearchFocused && _isSearchExpanded) {
        FocusScope.of(context).requestFocus(_searchFocusNode);
        print('Focus retained on search icon');
        return KeyEventResult.handled;
      }
      if (isSearchFocused) {
        _navFocusNodes.last.requestFocus();
        setState(() {
          _currentIndex = _navItems.length - 1;
        });
        print('Focus moved to last nav tab');
        return KeyEventResult.handled;
      }
      if (isNavTabFocused && _currentIndex > 0) {
        final newIndex = _currentIndex - 1;
        _navFocusNodes[newIndex].requestFocus();
        setState(() {
          _currentIndex = newIndex;
        });
        print('Navigated left to tab: $_currentIndex');
        return KeyEventResult.handled;
      }
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      if (isContentFocused) {
        _navFocusNodes[_currentIndex].requestFocus();
        setState(() {
          _isNavBarFocused = true;
        });
        print('Focus moved from content to nav tab: $_currentIndex');
        return KeyEventResult.handled;
      }
      if (isNavTabFocused && _currentIndex == 0) {
        _menuFocusNode.requestFocus();
        print('Focus moved to menu');
        return KeyEventResult.handled;
      } else if (isContentFocused && _currentIndex == 0) {
        _menuFocusNode.requestFocus();
        print('Focus moved to menu from content');
        return KeyEventResult.handled;
      } else if (isSettingsItemFocused) {
        final currentIndex =
            _settingsItemFocusNodes.indexWhere((node) => node.hasFocus);
        if (currentIndex > 0) {
          _settingsItemFocusNodes[currentIndex - 1].requestFocus();
          print('Settings item navigated up to index: ${currentIndex - 1}');
          return KeyEventResult.handled;
        } else if (_isSettingsDrawerOpen) {
          _settingsFocusNode.requestFocus();
          print('Focus moved from settings items to settings icon');
          return KeyEventResult.handled;
        }
      }
    } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      if (isNavTabFocused || isSearchFocused || isSettingsFocused) {
        if (_currentIndex == 0) {
          final homeState = _findTVHomeState();
          if (homeState != null) {
            setState(() {
              _isNavBarFocused = false;
            });
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (controller.bannerImages.isNotEmpty && homeState.mounted) {
                FocusScope.of(context).requestFocus(homeState.bannerFocusNode);
                homeState.scrollToBanner();
                print('Focused on bannerFocusNode from Home tab');
              } else {
                if (homeState.focusNodesPerRow.isNotEmpty &&
                    homeState.focusNodesPerRow[0].isNotEmpty) {
                  FocusScope.of(context)
                      .requestFocus(homeState.focusNodesPerRow[0][0]);
                  homeState.scrollToTile(0, 0);
                  homeState.focusedRow = 0;
                  homeState.focusedCol = 0;
                  print('No banners, focused on video category: Row 0, Col 0');
                }
              }
            });
            return KeyEventResult.handled;
          }
          print('Home state not found, focus unchanged');
          return KeyEventResult.ignored;
        }
        _contentFocusNodes[_currentIndex].requestFocus();
        setState(() {
          _isNavBarFocused = false;
        });
        print('Focus moved to content tab: $_currentIndex');
        return KeyEventResult.handled;
      } else if (isMenuFocused) {
        _navFocusNodes[_currentIndex].requestFocus();
        setState(() {
          _isNavBarFocused = true;
        });
        print('Focus moved from menu to nav tab: $_currentIndex');
        return KeyEventResult.handled;
      } else if (isSettingsFocused && _isSettingsDrawerOpen) {
        _settingsItemFocusNodes[0].requestFocus();
        print('Focus moved to first settings item');
        return KeyEventResult.handled;
      } else if (isSettingsItemFocused) {
        final currentIndex =
            _settingsItemFocusNodes.indexWhere((node) => node.hasFocus);
        if (currentIndex < _settingsItemFocusNodes.length - 1) {
          _settingsItemFocusNodes[currentIndex + 1].requestFocus();
          print('Settings item navigated down to index: ${currentIndex + 1}');
          return KeyEventResult.handled;
        }
      }
    } else if (event.logicalKey == LogicalKeyboardKey.select ||
        event.logicalKey == LogicalKeyboardKey.enter) {
      if (isNavTabFocused) {
        _onItemTapped(_currentIndex);
        print('Nav tab selected: $_currentIndex');
        return KeyEventResult.handled;
      }
      if (isSearchFocused) {
        _toggleSearch();
        print('Search toggled: $_isSearchExpanded');
        return KeyEventResult.handled;
      }
      if (isSettingsFocused) {
        _toggleSettingsDrawer();
        print('Settings drawer toggled');
        return KeyEventResult.handled;
      }
    } else if (event.logicalKey == LogicalKeyboardKey.goBack) {
      print(
          'Go Back key pressed - isSearchExpanded: $_isSearchExpanded, isSettingsDrawerOpen: $_isSettingsDrawerOpen');
      if (_isSearchExpanded) {
        setState(() {
          _isSearchExpanded = false;
          _searchController.clear();
        });
        _searchFocusNode.requestFocus();
        print('Search unexpanded, focus returned to search icon');
        return KeyEventResult.handled;
      } else if (_isSettingsDrawerOpen) {
        setState(() {
          _isSettingsDrawerOpen = false;
        });
        _settingsFocusNode.requestFocus();
        print('Settings drawer closed, focus returned to settings icon');
        return KeyEventResult.handled;
      }
      print('Go Back not handled, allowing propagation');
      return KeyEventResult.ignored;
    }
    return KeyEventResult.ignored;
  }

  TVHomeState? _findTVHomeState() {
    final homeWidget = _widgetOptions[0];
    final context = (homeWidget.key as GlobalKey?)?.currentState?.context;
    if (context != null) {
      final state = context.findAncestorStateOfType<TVHomeState>();
      print('TVHomeState found: ${state != null}');
      return state;
    }
    print('TVHomeState context not found');
    return null;
  }

  Widget _buildSettingsWidget() {
    return Focus(
      focusNode: _settingsFocusNode,
      onFocusChange: (hasFocus) {
        setState(() {});
        print('Settings icon focus changed: $hasFocus');
      },
      child: GestureDetector(
        onTap: _toggleSettingsDrawer,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color.fromARGB(163, 11, 84, 211),
            shape: BoxShape.circle,
            border: _settingsFocusNode.hasFocus
                ? Border.all(color: Colors.blueAccent, width: 2)
                : null,
          ),
          child: const Icon(
            Icons.settings,
            size: 18,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Focus(
        autofocus: true,
        onKeyEvent: _handleKeyEvent,
        child: Scaffold(
          backgroundColor: Colors.black,
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(56),
            child: _buildTopNavBar(),
          ),
          body: Stack(
            children: [
              Focus(
                focusNode: _contentFocusNodes.isNotEmpty
                    ? _contentFocusNodes[_currentIndex]
                    : FocusNode(),
                child: Container(
                  color: Colors.deepPurpleAccent.withOpacity(0.95),
                  child: _widgetOptions.isNotEmpty
                      ? _widgetOptions[_currentIndex]
                      : const Center(child: Text("No content")),
                ),
              ),
              TVSettingsScreen(
                isSettingsDrawerOpen: _isSettingsDrawerOpen,
                settingsItemFocusNodes: _settingsItemFocusNodes,
                toggleSettingsDrawer: _toggleSettingsDrawer,
                commToast: commToast,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopNavBar() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color.fromARGB(151, 34, 16, 81),
            Color.fromARGB(145, 68, 48, 184),
            Color.fromARGB(177, 47, 92, 198),
            Color.fromARGB(161, 2, 28, 71)
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        children: [
          const Text(
            "VideosAlarm",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 26,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(width: 16),
          ...List.generate(_navItems.length, (index) {
            bool isFocused = _navFocusNodes[index].hasFocus;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Focus(
                focusNode: _navFocusNodes[index],
                onFocusChange: (hasFocus) {
                  if (hasFocus) {
                    setState(() {
                      _currentIndex = index;
                    });
                    print('Nav tab focused: $index');
                  }
                },
                child: GestureDetector(
                  onTap: () => goToTab(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding:
                        const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                    decoration: BoxDecoration(
                      color: isFocused
                          ? const Color.fromARGB(255, 30, 78, 161)
                              .withOpacity(0.08)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: isFocused
                          ? const Border(
                              bottom: BorderSide(
                                  color: Colors.blueAccent, width: 1.6))
                          : null,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _navItems[index]['icon'],
                          size: isFocused ? 13 : 12,
                          color: isFocused ? Colors.white : Colors.white60,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _navItems[index]['label'],
                          style: TextStyle(
                            color: isFocused ? Colors.white : Colors.white60,
                            fontWeight:
                                isFocused ? FontWeight.bold : FontWeight.normal,
                            fontSize: isFocused ? 14 : 12,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
          const Spacer(),
          _buildSettingsWidget(),
        ],
      ),
    );
  }
}

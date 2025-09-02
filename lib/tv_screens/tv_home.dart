import 'dart:async';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:videos_alarm_app/components/app_style.dart';
import 'package:shimmer/shimmer.dart';
import 'package:videos_alarm_app/tv_screens/tv_bottom_bar_tabs.dart';
import 'package:videos_alarm_app/tv_screens/tv_dialog.dart';
import 'package:videos_alarm_app/tv_screens/tv_video_player.dart';

class TVHomeController extends GetxController {
  RxBool isLoading = false.obs;
  RxMap<String, List<Map<String, dynamic>>> categorizedVideosMap =
      <String, List<Map<String, dynamic>>>{}.obs;
  RxList<Map<String, dynamic>> allVideos = <Map<String, dynamic>>[].obs;
  RxString selectedCategory = 'All'.obs;
  RxString categoryTitle = 'We Think You’ll Love These'.obs;

  final PageController bannerPageController = PageController(initialPage: 0);
  RxInt currentBannerIndex = 0.obs;
  Timer? bannerTimer;
  RxList<Map<String, dynamic>> bannerImages = <Map<String, dynamic>>[].obs;

  void _refreshData() {
    getVideosList().then((_) {
      getBanners();
      startBannerTimer();
    });
  }

  @override
  void onInit() {
    super.onInit();
    _refreshData();
  }

  @override
  void onClose() {
    bannerPageController.dispose();
    bannerTimer?.cancel();
    super.onClose();
  }

  void startBannerTimer() {
    bannerTimer?.cancel();
    bannerTimer = Timer.periodic(const Duration(seconds: 5), (Timer timer) {
      if (bannerImages.isNotEmpty) {
        if (currentBannerIndex.value < bannerImages.length - 1) {
          currentBannerIndex.value++;
        } else {
          currentBannerIndex.value = 0;
        }

        if (bannerPageController.hasClients) {
          bannerPageController.animateToPage(
            currentBannerIndex.value,
            duration: const Duration(seconds: 1),
            curve: Curves.easeInOut,
          );
        }
      }
    });
  }

  Future<void> getBanners() async {
    try {
      FirebaseFirestore firestore = FirebaseFirestore.instance;
      QuerySnapshot querySnapshot = await firestore.collection('banners').get();

      List<Map<String, dynamic>> bannersList = [];

      for (QueryDocumentSnapshot doc in querySnapshot.docs) {
        var data = Map<String, dynamic>.from(doc.data() as Map);

        var banner = {
          "imageUrl": data["imageUrl"],
          "videoId": data.containsKey("videoId") ? data["videoId"] : null,
        };

        bannersList.add(banner);
      }

      bannerImages.assignAll(bannersList);
    } catch (error) {
      print("Error getting banners: $error");
    }
  }

  Future<void> getVideosList() async {
    isLoading.value = true;

    try {
      FirebaseFirestore firestore = FirebaseFirestore.instance;
      QuerySnapshot querySnapshot = await firestore.collection('bunny').get();

      Map<String, List<Map<String, dynamic>>> categorizedVideos = {};
      List<Map<String, dynamic>> videosList = [];

      for (QueryDocumentSnapshot doc in querySnapshot.docs) {
        var data = Map<String, dynamic>.from(doc.data() as Map);

        if (data['category'] == 'live') {
          continue;
        }

        if (data['releaseDate'] is Timestamp) {
          data['releaseDate'] = (data['releaseDate'] as Timestamp).toDate();
        }

        var video = {
          "releaseYear": data['releaseYear'],
          "starcast": data['starcast'],
          "cbfc": data['cbfc'],
          "myList": data['myList'],
          "duration": data['duration'],
          "director": data['director'],
          "title": data["title"],
          "description": data["description"],
          "category": data["category"],
          "videoUrl": data["videoUrl"],
          "thumbnailUrl": data["thumbnailUrl"],
          "releaseDate": data["releaseDate"],
          'videoId': doc.id,
        };

        videosList.add(video);

        String category = data["category"];
        if (categorizedVideos.containsKey(category)) {
          categorizedVideos[category]!.add(video);
        } else {
          categorizedVideos[category] = [video];
        }
      }

      allVideos.assignAll(videosList);
      categorizedVideosMap.assignAll(categorizedVideos);
      isLoading.value = false;
    } catch (error) {
      isLoading.value = false;
      Get.snackbar(
        'Error',
        'Something went wrong: $error',
      );
    }
  }

  List<Map<String, dynamic>> getVideosByCategory(String category) {
    if (category == 'All') {
      return allVideos;
    }
    return categorizedVideosMap[category] ?? [];
  }

  String formatDate(dynamic releaseDate) {
    if (releaseDate == null) return 'Unknown date';

    try {
      if (releaseDate is Timestamp) {
        DateTime date = releaseDate.toDate();
        return DateFormat('MMM dd, yyyy').format(date);
      } else if (releaseDate is DateTime) {
        return DateFormat('MMM dd, yyyy').format(releaseDate);
      } else {
        return 'Invalid date format';
      }
    } catch (e) {
      return 'Invalid date';
    }
  }

  Future<void> onRefresh() async {
    await getVideosList();
  }

  void updateCategoryTitle(String category) {
    switch (category) {
      case 'All':
        categoryTitle.value = 'We Think You’ll Love These';
        break;
      default:
        categoryTitle.value = category;
        break;
    }
  }

  void selectCategory(String category) {
    selectedCategory.value = category;
    updateCategoryTitle(category);
  }

  Map<String, dynamic>? getVideoById(String? videoId) {
    if (videoId == null) return null;
    try {
      return allVideos.firstWhere(
        (v) => v['videoId'] == videoId,
        orElse: () => {},
      );
    } catch (_) {
      return null;
    }
  }
}

class TVHome extends StatefulWidget {
  TVHome({Key? key}) : super(key: key);

  @override
  TVHomeState createState() => TVHomeState();
}

class TVHomeState extends State<TVHome> {
  final TVHomeController controller = Get.find<TVHomeController>();

  List<List<GlobalKey>> tileKeysPerRow = [];
  List<List<FocusNode>> focusNodesPerRow = [];
  int focusedRow = 0;
  int focusedCol = 0;

  final ScrollController listScrollController = ScrollController();
  final FocusNode contentFocusNode = FocusNode(debugLabel: 'HomeContentFocus');
  final FocusNode bannerFocusNode = FocusNode(debugLabel: 'BannerFocus');

  @override
  void initState() {
    super.initState();
    controller.isLoading.listen((isLoading) {
      if (!isLoading && mounted) {
        setState(() {
          _initializeFocusNodes();
          _setInitialFocus();
        });
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        controller._refreshData();
        _initializeFocusNodes();
        _setInitialFocus();
      }
    });
  }

  void _initializeFocusNodes() {
    _disposeFocusNodes();
    focusNodesPerRow = [];
    tileKeysPerRow = [];

    List<List<Map<String, dynamic>>> allRows = [];
    allRows.add(controller.getVideosByCategory('All'));
    controller.categorizedVideosMap.entries
        .where((e) => e.key != 'All')
        .forEach((e) {
      allRows.add(e.value);
    });

    for (var row in allRows) {
      focusNodesPerRow.add(List.generate(
          row.length,
          (index) =>
              FocusNode(debugLabel: 'Row${focusNodesPerRow.length}Col$index')));
      tileKeysPerRow.add(List.generate(row.length, (index) => GlobalKey()));
    }

    if (focusNodesPerRow.isEmpty) {
      focusNodesPerRow = [
        [FocusNode(debugLabel: 'FallbackRowCol')]
      ];
      tileKeysPerRow = [
        [GlobalKey()]
      ];
    }

    controller.selectedCategory.listen((_) {
      if (mounted) {
        setState(() {
          _initializeFocusNodes();
        });
      }
    });
  }

  void _setInitialFocus() {
    if (mounted) {
      final bottomBarState =
          context.findAncestorStateOfType<TVBottomBarTabsState>();
      if (bottomBarState != null) {
        bottomBarState.requestNavBarFocus();
      }
    }
  }

  void requestContentFocus() {
    if (mounted) {
      print(
          'requestContentFocus called: bannerImages.length = ${controller.bannerImages.length}');
      if (controller.bannerImages.isNotEmpty) {
        bannerFocusNode.requestFocus();
        scrollToBanner();
        print('Focused on bannerFocusNode');
      } else if (focusNodesPerRow.isNotEmpty &&
          focusNodesPerRow[0].isNotEmpty) {
        focusNodesPerRow[0][0].requestFocus();
        focusedRow = 0;
        focusedCol = 0;
        scrollToTile(0, 0);
        print('Focused on video category: Row 0, Col 0');
      }
    }
  }

  @override
  void dispose() {
    _disposeFocusNodes();
    contentFocusNode.dispose();
    bannerFocusNode.dispose();
    listScrollController.dispose();
    super.dispose();
  }

  void _disposeFocusNodes() {
    for (var row in focusNodesPerRow) {
      for (var node in row) {
        node.dispose();
      }
    }
    focusNodesPerRow.clear();
    tileKeysPerRow.clear();
  }

  void scrollToBanner() {
    print('scrollToBanner called');
    listScrollController.animateTo(
      0.0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
    );
  }

  void scrollToTile(int rowIdx, int colIdx) {
    final key = tileKeysPerRow[rowIdx][colIdx];
    if (key.currentContext != null) {
      Scrollable.ensureVisible(
        key.currentContext!,
        duration: const Duration(milliseconds: 200),
        alignment: 0.1,
        curve: Curves.easeInOut,
      );
    }
  }

  KeyEventResult _handleKeyEvent(
      BuildContext context, int rowIdx, int colIdx, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    List<List<Map<String, dynamic>>> allRows = [];
    allRows.add(controller.getVideosByCategory('All'));
    controller.categorizedVideosMap.entries
        .where((e) => e.key != 'All')
        .forEach((entry) {
      allRows.add(entry.value);
    });

    if (rowIdx >= allRows.length || colIdx >= allRows[rowIdx].length) {
      return KeyEventResult.ignored;
    }

    final video = allRows[rowIdx][colIdx];

    if (event.logicalKey == LogicalKeyboardKey.select ||
        event.logicalKey == LogicalKeyboardKey.enter) {
      if (video.isNotEmpty &&
          video["videoUrl"] != null &&
          video["videoUrl"].toString().isNotEmpty) {
        print(
            'Showing preview dialog for video: ${video['title']} (${video['videoId']})');
        showDialog<bool>(
          context: context,
          builder: (context) => TVVideoPreviewDialog(
            title: video['title'],
            description: video['description'],
            thumbnailUrl: video['thumbnailUrl'],
            duration: video['duration'],
            releaseYear: video['releaseYear'],
            cbfc: video['cbfc'],
            starcast: video['starcast'],
          ),
        ).then((result) {
          if (result == true) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => TVVideoPlayer(
                  releaseYear: video['releaseYear'],
                  starcast: video['starcast'],
                  cbfc: video['cbfc'],
                  myList: video['myList'],
                  duration: video['duration'],
                  director: video['director'],
                  videoLink: video['videoUrl'],
                  videoTitle: video['title'],
                  description: video['description'],
                  category: video['category'],
                  videoId: video['videoId'],
                ),
              ),
            );
          } else if (mounted) {
            FocusScope.of(context)
                .requestFocus(focusNodesPerRow[rowIdx][colIdx]);
            scrollToTile(rowIdx, colIdx);
          }
        });
      }
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      if (rowIdx == 0) {
        bannerFocusNode.requestFocus();
        scrollToBanner();
        print('Moved up to banner from video category');
        return KeyEventResult.handled;
      } else {
        int prevRow = rowIdx - 1;
        int prevCol = colIdx;
        if (focusNodesPerRow[prevRow].isNotEmpty) {
          if (prevCol >= focusNodesPerRow[prevRow].length)
            prevCol = focusNodesPerRow[prevRow].length - 1;
          FocusScope.of(context)
              .requestFocus(focusNodesPerRow[prevRow][prevCol]);
          scrollToTile(prevRow, prevCol);
          setState(() {
            focusedRow = prevRow;
            focusedCol = prevCol;
          });
          print('Moved up to Row $prevRow, Col $prevCol');
        }
        return KeyEventResult.handled;
      }
    } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      if (rowIdx < focusNodesPerRow.length - 1) {
        int nextRow = rowIdx + 1;
        int nextCol = colIdx;
        if (focusNodesPerRow[nextRow].isNotEmpty) {
          if (nextCol >= focusNodesPerRow[nextRow].length)
            nextCol = focusNodesPerRow[nextRow].length - 1;
          FocusScope.of(context)
              .requestFocus(focusNodesPerRow[nextRow][nextCol]);
          scrollToTile(nextRow, nextCol);
          setState(() {
            focusedRow = nextRow;
            focusedCol = nextCol;
          });
          print('Moved down to Row $nextRow, Col $nextCol');
        }
        return KeyEventResult.handled;
      }
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      if (colIdx > 0) {
        FocusScope.of(context)
            .requestFocus(focusNodesPerRow[rowIdx][colIdx - 1]);
        scrollToTile(rowIdx, colIdx - 1);
        setState(() {
          focusedCol = colIdx - 1;
        });
        print('Moved left to Col ${colIdx - 1}');
        return KeyEventResult.handled;
      }
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      if (colIdx < focusNodesPerRow[rowIdx].length - 1) {
        FocusScope.of(context)
            .requestFocus(focusNodesPerRow[rowIdx][colIdx + 1]);
        scrollToTile(rowIdx, colIdx + 1);
        setState(() {
          focusedCol = colIdx + 1;
        });
        print('Moved right to Col ${colIdx + 1}');
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _handleBannerKeyEvent(BuildContext context, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.select ||
        event.logicalKey == LogicalKeyboardKey.enter) {
      final banner = controller.bannerImages[controller.bannerImages.length -
          1 -
          controller.currentBannerIndex.value];
      final video = controller.getVideoById(banner['videoId']);
      if (video != null &&
          video.isNotEmpty &&
          video["videoUrl"] != null &&
          video["videoUrl"].toString().isNotEmpty) {
        print('Showing preview dialog for banner video: ${video['title']}');
        showDialog<bool>(
          context: context,
          builder: (context) => TVVideoPreviewDialog(
            title: video['title'],
            description: video['description'],
            thumbnailUrl: video['thumbnailUrl'],
            duration: video['duration'],
            releaseYear: video['releaseYear'],
            cbfc: video['cbfc'],
            starcast: video['starcast'],
          ),
        ).then((result) {
          if (result == true) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => TVVideoPlayer(
                  releaseYear: video['releaseYear'],
                  starcast: video['starcast'],
                  cbfc: video['cbfc'],
                  myList: video['myList'],
                  duration: video['duration'],
                  director: video['director'],
                  videoLink: video['videoUrl'],
                  videoTitle: video['title'],
                  description: video['description'],
                  category: video['category'],
                  videoId: video['videoId'],
                ),
              ),
            );
          } else if (mounted) {
            FocusScope.of(context).requestFocus(bannerFocusNode);
            scrollToBanner();
            print('Returned to banner focus after dialog');
          }
        });
      }
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      final bottomBarState =
          context.findAncestorStateOfType<TVBottomBarTabsState>();
      if (bottomBarState != null) {
        bottomBarState.requestNavBarFocus();
        print('Moved up to navbar from banner');
      }
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      if (focusNodesPerRow.isNotEmpty && focusNodesPerRow[0].isNotEmpty) {
        FocusScope.of(context).requestFocus(focusNodesPerRow[0][0]);
        scrollToTile(0, 0);
        setState(() {
          focusedRow = 0;
          focusedCol = 0;
        });
        print('Moved down to video category: Row 0, Col 0');
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
        event.logicalKey == LogicalKeyboardKey.arrowRight) {
      return KeyEventResult.ignored; // Let banners move automatically
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      List<Widget> videoRows = [];
      List<List<Map<String, dynamic>>> allRows = [];
      List<String?> rowTitles = [];

      allRows.add(controller.getVideosByCategory('All'));
      rowTitles.add(controller.categoryTitle.value);

      controller.categorizedVideosMap.entries
          .where((e) => e.key != 'All')
          .forEach((entry) {
        allRows.add(entry.value);
        rowTitles.add(entry.key);
      });

      bool needsReinit = false;
      if (focusNodesPerRow.length != allRows.length) {
        needsReinit = true;
      } else {
        for (int i = 0; i < allRows.length; i++) {
          if (focusNodesPerRow[i].length != allRows[i].length) {
            needsReinit = true;
            break;
          }
        }
      }
      if (needsReinit) {
        _initializeFocusNodes();
      }

      for (int rowIdx = 0; rowIdx < allRows.length; rowIdx++) {
        if (rowTitles[rowIdx] != null) {
          videoRows.add(
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 12.h),
              child: Text(
                rowTitles[rowIdx]!,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: rowIdx == 0 ? 24 : 22,
                ),
              ),
            ),
          );
        }
        videoRows.add(
          _buildVideoRow(context, allRows[rowIdx], rowIdx),
        );
      }

      return Focus(
        focusNode: contentFocusNode,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.arrowDown) {
            if (controller.bannerImages.isNotEmpty &&
                !bannerFocusNode.hasFocus) {
              FocusScope.of(context).requestFocus(bannerFocusNode);
              scrollToBanner();
              setState(() {});
              print('Focused on banner from content focus');
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: Scaffold(
          backgroundColor: blackColor,
          body: controller.isLoading.value
              ? _buildShimmerLoading()
              : RefreshIndicator(
                  onRefresh: () => controller.onRefresh(),
                  child: ListView(
                    controller: listScrollController,
                    padding: EdgeInsets.zero,
                    children: [
                      _buildBannerSection(context),
                      _buildBannerDetails(context),
                      SizedBox(
                        height: 32.h,
                      ),
                      ...videoRows,
                    ],
                  ),
                ),
        ),
      );
    });
  }

  Widget _buildBannerSection(BuildContext context) {
    return Container(
      height: 300.h,
      width: double.infinity,
      child: Obx(() {
        if (controller.bannerImages.isEmpty) {
          return Container(
            color: Colors.grey[900],
            height: 300.h,
          );
        }
        return Focus(
          focusNode: bannerFocusNode,
          onKeyEvent: (node, event) => _handleBannerKeyEvent(context, event),
          onFocusChange: (hasFocus) {
            if (hasFocus) {
              scrollToBanner();
              setState(() {});
              print('Banner section focused');
            }
          },
          child: PageView.builder(
            controller: controller.bannerPageController,
            itemCount: controller.bannerImages.length,
            onPageChanged: (index) {
              controller.currentBannerIndex.value = index;
              print('Banner changed to index: $index');
            },
            itemBuilder: (context, index) {
              final banner = controller
                  .bannerImages[controller.bannerImages.length - 1 - index];

              return Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    banner['imageUrl'],
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        Container(color: Colors.grey[800]),
                  ),
                  ClipRRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0),
                      child: Container(
                        color: Colors.black.withOpacity(0.3),
                      ),
                    ),
                  ),
                  Image.network(
                    banner['imageUrl'],
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) =>
                        const SizedBox.shrink(),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.center,
                        colors: [
                          Colors.black,
                          Colors.transparent,
                        ],
                        stops: const [0.0, 1.0],
                      ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerRight,
                        end: Alignment.center,
                        colors: [
                          Colors.black,
                          Colors.transparent,
                        ],
                        stops: const [0.0, 1.0],
                      ),
                    ),
                  ),
                  if (bannerFocusNode.hasFocus)
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.blue,
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                ],
              );
            },
          ),
        );
      }),
    );
  }

  Widget _buildBannerDetails(BuildContext context) {
    return Obx(() {
      if (controller.bannerImages.isEmpty) {
        return const SizedBox.shrink();
      }

      final banner = controller.bannerImages[controller.bannerImages.length -
          1 -
          controller.currentBannerIndex.value];
      final video = controller.getVideoById(banner['videoId']);

      if (video == null || video.isEmpty) {
        return Padding(
          padding: EdgeInsets.fromLTRB(40.w, 0, 40.w, 0),
          child: Text(
            'Streaming soon...',
            style: TextStyle(
              fontSize: 24,
              color: Colors.white70,
              fontStyle: FontStyle.italic,
            ),
          ),
        );
      }

      return Padding(
        padding: EdgeInsets.fromLTRB(40.w, 20.h, 40.w, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              video['title'] ?? 'No Title Available',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 12.h),
            Text(
              video['description'] != null &&
                      (video['description'] as String).isNotEmpty
                  ? video['description']
                  : 'More details coming soon.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.85),
                height: 1.4,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      );
    });
  }

  Widget _buildVideoRow(
      BuildContext context, List<Map<String, dynamic>> videos, int rowIdx) {
    if (videos.isEmpty) {
      return Container(
        height: 190.h,
        alignment: Alignment.center,
        child: const Text(
          'No videos in this category.',
          style: TextStyle(color: Colors.white70, fontSize: 18),
        ),
      );
    }

    return Container(
      height: 190.h,
      margin: EdgeInsets.only(left: 10.w, top: 8.h),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: videos.length,
        separatorBuilder: (_, __) => SizedBox(width: 12.w),
        itemBuilder: (context, colIdx) {
          return Container(
            key: tileKeysPerRow.length > rowIdx &&
                    tileKeysPerRow[rowIdx].length > colIdx
                ? tileKeysPerRow[rowIdx][colIdx]
                : null,
            child: Focus(
              focusNode: focusNodesPerRow.length > rowIdx &&
                      focusNodesPerRow[rowIdx].length > colIdx
                  ? focusNodesPerRow[rowIdx][colIdx]
                  : FocusNode(),
              onKeyEvent: (node, event) =>
                  _handleKeyEvent(context, rowIdx, colIdx, event),
              onFocusChange: (hasFocus) {
                if (hasFocus) scrollToTile(rowIdx, colIdx);
              },
              child: AnimatedBuilder(
                animation: focusNodesPerRow[rowIdx][colIdx],
                builder: (context, child) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 248.h,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10.r),
                      boxShadow: [
                        BoxShadow(
                          color: focusNodesPerRow[rowIdx][colIdx].hasFocus
                              ? Colors.blue.withOpacity(0.4)
                              : Colors.black.withOpacity(0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: child,
                  );
                },
                child: _buildVideoCard(videos[colIdx], rowIdx, colIdx),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildVideoCard(Map<String, dynamic> video, int rowIdx, int colIdx) {
    DateTime? releaseDate;
    if (video["releaseDate"] is DateTime) {
      releaseDate = video["releaseDate"] as DateTime;
    } else if (video["releaseDate"] is String) {
      try {
        releaseDate = DateTime.parse(video["releaseDate"] as String);
      } catch (e) {
        print("Error parsing releaseDate for ${video['title']}: $e");
        releaseDate = null;
      }
    }

    final thresholdDate = DateTime.now().subtract(const Duration(days: 60));
    final isRecentlyAdded =
        releaseDate != null && releaseDate.isAfter(thresholdDate);

    return GestureDetector(
      onTap: () {
        if (video.isNotEmpty &&
            video["videoUrl"] != null &&
            video["videoUrl"].toString().isNotEmpty) {
          print('Tapped video card: ${video['title']}');
          showDialog<bool>(
            context: context,
            builder: (context) => TVVideoPreviewDialog(
              title: video['title'],
              description: video['description'],
              thumbnailUrl: video['thumbnailUrl'],
              duration: video['duration'],
              releaseYear: video['releaseYear'],
              cbfc: video['cbfc'],
              starcast: video['starcast'],
            ),
          ).then((result) {
            if (result == true) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => TVVideoPlayer(
                    releaseYear: video['releaseYear'],
                    starcast: video['starcast'],
                    cbfc: video['cbfc'],
                    myList: video['myList'],
                    duration: video['duration'],
                    director: video['director'],
                    videoLink: video['videoUrl'],
                    videoTitle: video['title'],
                    description: video['description'],
                    category: video['category'],
                    videoId: video['videoId'],
                  ),
                ),
              );
            }
          });
        }
      },
      child: Container(
        height: 248.h,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10.r),
        ),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10.r),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Image.network(
                    video['thumbnailUrl'] ?? "",
                    width: 80.w,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 80.w,
                      height: 120.h,
                      color: Colors.grey,
                      child: const Center(child: Text("No Image")),
                    ),
                  ),
                  Container(
                    padding:
                        EdgeInsets.symmetric(vertical: 6.h, horizontal: 6.w),
                    child: Text(
                      video['title'] ?? "",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
            if (isRecentlyAdded)
              Positioned(
                top: 3.h,
                right: 3.w,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: Colors.red[500],
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  child: const Text(
                    "Recently added",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 6,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Container(
          height: 330.h,
          color: Colors.grey[800],
        ),
        SizedBox(height: 24.h),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 40.w),
          child: Shimmer.fromColors(
            baseColor: Colors.grey[800]!.withOpacity(0.5),
            highlightColor: Colors.grey[500]!.withOpacity(0.3),
            child: Container(
              height: 32.h,
              width: 180.w,
              color: Colors.grey[800],
            ),
          ),
        ),
        SizedBox(height: 8.h),
        Container(
          height: 190.h,
          margin: EdgeInsets.only(left: 40.w, top: 8.h),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: 6,
            separatorBuilder: (_, __) => SizedBox(width: 20.w),
            itemBuilder: (context, index) {
              return Shimmer.fromColors(
                baseColor: Colors.grey[800]!.withOpacity(0.5),
                highlightColor: Colors.grey[500]!.withOpacity(0.3),
                child: Container(
                  width: 128.w,
                  height: 180.h,
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

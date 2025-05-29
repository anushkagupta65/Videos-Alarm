import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:videos_alarm_app/components/app_style.dart';
import 'package:videos_alarm_app/screens/view_video.dart';

class HomeController extends GetxController {
  RxBool isLoading = false.obs;
  RxMap<String, List<Map<String, dynamic>>> categorizedVideosMap =
      <String, List<Map<String, dynamic>>>{}.obs;
  RxList<Map<String, dynamic>> allVideos = <Map<String, dynamic>>[].obs;
  RxString selectedCategory = 'All'.obs;
  RxString categoryTitle = 'Latest Shows'.obs; // Default title

  // Banner Configuration
  final PageController bannerPageController = PageController(initialPage: 0);
  RxInt currentBannerIndex = 0.obs;
  Timer? bannerTimer;
  RxList<Map<String, dynamic>> bannerImages = <Map<String, dynamic>>[].obs;

  @override
  void onInit() {
    super.onInit();
    getVideosList();
    getBanners();
    startBannerTimer();
  }

  @override
  void onClose() {
    bannerPageController.dispose();
    bannerTimer?.cancel();
    super.onClose();
  }

  void startBannerTimer() {
    bannerTimer = Timer.periodic(const Duration(seconds: 3), (Timer timer) {
      if (bannerImages.isNotEmpty) {
        if (currentBannerIndex.value < bannerImages.length - 1) {
          currentBannerIndex.value++;
        } else {
          currentBannerIndex.value = 0;
        }

        if (bannerPageController.hasClients) {
          bannerPageController.animateToPage(
            currentBannerIndex.value,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeIn,
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
        };

        bannersList.add(banner);
      }

      bannerImages.assignAll(bannersList); // Use assignAll for RxList
    } catch (error) {
      print("Error getting banners: $error");
    }
  }

  Future<void> getVideosList() async {
    isLoading.value = true;

    try {
      FirebaseFirestore firestore = FirebaseFirestore.instance;
      QuerySnapshot querySnapshot = await firestore.collection('videos').get();

      Map<String, List<Map<String, dynamic>>> categorizedVideos = {};
      List<Map<String, dynamic>> videosList = [];

      for (QueryDocumentSnapshot doc in querySnapshot.docs) {
        var data = Map<String, dynamic>.from(doc.data() as Map);

        if (data['category'] == 'live') {
          continue;
        }

        if (data['createdAt'] is Timestamp) {
          data['createdAt'] = (data['createdAt'] as Timestamp).toDate();
        }

        var video = {
          "title": data["title"],
          "description": data["description"],
          "category": data["category"],
          "videoUrl": data["videoUrl"],
          "thumbnailUrl": data["thumbnailUrl"],
          "createdAt": data["createdAt"],
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

      allVideos.assignAll(videosList); // Use assignAll for RxList
      categorizedVideosMap
          .assignAll(categorizedVideos); // Use assignAll for RxMap
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

  String formatDate(dynamic createdAt) {
    if (createdAt == null) return 'Unknown date';

    try {
      if (createdAt is Timestamp) {
        DateTime date = createdAt.toDate();
        return DateFormat('MMM dd, yyyy').format(date);
      } else if (createdAt is DateTime) {
        return DateFormat('MMM dd, yyyy').format(createdAt);
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
        categoryTitle.value = 'Latest Shows';
        break;
      case 'Movies':
        categoryTitle.value = 'Latest Movies';
        break;
      case 'Songs':
        categoryTitle.value = 'Latest Songs';
        break;
      default:
        categoryTitle.value =
            'Latest ' + category; //For if other categories exist
        break;
    }
  }

  void selectCategory(String category) {
    selectedCategory.value = category;
    updateCategoryTitle(category);
  }
}

class Home extends StatelessWidget {
  Home({Key? key}) : super(key: key);

  final HomeController controller = Get.put(HomeController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: blackColor,
      body: Obx(() {
        return controller.isLoading.value
            ? _buildShimmerLoading()
            : RefreshIndicator(
                onRefresh: () => controller.onRefresh(),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildBannerSection(),
                      _buildCategoryButtons(),
                      Center(
                        child: Obx(() => Text(
                              controller.categoryTitle.value,
                              style: TextStyle(
                                  fontWeight: boldFont,
                                  color: whiteColor,
                                  fontSize: 20),
                            )),
                      ),
                      _buildVideoList(),
                    ],
                  ),
                ),
              );
      }),
    );
  }

  Widget _buildBannerSection() {
    return Container(
      height: 200,
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          PageView.builder(
            controller: controller.bannerPageController,
            itemCount: controller.bannerImages.length,
            onPageChanged: (index) {
              controller.currentBannerIndex.value = index;
            },
            itemBuilder: (context, index) {
              return _bannerCard(controller.bannerImages[index]['imageUrl']);
            },
          ),
          Positioned(
            bottom: 10,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: controller.bannerImages.asMap().entries.map((entry) {
                return Container(
                  width: 8.0,
                  height: 8.0,
                  margin: const EdgeInsets.symmetric(
                      vertical: 8.0, horizontal: 4.0),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: controller.currentBannerIndex.value == entry.key
                        ? Colors.white
                        : Colors.grey[600]!,
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bannerCard(String imageUrl) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15.0),
        child: Image.network(
          imageUrl,
          fit: BoxFit.contain,
          width: double.infinity,
        ),
      ),
    );
  }

  Widget _buildCategoryButtons() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _categoryButton('All', Icons.all_inclusive_rounded),
            ...controller.categorizedVideosMap.keys
                .toList()
                .where((category) => category != 'live')
                .map((category) {
              return _categoryButton(category, Icons.movie_filter_rounded);
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoList() {
    List<Map<String, dynamic>> videos =
        controller.getVideosByCategory(controller.selectedCategory.value);

    return videos.isEmpty
        ? Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Text(
                'No videos in this category.',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            ),
          )
        : ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: videos.length,
            itemBuilder: (context, index) {
              var video = videos[index];
              return _buildVideoCard(video);
            },
          );
  }

  Widget _buildShimmerLoading() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: Colors.grey[800]!.withOpacity(0.5),
            borderRadius: BorderRadius.circular(20),
          ),
          height: 200,
        );
      },
    );
  }

  Widget _buildVideoCard(Map<String, dynamic> video) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GestureDetector(
        onTap: () {
          Get.to(() => ViewVideo(
                releaseYear: video['releaseYear'],
                cbfc: video['cbfc'],
                myList: video['myList'],
                duration: video['duration'],
                director: video['director'],
                videoTitle: video['title'].toString(),
                description: video['description'],
                videoLink: video['videoUrl'],
                category: video['category'],
                videoId: video['videoId'],
              ));
        },
        child: Container(
          decoration: BoxDecoration(
            color: const Color.fromARGB(255, 15, 36, 75),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color.fromARGB(255, 3, 16, 39),
                spreadRadius: 1,
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Stack(
                  children: [
                    Image.network(
                      video['thumbnailUrl'],
                      width: double.infinity,
                      height: 230,
                      fit: BoxFit.fill,
                    ),
                    Positioned(
                        bottom: 8,
                        left: 8,
                        child: Text(
                          'Released: ${controller.formatDate(video['createdAt'])}',
                          style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              shadows: [
                                Shadow(
                                  blurRadius: 2.0,
                                  color: Colors.black,
                                  offset: Offset(1.0, 1.0),
                                )
                              ]),
                        )),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.4),
                            Colors.transparent
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _categoryButton(String category, IconData icon) {
    return GestureDetector(
      onTap: () {
        controller.selectCategory(category);
      },
      child: Obx(() => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6.0),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
              decoration: BoxDecoration(
                color: controller.selectedCategory.value == category
                    ? Colors.deepPurpleAccent
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: Colors.deepPurpleAccent.withOpacity(0.6),
                  width: 1.3,
                ),
              ),
              child: Row(
                children: [
                  Icon(icon,
                      color: controller.selectedCategory.value == category
                          ? whiteColor
                          : greyColor,
                      size: 19),
                  const SizedBox(width: 7),
                  Text(
                    category,
                    style: TextStyle(
                      color: controller.selectedCategory.value == category
                          ? whiteColor
                          : greyColor,
                      fontWeight: FontWeight.w500,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          )),
    );
  }
}

// import 'dart:async';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:intl/intl.dart';
// import 'package:videos_alarm_app/components/app_style.dart';
// import 'package:videos_alarm_app/screens/view_video.dart';

// class HomeController extends GetxController {
//   RxBool isLoading = false.obs;
//   RxMap<String, List<Map<String, dynamic>>> categorizedVideosMap =
//       <String, List<Map<String, dynamic>>>{}.obs;
//   RxList<Map<String, dynamic>> allVideos = <Map<String, dynamic>>[].obs;
//   RxString selectedCategory = 'All'.obs;
//   RxString categoryTitle = 'Latest Shows'.obs; // Default title

//   // Banner Configuration
//   final PageController bannerPageController = PageController(initialPage: 0);
//   RxInt currentBannerIndex = 0.obs;
//   Timer? bannerTimer;
//   RxList<Map<String, dynamic>> bannerImages = <Map<String, dynamic>>[].obs;

//   @override
//   void onInit() {
//     super.onInit();
//     getVideosList();
//     getBanners();
//     startBannerTimer();
//   }

//   @override
//   void onClose() {
//     bannerPageController.dispose();
//     bannerTimer?.cancel();
//     super.onClose();
//   }

//   void startBannerTimer() {
//     bannerTimer = Timer.periodic(const Duration(seconds: 3), (Timer timer) {
//       if (bannerImages.isNotEmpty) {
//         if (currentBannerIndex.value < bannerImages.length - 1) {
//           currentBannerIndex.value++;
//         } else {
//           currentBannerIndex.value = 0;
//         }

//         if (bannerPageController.hasClients) {
//           bannerPageController.animateToPage(
//             currentBannerIndex.value,
//             duration: const Duration(milliseconds: 500),
//             curve: Curves.easeIn,
//           );
//         }
//       }
//     });
//   }

//   Future<void> getBanners() async {
//     try {
//       FirebaseFirestore firestore = FirebaseFirestore.instance;
//       QuerySnapshot querySnapshot = await firestore.collection('banners').get();

//       List<Map<String, dynamic>> bannersList = [];

//       for (QueryDocumentSnapshot doc in querySnapshot.docs) {
//         var data = Map<String, dynamic>.from(doc.data() as Map);

//         var banner = {
//           "imageUrl": data["imageUrl"],
//         };

//         bannersList.add(banner);
//       }

//       bannerImages.assignAll(bannersList); // Use assignAll for RxList
//     } catch (error) {
//       print("Error getting banners: $error");
//     }
//   }

//   Future<void> getVideosList() async {
//     isLoading.value = true;

//     try {
//       FirebaseFirestore firestore = FirebaseFirestore.instance;
//       QuerySnapshot querySnapshot = await firestore.collection('videos').get();

//       Map<String, List<Map<String, dynamic>>> categorizedVideos = {};
//       List<Map<String, dynamic>> videosList = [];

//       for (QueryDocumentSnapshot doc in querySnapshot.docs) {
//         var data = Map<String, dynamic>.from(doc.data() as Map);

//         if (data['category'] == 'live') {
//           continue;
//         }

//         if (data['releaseDate'] is Timestamp) {
//           data['releaseDate'] = (data['releaseDate'] as Timestamp).toDate();
//         }

//         var video = {
//           "releaseYear": data['releaseYear'],
//           "cbfc": data['cbfc'],
//           "myList": data['myList'],
//           "duration": data['duration'],
//           "director": data['director'],
//           "title": data["title"],
//           "description": data["description"],
//           "category": data["category"],
//           "videoUrl": data["videoUrl"],
//           "thumbnailUrl": data["thumbnailUrl"],
//           "releaseDate": data["releaseDate"],
//           'videoId': doc.id,
//         };

//         videosList.add(video);

//         String category = data["category"];
//         if (categorizedVideos.containsKey(category)) {
//           categorizedVideos[category]!.add(video);
//         } else {
//           categorizedVideos[category] = [video];
//         }
//       }

//       allVideos.assignAll(videosList); // Use assignAll for RxList
//       categorizedVideosMap
//           .assignAll(categorizedVideos); // Use assignAll for RxMap
//       isLoading.value = false;
//     } catch (error) {
//       isLoading.value = false;

//       Get.snackbar(
//         'Error',
//         'Something went wrong: $error',
//       );
//     }
//   }

//   List<Map<String, dynamic>> getVideosByCategory(String category) {
//     if (category == 'All') {
//       return allVideos;
//     }
//     return categorizedVideosMap[category] ?? [];
//   }

//   String formatDate(dynamic releaseDate) {
//     if (releaseDate == null) return 'Unknown date';

//     try {
//       if (releaseDate is Timestamp) {
//         DateTime date = releaseDate.toDate();
//         return DateFormat('MMM dd, yyyy').format(date);
//       } else if (releaseDate is DateTime) {
//         return DateFormat('MMM dd, yyyy').format(releaseDate);
//       } else {
//         return 'Invalid date format';
//       }
//     } catch (e) {
//       return 'Invalid date';
//     }
//   }

//   Future<void> onRefresh() async {
//     await getVideosList();
//   }

//   void updateCategoryTitle(String category) {
//     switch (category) {
//       case 'All':
//         categoryTitle.value = 'Latest Shows';
//         break;
//       case 'Movies':
//         categoryTitle.value = 'Latest Movies';
//         break;
//       case 'Songs':
//         categoryTitle.value = 'Latest Songs';
//         break;
//       default:
//         categoryTitle.value =
//             'Latest ' + category; //For if other categories exist
//         break;
//     }
//   }

//   void selectCategory(String category) {
//     selectedCategory.value = category;
//     updateCategoryTitle(category);
//   }
// }

// class Home extends StatelessWidget {
//   Home({Key? key}) : super(key: key);

//   final HomeController controller = Get.put(HomeController());

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: blackColor,
//       body: Obx(() {
//         return controller.isLoading.value
//             ? _buildShimmerLoading()
//             : RefreshIndicator(
//                 onRefresh: () => controller.onRefresh(),
//                 child: SingleChildScrollView(
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       _buildBannerSection(),
//                       _buildCategoryButtons(),
//                       Center(
//                         child: Obx(() => Text(
//                               controller.categoryTitle.value,
//                               style: TextStyle(
//                                   fontWeight: boldFont,
//                                   color: whiteColor,
//                                   fontSize: 20),
//                             )),
//                       ),
//                       _buildVideoList(),
//                     ],
//                   ),
//                 ),
//               );
//       }),
//     );
//   }

//   Widget _buildBannerSection() {
//     return Container(
//       height: 200,
//       width: double.infinity,
//       margin: const EdgeInsets.only(bottom: 10),
//       child: Stack(
//         alignment: Alignment.bottomCenter,
//         children: [
//           PageView.builder(
//             controller: controller.bannerPageController,
//             itemCount: controller.bannerImages.length,
//             onPageChanged: (index) {
//               controller.currentBannerIndex.value = index;
//             },
//             itemBuilder: (context, index) {
//               return _bannerCard(controller.bannerImages[index]['imageUrl']);
//             },
//           ),
//           Positioned(
//             bottom: 10,
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: controller.bannerImages.asMap().entries.map((entry) {
//                 return Container(
//                   width: 8.0,
//                   height: 8.0,
//                   margin: const EdgeInsets.symmetric(
//                       vertical: 8.0, horizontal: 4.0),
//                   decoration: BoxDecoration(
//                     shape: BoxShape.circle,
//                     color: controller.currentBannerIndex.value == entry.key
//                         ? Colors.white
//                         : Colors.grey[600]!,
//                   ),
//                 );
//               }).toList(),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _bannerCard(String imageUrl) {
//     return Container(
//       margin: const EdgeInsets.symmetric(horizontal: 10.0),
//       decoration: BoxDecoration(
//         borderRadius: BorderRadius.circular(15.0),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.2),
//             spreadRadius: 1,
//             blurRadius: 5,
//             offset: const Offset(0, 3),
//           ),
//         ],
//       ),
//       child: ClipRRect(
//         borderRadius: BorderRadius.circular(15.0),
//         child: Image.network(
//           imageUrl,
//           fit: BoxFit.fill,
//           width: double.infinity,
//         ),
//       ),
//     );
//   }

//   Widget _buildCategoryButtons() {
//     return Container(
//       padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
//       child: SingleChildScrollView(
//         scrollDirection: Axis.horizontal,
//         child: Row(
//           children: [
//             _categoryButton('All', Icons.all_inclusive_rounded),
//             ...controller.categorizedVideosMap.keys
//                 .toList()
//                 .where((category) => category != 'live')
//                 .map((category) {
//               return _categoryButton(category, Icons.movie_filter_rounded);
//             }).toList(),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildVideoList() {
//     List<Map<String, dynamic>> videos =
//         controller.getVideosByCategory(controller.selectedCategory.value);

//     return videos.isEmpty
//         ? Center(
//             child: Padding(
//               padding: const EdgeInsets.symmetric(vertical: 40),
//               child: Text(
//                 'No videos in this category.',
//                 style: TextStyle(color: Colors.white70, fontSize: 16),
//               ),
//             ),
//           )
//         : ListView.builder(
//             shrinkWrap: true,
//             physics: const NeverScrollableScrollPhysics(),
//             padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//             itemCount: videos.length,
//             itemBuilder: (context, index) {
//               var video = videos[index];
//               return _buildVideoCard(video);
//             },
//           );
//   }

//   Widget _buildShimmerLoading() {
//     return ListView.builder(
//       padding: const EdgeInsets.all(16),
//       itemCount: 5,
//       itemBuilder: (context, index) {
//         return Container(
//           margin: const EdgeInsets.only(bottom: 20),
//           decoration: BoxDecoration(
//             color: Colors.grey[800]!.withOpacity(0.5),
//             borderRadius: BorderRadius.circular(20),
//           ),
//           height: 200,
//         );
//       },
//     );
//   }

//   Widget _buildVideoCard(Map<String, dynamic> video) {
//     return Padding(
//       padding: const EdgeInsets.only(bottom: 16),
//       child: GestureDetector(
//         onTap: () {
//           Get.to(() => ViewVideo(
//                 releaseYear: video['releaseYear'],
//                 cbfc: video['cbfc'],
//                 myList: video['myList'],
//                 duration: video['duration'],
//                 director: video['director'],
//                 videoTitle: video['title'].toString(),
//                 description: video['description'],
//                 videoLink: video['videoUrl'],
//                 category: video['category'],
//                 videoId: video['videoId'],
//               ));
//         },
//         child: Container(
//           decoration: BoxDecoration(
//             color: const Color.fromARGB(255, 15, 36, 75),
//             borderRadius: BorderRadius.circular(20),
//             boxShadow: [
//               BoxShadow(
//                 color: const Color.fromARGB(255, 3, 16, 39),
//                 spreadRadius: 1,
//                 blurRadius: 8,
//                 offset: const Offset(0, 4),
//               ),
//             ],
//           ),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               ClipRRect(
//                 borderRadius: BorderRadius.circular(10),
//                 child: Stack(
//                   children: [
//                     Image.network(
//                       video['thumbnailUrl'],
//                       width: double.infinity,
//                       height: 230,
//                       fit: BoxFit.fill,
//                     ),
//                     Positioned(
//                         bottom: 8,
//                         left: 8,
//                         child: Text(
//                           'Released: ${controller.formatDate(video['releaseDate'])}',
//                           style: const TextStyle(
//                               color: Colors.white70,
//                               fontSize: 13,
//                               shadows: [
//                                 Shadow(
//                                   blurRadius: 2.0,
//                                   color: Colors.black,
//                                   offset: Offset(1.0, 1.0),
//                                 )
//                               ]),
//                         )),
//                     Container(
//                       decoration: BoxDecoration(
//                         gradient: LinearGradient(
//                           begin: Alignment.topCenter,
//                           end: Alignment.bottomCenter,
//                           colors: [
//                             Colors.black.withOpacity(0.4),
//                             Colors.transparent
//                           ],
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _categoryButton(String category, IconData icon) {
//     return GestureDetector(
//       onTap: () {
//         controller.selectCategory(category);
//       },
//       child: Obx(() => Padding(
//             padding: const EdgeInsets.symmetric(horizontal: 6.0),
//             child: Container(
//               padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
//               decoration: BoxDecoration(
//                 color: controller.selectedCategory.value == category
//                     ? Colors.deepPurpleAccent
//                     : Colors.transparent,
//                 borderRadius: BorderRadius.circular(30),
//                 border: Border.all(
//                   color: Colors.deepPurpleAccent.withOpacity(0.6),
//                   width: 1.3,
//                 ),
//               ),
//               child: Row(
//                 children: [
//                   Icon(icon,
//                       color: controller.selectedCategory.value == category
//                           ? whiteColor
//                           : greyColor,
//                       size: 19),
//                   const SizedBox(width: 7),
//                   Text(
//                     category,
//                     style: TextStyle(
//                       color: controller.selectedCategory.value == category
//                           ? whiteColor
//                           : greyColor,
//                       fontWeight: FontWeight.w500,
//                       fontSize: 15,
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           )),
//     );
//   }
// }

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:videos_alarm_app/components/app_style.dart';
import 'package:videos_alarm_app/screens/view_video.dart';

class HomeController extends GetxController {
  RxBool isLoading = false.obs;
  RxMap<String, List<Map<String, dynamic>>> categorizedVideosMap =
      <String, List<Map<String, dynamic>>>{}.obs;
  RxList<Map<String, dynamic>> allVideos = <Map<String, dynamic>>[].obs;
  RxString selectedCategory = 'All'.obs;
  RxString categoryTitle = 'Latest Shows'.obs;

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
    bannerTimer = Timer.periodic(Duration(seconds: 3), (Timer timer) {
      if (bannerImages.isNotEmpty) {
        if (currentBannerIndex.value < bannerImages.length - 1) {
          currentBannerIndex.value++;
        } else {
          currentBannerIndex.value = 0;
        }

        if (bannerPageController.hasClients) {
          bannerPageController.animateToPage(
            currentBannerIndex.value,
            duration: Duration(milliseconds: 500),
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

      bannerImages.assignAll(bannersList);
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
        categoryTitle.value = 'Latest Shows';
        break;
      case 'Movies':
        categoryTitle.value = 'Latest Movies';
        break;
      case 'Songs':
        categoryTitle.value = 'Latest Songs';
        break;
      default:
        categoryTitle.value = 'Latest ' + category;
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
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
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
                                    fontSize: 20.sp),
                              )),
                        ),
                        _buildVideoList(),
                      ],
                    ),
                  ),
                ),
              );
      }),
    );
  }

  Widget _buildBannerSection() {
    return Column(
      children: [
        Container(
          height: 150.h,
          width: double.infinity,
          margin: EdgeInsets.only(bottom: 8.h),
          child: PageView.builder(
            controller: controller.bannerPageController,
            itemCount: controller.bannerImages.length,
            onPageChanged: (index) {
              controller.currentBannerIndex.value = index;
            },
            itemBuilder: (context, index) {
              return _bannerCard(controller
                      .bannerImages[controller.bannerImages.length - 1 - index]
                  ['imageUrl']);
            },
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: controller.bannerImages.asMap().entries.map((entry) {
            return Container(
              width: 8.w,
              height: 8.h,
              margin: EdgeInsets.symmetric(vertical: 8.h, horizontal: 4.w),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: controller.currentBannerIndex.value == entry.key
                    ? Colors.white
                    : Colors.grey[600]!,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _bannerCard(String imageUrl) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 10.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            spreadRadius: 1.w,
            blurRadius: 5.w,
            offset: Offset(0, 3.h),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15.r),
        child: Image.network(
          imageUrl,
          fit: BoxFit.fill,
          width: double.infinity,
        ),
      ),
    );
  }

  Widget _buildCategoryButtons() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 12.w),
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
              padding: EdgeInsets.symmetric(vertical: 40.h),
              child: Text(
                'No videos in this category.',
                style: TextStyle(color: Colors.white70, fontSize: 16.sp),
              ),
            ),
          )
        : ListView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
            itemCount: videos.length,
            itemBuilder: (context, index) {
              var video = videos[index];
              return _buildVideoCard(video);
            },
          );
  }

  Widget _buildShimmerLoading() {
    return ListView.builder(
      padding: EdgeInsets.all(16.w),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Container(
          margin: EdgeInsets.only(bottom: 20.h),
          decoration: BoxDecoration(
            color: Colors.grey[800]!.withOpacity(0.5),
            borderRadius: BorderRadius.circular(20.r),
          ),
          height: 200.h,
        );
      },
    );
  }

  Widget _buildVideoCard(Map<String, dynamic> video) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: GestureDetector(
        onTap: () {
          Get.to(() => ViewVideo(
                releaseYear: video['releaseYear'],
                starcast: video['starcast'],
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.all(Radius.circular(10.r)),
              child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.4),
                        Colors.transparent,
                      ],
                    ),
                    image: DecorationImage(
                      image: NetworkImage(video['thumbnailUrl']),
                      fit: BoxFit.fill,
                    ),
                  ),
                  width: double.infinity,
                  height: 150.h),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "${video['title']}",
                    style: TextStyle(
                      color: whiteColor,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          blurRadius: 1,
                          color: Colors.black,
                          offset: Offset(1, 1),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'Released: ${controller.formatDate(video['releaseDate'])}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      shadows: [
                        Shadow(
                          blurRadius: 1,
                          color: Colors.black,
                          offset: Offset(1, 1),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
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
            padding: EdgeInsets.symmetric(horizontal: 6.w),
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 14.w),
              decoration: BoxDecoration(
                color: controller.selectedCategory.value == category
                    ? Colors.deepPurpleAccent
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(30.r),
                border: Border.all(
                  color: Colors.deepPurpleAccent.withOpacity(0.6),
                  width: 1.3.w,
                ),
              ),
              child: Row(
                children: [
                  Icon(icon,
                      color: controller.selectedCategory.value == category
                          ? whiteColor
                          : greyColor,
                      size: 19.sp),
                  SizedBox(width: 7.w),
                  Text(
                    category,
                    style: TextStyle(
                      color: controller.selectedCategory.value == category
                          ? whiteColor
                          : greyColor,
                      fontWeight: FontWeight.w500,
                      fontSize: 15.sp,
                    ),
                  ),
                ],
              ),
            ),
          )),
    );
  }
}

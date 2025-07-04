import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VideoController extends GetxController {
  var isLoading = true.obs;
  var isVideoChanging = false.obs;
  var isUserActive = false.obs;

  var currentVideoTitle = ''.obs;
  var currentVideoDescription = ''.obs;
  var currentVideoLink = ''.obs;
  var currentVideoCategory = ''.obs;

  var sameCategoryVideos = <Map<String, dynamic>>[].obs;
  var otherCategoryVideos = <String, List<Map<String, dynamic>>>{}.obs;

  @override
  void onInit() {
    super.onInit();
    // You can put initial data loading or setup here.  For example:
    checkUserActiveStatus(); // Load user active status on initialization.
  }

  Future<void> initializeVideo(
      String videoTitle, String description, String videoLink) async {
    currentVideoTitle.value = videoTitle;
    currentVideoDescription.value = description;
    currentVideoLink.value = videoLink;
    isLoading.value = false;
  }

  Future<void> checkUserActiveStatus() async {
    try {
      FirebaseFirestore firestore = FirebaseFirestore.instance;
      User? currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser != null) {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        bool isTestUser = prefs.getBool('isTestUser') ?? false;

        // If test user, set active status to true and skip Firestore query
        if (isTestUser) {
          print(
              "\n\n subscription controller ---- Test user detected, setting isUserActive to true");
          isUserActive.value = false;
          return;
        }
        DocumentSnapshot userDoc =
            await firestore.collection('users').doc(currentUser.uid).get();
        if (userDoc.exists) {
          var data = userDoc.data() as Map<String, dynamic>;
          isUserActive.value = data['Active'] ?? false;
        }
      }
    } catch (e) {
      print("Error checking user active status: $e");
    }
  }

  Future<void> fetchSameCategoryVideos(String category) async {
    try {
      FirebaseFirestore firestore = FirebaseFirestore.instance;
      QuerySnapshot querySnapshot = await firestore.collection('bunny').get();

      Map<String, List<Map<String, dynamic>>> categorizedVideos = {};

      for (QueryDocumentSnapshot doc in querySnapshot.docs) {
        // Change to QueryDocumentSnapshot
        var data = doc.data() as Map<String, dynamic>;
        String videoCategory = data['category'];

        print('Subscribed to notifications id${doc.id}');
        categorizedVideos.putIfAbsent(videoCategory, () => []);
        categorizedVideos[videoCategory]?.add({
          "releaseYear": data['releaseYear'],
          "starcast": data['starcast'],
          "cbfc": data['cbfc'],
          "myList": data['myList'],
          "duration": data['duration'],
          "director": data['director'],
          'title': data['title'],
          'description': data['description'],
          'videoUrl': data['videoUrl'],
          'thumbnailUrl': data['thumbnailUrl'],
          'videoId': doc.id, // doc.id contains the DOCUMENT ID.
        });
      }

      sameCategoryVideos.value = categorizedVideos[category] ?? [];
      categorizedVideos.remove(category);
      otherCategoryVideos.value = categorizedVideos;
    } catch (e) {
      print("Error fetching videos: $e");
    }
  }

  Future<void> changeVideo(String videoUrl, String title, String description,
      String category) async {
    if (isVideoChanging.value) return;

    isVideoChanging.value = true;
    currentVideoTitle.value = title;
    currentVideoDescription.value = description;
    currentVideoCategory.value = category;

    await Future.delayed(const Duration(milliseconds: 500));
    currentVideoLink.value = videoUrl;
    isVideoChanging.value = false;
  }
}

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:videos_alarm_app/screens/video_player_page.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// LiveVideos Controller
class LiveVideosController extends GetxController {
  var isLoading = false.obs;
  var errorMessage = ''.obs;
  var liveVideos = <VideoItem>[].obs;
  var pastLiveVideos = <VideoItem>[].obs;
  final String youtubeApiKey =
      'AIzaSyA3Co3oJkuMfsrLttokAU55y4STgBcZNHw'; // Replace with your actual API key

  @override
  void onInit() {
    super.onInit();
    // **Register the controller ONCE, as soon as it's created**
    //   Important: Remove this from the LiveVideos screen
    loadLiveVideos();
  }

  Future<void> loadLiveVideos() async {
    isLoading.value = true;
    errorMessage.value = '';
    liveVideos.clear();
    pastLiveVideos.clear();

    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot =
          await FirebaseFirestore.instance.collection('live_videos').get();

      for (final doc in snapshot.docs) {
        final data = doc.data();
        if (data != null) {
          try {
            final video = VideoItem.fromJson(data);
            final isLive = await checkLiveStatus(video.videoId);

            if (isLive) {
              liveVideos.add(video);
            } else {
              pastLiveVideos.add(video);
            }
          } catch (e) {
            print("Error parsing video data: $e, doc ID: ${doc.id}");
          }
        } else {
          print("Document data is null for doc ID: ${doc.id}");
        }
      }
    } catch (e) {
      print("Error loading live videos: $e");
      errorMessage.value =
          "Failed to load live videos. Please check your internet connection and Firebase configuration.";
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> checkLiveStatus(String videoId) async {
    try {
      final url = Uri.parse(
          'https://www.googleapis.com/youtube/v3/videos?part=liveStreamingDetails&id=$videoId&key=$youtubeApiKey');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        if (jsonResponse['items'] != null && jsonResponse['items'].isNotEmpty) {
          final item = jsonResponse['items'][0];
          if (item['liveStreamingDetails'] != null &&
              item['liveStreamingDetails']['actualEndTime'] == null) {
            return true; // Live stream is still active
          }
        }
        return false; // Live stream has ended or is not a live stream
      } else {
        print('Failed to fetch live status: ${response.statusCode}');
        return false; // Assume not live on error
      }
    } catch (e) {
      print('Error checking live status: $e');
      return false; // Assume not live on error
    }
  }
}

// Video Item
class VideoItem {
  final String videoId;
  final String title;
  final String description;
  final String thumbnailUrl;
  final String actualStartTime;
  final List<String> videoTags;
  final int concurrentViewers;
  final DateTime createdAt;

  String get formattedCreatedAt => DateFormat('MMM dd').format(createdAt);

  VideoItem({
    required this.videoId,
    required this.title,
    required this.description,
    required this.concurrentViewers,
    required this.thumbnailUrl,
    required this.actualStartTime,
    required this.videoTags,
    required this.createdAt,
  });

  factory VideoItem.fromJson(Map<String, dynamic> json) {
    Timestamp? createdAtTimestamp = json['createdAt'] as Timestamp?;
    DateTime createdAtDateTime = createdAtTimestamp != null ? createdAtTimestamp.toDate() : DateTime.now();

    return VideoItem(
      videoId: json['videoId'] as String? ?? '',
      title: json['videoTitle'] as String? ?? 'No Title',
      description: json['videoDescription'] as String? ?? 'No Description',
      thumbnailUrl: json['videoThumbnailUrl'] as String? ?? '',
      actualStartTime: json['actualStartTime'] as String? ?? 'Not Available',
      videoTags: List<String>.from(json['videoTags'] as List? ?? []),
      concurrentViewers: json['concurrentViewers']as int? ?? 0,
      createdAt: createdAtDateTime,
      
    );
  }
}

// LiveVideos Screen
class LiveVideos extends StatelessWidget {
  const LiveVideos({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final liveVideosController = Get.find<LiveVideosController>(); // Get the controller

    return Scaffold(
      backgroundColor: Colors.black,
      body: Obx(() {
        // Observe the liveVideos list for changes.
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          
          children: [
            if (liveVideosController.liveVideos.isNotEmpty) // Conditionally render based on live video count
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Center(
                  child: Text(
                    "Live Streams",
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            if (liveVideosController.liveVideos.isNotEmpty)
              SizedBox(height: 260, child: LiveVideosList(isLive: true)), // Render only if there are live videos
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text(
                "Past Live Streams",
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(child: LiveVideosList(isLive: false)),
          ],
        );
      }),
    );
  }
}

// LiveVideosList Widget
class LiveVideosList extends StatelessWidget {
  final bool isLive;
  final liveVideosController = Get.find<LiveVideosController>(); // Get existing controller

  LiveVideosList({Key? key, required this.isLive}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final videosToShow = isLive
          ? liveVideosController.liveVideos
          : liveVideosController.pastLiveVideos; // Use separate lists

      if (liveVideosController.isLoading.value) {
        return const Center(child: CircularProgressIndicator(color: Colors.white));
      } else if (liveVideosController.errorMessage.value.isNotEmpty) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.only(right: 16, left: 16,bottom: 16,top: 0),
            child: Text(
              liveVideosController.errorMessage.value,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
          ),
        );
      } else if (videosToShow.isEmpty) {
        return Center(
            child: Text("No ${isLive ? 'live' : 'past live'} videos found.",
                style: const TextStyle(color: Colors.white)));
      } else {
        return ListView.builder(
          scrollDirection: isLive ? Axis.horizontal : Axis.vertical,
          padding: const EdgeInsets.all(8.0),
          itemCount: videosToShow.length,
          itemBuilder: (context, index) {
            final video = videosToShow[index];
            return _buildVideoCard(context, video, isLive);
          },
        );
      }
    });
  }

  Widget _buildVideoCard(BuildContext context, VideoItem video, bool isLive) {
    return GestureDetector(
      onTap: () {
        Get.to(() => VideoPlayerPage(video: video));
      },
      child: Container(
        width: isLive ? 300 : double.infinity,
        height: isLive ? null : 120, // Adjust height for past videos
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 15, 36, 75),
          borderRadius: BorderRadius.circular(10),
        ),
        child: isLive
            ? _buildLiveCardContent(video)
            : _buildPastLiveCardContent(video),
      ),
    );
  }

  Widget _buildLiveCardContent(VideoItem video) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Stack(
            alignment: Alignment.topLeft,
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                  image: DecorationImage(
                    image: NetworkImage(video.thumbnailUrl),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Container(
                margin: const EdgeInsets.all(8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'LIVE',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                video.title,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${video.concurrentViewers} Views',
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  ),
                  Text(
                    video.formattedCreatedAt,
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPastLiveCardContent(VideoItem video) {
    return Row(
      children: [
        SizedBox(
          width: 150,
          height: 120,
          child: ClipRRect(
            borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(10), bottomLeft: Radius.circular(10)),
            child: Image.network(
              video.thumbnailUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return const Center(child: Icon(Icons.error, color: Colors.red));
              },
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Text(
                  video.title,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${video.concurrentViewers} Views',
                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                ),
                Text(
                  video.formattedCreatedAt,
                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
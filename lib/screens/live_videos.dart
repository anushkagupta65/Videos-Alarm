import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:videos_alarm_app/screens/video_player_page.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class LiveVideosController extends GetxController {
  var isLoading = false.obs;
  var errorMessage = ''.obs;
  var liveVideos = <VideoItem>[].obs;
  var pastLiveVideos = <VideoItem>[].obs;

  final String youtubeApiKey = 'AIzaSyA3Co3oJkuMfsrLttokAU55y4STgBcZNHw';

  @override
  void onInit() {
    super.onInit();
    loadLiveVideos();
  }

  Future<void> loadLiveVideos() async {
    isLoading.value = true;
    errorMessage.value = '';
    liveVideos.clear();
    pastLiveVideos.clear();

    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot =
          await FirebaseFirestore.instance
              .collection('live_videos')
              .orderBy('createdAt', descending: true)
              .get();

      List<VideoItem> tempLiveVideos = [];
      List<VideoItem> tempPastLiveVideos = [];

      for (final doc in snapshot.docs) {
        final data = doc.data();

        try {
          final video = VideoItem.fromJson(data);

          if (video.videoId.isNotEmpty) {
            final youtubeDetails = await _fetchYouTubeDetails(video.videoId);

            video.dynamicViewCount = youtubeDetails['viewCount'];

            if (youtubeDetails['isLive']) {
              tempLiveVideos.add(video);
            } else {
              tempPastLiveVideos.add(video);
            }
          } else {
            tempPastLiveVideos.add(video);
          }
        } catch (e) {
          print("Error processing video document (ID: ${doc.id}): $e");
        }
      }

      tempLiveVideos.sort((a, b) => b.releaseDate.compareTo(a.releaseDate));
      liveVideos.addAll(tempLiveVideos);

      tempPastLiveVideos.sort((a, b) => b.releaseDate.compareTo(a.releaseDate));
      pastLiveVideos.addAll(tempPastLiveVideos);
    } catch (e) {
      print("Error loading live videos from Firestore: $e");
      errorMessage.value =
          "Failed to load live videos. Please check your internet connection and Firebase configuration.";
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> refreshVideos() async {
    await loadLiveVideos();
  }

  Future<Map<String, dynamic>> _fetchYouTubeDetails(String videoId) async {
    if (youtubeApiKey == '' || youtubeApiKey.isEmpty) {
      print(
          'YouTube API Key is not set or is the placeholder. Please replace it.');
      return {'isLive': false, 'viewCount': 'API Key Missing'};
    }

    try {
      final url = Uri.parse(
          'https://www.googleapis.com/youtube/v3/videos?part=liveStreamingDetails,statistics&id=$videoId&key=$youtubeApiKey');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        if (jsonResponse['items'] != null && jsonResponse['items'].isNotEmpty) {
          final item = jsonResponse['items'][0];
          final liveStreamingDetails = item['liveStreamingDetails'];
          final statistics = item['statistics'];

          if (liveStreamingDetails != null &&
              liveStreamingDetails['actualEndTime'] == null &&
              liveStreamingDetails['actualStartTime'] != null) {
            final viewers = int.tryParse(
                    liveStreamingDetails['concurrentViewers'] ?? '0') ??
                0;
            return {
              'isLive': true,
              'viewCount': '${NumberFormat.compact().format(viewers)} watching',
            };
          } else if (statistics != null) {
            final views = int.tryParse(statistics['viewCount'] ?? '0') ?? 0;
            return {
              'isLive': false,
              'viewCount': '${NumberFormat.compact().format(views)} views',
            };
          }
        }
      } else {
        print(
            'Failed to fetch YouTube details (Status: ${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      print('Error checking YouTube details for videoId $videoId: $e');
    }

    return {'isLive': false, 'viewCount': 'N/A views'};
  }
}

class VideoItem {
  final String videoId;
  final String title;
  final String description;
  final String thumbnailUrl;
  final String actualStartTime;
  final List<String> videoTags;
  final int concurrentViewers;
  final DateTime releaseDate;
  final DateTime? createdAt;
  String dynamicViewCount;

  String get formattedreleaseDate =>
      DateFormat('MMMM dd yyyy').format(releaseDate);

  String get formattedCreatedAt => createdAt != null
      ? DateFormat('MMMM dd, yyyy').format(createdAt!)
      : 'Unknown';

  VideoItem({
    required this.videoId,
    required this.title,
    required this.description,
    required this.concurrentViewers,
    required this.thumbnailUrl,
    required this.actualStartTime,
    required this.videoTags,
    required this.releaseDate,
    this.createdAt,
    this.dynamicViewCount = '',
  });

  factory VideoItem.fromJson(Map<String, dynamic> json) {
    DateTime parsedReleaseDate;
    final String? actualStartTimeStr = json['actualStartTime'] as String?;
    if (actualStartTimeStr != null && actualStartTimeStr.isNotEmpty) {
      try {
        parsedReleaseDate = DateTime.parse(actualStartTimeStr);
      } catch (e) {
        print(
            "Error parsing actualStartTime '$actualStartTimeStr' for video ${json['videoId']}: $e");
        parsedReleaseDate = DateTime(2000, 1, 1);
      }
    } else {
      parsedReleaseDate = DateTime(2000, 1, 1);
    }

    Timestamp? createdAtTimestamp = json['createdAt'] as Timestamp?;
    DateTime? createdAtDateTime = createdAtTimestamp?.toDate();

    return VideoItem(
      videoId: json['videoId'] as String? ?? '',
      title: json['videoTitle'] as String? ?? 'No Title',
      description: json['videoDescription'] as String? ?? 'No Description',
      thumbnailUrl: json['videoThumbnailUrl'] as String? ?? '',
      actualStartTime: actualStartTimeStr ?? 'Not Available',
      videoTags: List<String>.from(json['videoTags'] as List? ?? []),
      concurrentViewers: json['concurrentViewers'] as int? ?? 0,
      releaseDate: parsedReleaseDate,
      createdAt: createdAtDateTime,
    );
  }
}

class LiveVideos extends StatelessWidget {
  const LiveVideos({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final liveVideosController = Get.put(LiveVideosController());

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: RefreshIndicator(
        onRefresh: () => liveVideosController.refreshVideos(),
        backgroundColor: const Color(0xFF1A1A2E),
        color: Colors.redAccent,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              backgroundColor: const Color(0xFF0A0A0A),
              floating: true,
              snap: true,
              elevation: 0,
              title: const Text(
                "Live Streams",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  onPressed: () => liveVideosController.refreshVideos(),
                  tooltip: "Refresh Videos",
                ),
              ],
            ),
            Obx(() {
              if (liveVideosController.isLoading.value) {
                return const SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          color: Colors.redAccent,
                          strokeWidth: 3,
                        ),
                        SizedBox(height: 16),
                        Text(
                          "Loading videos...",
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                );
              }

              if (liveVideosController.errorMessage.value.isNotEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Container(
                      margin: const EdgeInsets.all(24),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline,
                              color: Colors.redAccent, size: 48),
                          const SizedBox(height: 16),
                          Text(
                            liveVideosController.errorMessage.value,
                            style: const TextStyle(color: Colors.white),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () =>
                                liveVideosController.refreshVideos(),
                            icon: const Icon(Icons.refresh),
                            label: const Text("Retry"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              return SliverList(
                delegate: SliverChildListDelegate([
                  if (liveVideosController.liveVideos.isEmpty)
                    const EmptyState(
                      message: "Currently there are no ongoing live videos",
                      icon: Icons.live_tv,
                    )
                  else ...[
                    const SectionHeader(
                      title: "🔴 Currently Live",
                      subtitle: "Active streams right now",
                    ),
                    SizedBox(
                      height: 280,
                      child: LiveVideosList(isLive: true),
                    ),
                    const SizedBox(height: 24),
                  ],
                  const SectionHeader(
                    title: "Past Streams",
                    subtitle: "Previously recorded live content",
                  ),
                  if (liveVideosController.pastLiveVideos.isEmpty)
                    const EmptyState(
                      message: "No past live videos available",
                      icon: Icons.video_library_outlined,
                    )
                  else
                    LiveVideosList(isLive: false),
                ]),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const SectionHeader({
    Key? key,
    required this.title,
    required this.subtitle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final String message;
  final IconData icon;

  const EmptyState({
    Key? key,
    required this.message,
    required this.icon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: Colors.grey[600],
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class LiveVideosList extends StatelessWidget {
  final bool isLive;
  final liveVideosController = Get.find<LiveVideosController>();

  LiveVideosList({Key? key, required this.isLive}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final videosToShow = isLive
          ? liveVideosController.liveVideos
          : liveVideosController.pastLiveVideos;

      if (videosToShow.isEmpty) {
        return EmptyState(
          message: "No ${isLive ? 'live' : 'past live'} videos found",
          icon: isLive ? Icons.live_tv : Icons.video_library_outlined,
        );
      }

      if (isLive) {
        return ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: videosToShow.length,
          itemBuilder: (context, index) {
            final video = videosToShow[index];
            return _buildLiveVideoCard(context, video);
          },
        );
      } else {
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: videosToShow.length,
          itemBuilder: (context, index) {
            final video = videosToShow[index];
            return _buildPastVideoCard(context, video);
          },
        );
      }
    });
  }

  Widget _buildLiveVideoCard(BuildContext context, VideoItem video) {
    return GestureDetector(
      onTap: () {
        Get.to(() => VideoPlayerPage(video: video, isLive: true));
      },
      child: Container(
        width: 280,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1A1A2E),
              Color(0xFF16213E),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(16)),
                      image: DecorationImage(
                        image: NetworkImage(video.thumbnailUrl),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withOpacity(0.4),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'LIVE',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(16)),
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withOpacity(0.7),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      video.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Icon(Icons.remove_red_eye,
                            size: 14, color: Colors.grey[400]),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            video.dynamicViewCount,
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      video.formattedreleaseDate,
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPastVideoCard(BuildContext context, VideoItem video) {
    return GestureDetector(
      onTap: () {
        Get.to(() => VideoPlayerPage(video: video, isLive: false));
      },
      child: Container(
        height: 120,
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Color(0xFF1A1A2E),
              Color(0xFF16213E),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 160,
              height: 120,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
                image: DecorationImage(
                  image: NetworkImage(video.thumbnailUrl),
                  fit: BoxFit.cover,
                ),
              ),
              child: Stack(
                children: [
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        "Exclusive",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      video.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.visibility,
                                size: 14, color: Colors.grey[400]),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                video.dynamicViewCount,
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.calendar_today,
                                size: 14, color: Colors.grey[500]),
                            const SizedBox(width: 4),
                            Text(
                              video.formattedreleaseDate,
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Icon(
                Icons.arrow_forward_ios,
                color: Colors.grey[600],
                size: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:icons_plus/icons_plus.dart';
import 'dart:async';
import 'dart:ui';
import 'package:videos_alarm_app/screens/Vid_controller.dart';
import 'package:videos_alarm_app/screens/subscriptions.dart';
import 'package:videos_alarm_app/screens/video_thumb.dart';
import 'package:video_player/video_player.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

// Model to store ad information
class VideoAd {
  final Duration timestamp;
  final Duration duration;
  final String adUrl; // YouTube video ID
  bool played;

  VideoAd({
    required this.timestamp,
    required this.duration,
    required this.adUrl,
    this.played = false,
  });
}

// Separate Controller for ViewVideo screen to handle state and logic
class ViewVideoController extends GetxController with WidgetsBindingObserver {
  final String? videoLink;
  final String? videoTitle;
  final String? description;
  final String? category;
  final String? videoId;

  ViewVideoController({
    required this.videoLink,
    required this.videoTitle,
    required this.description,
    required this.category,
    required this.videoId,
  });

  Rx<ChewieController?> chewieController = Rx<ChewieController?>(null);
  Rx<VideoPlayerController?> videoPlayerController =
      Rx<VideoPlayerController?>(null);
  Rx<YoutubePlayerController?> adYoutubePlayerController =
      Rx<YoutubePlayerController?>(null);
  final VideoController videoController = Get.find<VideoController>();
  RxBool isVisible = false.obs;
  RxBool viewCountUpdated = false.obs;

  // Ad-related variables
  RxBool isAdPlaying = false.obs;
  Rx<VideoAd?> currentAd = Rx<VideoAd?>(null);
  Timer? adSchedulerTimer;
  List<VideoAd> sortedAds = [];
  int nextAdIndex = 0;
  Duration lastKnownPosition = Duration.zero;
  RxBool isResuming = false.obs; // ADD THIS LINE

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);

    if (videoLink == null ||
        videoTitle == null ||
        description == null ||
        videoId == null) {
      Get.snackbar('Error', 'Missing video data');
      return;
    }

    videoController.initializeVideo(videoTitle!, description!, videoLink!);
    videoController.fetchSameCategoryVideos(category ?? '');
    videoController.checkUserActiveStatus();

    _fetchVideoAds();
    _incrementViewCount();

    Future.delayed(const Duration(milliseconds: 100), () {
      isVisible.value = true;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.resumed:
        // Re-initialize video and ads when app is resumed
        _reinitializeVideoAndAds();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        // Pause video when app is inactive, paused, or detached
        chewieController.value?.pause();
        break;
      case AppLifecycleState.hidden:
        // TODO: Handle this case.
        break;
    }
  }

  Future<void> _reinitializeVideoAndAds() async {
    // Ensure the main video URL is valid before re-initializing
    if (videoLink != null && videoLink!.isNotEmpty) {
      await _initializeVideoPlayer(videoLink!); // Re-initialize main video
      sortedAds
          .forEach((ad) => ad.played = false); // Reset played status of ads
      nextAdIndex = 0; // Reset ad index
      _startAdScheduler(); // Restart ad scheduler
    }
  }

  Future<void> _fetchVideoAds() async {
    try {
      final adsSnapshot = await FirebaseFirestore.instance
          .collection('bunny')
          .doc(videoId)
          .collection('ads')
          .get();

      final ads = adsSnapshot.docs.map((doc) {
        final data = doc.data();
        final adUrl = data['videoUrl'] as String? ?? '';
        final videoId = YoutubePlayer.convertUrlToId(adUrl) ?? adUrl;

        return VideoAd(
          timestamp:
              Duration(seconds: (data['startTimestamp'] as num? ?? 0).toInt()),
          duration: Duration(
                  seconds: (data['endTimestamp'] as num? ?? 15).toInt()) -
              Duration(seconds: (data['startTimestamp'] as num? ?? 0).toInt()),
          adUrl: videoId,
        );
      }).toList();

      ads.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      sortedAds = ads;
      _initializeVideoPlayer(videoLink!);
    } catch (e) {
      print('Error fetching ads: $e');
      _initializeVideoPlayer(videoLink!);
    }
  }

  Future<void> _initializeVideoPlayer(String videoUrl) async {
    try {
      await videoPlayerController.value?.dispose();
      videoPlayerController.value =
          VideoPlayerController.networkUrl(Uri.parse(videoUrl));
      await videoPlayerController.value!.initialize();

      chewieController.value = ChewieController(
        videoPlayerController: videoPlayerController.value!,
        autoPlay: videoController.isUserActive.value && !isAdPlaying.value,
        looping: false,
        allowFullScreen: true,
        allowedScreenSleep: false,
        aspectRatio: videoPlayerController.value!.value.aspectRatio,
        errorBuilder: (context, errorMessage) => Center(
          child:
              Text(errorMessage, style: const TextStyle(color: Colors.white)),
        ),
      )..addListener(_videoListener);

      if (videoController.isUserActive.value && sortedAds.isNotEmpty) {
        _startAdScheduler();
      }
    } catch (e) {
      print('Error initializing video player: $e');
      Get.snackbar('Error', 'Failed to load video');
    }
    update(); // Trigger UI update
  }

  void _videoListener() {
    if (!videoController.isUserActive.value || isAdPlaying.value) return;

    final currentPosition = videoPlayerController.value!.value.position;
    final positionJump = (currentPosition - lastKnownPosition).abs() >
        const Duration(milliseconds: 500);

    if (positionJump && lastKnownPosition != Duration.zero) {
      _handleSeek(currentPosition);
    }
    lastKnownPosition = currentPosition;
  }

  void _handleSeek(Duration currentPosition) {
    adSchedulerTimer?.cancel();

    if (!videoController.isUserActive.value) return;

    nextAdIndex = sortedAds
        .indexWhere((ad) => !ad.played && ad.timestamp > currentPosition);
    if (nextAdIndex == -1) nextAdIndex = sortedAds.length;

    for (final ad in sortedAds) {
      final diffFromAd = currentPosition - ad.timestamp;
      if (!ad.played &&
          diffFromAd > Duration.zero &&
          diffFromAd < const Duration(seconds: 2)) {
        nextAdIndex = sortedAds.indexOf(ad) + 1;
        _playAd(ad);
        return;
      }
    }

    _startAdScheduler();
  }

  void _startAdScheduler() {
    adSchedulerTimer?.cancel();
    if (!videoController.isUserActive.value || nextAdIndex >= sortedAds.length)
      return;

    final nextAd = sortedAds[nextAdIndex];
    final currentPosition =
        videoPlayerController.value?.value.position ?? Duration.zero;
    final timeUntilAd = nextAd.timestamp - currentPosition;

    if (timeUntilAd <= Duration.zero) {
      if (currentPosition - nextAd.timestamp > const Duration(seconds: 2)) {
        nextAd.played = true;
        nextAdIndex++;
        _startAdScheduler();
      } else {
        _playAd(nextAd);
      }
      return;
    }

    adSchedulerTimer = Timer(timeUntilAd, () => _playAd(nextAd));
  }

  void _playAd(VideoAd ad) {
    if (!videoController.isUserActive.value || isAdPlaying.value) return;

    ad.played = true;
    lastKnownPosition =
        videoPlayerController.value?.value.position ?? Duration.zero;
    chewieController.value?.pause();

    adYoutubePlayerController.value = YoutubePlayerController(
      initialVideoId: ad.adUrl,
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
        loop: false,
        controlsVisibleAtStart: false,
        showLiveFullscreenButton: false,
        disableDragSeek: true,
      ),
    );

    // Add listener for ad playback
    void adListener() {
      if (adYoutubePlayerController.value == null) return;

      if (adYoutubePlayerController.value!.value.isReady) {
        final adPosition = adYoutubePlayerController.value!.value.position;
        final adDuration = ad.duration;

        // **Here is the modification:** Listen for the video to end.
        if (adYoutubePlayerController.value!.value.playerState ==
                PlayerState.ended ||
            adPosition >= adDuration) {
          if (!isResuming.value) {
            isResuming.value =
                true; // Prevent multiple calls during resume process

            adYoutubePlayerController.value!
                .removeListener(adListener); // Remove listener before resuming

            _resumeMainVideo();
          }
        }
      }
    }

    adYoutubePlayerController.value!.addListener(adListener);

    isAdPlaying.value = true;
    currentAd.value = ad;

    update(); // Trigger UI update
  }

  void _resumeMainVideo() async {
    if (adYoutubePlayerController.value == null) return;

    // Pause and dispose YouTube controller safely
    adYoutubePlayerController.value!.pause();

    // **Delay before disposing:** Added a small delay
    await Future.delayed(const Duration(
        milliseconds: 200)); //Small delay to ensure pause is executed.

    final tempController = adYoutubePlayerController.value;
    adYoutubePlayerController.value = null; // Clear reference before disposal
    tempController!.dispose();

    isAdPlaying.value = false;
    currentAd.value = null;

    // Resume Chewie video from the last known position
    chewieController.value?.seekTo(lastKnownPosition);

    await Future.delayed(const Duration(
        milliseconds: 100)); //Small delay to ensure seek is executed.

    chewieController.value?.play();
    nextAdIndex++;
    _startAdScheduler();

    isResuming.value = false; // Reset the flag
    update(); // Trigger UI update
  }

  Future<void> _incrementViewCount() async {
    if (viewCountUpdated.value) return;

    try {
      final videoDocRef =
          FirebaseFirestore.instance.collection('bunny').doc(videoId);
      await videoDocRef.update({'views': FieldValue.increment(1)});
      viewCountUpdated.value = true;
    } catch (e) {
      print('Error incrementing view count: $e');
    }
  }

  Future<void> refreshContent() async {
    sortedAds.forEach((ad) => ad.played = false);
    nextAdIndex = 0;
    isAdPlaying.value = false;
    adSchedulerTimer?.cancel();

    await _fetchVideoAds();
    videoController.fetchSameCategoryVideos(category ?? '');
    update(); // Trigger UI update
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    chewieController.value?.pause(); //Ensure video is paused before disposing
    chewieController.value?.removeListener(_videoListener);
    chewieController.value?.dispose();
    videoPlayerController.value?.dispose();
    adYoutubePlayerController.value
        ?.dispose(); // Safe disposal in case listener didn’t trigger
    adSchedulerTimer?.cancel();
    super.onClose();
  }
}

class ViewVideo extends StatelessWidget {
  final String? videoLink;
  final String? releaseYear;
  final String? cbfc;
  final String? director;
  final String? duration;
  final String? videoTitle;
  final String? description;
  final String? category;
  final String? videoId;
  final String? starcast;
  final bool? myList;

  const ViewVideo({
    super.key,
    this.videoLink,
    this.videoTitle,
    this.description,
    this.category,
    this.videoId,
    this.releaseYear,
    this.director,
    this.duration,
    this.cbfc,
    this.starcast,
    this.myList,
  });

  @override
  Widget build(BuildContext context) {
    // Initialize the controller using Get.put and pass in the parameters
    final ViewVideoController controller = Get.put(
      ViewVideoController(
        videoLink: videoLink,
        videoTitle: videoTitle,
        description: description,
        category: category,
        videoId: videoId,
      ),
    );

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.black,
        title: Obx(() => Text(
              controller.videoController.currentVideoTitle.value,
              style: const TextStyle(color: Colors.white, fontSize: 18),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            controller.chewieController.value?.pause();
            Navigator.pop(context);
            Get.delete<ViewVideoController>(); //THIS IS THE MOST IMPORTANT LINE
          },
        ),
      ),
      body: Obx(() {
        if (controller.videoController.isLoading.value) {
          return const Center(
              child: CircularProgressIndicator(color: Colors.white));
        }

        return RefreshIndicator(
          onRefresh: () => controller.refreshContent(),
          color: Colors.white,
          child: GetBuilder<ViewVideoController>(
            builder: (controller) {
              return Stack(
                children: [
                  SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          height: 240,
                          width: double.infinity,
                          child: controller.isAdPlaying.value &&
                                  controller.adYoutubePlayerController.value !=
                                      null
                              ? YoutubePlayer(
                                  controller: controller
                                      .adYoutubePlayerController.value!,
                                  showVideoProgressIndicator: true,
                                  progressIndicatorColor: Colors.red,
                                )
                              : (controller.chewieController.value != null
                                  ? Chewie(
                                      controller:
                                          controller.chewieController.value!)
                                  : const Center(
                                      child: CircularProgressIndicator(
                                          color: Colors.white))),
                        ),
                        if (controller.isAdPlaying.value) ...[
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.black87,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'Advertisement',
                                    style: TextStyle(
                                        color: Colors.white, fontSize: 14),
                                  ),
                                ),
                                StreamBuilder<Duration>(
                                  stream: Stream.periodic(
                                          const Duration(seconds: 1))
                                      .map((_) =>
                                          controller.adYoutubePlayerController
                                              .value?.value.position ??
                                          Duration.zero)
                                      .takeWhile((pos) =>
                                          pos <
                                          (controller
                                                  .currentAd.value?.duration ??
                                              Duration.zero)),
                                  builder: (context, snapshot) {
                                    final remaining =
                                        (controller.currentAd.value?.duration ??
                                                Duration.zero) -
                                            (snapshot.data ?? Duration.zero);
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.black87,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'Ad: ${remaining.inSeconds}s',
                                        style: const TextStyle(
                                            color: Colors.white, fontSize: 14),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            videoTitle ?? "No Title",
                            style: const TextStyle(
                              fontSize: 22,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Text(
                            description ?? "No Description",
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: StreamBuilder<DocumentSnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('bunny')
                                .doc(videoId)
                                .snapshots(),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) {
                                return const Text('Views: Loading...',
                                    style: TextStyle(color: Colors.white));
                              }
                              final views = snapshot.data!['views'] ?? 0;
                              return Text('Views: $views',
                                  style: const TextStyle(color: Colors.white));
                            },
                          ),
                        ),
                        const SizedBox(height: 20),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: const Text(
                            'More Like This',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 200,
                          child: Obx(() => ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: controller
                                    .videoController.sameCategoryVideos.length,
                                itemBuilder: (context, index) {
                                  final video = controller.videoController
                                      .sameCategoryVideos[index];
                                  return GestureDetector(
                                    onTap: () {
                                      controller.chewieController.value
                                          ?.pause();
                                      Get.off(
                                        () => ViewVideo(
                                          releaseYear: video['releaseYear'],
                                          starcast: video['starcast'],
                                          cbfc: video['cbfc'],
                                          myList: video['myList'],
                                          duration: video['duration'],
                                          director: video['director'],
                                          videoLink: video['videoUrl'],
                                          videoTitle: video['title'],
                                          description: video['description'],
                                          category: category,
                                          videoId: video['videoId'],
                                        ),
                                      );
                                    },
                                    child: Padding(
                                      padding:
                                          const EdgeInsets.only(right: 10.0),
                                      child: VideoThumbnail(video: video),
                                    ),
                                  );
                                },
                              )),
                        ),
                      ],
                    ),
                  ),
                  if (!controller.videoController.isUserActive.value)
                    Positioned.fill(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                        child: Center(
                          child: Container(
                            width: MediaQuery.of(context).size.width * 0.8,
                            constraints: const BoxConstraints(maxWidth: 400),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: Colors.black87,
                            ),
                            padding: const EdgeInsets.all(20),
                            child: AnimatedScale(
                              scale: controller.isVisible.value ? 1.0 : 0.0,
                              duration: const Duration(milliseconds: 100),
                              curve: Curves.easeOut,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(BoxIcons.bx_lock,
                                      size: 50, color: Colors.white),
                                  const SizedBox(height: 20),
                                  const Text(
                                    "A subscription is required\nto access this content.",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 20),
                                  ElevatedButton(
                                    onPressed: () =>
                                        Get.to(() => SubscriptionsScreen()),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blueAccent,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 30, vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: const Text("Activate Account",
                                        style: TextStyle(fontSize: 16)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
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
}

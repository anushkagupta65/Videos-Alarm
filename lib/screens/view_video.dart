import 'package:better_player_enhanced/better_player.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:ui';
import 'package:videos_alarm_app/screens/Vid_controller.dart';
import 'package:videos_alarm_app/screens/subscriptions.dart';
import 'package:videos_alarm_app/screens/video_thumb.dart';
import 'package:video_player/video_player.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:videos_alarm_app/screens/watch_later_button.dart';
import 'package:videos_alarm_app/services/dynamic_link_services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class VideoAd {
  final Duration timestamp;
  final Duration duration;
  final String adUrl;
  bool played;

  VideoAd({
    required this.timestamp,
    required this.duration,
    required this.adUrl,
    this.played = false,
  });
}

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
  RxBool viewCountUpdated = false.obs;

  RxBool isAdPlaying = false.obs;
  Rx<VideoAd?> currentAd = Rx<VideoAd?>(null);
  Timer? adSchedulerTimer;
  List<VideoAd> sortedAds = [];
  int nextAdIndex = 0;
  Duration lastKnownPosition = Duration.zero;
  RxBool isResuming = false.obs;

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
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.resumed:
        _reinitializeVideoAndAds();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        chewieController.value?.pause();
        break;
      case AppLifecycleState.hidden:
        break;
    }
  }

  Future<void> _reinitializeVideoAndAds() async {
    if (videoLink != null && videoLink!.isNotEmpty) {
      await _initializeVideoPlayer(videoLink!);
      sortedAds.forEach((ad) => ad.played = false);
      nextAdIndex = 0;
      _startAdScheduler();
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

  Future<void> addToWatchlist(String userId, String videoId) async {
    final userRef = FirebaseFirestore.instance.collection('users').doc(userId);

    await userRef.update({
      'watchlist': FieldValue.arrayUnion([videoId])
    });
  }

  Future<void> removeFromWatchlist(String userId, String videoId) async {
    final userRef = FirebaseFirestore.instance.collection('users').doc(userId);

    await userRef.update({
      'watchlist': FieldValue.arrayRemove([videoId])
    });
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
      // Get.snackbar('Error', 'Failed to load video');
    }
    update();
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

    void adListener() {
      if (adYoutubePlayerController.value == null) return;

      if (adYoutubePlayerController.value!.value.isReady) {
        final adPosition = adYoutubePlayerController.value!.value.position;
        final adDuration = ad.duration;

        if (adYoutubePlayerController.value!.value.playerState ==
                PlayerState.ended ||
            adPosition >= adDuration) {
          if (!isResuming.value) {
            isResuming.value = true;
            adYoutubePlayerController.value!.removeListener(adListener);
            _resumeMainVideo();
          }
        }
      }
    }

    adYoutubePlayerController.value!.addListener(adListener);

    isAdPlaying.value = true;
    currentAd.value = ad;

    update();
  }

  void _resumeMainVideo() async {
    if (adYoutubePlayerController.value == null) return;

    adYoutubePlayerController.value!.pause();

    await Future.delayed(const Duration(milliseconds: 200));

    final tempController = adYoutubePlayerController.value;
    adYoutubePlayerController.value = null;
    tempController!.dispose();

    isAdPlaying.value = false;
    currentAd.value = null;

    chewieController.value?.seekTo(lastKnownPosition);

    await Future.delayed(const Duration(milliseconds: 100));

    chewieController.value?.play();
    nextAdIndex++;
    _startAdScheduler();

    isResuming.value = false;
    update();
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
    update();
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    chewieController.value?.pause();
    chewieController.value?.removeListener(_videoListener);
    chewieController.value?.dispose();
    videoPlayerController.value?.dispose();
    adYoutubePlayerController.value?.dispose();
    adSchedulerTimer?.cancel();
    super.onClose();
  }
}

class SubscriptionAlert extends StatefulWidget {
  final VoidCallback onActivate;

  const SubscriptionAlert({Key? key, required this.onActivate})
      : super(key: key);

  @override
  _SubscriptionAlertState createState() => _SubscriptionAlertState();
}

class _SubscriptionAlertState extends State<SubscriptionAlert> {
  bool _isVisible = false;
  final GlobalKey _textKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_textKey.currentContext != null) {
        setState(() {
          _isVisible = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Center(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.8,
            constraints: const BoxConstraints(maxWidth: 400),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.grey[900]!.withOpacity(0.7),
            ),
            padding: const EdgeInsets.all(20),
            child: AnimatedScale(
              scale: _isVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 850),
              curve: Curves.easeOut,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    BoxIcons.bx_crown,
                    size: 72,
                    color: Colors.yellowAccent[700]!.withOpacity(0.9),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "A subscription is required\nto access this content.",
                    key: _textKey,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: widget.onActivate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent[400],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 30, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      "Activate Account",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                        wordSpacing: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
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

  // Helper method to parse Bunny Stream URL and extract pullZone and videoId
  Map<String, String>? _parseBunnyStreamUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final host = uri.host;
      final pathSegments = uri.pathSegments;

      // Handle iframe.mediadelivery.net format: https://iframe.mediadelivery.net/play/pullZone/videoId
      if (host == 'iframe.mediadelivery.net' && pathSegments.length >= 3) {
        if (pathSegments[0] == 'play') {
          final pullZone = 'vz-c8b15156-f2f';
          final videoId = pathSegments[2];
          return {
            'pullZone': pullZone,
            'videoId': videoId,
          };
        }
      }
      // Handle direct CDN format: https://pullzone.b-cdn.net/videoId/playlist.m3u8
      else if (host.contains('.b-cdn.net') && pathSegments.isNotEmpty) {
        final pullZone = host.split('.b-cdn.net')[0];
        final videoId = pathSegments[0];
        return {
          'pullZone': pullZone,
          'videoId': videoId,
        };
      }
    } catch (e) {
      print('Error parsing Bunny Stream URL: $e');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
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
        centerTitle: true,
        elevation: 3,
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
            Navigator.pop(context);
            Get.delete<ViewVideoController>();
          },
        ),
      ),
      body: Obx(() {
        if (controller.videoController.isLoading.value) {
          return const Center(
              child: CircularProgressIndicator(color: Colors.white));
        }

        final isSubscribed = controller.videoController.isUserActive.value;

        return RefreshIndicator(
          onRefresh: () => controller.refreshContent(),
          color: Colors.white,
          child: GetBuilder<ViewVideoController>(
            builder: (controller) {
              return Stack(
                children: [
                  if (isSubscribed)
                    SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            height: 240,
                            width: double.infinity,
                            child: Stack(
                              children: [
                                if (videoLink != null && videoLink!.isNotEmpty)
                                  Builder(
                                    builder: (context) {
                                      final parsedUrl =
                                          _parseBunnyStreamUrl(videoLink!);
                                      if (parsedUrl != null) {
                                        return BunnyStreamBetterPlayer(
                                          pullZone: parsedUrl['pullZone']!,
                                          videoId: parsedUrl['videoId']!,
                                        );
                                      } else {
                                        return const Center(
                                          child: Text(
                                            'Invalid Bunny Stream URL format',
                                            style:
                                                TextStyle(color: Colors.white),
                                          ),
                                        );
                                      }
                                    },
                                  )
                                else
                                  const Center(
                                    child: Text(
                                      'No video URL available',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                              ],
                            ),
                          ),

                          // Video Title
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            child: Text(
                              videoTitle ?? "No Title",
                              style: const TextStyle(
                                fontSize: 22,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),

                          // Video Details (Year, CBFC, Duration)
                          if (releaseYear != null ||
                              cbfc != null ||
                              duration != null) ...[
                            Padding(
                              padding:
                                  const EdgeInsets.only(left: 16, bottom: 12),
                              child: Row(
                                children: [
                                  if (releaseYear != null) ...[
                                    Text(
                                      releaseYear!,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.white70,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                  ],
                                  if (cbfc != null) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade800,
                                        border: Border.all(),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        cbfc!,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Colors.white70,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                  ],
                                  if (duration != null)
                                    Text(
                                      duration!,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.white70,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],

                          // Description
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              description ?? "No Description",
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Cast and Director
                          if (starcast != null || director != null) ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 6),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (starcast != null) ...[
                                    Text(
                                      "Cast: $starcast",
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.white70,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                  if (director != null) ...[
                                    Text(
                                      'Director: $director',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.white70,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),

                          // Views Counter
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: videoId == null
                                ? const Text(
                                    'Views: N/A',
                                    style: TextStyle(color: Colors.white),
                                  )
                                : StreamBuilder<DocumentSnapshot>(
                                    stream: FirebaseFirestore.instance
                                        .collection('bunny')
                                        .doc(videoId)
                                        .snapshots(),
                                    builder: (context, snapshot) {
                                      if (snapshot.connectionState ==
                                          ConnectionState.waiting) {
                                        return const Text(
                                          'Views: Loading...',
                                          style: TextStyle(color: Colors.white),
                                        );
                                      }

                                      if (snapshot.hasError) {
                                        return const Text(
                                          'Views: Error',
                                          style: TextStyle(color: Colors.white),
                                        );
                                      }

                                      final doc = snapshot.data;

                                      if (doc == null || !doc.exists) {
                                        return const Text(
                                          'Views: N/A',
                                          style: TextStyle(color: Colors.white),
                                        );
                                      }

                                      final views = (doc.data() as Map<String,
                                              dynamic>)['views'] ??
                                          0;

                                      return Text(
                                        'Views: $views',
                                        style: const TextStyle(
                                            color: Colors.white70),
                                      );
                                    },
                                  ),
                          ),
                          const SizedBox(height: 20),

                          // Share Button
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                WatchLaterButton(videoId: videoId!),
                                const SizedBox(width: 12),
                                Column(
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.share,
                                        color: Colors.white,
                                        size: 32,
                                      ),
                                      onPressed: () async {
                                        try {
                                          print('Starting video share process');
                                          final videoID = videoId ?? '';
                                          print(
                                              'Fetching video document for ID: $videoID');
                                          final videoDoc =
                                              await FirebaseFirestore.instance
                                                  .collection('bunny')
                                                  .doc(videoID)
                                                  .get();

                                          final thumbnailURL =
                                              videoDoc.data()?['thumbnailUrl']
                                                      as String? ??
                                                  '';
                                          print(
                                              'Retrieved thumbnail URL: $thumbnailURL');

                                          final dynamicLinkService =
                                              DynamicLinkService();
                                          print(
                                              'Creating dynamic link with parameters: '
                                              'videoId=$videoID, '
                                              'videoTitle=${videoTitle ?? 'Videos Alarm'}, '
                                              'videoDescription=${description ?? 'Check out this amazing video on Videos Alarm!'}, '
                                              'thumbnailUrl=$thumbnailURL');
                                          final deepLink =
                                              await dynamicLinkService
                                                  .createShareVideoLink(
                                            videoId: videoID,
                                          );

                                          print(
                                              "Dynamic Link created: $deepLink");

                                          if (deepLink.isNotEmpty) {
                                            print('Sharing dynamic link');
                                            Share.share(
                                              'Tap on the below link to watch a video\n\n'
                                              '$deepLink\n'
                                              '\n'
                                              'Sent by VideosAlarm.',
                                              subject: 'Check out this video!',
                                            );
                                            print('Share action completed');
                                          }
                                        } catch (e) {
                                          print(
                                              "Error creating/sharing dynamic link: $e");
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                  'Failed to share video: $e'),
                                            ),
                                          );
                                        }
                                      },
                                    ),
                                    const SizedBox(height: 12),
                                    const Text(
                                      "Share",
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                )
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // More Like This Section
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
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
                                  itemCount: controller.videoController
                                      .sameCategoryVideos.length,
                                  itemBuilder: (context, index) {
                                    final newvideo = controller.videoController
                                        .sameCategoryVideos[index];
                                    return GestureDetector(
                                      onTap: () async {
                                        print("this is pressed");
                                        print(
                                            "these are the details - \n releaseYear: ${newvideo['releaseYear']} \n starcast: ${newvideo['starcast']} \n videoId: ${newvideo['videoId']} \n cbfc: ${newvideo['cbfc']} \n duration: ${newvideo['duration']} \n videoLink: ${newvideo['videoUrl']} \n videoTitle: ${newvideo['title']} \n description: ${newvideo['description']}");

                                        // Get the thumbnail (adjust this if your schema is different)
                                        String? thumbnailUrl =
                                            newvideo['thumbnailUrl'];

                                        bool? result = await showDialog<bool>(
                                          context: context,
                                          barrierDismissible: true,
                                          builder: (context) =>
                                              VideoPreviewDialog(
                                            title: newvideo['title'],
                                            description:
                                                newvideo['description'],
                                            thumbnailUrl: thumbnailUrl,
                                            duration: newvideo['duration'],
                                            releaseYear:
                                                newvideo['releaseYear'],
                                            cbfc: newvideo['cbfc'],
                                            starcast: newvideo['starcast'],
                                          ),
                                        );

                                        if (result == true) {
                                          Navigator.of(context).pushReplacement(
                                            MaterialPageRoute(
                                              builder: (_) => ViewVideo(
                                                releaseYear:
                                                    newvideo['releaseYear'],
                                                starcast: newvideo['starcast'],
                                                cbfc: newvideo['cbfc'],
                                                myList: newvideo['myList'],
                                                duration: newvideo['duration'],
                                                director: newvideo['director'],
                                                videoLink: newvideo['videoUrl'],
                                                videoTitle: newvideo['title'],
                                                description:
                                                    newvideo['description'],
                                                category: category,
                                                videoId: newvideo['videoId'],
                                              ),
                                            ),
                                          );
                                        }
                                      },
                                      child: Padding(
                                        padding:
                                            const EdgeInsets.only(right: 10),
                                        child: VideoThumbnail(video: newvideo),
                                      ),
                                    );
                                  },
                                )),
                          ),
                        ],
                      ),
                    ),
                  if (!isSubscribed)
                    SubscriptionAlert(
                      onActivate: () => Get.to(() => SubscriptionsScreen()),
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

class BunnyStreamBetterPlayer extends StatefulWidget {
  final String pullZone;
  final String videoId;

  const BunnyStreamBetterPlayer({
    super.key,
    required this.pullZone,
    required this.videoId,
  });

  @override
  State<BunnyStreamBetterPlayer> createState() =>
      _BunnyStreamBetterPlayerState();
}

class _BunnyStreamBetterPlayerState extends State<BunnyStreamBetterPlayer> {
  BetterPlayerController? _betterPlayerController;
  SharedPreferences? _prefs;
  bool _hasResumed = false;
  bool _isDisposed = false;

  String get _videoKey => "video_position_${widget.videoId}";

  @override
  void initState() {
    super.initState();
    _initAsync();
  }

  Future<void> _initAsync() async {
    try {
      _prefs = await SharedPreferences.getInstance();

      final videoUrl =
          "https://${widget.pullZone}.b-cdn.net/${widget.videoId}/playlist.m3u8";

      final betterPlayerDataSource = BetterPlayerDataSource(
        BetterPlayerDataSourceType.network,
        videoUrl,
        asmsTrackNames: ["Low", "Medium", "High"],
      );

      final controller = BetterPlayerController(
        BetterPlayerConfiguration(
          autoPlay: true,
          allowedScreenSleep: false,
          aspectRatio: 16 / 9,
          fullScreenAspectRatio: 3 / 2,
          autoDetectFullscreenAspectRatio: true,
          handleLifecycle: true,
          controlsConfiguration: const BetterPlayerControlsConfiguration(
            enableQualities: true,
            enablePlaybackSpeed: true,
            enableMute: true,
            enableFullscreen: true,
            enableProgressBarDrag: true,
          ),
          eventListener: (event) async {
            if (event.betterPlayerEventType == BetterPlayerEventType.play) {
              WakelockPlus.enable();

              if (!_hasResumed) {
                _hasResumed = true;
                final lastPosition = _prefs?.getInt(_videoKey) ?? 0;
                if (lastPosition > 0) {
                  _betterPlayerController!
                      .seekTo(Duration(seconds: lastPosition));
                }
              }
            }

            if (event.betterPlayerEventType == BetterPlayerEventType.pause ||
                event.betterPlayerEventType == BetterPlayerEventType.finished) {
              WakelockPlus.disable();
              await _saveCurrentPosition("eventListener");
            }
          },
        ),
        betterPlayerDataSource: betterPlayerDataSource,
      );

      if (!_isDisposed) {
        setState(() {
          _betterPlayerController = controller;
        });
      }
    } catch (e, st) {
      print(
          "[BunnyStreamBetterPlayer] Error initializing BetterPlayer: $e\n$st");
    }
  }

  Future<void> _saveCurrentPosition([String from = "unknown"]) async {
    if (_betterPlayerController == null || _prefs == null) {
      return;
    }
    final position =
        await _betterPlayerController!.videoPlayerController?.position;
    if (position != null) {
      int saveSeconds = position.inSeconds - 15;
      if (saveSeconds < 0) saveSeconds = 0;
      await _prefs!.setInt(_videoKey, saveSeconds);
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _saveCurrentPosition("dispose").then((_) {
      _betterPlayerController?.dispose();
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_betterPlayerController == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return BetterPlayer(controller: _betterPlayerController!);
  }
}

class VideoPreviewDialog extends StatelessWidget {
  final String? title;
  final String? description;
  final String? thumbnailUrl;
  final String? duration;
  final String? releaseYear;
  final String? cbfc;
  final String? starcast;

  const VideoPreviewDialog({
    Key? key,
    this.title,
    this.description,
    this.thumbnailUrl,
    this.duration,
    this.releaseYear,
    this.cbfc,
    this.starcast,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[900]?.withOpacity(0.95),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.45),
              blurRadius: 32,
              spreadRadius: 1,
              offset: const Offset(0, 18),
            ),
            BoxShadow(
              color: Colors.deepPurpleAccent.withOpacity(0.09),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: thumbnailUrl != null && thumbnailUrl!.isNotEmpty
                      ? Image.network(
                          thumbnailUrl!,
                          width: double.infinity,
                          height: 170,
                          fit: BoxFit.fill,
                          errorBuilder: (ctx, err, stack) => Container(
                            color: Colors.grey[800],
                            height: 170,
                            child: const Center(
                              child: Icon(Icons.broken_image,
                                  color: Colors.white38, size: 46),
                            ),
                          ),
                        )
                      : Container(
                          width: double.infinity,
                          height: 170,
                          color: Colors.grey[800],
                          child: const Center(
                            child: Icon(Icons.broken_image,
                                color: Colors.white38, size: 46),
                          ),
                        ),
                ),
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.12),
                          Colors.black.withOpacity(0.32),
                          Colors.deepPurpleAccent.withOpacity(0.08),
                        ],
                        stops: const [0.0, 0.6, 1.0],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    title ?? "Untitled",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 22,
                      letterSpacing: 0.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (releaseYear != null && releaseYear!.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Chip(
                    label: Text(
                      releaseYear!,
                      style: const TextStyle(fontSize: 12, color: Colors.white),
                    ),
                    backgroundColor: Colors.deepPurple.withOpacity(0.6),
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                if (cbfc != null && cbfc!.isNotEmpty) ...[
                  _InfoPill(label: cbfc!),
                  const SizedBox(width: 8),
                ],
                if (duration != null && duration!.isNotEmpty)
                  _InfoPill(label: duration!),
              ],
            ),
            const SizedBox(height: 12),
            AnimatedOpacity(
              opacity: 1,
              duration: const Duration(milliseconds: 350),
              child: Container(
                alignment: Alignment.centerLeft,
                child: Text(
                  description ?? "",
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
                    height: 1.35,
                  ),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            if (starcast != null && starcast!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Cast: ",
                    style: TextStyle(
                      color: Colors.deepPurpleAccent,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      starcast!,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white30, width: 1.1),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9),
                      ),
                      backgroundColor: Colors.black.withOpacity(0.1),
                      shadowColor: Colors.deepPurple.withOpacity(0.12),
                      elevation: 0,
                    ),
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text("Cancel"),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurpleAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9),
                      ),
                      shadowColor: Colors.deepPurpleAccent.withOpacity(0.3),
                      elevation: 3,
                    ),
                    icon: const Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                    ),
                    label:
                        title == "Streaming Soon" ? Text("Soon") : Text("Play"),
                    onPressed: () => Navigator.of(context).pop(true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final String label;

  const _InfoPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.deepPurpleAccent.withOpacity(0.20),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white70,
          fontWeight: FontWeight.w500,
          fontSize: 12,
        ),
      ),
    );
  }
}

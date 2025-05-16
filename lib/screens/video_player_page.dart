import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:videos_alarm_app/screens/Vid_controller.dart';
import 'package:videos_alarm_app/screens/home.dart';
import 'package:videos_alarm_app/screens/live_videos.dart';
import 'package:videos_alarm_app/screens/subscriptions.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class VideoPlayerPage extends StatefulWidget {
  final VideoItem video;

  const VideoPlayerPage({Key? key, required this.video}) : super(key: key);

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  late YoutubePlayerController _controller;
  bool _isPlayerReady = false;
  bool _showFullDescription = false;
  final VideoController videoController = Get.put(VideoController());
  bool _isVisible = false;
  bool _isFullScreen = false;

  @override
  void initState() {
    super.initState();
    String? videoId = widget.video.videoId;
    _controller = YoutubePlayerController(
      initialVideoId: videoId ?? '',
      flags: const YoutubePlayerFlags(
        mute: false,
        autoPlay: false,
        disableDragSeek: false,
        loop: false,
        isLive: true,
        forceHD: false,
        enableCaption: true,
      ),
    )..addListener(_onPlayerStateChange);
    
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        setState(() {
          _isVisible = true;
        });
      }
    });
  }

  void _onPlayerStateChange() {
    if (_isPlayerReady && mounted) {
      if (_controller.value.isFullScreen != _isFullScreen) {
        setState(() {
          _isFullScreen = _controller.value.isFullScreen;
        });
        
        if (_isFullScreen) {
          SystemChrome.setPreferredOrientations([
            DeviceOrientation.landscapeLeft,
            DeviceOrientation.landscapeRight,
          ]);
        } else {
          SystemChrome.setPreferredOrientations([
            DeviceOrientation.portraitUp,
          ]);
        }
      }
    }
  }

  void _stopVideo() {
    try {
      _controller.pause();
      _controller.seekTo(Duration.zero); // Reset to start
      _controller.dispose(); // Explicitly stop the video
    } catch (e) {
      debugPrint('Error stopping video: $e');
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onPlayerStateChange);
    _stopVideo(); // Stop video before disposing
    _controller.dispose();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_isFullScreen) {
          _controller.toggleFullScreenMode();
          return false;
        }
        _stopVideo(); // Stop video before navigation
        Navigator.of(context).pop(); // Explicitly handle navigation
        return false; // Return false since we're handling navigation manually
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF121212),
        appBar: _isFullScreen 
          ? null 
          : AppBar(
              foregroundColor: Colors.white,
              backgroundColor: Colors.transparent,
              elevation: 0,
              systemOverlayStyle: SystemUiOverlayStyle.light,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  _stopVideo(); // Stop video when back button is pressed
                  Navigator.of(context).pop();
                },
              ),
              title: Text(
                'VideosAlarm live',
                style: GoogleFonts.montserrat(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 18,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              centerTitle: true,
            ),
        body: Stack(
          children: [
            SingleChildScrollView(
              physics: _isFullScreen ? const NeverScrollableScrollPhysics() : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  YoutubePlayerBuilder(
                    onExitFullScreen: () {
                      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
                      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
                    },
                    onEnterFullScreen: () {
                      SystemChrome.setPreferredOrientations([
                        DeviceOrientation.landscapeLeft,
                        DeviceOrientation.landscapeRight,
                      ]);
                      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
                    },
                    player: YoutubePlayer(
                      controller: _controller,
                      showVideoProgressIndicator: true,
                      progressIndicatorColor: Colors.blueAccent,
                      onReady: () {
                        _isPlayerReady = true;
                        if (mounted) setState(() {});
                      },
                      onEnded: (metadata) {
                        _stopVideo(); // Stop when video ends
                      },
                      progressColors: const ProgressBarColors(
                        playedColor: Colors.blueAccent,
                        handleColor: Colors.blueAccent,
                      ),
                      topActions: [
                        const SizedBox(width: 8.0),
                        Expanded(
                          child: Text(
                            _controller.metadata.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18.0,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                    builder: (context, player) {
                      return Column(
                        children: [
                          player,
                          if (!_isFullScreen) ...[
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.video.title,
                                    style: GoogleFonts.openSans(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(Icons.remove_red_eye, color: Colors.grey[600], size: 16),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${widget.video.concurrentViewers} views',
                                        style: GoogleFonts.roboto(color: Colors.grey[600], fontSize: 12),
                                      ),
                                      const SizedBox(width: 12),
                                      Icon(Icons.calendar_today, color: Colors.grey[600], size: 16),
                                      const SizedBox(width: 4),
                                      Text(
                                        widget.video.formattedCreatedAt,
                                        style: GoogleFonts.roboto(color: Colors.grey[600], fontSize: 12),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 8.0,
                                    runSpacing: 4.0,
                                    children: widget.video.videoTags.map((tag) {
                                      return Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.grey[800],
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        child: Text(
                                          tag,
                                          style: GoogleFonts.roboto(color: Colors.grey[400], fontSize: 12),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Description',
                                    style: GoogleFonts.montserrat(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  AnimatedSize(
                                    duration: const Duration(milliseconds: 200),
                                    child: ConstrainedBox(
                                      constraints: _showFullDescription
                                          ? const BoxConstraints()
                                          : const BoxConstraints(maxHeight: 120),
                                      child: Text(
                                        widget.video.description,
                                        style: GoogleFonts.openSans(
                                          color: Colors.grey[400],
                                          fontSize: 14,
                                          height: 1.5,
                                        ),
                                        softWrap: true,
                                        overflow: TextOverflow.fade,
                                      ),
                                    ),
                                  ),
                                  if (widget.video.description.length > 100)
                                    TextButton(
                                      onPressed: () {
                                        if (mounted) {
                                          setState(() {
                                            _showFullDescription = !_showFullDescription;
                                          });
                                        }
                                      },
                                      child: Text(
                                        _showFullDescription ? 'Show Less' : 'Show More',
                                        style: const TextStyle(color: Colors.blue),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
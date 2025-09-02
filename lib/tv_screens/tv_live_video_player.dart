import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:videos_alarm_app/screens/live_videos.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:videos_alarm_app/screens/Vid_controller.dart';

class TVLiveVideoPlayer extends StatefulWidget {
  final VideoItem video;

  const TVLiveVideoPlayer({Key? key, required this.video}) : super(key: key);

  @override
  State<TVLiveVideoPlayer> createState() => _TVLiveVideoPlayerState();
}

class _TVLiveVideoPlayerState extends State<TVLiveVideoPlayer> {
  late YoutubePlayerController _controller;
  bool _isPlayerReady = false;
  final VideoController videoController = Get.find<VideoController>();

  late FocusNode _playerFocusNode;
  late FocusNode _backButtonFocusNode;
  late FocusNode _descriptionButtonFocusNode;

  @override
  void initState() {
    super.initState();
    String? videoId = widget.video.videoId;
    _controller = YoutubePlayerController(
      initialVideoId: videoId,
      flags: const YoutubePlayerFlags(
        mute: false,
        autoPlay: true,
        disableDragSeek: false,
        loop: false,
        isLive: true,
        forceHD: true,
        enableCaption: true,
      ),
    )..addListener(_onPlayerStateChange);

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    _playerFocusNode = FocusNode();
    _backButtonFocusNode = FocusNode();
    _descriptionButtonFocusNode = FocusNode();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _playerFocusNode.requestFocus();
    });
  }

  void _onPlayerStateChange() {
    if (_isPlayerReady && mounted) {
      setState(() {});
    }
  }

  void _stopVideoAndExit() {
    try {
      _controller.pause();
      _controller.seekTo(Duration.zero);
    } catch (e) {
      debugPrint('Error stopping video: $e');
    }
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _controller.removeListener(_onPlayerStateChange);
    _controller.dispose();

    _playerFocusNode.dispose();
    _backButtonFocusNode.dispose();
    _descriptionButtonFocusNode.dispose();

    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  void _handleKeyEvent(RawKeyEvent event) {
    if (event is! RawKeyDownEvent) return;

    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.arrowRight && _playerFocusNode.hasFocus) {
      _backButtonFocusNode.requestFocus();
    } else if (key == LogicalKeyboardKey.arrowLeft &&
        (_backButtonFocusNode.hasFocus ||
            _descriptionButtonFocusNode.hasFocus)) {
      _playerFocusNode.requestFocus();
    } else if (key == LogicalKeyboardKey.arrowDown &&
        _backButtonFocusNode.hasFocus) {
      if (widget.video.description.length > 100) {
        _descriptionButtonFocusNode.requestFocus();
      }
    } else if (key == LogicalKeyboardKey.arrowUp &&
        _descriptionButtonFocusNode.hasFocus) {
      _backButtonFocusNode.requestFocus();
    } else if ((key == LogicalKeyboardKey.select ||
            key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.gameButtonA) &&
        _playerFocusNode.hasFocus) {
      _controller.value.isPlaying ? _controller.pause() : _controller.play();
    } else if ((key == LogicalKeyboardKey.select ||
            key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.gameButtonA) &&
        _backButtonFocusNode.hasFocus) {
      _stopVideoAndExit();
    } else if (key == LogicalKeyboardKey.backspace ||
        key == LogicalKeyboardKey.escape) {
      _stopVideoAndExit();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: RawKeyboardListener(
        focusNode: FocusNode(),
        autofocus: true,
        onKey: _handleKeyEvent,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.max,
          children: [
            Expanded(
              flex: 23,
              child: _buildPlayerPanel(),
            ),
            Expanded(
              flex: 7,
              child: _buildDetailsPanel(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerPanel() {
    return Focus(
      focusNode: _playerFocusNode,
      onFocusChange: (hasFocus) => setState(() {}),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          border: Border.all(
            color: _playerFocusNode.hasFocus
                ? Colors.blue.shade700
                : Colors.transparent,
            width: 4.0,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: YoutubePlayer(
            controller: _controller,
            showVideoProgressIndicator: true,
            progressIndicatorColor: Colors.red,
            onReady: () {
              _isPlayerReady = true;
              if (mounted) setState(() {});
            },
            onEnded: (metadata) {
              _stopVideoAndExit();
            },
            progressColors: const ProgressBarColors(
              playedColor: Colors.red,
              handleColor: Colors.red,
              bufferedColor: Colors.grey,
              backgroundColor: Colors.white24,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailsPanel() {
    return Container(
      color: const Color(0xFF181818),
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Focus(
              focusNode: _backButtonFocusNode,
              onFocusChange: (hasFocus) => setState(() {}),
              child: ElevatedButton.icon(
                onPressed: _stopVideoAndExit,
                icon: const Icon(
                  Icons.arrow_back,
                  size: 16,
                  color: Colors.white,
                ),
                label: const Text('Back'),
                style: _tvButtonStyle(_backButtonFocusNode.hasFocus),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              widget.video.title,
              style: GoogleFonts.roboto(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Icon(Icons.remove_red_eye, color: Colors.grey[400], size: 14),
                const SizedBox(width: 4),
                Text(
                  '${widget.video.concurrentViewers} views',
                  style:
                      GoogleFonts.roboto(color: Colors.grey[400], fontSize: 12),
                ),
                const SizedBox(width: 16),
                Icon(Icons.calendar_today, color: Colors.grey[400], size: 14),
                const SizedBox(width: 4),
                Text(
                  widget.video.formattedreleaseDate,
                  style:
                      GoogleFonts.roboto(color: Colors.grey[400], fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Description',
              style: GoogleFonts.roboto(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.video.description,
              style: GoogleFonts.roboto(
                color: Colors.grey[300],
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  ButtonStyle _tvButtonStyle(bool hasFocus) {
    return ElevatedButton.styleFrom(
      backgroundColor:
          hasFocus ? Colors.redAccent.shade700 : const Color(0xFF333333),
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
      textStyle: GoogleFonts.roboto(
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: hasFocus
            ? const BorderSide(color: Colors.white, width: 1.5)
            : BorderSide.none,
      ),
      elevation: hasFocus ? 6 : 2,
    );
  }
}

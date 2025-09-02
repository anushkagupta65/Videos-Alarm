import 'package:better_player_enhanced/better_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:videos_alarm_app/screens/video_thumb.dart';
import 'package:videos_alarm_app/screens/view_video.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class TVVideoPlayer extends StatefulWidget {
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

  const TVVideoPlayer({
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
  State<TVVideoPlayer> createState() => _TVVideoPlayerState();
}

class _TVVideoPlayerState extends State<TVVideoPlayer> {
  late final ViewVideoController controller;
  BetterPlayerController? _betterPlayerController;

  bool _isPanelVisible = false;

  // --- Focus Nodes for D-Pad Navigation ---
  final FocusNode _playerFocus = FocusNode();
  final FocusNode _moreLikeThisFocus = FocusNode();

  int _moreLikeThisIndex = 0;
  final ScrollController _moreLikeThisScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    controller = Get.put(
      ViewVideoController(
        videoLink: widget.videoLink,
        videoTitle: widget.videoTitle,
        description: widget.description,
        category: widget.category,
        videoId: widget.videoId,
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Default focus to the player.
      _playerFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    _playerFocus.dispose();
    _moreLikeThisFocus.dispose();
    _moreLikeThisScrollController.dispose();
    _betterPlayerController?.dispose(forceDispose: true);
    Get.delete<ViewVideoController>();
    super.dispose();
  }

  // --- DATA & ACTIONS ---

  void _onPlayerCreated(BetterPlayerController playerController) {
    if (mounted) {
      setState(() => _betterPlayerController = playerController);
      _playerFocus.requestFocus();
    }
  }

  // --- UI STATE & D-PAD LOGIC ---

  void _showPanel() {
    if (!_isPanelVisible) {
      setState(() => _isPanelVisible = true);
      // If there are items to focus, move focus to the list.
      if (controller.videoController.sameCategoryVideos.isNotEmpty) {
        _moreLikeThisFocus.requestFocus();
      }
    }
  }

  void _hidePanel() {
    if (_isPanelVisible) {
      setState(() => _isPanelVisible = false);
      _playerFocus.requestFocus();
    }
  }

  void _scrollToMoreLikeThisItem() {
    final itemWidth = 290.0; // Width (280) + Margin (10)
    final offset = _moreLikeThisIndex * itemWidth;
    _moreLikeThisScrollController.animateTo(
      offset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _onMoreLikeThisTapped(Map<String, dynamic> newvideo) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => TVVideoPlayer(
          releaseYear: newvideo['releaseYear'],
          starcast: newvideo['starcast'],
          cbfc: newvideo['cbfc'],
          myList: newvideo['myList'],
          duration: newvideo['duration'],
          director: newvideo['director'],
          videoLink: newvideo['videoUrl'],
          videoTitle: newvideo['title'],
          description: newvideo['description'],
          category: widget.category,
          videoId: newvideo['videoId'],
        ),
      ),
    );
  }

  Map<String, String>? _parseBunnyStreamUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final host = uri.host;
      final pathSegments = uri.pathSegments;

      if (host == 'iframe.mediadelivery.net' && pathSegments.length >= 3) {
        if (pathSegments[0] == 'play') {
          return {'pullZone': 'vz-c8b15156-f2f', 'videoId': pathSegments[2]};
        }
      } else if (host.contains('.b-cdn.net') && pathSegments.isNotEmpty) {
        return {
          'pullZone': host.split('.b-cdn.net')[0],
          'videoId': pathSegments[0]
        };
      }
    } catch (e) {
      debugPrint('Error parsing Bunny Stream URL: $e');
    }
    return null;
  }

  // --- WIDGET BUILD ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          _buildPlayerPanel(),
          _buildDetailsPanel(),
        ],
      ),
    );
  }

  Widget _buildPlayerPanel() {
    return Focus(
      focusNode: _playerFocus,
      onKey: (node, event) {
        if (event is! RawKeyDownEvent) return KeyEventResult.ignored;
        final key = event.logicalKey;

        if (_betterPlayerController != null) {
          if (key != LogicalKeyboardKey.arrowDown) {
            _betterPlayerController!.setControlsVisibility(true);
          }

          if (key == LogicalKeyboardKey.arrowDown) {
            _showPanel();
            return KeyEventResult.handled;
          } else if (key == LogicalKeyboardKey.select ||
              key == LogicalKeyboardKey.enter) {
            if (_betterPlayerController!.isPlaying() ?? false) {
              _betterPlayerController!.pause();
            } else {
              _betterPlayerController!.play();
            }
            return KeyEventResult.handled;
          } else if (key == LogicalKeyboardKey.arrowRight) {
            final currentPosition =
                _betterPlayerController!.videoPlayerController?.value.position;
            if (currentPosition != null) {
              _betterPlayerController!
                  .seekTo(currentPosition + const Duration(seconds: 10));
            }
            return KeyEventResult.handled;
          } else if (key == LogicalKeyboardKey.arrowLeft) {
            final currentPosition =
                _betterPlayerController!.videoPlayerController?.value.position;
            if (currentPosition != null) {
              final newPosition = currentPosition - const Duration(seconds: 10);
              _betterPlayerController!
                  .seekTo(newPosition.isNegative ? Duration.zero : newPosition);
            }
            return KeyEventResult.handled;
          }
        }

        if (key == LogicalKeyboardKey.backspace ||
            key == LogicalKeyboardKey.escape) {
          Navigator.pop(context);
          return KeyEventResult.handled;
        }

        return KeyEventResult.ignored;
      },
      child: (widget.videoLink != null && widget.videoLink!.isNotEmpty)
          ? Builder(builder: (context) {
              final parsedUrl = _parseBunnyStreamUrl(widget.videoLink!);
              if (parsedUrl != null) {
                return BunnyStreamBetterPlayer(
                  key: ValueKey(widget.videoId),
                  pullZone: parsedUrl['pullZone']!,
                  videoId: parsedUrl['videoId']!,
                  onPlayerCreated: _onPlayerCreated,
                );
              }
              return const Center(
                  child: Text('Invalid Video URL',
                      style: TextStyle(color: Colors.white)));
            })
          : const Center(
              child:
                  Text('No Video URL', style: TextStyle(color: Colors.white))),
    );
  }

  Widget _buildDetailsPanel() {
    return AnimatedSlide(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      offset: _isPanelVisible ? Offset.zero : const Offset(0, 1),
      child: Container(
        padding: const EdgeInsets.fromLTRB(48, 24, 48, 32),
        color: Colors.black.withOpacity(0.85),
        child: Obx(() {
          if (controller.videoController.isLoading.value) {
            return const Center(
                child: CircularProgressIndicator(color: Colors.white));
          }
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildVideoInfo(), // The buttons row is removed
              const SizedBox(height: 24),
              const Text('More Like This',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              const SizedBox(height: 12),
              _buildMoreLikeThisSection(),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildVideoInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.videoTitle ?? "No Title",
          style: const TextStyle(
              fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 16),
        _buildVideoMetadata(),
        const SizedBox(height: 12),
        Text(
          widget.description ?? "No description available.",
          style: TextStyle(fontSize: 14, color: Colors.grey[300], height: 1.5),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildVideoMetadata() {
    return Row(
      children: [
        if (widget.releaseYear != null) ...[
          Text(widget.releaseYear!,
              style: const TextStyle(fontSize: 14, color: Colors.white70)),
          const SizedBox(width: 16),
        ],
        if (widget.cbfc != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(4)),
            child: Text(widget.cbfc!,
                style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ),
          const SizedBox(width: 16),
        ],
        if (widget.duration != null)
          Text(widget.duration!,
              style: const TextStyle(fontSize: 14, color: Colors.white70)),
      ],
    );
  }

  Widget _buildMoreLikeThisSection() {
    return Focus(
      focusNode: _moreLikeThisFocus,
      onKey: (node, event) {
        if (event is! RawKeyDownEvent) return KeyEventResult.ignored;
        final key = event.logicalKey;
        final videos = controller.videoController.sameCategoryVideos;
        final maxIndex = videos.length - 1;

        if (key == LogicalKeyboardKey.arrowUp) {
          _hidePanel(); // Pressing UP now hides the panel
          return KeyEventResult.handled;
        } else if (key == LogicalKeyboardKey.arrowRight) {
          if (_moreLikeThisIndex < maxIndex) {
            setState(() {
              _moreLikeThisIndex++;
              _scrollToMoreLikeThisItem();
            });
          }
          return KeyEventResult.handled;
        } else if (key == LogicalKeyboardKey.arrowLeft) {
          if (_moreLikeThisIndex > 0) {
            setState(() {
              _moreLikeThisIndex--;
              _scrollToMoreLikeThisItem();
            });
          }
          return KeyEventResult.handled;
        } else if (key == LogicalKeyboardKey.select ||
            key == LogicalKeyboardKey.enter) {
          if (videos.isNotEmpty && _moreLikeThisIndex < videos.length) {
            _onMoreLikeThisTapped(videos[_moreLikeThisIndex]);
          }
          return KeyEventResult.handled;
        } else if (key == LogicalKeyboardKey.backspace ||
            key == LogicalKeyboardKey.escape) {
          _hidePanel();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: SizedBox(
        height: 194,
        child: Obx(
          () {
            final videos = controller.videoController.sameCategoryVideos;
            if (videos.isEmpty) {
              return const SizedBox.shrink();
            }
            return ListView.builder(
              controller: _moreLikeThisScrollController,
              scrollDirection: Axis.horizontal,
              itemCount: videos.length,
              itemBuilder: (context, index) {
                final video = videos[index];
                final bool isFocused =
                    _moreLikeThisFocus.hasFocus && index == _moreLikeThisIndex;
                return GestureDetector(
                  onTap: () => _onMoreLikeThisTapped(video),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isFocused ? Colors.white : Colors.transparent,
                        width: 3,
                      ),
                    ),
                    child: SizedBox(
                      width: 280,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: VideoThumbnail(video: video),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

// No changes needed for BunnyStreamBetterPlayer, it can remain as is.
class BunnyStreamBetterPlayer extends StatefulWidget {
  final String pullZone;
  final String videoId;
  final Function(BetterPlayerController) onPlayerCreated;

  const BunnyStreamBetterPlayer({
    super.key,
    required this.pullZone,
    required this.videoId,
    required this.onPlayerCreated,
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
          fit: BoxFit.contain,
          autoPlay: true,
          allowedScreenSleep: false,
          handleLifecycle: true,
          controlsConfiguration: const BetterPlayerControlsConfiguration(
            playerTheme: BetterPlayerTheme.material,
            showControls: true,
            enableSkips: true,
            enableFullscreen: false,
            enableQualities: true,
            enablePlaybackSpeed: true,
          ),
          eventListener: (event) async {
            if (event.betterPlayerEventType == BetterPlayerEventType.play) {
              WakelockPlus.enable();
              if (!_hasResumed) {
                _hasResumed = true;
                final lastPosition = _prefs?.getInt(_videoKey) ?? 0;
                if (lastPosition > 0 && _betterPlayerController != null) {
                  _betterPlayerController!
                      .seekTo(Duration(seconds: lastPosition));
                }
              }
            }
            if (event.betterPlayerEventType == BetterPlayerEventType.pause ||
                event.betterPlayerEventType == BetterPlayerEventType.finished) {
              WakelockPlus.disable();
              await _saveCurrentPosition();
            }
          },
        ),
        betterPlayerDataSource: betterPlayerDataSource,
      );

      if (!_isDisposed) {
        widget.onPlayerCreated(controller);
        setState(() {
          _betterPlayerController = controller;
        });
      }
    } catch (e, st) {
      debugPrint(
          "[BunnyStreamBetterPlayer] Error initializing BetterPlayer: $e\n$st");
    }
  }

  Future<void> _saveCurrentPosition() async {
    if (_betterPlayerController == null || _prefs == null) return;
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
    _saveCurrentPosition().whenComplete(() {
      _betterPlayerController?.dispose(forceDispose: true);
    });
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_betterPlayerController == null) {
      return const Center(
          child: CircularProgressIndicator(color: Colors.white));
    }
    return BetterPlayer(controller: _betterPlayerController!);
  }
}

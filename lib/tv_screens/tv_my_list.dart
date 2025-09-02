import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:videos_alarm_app/tv_screens/tv_dialog.dart';
import 'package:videos_alarm_app/tv_screens/tv_home.dart';
import 'package:videos_alarm_app/tv_screens/tv_video_player.dart';

class WatchLaterPageTV extends StatefulWidget {
  final List<String> watchLaterVideoIds;

  const WatchLaterPageTV(this.watchLaterVideoIds, {super.key});

  @override
  State<WatchLaterPageTV> createState() => _WatchLaterPageTVState();
}

class _WatchLaterPageTVState extends State<WatchLaterPageTV>
    with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();
  List<List<FocusNode>> _focusNodes = [];
  List<List<GlobalKey>> _itemKeys = [];
  static const int _crossAxisCount = 3;
  late final TVHomeController controller;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    controller = Get.find<
        TVHomeController>(); // Assumes controller is initialized in main.dart or parent
    // Alternative: If only used here, use Get.put:
    // controller = Get.put(TVHomeController(), permanent: true);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _disposeFocusNodes();
    // Do NOT call Get.delete<TVHomeController>() unless this is the only screen using it
    super.dispose();
  }

  void _disposeFocusNodes() {
    for (var row in _focusNodes) {
      for (var node in row) {
        node.dispose();
      }
    }
    _focusNodes = [];
    _itemKeys = [];
  }

  void _scrollToItem(int row, int col) {
    if (row < 0 ||
        row >= _itemKeys.length ||
        col < 0 ||
        col >= _itemKeys[row].length) {
      return;
    }
    final key = _itemKeys[row][col];
    if (key.currentContext != null) {
      Scrollable.ensureVisible(
        key.currentContext!,
        duration: const Duration(milliseconds: 300),
        alignment: 0.5,
        curve: Curves.easeInOut,
      );
    }
  }

  KeyEventResult _handleCardKeyEvent(
      KeyEvent event, int row, int col, Map<String, dynamic> video) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.select ||
        event.logicalKey == LogicalKeyboardKey.enter) {
      if (video.isNotEmpty &&
          video["videoUrl"] != null &&
          video["videoUrl"].toString().isNotEmpty) {
        debugPrint(
            'Showing preview dialog for video: ${video['title']} (${video['videoId']})');
        showDialog<bool>(
          context: context,
          builder: (context) => TVVideoPreviewDialog(
            title: video['title'],
            description: video['description'],
            thumbnailUrl: video['thumbnailUrl'],
            duration: video['duration'],
            releaseYear: video['releaseYear'],
            cbfc: video['cbfc'],
            starcast: video['starcast'],
          ),
        ).then((result) {
          if (result == true && mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => TVVideoPlayer(
                  releaseYear: video['releaseYear'],
                  starcast: video['starcast'],
                  cbfc: video['cbfc'],
                  myList: video['myList'],
                  duration: video['duration'],
                  director: video['director'],
                  videoLink: video['videoUrl'],
                  videoTitle: video['title'],
                  description: video['description'],
                  category: video['category'],
                  videoId: video['videoId'],
                ),
              ),
            );
          }
        });
      }
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      if (row > 0) {
        int prevRow = row - 1;
        int prevCol = col.clamp(0, _focusNodes[prevRow].length - 1);
        _focusNodes[prevRow][prevCol].requestFocus();
        _scrollToItem(prevRow, prevCol);
        return KeyEventResult.handled;
      }
    } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      if (row < _focusNodes.length - 1) {
        int nextRow = row + 1;
        int nextCol = col.clamp(0, _focusNodes[nextRow].length - 1);
        _focusNodes[nextRow][nextCol].requestFocus();
        _scrollToItem(nextRow, nextCol);
        return KeyEventResult.handled;
      }
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      if (col > 0) {
        _focusNodes[row][col - 1].requestFocus();
        _scrollToItem(row, col - 1);
        return KeyEventResult.handled;
      }
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      if (col < _focusNodes[row].length - 1) {
        _focusNodes[row][col + 1].requestFocus();
        _scrollToItem(row, col + 1);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Obx(() {
          // Directly access controller.allVideos to ensure reactivity
          final loadedVideos = controller.allVideos
              .where((video) =>
                  widget.watchLaterVideoIds.contains(video['videoId']))
              .toList();

          // Rebuild focus nodes only if necessary
          if (loadedVideos.length != _itemKeys.expand((e) => e).length) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted ||
                  loadedVideos.length == _itemKeys.expand((e) => e).length)
                return;

              setState(() {
                _disposeFocusNodes();

                if (loadedVideos.isNotEmpty) {
                  final int gridRowCount =
                      (loadedVideos.length / _crossAxisCount).ceil();
                  _focusNodes = List.generate(gridRowCount, (i) {
                    final int start = i * _crossAxisCount;
                    final int end =
                        (start + _crossAxisCount).clamp(0, loadedVideos.length);
                    final int itemsInRow = end - start;
                    return List.generate(
                        itemsInRow,
                        (j) =>
                            FocusNode(debugLabel: 'VideoCard Row $i Col $j'));
                  });

                  _itemKeys = List.generate(gridRowCount, (i) {
                    final int start = i * _crossAxisCount;
                    final int end =
                        (start + _crossAxisCount).clamp(0, loadedVideos.length);
                    final int itemsInRow = end - start;
                    return List.generate(itemsInRow, (j) => GlobalKey());
                  });
                }

                if (_focusNodes.isNotEmpty && _focusNodes.first.isNotEmpty) {
                  FocusScope.of(context).requestFocus(_focusNodes.first.first);
                }
              });
            });
          }

          if (widget.watchLaterVideoIds.isEmpty) {
            return const Center(
              child: Text(
                'Your Watchlist is empty — start adding movies to watch anytime.',
                style: TextStyle(color: Colors.white70, fontSize: 24),
              ),
            );
          }

          if (loadedVideos.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          return Padding(
            padding: const EdgeInsets.all(32.0),
            child: GridView.builder(
              controller: _scrollController,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: _crossAxisCount,
                childAspectRatio: 3 / 1.5,
                crossAxisSpacing: 24,
                mainAxisSpacing: 24,
              ),
              itemCount: loadedVideos.length,
              itemBuilder: (context, index) {
                final video = loadedVideos[index];
                final row = index ~/ _crossAxisCount;
                final col = index % _crossAxisCount;

                if (row >= _focusNodes.length ||
                    col >= _focusNodes[row].length) {
                  return const SizedBox.shrink();
                }

                return FocusableVideoCard(
                  key: _itemKeys[row][col],
                  video: video,
                  focusNode: _focusNodes[row][col],
                  onKeyEvent: (node, event) =>
                      _handleCardKeyEvent(event, row, col, video),
                );
              },
            ),
          );
        }),
      ),
    );
  }
}

class FocusableVideoCard extends StatefulWidget {
  final Map<String, dynamic> video;
  final FocusNode focusNode;
  final FocusOnKeyEventCallback onKeyEvent;

  const FocusableVideoCard({
    super.key,
    required this.video,
    required this.focusNode,
    required this.onKeyEvent,
  });

  @override
  State<FocusableVideoCard> createState() => _FocusableVideoCardState();
}

class _FocusableVideoCardState extends State<FocusableVideoCard> {
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChange);
    _isFocused = widget.focusNode.hasFocus;
  }

  @override
  void didUpdateWidget(covariant FocusableVideoCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusNode != oldWidget.focusNode) {
      oldWidget.focusNode.removeListener(_onFocusChange);
      widget.focusNode.addListener(_onFocusChange);
      _isFocused = widget.focusNode.hasFocus;
    }
  }

  void _onFocusChange() {
    if (mounted) {
      setState(() => _isFocused = widget.focusNode.hasFocus);
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    // Do not dispose focusNode here; it's managed by _WatchLaterPageTVState
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cardBorder = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: _isFocused
          ? const BorderSide(color: Colors.blueAccent, width: 2.0)
          : BorderSide.none,
    );

    return Focus(
      focusNode: widget.focusNode,
      onKeyEvent: widget.onKeyEvent,
      canRequestFocus: true,
      skipTraversal: false,
      child: AnimatedScale(
        scale: _isFocused ? 1.05 : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        child: Card(
          elevation: _isFocused ? 10 : 2,
          shape: cardBorder,
          clipBehavior: Clip.antiAlias,
          color: const Color(0xFF212121),
          child: Image.network(
            widget.video['thumbnailUrl'] ?? '',
            fit: BoxFit.fill,
            errorBuilder: (context, error, stackTrace) => const Center(
              child: Icon(Icons.movie, color: Colors.white70, size: 40),
            ),
          ),
        ),
      ),
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:videos_alarm_app/screens/live_videos.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';

import 'package:videos_alarm_app/tv_screens/tv_live_video_player.dart';

class TVLiveVideosController extends GetxController {
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
          await FirebaseFirestore.instance.collection('live_videos').get();

      for (final doc in snapshot.docs) {
        final data = doc.data();
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
      }
    } catch (e) {
      print("Error loading live videos: $e");
      errorMessage.value =
          "Failed to load live videos. Please check your internet connection and Firebase configuration.";
    } finally {
      pastLiveVideos.sort((a, b) => b.releaseDate.compareTo(a.releaseDate));
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
              item['liveStreamingDetails']['actualEndTime'] == null &&
              item['liveStreamingDetails']['actualStartTime'] != null) {
            return true;
          }
        }
        return false;
      } else {
        print('Failed to fetch live status: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('Error checking live status: $e');
      return false;
    }
  }
}

class TVLiveVideos extends StatefulWidget {
  const TVLiveVideos({Key? key}) : super(key: key);

  @override
  State<TVLiveVideos> createState() => _TVLiveVideosState();
}

class _TVLiveVideosState extends State<TVLiveVideos> {
  final TVLiveVideosController liveVideosController =
      Get.find<TVLiveVideosController>();
  final ScrollController _scrollController = ScrollController();

  List<List<FocusNode>> _focusNodes = [];
  List<List<GlobalKey>> _itemKeys = [];

  StreamSubscription? _isLoadingSubscription;

  static const int _pastVideosCrossAxisCount = 3;

  @override
  void initState() {
    super.initState();
    _isLoadingSubscription =
        liveVideosController.isLoading.listen(_onLoadingStateChanged);

    if (!liveVideosController.isLoading.value) {
      _initializeFocusNodes();
    }
  }

  void _onLoadingStateChanged(bool isLoading) {
    if (!isLoading && mounted) {
      setState(() {
        _initializeFocusNodes();
      });
    }
  }

  void _initializeFocusNodes() {
    _disposeFocusNodes();

    final liveVideos = liveVideosController.liveVideos;
    final pastVideos = liveVideosController.pastLiveVideos;

    if (liveVideos.isNotEmpty) {
      _focusNodes.add(List.generate(
          liveVideos.length, (i) => FocusNode(debugLabel: 'LiveVideo $i')));
      _itemKeys.add(List.generate(liveVideos.length, (i) => GlobalKey()));
    }

    if (pastVideos.isNotEmpty) {
      final int gridRowCount =
          (pastVideos.length / _pastVideosCrossAxisCount).ceil();
      for (int i = 0; i < gridRowCount; i++) {
        final int start = i * _pastVideosCrossAxisCount;
        final int end =
            min(start + _pastVideosCrossAxisCount, pastVideos.length);
        final int itemsInRow = end - start;

        _focusNodes.add(List.generate(itemsInRow,
            (j) => FocusNode(debugLabel: 'PastVideo Row $i Col $j')));
        _itemKeys.add(List.generate(itemsInRow, (j) => GlobalKey()));
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _focusNodes.isNotEmpty && _focusNodes.first.isNotEmpty) {
        _focusNodes.first.first.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _disposeFocusNodes();
    _isLoadingSubscription?.cancel();
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

  KeyEventResult _handleKeyEvent(
      KeyEvent event, int currentRow, int currentCol, VideoItem video) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.select ||
        event.logicalKey == LogicalKeyboardKey.enter) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TVLiveVideoPlayer(video: video),
        ),
      );
      print("222222 === TVLiveVideoPlayer was called from here");
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      if (currentRow > 0) {
        int prevRow = currentRow - 1;
        int prevCol = min(currentCol, _focusNodes[prevRow].length - 1);
        _focusNodes[prevRow][prevCol].requestFocus();
        _scrollToItem(prevRow, prevCol);
        return KeyEventResult.handled;
      }
    } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      if (currentRow < _focusNodes.length - 1) {
        int nextRow = currentRow + 1;
        int nextCol = min(currentCol, _focusNodes[nextRow].length - 1);
        _focusNodes[nextRow][nextCol].requestFocus();
        _scrollToItem(nextRow, nextCol);
        return KeyEventResult.handled;
      }
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      if (currentCol > 0) {
        _focusNodes[currentRow][currentCol - 1].requestFocus();
        _scrollToItem(currentRow, currentCol - 1);
        return KeyEventResult.handled;
      }
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      if (currentCol < _focusNodes[currentRow].length - 1) {
        _focusNodes[currentRow][currentCol + 1].requestFocus();
        _scrollToItem(currentRow, currentCol + 1);
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Obx(() {
        if (liveVideosController.isLoading.value && _focusNodes.isEmpty) {
          return const Center(
              child: CircularProgressIndicator(color: Colors.white));
        }

        if (liveVideosController.errorMessage.value.isNotEmpty) {
          return Center(
            child: Text(
              liveVideosController.errorMessage.value,
              style: const TextStyle(color: Colors.red, fontSize: 18),
              textAlign: TextAlign.center,
            ),
          );
        }

        final liveVideos = liveVideosController.liveVideos;
        final pastVideos = liveVideosController.pastLiveVideos;
        final bool hasLiveVideos = liveVideos.isNotEmpty;
        int logicalRowOffset = hasLiveVideos ? 1 : 0;

        return SingleChildScrollView(
          controller: _scrollController,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 24.0, horizontal: 48.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasLiveVideos) _buildSectionTitle("Live Now"),
                if (hasLiveVideos)
                  SizedBox(
                    height: 260,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: liveVideos.length,
                      itemBuilder: (context, index) {
                        final video = liveVideos[index];
                        return _TVVideoCard(
                          video: video,
                          isLive: true,
                          itemKey: _itemKeys[0][index],
                          focusNode: _focusNodes[0][index],
                          onKeyEvent: (node, event) =>
                              _handleKeyEvent(event, 0, index, video),
                        );
                      },
                    ),
                  ),
                if (hasLiveVideos) const SizedBox(height: 32),
                _buildSectionTitle("Past Live Streams"),
                if (pastVideos.isEmpty)
                  SizedBox(
                    height: 150,
                    child: Center(
                      child: Text(
                        "No Past Live Streams Found.",
                        style: TextStyle(color: Colors.grey[600], fontSize: 18),
                      ),
                    ),
                  )
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: _pastVideosCrossAxisCount,
                      childAspectRatio: 11 / 9,
                      crossAxisSpacing: 24,
                      mainAxisSpacing: 24,
                    ),
                    itemCount: pastVideos.length,
                    itemBuilder: (context, index) {
                      final video = pastVideos[index];
                      final int row = index ~/ _pastVideosCrossAxisCount;
                      final int col = index % _pastVideosCrossAxisCount;
                      final int absoluteRow = logicalRowOffset + row;
                      return _TVVideoCard(
                        video: video,
                        isLive: false,
                        itemKey: _itemKeys[absoluteRow][col],
                        focusNode: _focusNodes[absoluteRow][col],
                        onKeyEvent: (node, event) =>
                            _handleKeyEvent(event, absoluteRow, col, video),
                      );
                    },
                  ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 28,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

// --- WIDGET WITH SWAPPED STYLING ---

class _TVVideoCard extends StatefulWidget {
  final VideoItem video;
  final bool isLive;
  final FocusNode focusNode;
  final GlobalKey itemKey;
  final KeyEventResult Function(FocusNode, KeyEvent) onKeyEvent;

  const _TVVideoCard({
    Key? key,
    required this.video,
    required this.isLive,
    required this.focusNode,
    required this.itemKey,
    required this.onKeyEvent,
  }) : super(key: key);

  @override
  State<_TVVideoCard> createState() => _TVVideoCardState();
}

class _TVVideoCardState extends State<_TVVideoCard> {
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChange);
    _isFocused = widget.focusNode.hasFocus;
  }

  @override
  void didUpdateWidget(covariant _TVVideoCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusNode != oldWidget.focusNode) {
      oldWidget.focusNode.removeListener(_onFocusChange);
      widget.focusNode.addListener(_onFocusChange);
      _isFocused = widget.focusNode.hasFocus;
    }
  }

  void _onFocusChange() {
    if (mounted) {
      setState(() {
        _isFocused = widget.focusNode.hasFocus;
      });
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: widget.itemKey,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: Focus(
        focusNode: widget.focusNode,
        onKeyEvent: widget.onKeyEvent,
        child: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => TVLiveVideoPlayer(video: widget.video),
              ),
            );
            print("111111 === TVLiveVideoPlayer was called from here");
          },
          // SWAPPED LOGIC:
          // Live videos get the scale/border style.
          // Past live videos get the bottom line style.
          child: widget.isLive
              ? _buildScaleAndBorderStyleCard()
              : _buildBottomLineStyleCard(),
        ),
      ),
    );
  }

  Widget _buildBottomLineStyleCard() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: _isFocused
            ? const Border(
                top: BorderSide(color: Colors.blueAccent, width: 1.5),
                right: BorderSide(color: Colors.blueAccent, width: 2),
                left: BorderSide(color: Colors.blueAccent, width: 1.5),
                bottom: BorderSide(color: Colors.blueAccent, width: 2.5),
              )
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildThumbnail(),
            _buildInfoPanel(),
          ],
        ),
      ),
    );
  }

  // RENAMED & REPURPOSED: Style with scaling and an orange border for LIVE videos
  Widget _buildScaleAndBorderStyleCard() {
    final cardBorder = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: BorderSide(
        color: _isFocused ? Colors.deepOrangeAccent : Colors.transparent,
        width: 3.0,
      ),
    );

    return AnimatedScale(
      scale: _isFocused ? 1.05 : 1.0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      child: Card(
        elevation: _isFocused ? 10 : 2,
        shape: cardBorder,
        clipBehavior: Clip.antiAlias,
        color: const Color(0xFF212121),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildThumbnail(),
            _buildInfoPanel(),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail() {
    return Expanded(
      flex: 6,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            widget.video.thumbnailUrl,
            fit: BoxFit.fill,
            errorBuilder: (context, error, stackTrace) => const Center(
                child: Icon(Icons.broken_image, color: Colors.grey, size: 48)),
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return const Center(
                  child: CircularProgressIndicator(strokeWidth: 2));
            },
          ),
          if (widget.isLive) _buildLiveBadge(),
        ],
      ),
    );
  }

  Widget _buildInfoPanel() {
    return Expanded(
      flex: 4,
      child: Container(
        padding: const EdgeInsets.all(8.0),
        color: const Color(0xFF2a2a2a),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              widget.video.title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${widget.video.concurrentViewers} Views',
                  style: TextStyle(color: Colors.grey[400], fontSize: 8),
                ),
                Text(
                  widget.video.formattedreleaseDate,
                  style: TextStyle(color: Colors.grey[400], fontSize: 8),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveBadge() {
    return Positioned(
      top: 10,
      left: 10,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.9),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text(
          'LIVE',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

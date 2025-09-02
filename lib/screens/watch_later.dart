// ignore_for_file: unnecessary_null_comparison

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:videos_alarm_app/screens/home.dart';
import 'package:videos_alarm_app/screens/view_video.dart';

class WatchLaterPage extends StatelessWidget {
  final List<String> watchLaterVideoIds;

  WatchLaterPage(this.watchLaterVideoIds);

  String _formatDate(dynamic releaseDate) {
    if (releaseDate == null) return 'Unknown date';
    try {
      if (releaseDate is DateTime) {
        return DateFormat('MMM dd, yyyy').format(releaseDate);
      }
    } catch (_) {}
    return 'Invalid date';
  }

  @override
  Widget build(BuildContext context) {
    final HomeController controller = Get.put(HomeController());

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Watch Later'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: watchLaterVideoIds.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'Your Watchlist is empty — start adding movies to watch anytime.',
                  style: TextStyle(color: Colors.white70, fontSize: 18),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView.builder(
              itemCount: watchLaterVideoIds.length,
              itemBuilder: (context, index) {
                final videoId = watchLaterVideoIds[index];
                final video = controller.getVideoById(videoId);

                return GestureDetector(
                  onTap: () async {
                    print('Tile tapped. videoId: $videoId');
                    if (video != null &&
                        video.isNotEmpty &&
                        video["videoUrl"] != null &&
                        video["videoUrl"].toString().isNotEmpty) {
                      print(
                          'Showing preview dialog for video: ${video['title']} (${video['videoId']})');
                      String? thumbnailUrl = video['thumbnailUrl'];
                      bool? result = await showDialog<bool>(
                        context: context,
                        barrierDismissible: true,
                        builder: (context) => VideoPreviewDialog(
                          title: video['title'],
                          description: video['description'],
                          thumbnailUrl: thumbnailUrl,
                          duration: video['duration'],
                          releaseYear: video['releaseYear'],
                          cbfc: video['cbfc'],
                          starcast: video['starcast'],
                        ),
                      );

                      if (result == true) {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => ViewVideo(
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
                    }
                  },
                  child: Card(
                    color: const Color(0xFF1E1E1E),
                    margin:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.horizontal(
                              left: Radius.circular(12),
                              right: Radius.circular(12),
                            ),
                            child: Image.network(
                              video!['thumbnailUrl'] ?? '',
                              width: 148,
                              height: 100,
                              fit: BoxFit.fill,
                              errorBuilder: (_, __, ___) => Container(
                                width: 148,
                                height: 100,
                                color: Colors.grey[800],
                                child: const Icon(Icons.broken_image,
                                    color: Colors.white70),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    video['title'] ?? 'No Title',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    video['description'] ?? '',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'CBFC: ${video['cbfc'] ?? '-'}',
                                    style: const TextStyle(
                                      color: Colors.white60,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Released: ${_formatDate(video['releaseDate'])}',
                                    style: const TextStyle(
                                      color: Colors.white38,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

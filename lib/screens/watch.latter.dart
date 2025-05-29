import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:videos_alarm_app/screens/view_video.dart';

class WatchLaterPage extends StatelessWidget {
  final List<Map<String, dynamic>> watchLaterVideos;

  WatchLaterPage(this.watchLaterVideos);

  // Helper method to format date
  String _formatDate(dynamic createdAt) {
    if (createdAt == null) return 'Unknown date';

    try {
      if (createdAt is DateTime) {
        return DateFormat('MMM dd, yyyy').format(createdAt);
      } else {
        return 'Invalid date format';
      }
    } catch (e) {
      return 'Invalid date';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Watch Later'),
      ),
      body: ListView.builder(
        itemCount: watchLaterVideos.length,
        itemBuilder: (context, index) {
          var video = watchLaterVideos[index];

          bool hasValidData = video['videoUrl'] != null &&
              video['title'] != null &&
              video['description'] != null;

          return ListTile(
            title: Text(video['title'] ?? 'No title'),
            subtitle: Text('Created on: ${_formatDate(video['releaseDate'])}'),
            onTap: () {
              print('Tapped on video: ${video['title']}');
              if (hasValidData) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ViewVideo(
                      releaseYear: video['releaseYear'],
                      cbfc: video['cbfc'],
                      myList: video['myList'],
                      duration: video['duration'],
                      director: video['director'],
                      videoLink: video['videoUrl'],
                      videoTitle: video['title'],
                      description: video['description'],
                      category: video['category'],
                    ),
                  ),
                );
              } else {
                print("Error: Missing video data.");
              }
            },
          );
        },
      ),
    );
  }
}

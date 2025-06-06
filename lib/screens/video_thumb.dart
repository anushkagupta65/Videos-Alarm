import 'package:flutter/material.dart';

class VideoThumbnail extends StatelessWidget {
  final Map<String, dynamic> video;

  const VideoThumbnail({Key? key, required this.video}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 260,
            height: 140,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              image: DecorationImage(
                fit: BoxFit.cover,
                image: NetworkImage(video['thumbnailUrl']),
              ),
            ),
          ),
          const SizedBox(height: 5),
          Container(
            width: 120,
            child: Text(
              video['title'],
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

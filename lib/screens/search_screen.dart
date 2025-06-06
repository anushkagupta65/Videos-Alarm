import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:videos_alarm_app/components/app_style.dart';
import 'package:videos_alarm_app/screens/view_video.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  bool isLoading = false;
  Map<String, List<Map<String, dynamic>>> categorizedVideosMap = {};
  Map<String, List<Map<String, dynamic>>> filteredVideosMap = {};
  TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _getVideosList();
  }

  Future<void> _getVideosList() async {
    setState(() {
      isLoading = true;
    });

    try {
      FirebaseFirestore firestore = FirebaseFirestore.instance;

      QuerySnapshot querySnapshot = await firestore.collection('videos').get();

      Map<String, List<Map<String, dynamic>>> categorizedVideos = {};

      querySnapshot.docs.forEach((doc) {
        var data = doc.data() as Map<String, dynamic>;

        // Skip videos with category 'live'
        if (data['category'] == 'live') {
          return;
        }

        var video = {
          "releaseYear": data['releaseYear'],
          "starcast": data['starcast'],
          "cbfc": data['cbfc'],
          "myList": data['myList'],
          "duration": data['duration'],
          "director": data['director'],
          "title": data["title"],
          "description": data["description"],
          "category": data["category"],
          "videoUrl": data["videoUrl"],
          "thumbnailUrl": data["thumbnailUrl"],
          'videoId': doc.id, // doc.id contains the DOCUMENT ID.
        };

        String category = data["category"];
        if (categorizedVideos.containsKey(category)) {
          categorizedVideos[category]!.add(video);
        } else {
          categorizedVideos[category] = [video];
        }
      });

      setState(() {
        categorizedVideosMap = categorizedVideos;
        filteredVideosMap = categorizedVideos; // Initially show all videos
        isLoading = false;
      });

      print("\nCategorized Videos: ${jsonEncode(categorizedVideos)}");
    } catch (error) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Something went wrong: $error')),
      );
    }
  }

  @override
  void dispose() {
    super.dispose();
    searchController.dispose();
  }

  void _searchVideos(String query) {
    if (query.isEmpty) {
      setState(() {
        filteredVideosMap = categorizedVideosMap;
      });
      return;
    }

    Map<String, List<Map<String, dynamic>>> filtered = {};

    categorizedVideosMap.forEach((category, videos) {
      List<Map<String, dynamic>> filteredVideos = videos
          .where((video) =>
              video['title'].toLowerCase().contains(query.toLowerCase()) ||
              video['description'].toLowerCase().contains(query.toLowerCase()))
          .toList();

      if (filteredVideos.isNotEmpty) {
        filtered[category] = filteredVideos;
      }
    });

    setState(() {
      filteredVideosMap = filtered;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: blackColor,
      body: Column(
        children: [
          // Search bar in the body
          Padding(
            padding: const EdgeInsets.all(15.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white, width: 0.3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 5,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(Icons.search, color: Colors.white.withOpacity(0.6)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: searchController,
                      onChanged: _searchVideos,
                      decoration: InputDecoration(
                        hintText: 'Search videos...',
                        hintStyle:
                            TextStyle(color: Colors.white.withOpacity(0.5)),
                        border: InputBorder.none,
                      ),
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Loading and video list
          isLoading
              ? Center(child: CircularProgressIndicator())
              : filteredVideosMap.isEmpty
                  ? Center(
                      child: Text(
                        'No videos found',
                        style: TextStyle(
                          color: whiteColor,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  : Expanded(
                      child: ListView(
                        children: filteredVideosMap.entries.map((entry) {
                          String categoryName = entry.key;
                          List<Map<String, dynamic>> videosInCategory =
                              entry.value;

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Category Title
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16.0),
                                  child: Text(
                                    categoryName,
                                    style: TextStyle(
                                      color: whiteColor,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                // Videos in the Category
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: videosInCategory.map((video) {
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12.0),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            GestureDetector(
                                              onTap: () {
                                                print(
                                                    "Video tapped: ${video['title']}");
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) =>
                                                        ViewVideo(
                                                      releaseYear:
                                                          video['releaseYear'],
                                                      cbfc: video['cbfc'],
                                                      myList: video['myList'],
                                                      duration:
                                                          video['duration'],
                                                      director:
                                                          video['director'],
                                                      videoTitle: video['title']
                                                          .toString(),
                                                      description:
                                                          video['description'],
                                                      videoLink:
                                                          video['videoUrl'],
                                                      category:
                                                          video['category'],
                                                      videoId: video['videoId'],
                                                    ),
                                                  ),
                                                );
                                              },
                                              child: Container(
                                                width: 260,
                                                height: 140,
                                                decoration: BoxDecoration(
                                                  color: darkColor,
                                                  image: DecorationImage(
                                                    fit: BoxFit.fill,
                                                    image: NetworkImage(
                                                        video['thumbnailUrl']),
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Container(
                                              width: 200,
                                              height: 40,
                                              child: Text(
                                                video['title'],
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 2,
                                                style: TextStyle(
                                                    color: whiteColor,
                                                    fontSize: 12),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
        ],
      ),
    );
  }
}

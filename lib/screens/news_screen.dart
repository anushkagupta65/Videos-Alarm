import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:videos_alarm_app/api_services/models/news_list.dart';
import 'package:videos_alarm_app/components/app_style.dart';
import 'package:videos_alarm_app/components/blogdetailspage.dart';
import '../components/check_internet.dart';
import '../components/common_toast.dart';
import '../components/loader.dart';
import '../components/network_error_wiget.dart';
import 'package:intl/intl.dart';

class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  NewsList newsList = NewsList();
  bool isLoading = true;
  String selectedFilter = "Latest"; // Default filter is "Latest"

  Future<void> _getNews() async {
    try {
      QuerySnapshot querySnapshot =
          await FirebaseFirestore.instance.collection('blogs').get();

      List<Articles> articles = querySnapshot.docs.map((doc) {
        var data = doc.data() as Map<String, dynamic>;
        return Articles(
          source: Sources(
            id: data['source']['id'],
            name: data['source']['name'],
          ),
          author: data['author'],
          title: data['title'],
          description: data['description'],
          url: data['url'],
          urlToImage: data['urlToImage'],
          publishedAt: data['publishedAt'],
          content: data['content'],
        );
      }).toList();

      // Sort articles based on selected filter
      if (selectedFilter == "Latest") {
        articles.sort((a, b) => DateTime.parse(b.publishedAt!).compareTo(DateTime.parse(a.publishedAt!)));
      } else if (selectedFilter == "Oldest") {
        articles.sort((a, b) => DateTime.parse(a.publishedAt!).compareTo(DateTime.parse(b.publishedAt!)));
      }

      setState(() {
        newsList = NewsList(
          status: 'success',
          totalResults: articles.length,
          articles: articles,
        );
        isLoading = false;
      });
    } catch (error) {
      setState(() {
        isLoading = false;
      });
    }
  }

  bool isNetwork = true;

  _checkNetWork() async {
    if (!await isNetworkAvailable()) {
      setState(() {
        isNetwork = false;
      });
    } else {
      _getNews();
    }
  }

  @override
  void initState() {
    super.initState();
    _checkNetWork();
  }

  @override
  Widget build(BuildContext context) {
    if (isNetwork == false) {
      return networkError();
    }
    return Scaffold(
      backgroundColor: blackColor,
      appBar: AppBar(
        backgroundColor: blackColor,
        foregroundColor: whiteColor,
        title: Text('Top Headlines',style: TextStyle(color:whiteColor),),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() {
                selectedFilter = value;
                isLoading = true; // Reset loading state while fetching data
              });
              _getNews(); // Fetch news after filter is applied
            },
            itemBuilder: (BuildContext context) {
              return ['Latest', 'Oldest'].map((String choice) {
                return PopupMenuItem<String>(
                  value: choice,
                  child: Text(choice),
                );
              }).toList();
            },
          ),
        ],
      ),
      body: isLoading
          ? LoaderWidget()
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
           
                  ListView.separated(
                    itemCount: newsList.articles!.length,
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.symmetric(
                      horizontal: MediaQuery.of(context).size.width * 0.025,
                    ),
                    separatorBuilder: (context, i) => SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      var data = newsList.articles![index];
                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  BlogDetailsScreen(article: data),
                            ),
                          );
                        },
                        child: Card(
                          elevation: 5, // Add elevation for shadow
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15), // Increased border radius for modern feel
                          ),
                          child: Stack(
                            children: [
                              // Background image
                              ClipRRect(
                                borderRadius: BorderRadius.circular(15),
                                child: Image.network(
                                  data.urlToImage.toString(),
                                  width: double.infinity,
                                  height: 250, // Set a fixed height for the image
                                  fit: BoxFit.cover, // Make the image cover the card
                                ),
                              ),
                              // Overlay to make text readable
                              Container(
                                width: double.infinity,
                                height: 250, // Same height as image
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(15),
                                  color: blackColor.withOpacity(0.6), // Semi-transparent overlay
                                ),
                                padding: EdgeInsets.all(10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            data.title.toString(),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 16, // Increased font size
                                              fontWeight: FontWeight.bold,
                                              color: whiteColor,
                                            ),
                                          ),
                                          SizedBox(height: 8), // Adjusted space
                                          Text(
                                            data.description.toString(),
                                            maxLines: 3,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 14, // Adjusted font size
                                              color: grey300,
                                            ),
                                          ),
                                          SizedBox(height: 10),
                                          Text(
                                            DateFormat('d MMM yyyy').format(
                                              DateTime.parse(
                                                  data.publishedAt.toString()),
                                            ),
                                            style: TextStyle(
                                                color: greyColor,
                                                fontSize: 12), // Smaller date font
                                          ),
                                        ],
                                      ),
                                    ),
                                    // "Read More" text at the bottom
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8.0),
                                      child: Align(
                                        alignment: Alignment.centerRight,
                                        child: Text(
                                          "Read more",
                                          style: TextStyle(
                                            color: whiteColor,
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            decoration: TextDecoration.underline, // Underline for clickability
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }
}

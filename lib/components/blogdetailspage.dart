import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:videos_alarm_app/api_services/models/news_list.dart';
import 'package:videos_alarm_app/components/app_style.dart';

class BlogDetailsScreen extends StatelessWidget {
  final Articles article;

  const BlogDetailsScreen({Key? key, required this.article}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        elevation: 3,
        backgroundColor: blackColor,
        foregroundColor: whiteColor,
        title: Text(article.title ?? "Blog Details"),
      ),
      body: Container(
        height: height,
        color: blackColor,
        // decoration: BoxDecoration(
        //   gradient: LinearGradient(
        //     colors: [Colors.black87, Colors.black54],
        //     begin: Alignment.topCenter,
        //     end: Alignment.bottomCenter,
        //   ),
        // ),
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                elevation: 5,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: article.urlToImage != null
                      ? Image.network(
                          article.urlToImage!,
                          fit: BoxFit.cover,
                          width: width,
                          height: height * 0.25,
                        )
                      : SizedBox.shrink(),
                ),
              ),
              SizedBox(height: 20),
              Text(
                article.title ?? "",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: whiteColor,
                  shadows: [
                    Shadow(
                      blurRadius: 5.0,
                      color: Colors.black54,
                      offset: Offset(0.0, 2.0),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 8),
              Text(
                   DateFormat('d MMM yyyy').format(
                                              DateTime.parse(
                                                  article.publishedAt.toString()),
                                            ),
                style: TextStyle(color: Colors.grey),
              ),
              SizedBox(height: 20),
              Text(
                article.content ?? "",
                // "lksjdldsfkjsdlkj lksdfjlk jlkd lsdjflksdj kljsdflkjslk jlksdjf sdlkfjklsjflk jdlksfjdlskj lkfjlkjlk jlskjflkj lkjlskdjlk jlsdkfnjdslkj lkdjsfklj lkjdslfkj lkjflkj kldjflkj kldsfjlk jkljfdklj klsdjfklj lksdjfkdlsjf kldjfkldsjfkl jdsklsfjk jkdsfjkl kldsfjlkj kldjfkl jklsdjflkklsdjflksdjj kjdsfkljdsklj lksdjfklfjkl jkljkl kdjflkj kljdsfklsjdkl jklsdfjkl jkldsjfklsdj klsjdflkj lkdjflkj lksjdflkj kljdsflkj lksdj lkjsdklfjsdklj lkdjsflkj klj lksdjflkjlk jsdklfjsdlkfj sdlkfjsdlkfjsdklj kldsjfkldsfjsdklfjkljkl jdslkfjdsklfjdsklfjdlkj kldsjfkldsjfkl jkldfjlkj lkj kl kjdlksjflk jlksdjflksdj lkjsdflkjskl jlkdsjflksdj lkjsdlkfjkl jklsdjflksdj kljfklsdj kldjfklsdjk ljdsklfjsdkfljlk jklfjkl jksldfjkl jksdlfjksdljfk jsdklfjsdkljk lskdlfjklcj kldjskfljkl jsdklfjsdklj jsdklfjdslkjfkl jdklsfjklsdj kdjfkldsfjk jdklfjdsklvjkds jfskldj klsdjflksdjflk jklsdjfklsdjfkl klsdfjklsdfjsdklj klsdjfklsdjlkfjkl jflkj lkjdslkfjlk jsdlkfjlk jslkdfjkljkljglkdj lkfjgklj klfjdglkj lkjflksj kljfdglkfjd lkjfkldgjdfk ljlkfjgkljlkj  nm,d j  dsjksd jkv jkd vjk j wkj vjk e jvnwjksdljfsklfjsdklfj sjflkj kl ksfklsbj nkdnfklsnbkdn kldnfklsnbkdlfnlk nlkdnfklsdnlkdsnvlk mslkdfmsdklvmklsjlk jlkfjsdlkj lkjlfkdjsdlkfjlk jdlkfjdslkj lkjslfjsdlkj klfjlkdsjlk jlkgjdslkj lksjflksdjlk jslkfjdsklj lkdjflksdjlkj lkdsjflkdsjflk jlkfjsdlkjf kjfklsdjflk ksdlflwfweiiwewiefjl jdilweiwlefl iile kljdklj lkjwelkjlk jelkwrjl jioejfioj lksdjfisdjvlkxc jlkdsjfklj lkdsjfklsdj sdnf,sdn kldnfm,sdn ,sdfnsdn ,sdfnsdjfn jndfjksnfvilsi ldirwdqwdwdlkn kwjdkjwcv kjfekdsdvndm,vddfjsknvksd jlkjfklj lkjsdklfjklweji lsdnfliwef lknfjsdkljsdkcjvl kkewjflisdklc isejfsdkvdsjklv lkejflksjflsfj",
                style: TextStyle(fontSize: 16, color: whiteColor),
              ),
              SizedBox(height: 20),
              // Row(
              //   mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              //   children: [
              //     ElevatedButton.icon(
              //       onPressed: () {
              //         // Share article logic
              //       },
              //       icon: Icon(Icons.share),
              //       label: Text("Share"),
              //       style: ElevatedButton.styleFrom(
              //         backgroundColor: Colors.blue,
              //       ),
              //     ),
              //     ElevatedButton.icon(
              //       onPressed: () {
              //         // Save article logic
              //       },
              //       icon: Icon(Icons.bookmark),
              //       label: Text("Save"),
              //       style: ElevatedButton.styleFrom(
              //         backgroundColor: Colors.green,
              //       ),
              //     ),
              //   ],
              // ),
            ],
          ),
        ),
      ),
    );
  }
}

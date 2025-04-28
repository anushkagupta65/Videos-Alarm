// import 'package:dio/dio.dart';
// import 'package:retrofit/retrofit.dart';

// import '../models/news_list.dart';
// part 'news_client.g.dart';


// // flutter pub run build_runner build
// // flutter pub run build_runner build --delete-conflicting-outputs


// @RestApi(baseUrl: "https://newsapi.org")


// abstract class NewsRestClient {
//   factory NewsRestClient(Dio dio, {String baseUrl}) = _NewsRestClient;


//   @GET("/v2/top-headlines?country=in&apiKey=a720d9084bcd4956b6211b71953f65b7")
//   Future<NewsList> newsList();
// }
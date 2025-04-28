import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';
import '../models/banner_list.dart';
import '../models/genre_list.dart';
import '../models/genre_videos_list.dart';
import '../models/movie_tvshow_videos.dart';
import '../models/videos_list.dart';
part 'client.g.dart';

// flutter pub run build_runner build
// flutter pub run build_runner build --delete-conflicting-outputs

// @RestApi(baseUrl: "https://admin.videosalarm.in")
@RestApi(baseUrl: "https://videosalarm.com")
abstract class RestClient {
  factory RestClient(Dio dio, {String baseUrl}) = _RestClient;

  @POST("/api/user-registration")
  Future<dynamic> userRegistration(
    @Field("mobile") String mobile,
  );

  @POST("/api/user-login")
  Future<dynamic> userLogIn(
    @Field("mobile") String mobile,
  );

  @POST("/api/otp-varification")
  Future<dynamic> otpVarification(
    @Field("mobile") String mobile,
    @Field("otp") String otp,
  );

  @GET("/api/genre-list")
  Future<GenreList> geneList();

  @GET("/api/video-list")
  Future<VideosList> videosList();

  @GET("/api/genre-video-list")
  Future<GenreVideosList> genreVideoList(
    @Field("genre_id") int? subcategoryId,
  );

  @GET("/api/movie-video-list")
  Future<MovieList> movieList();

  @GET("/api/tvshowsList-list")
  Future<TvShowList> tvShowList();

  @GET("/api/videos-list")
  Future<VideoList> videoList();

  @GET("/api/banner-list")
  Future<BannerList> bannerList();
}

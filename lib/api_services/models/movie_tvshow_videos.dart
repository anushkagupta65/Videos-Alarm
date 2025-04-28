import 'package:json_annotation/json_annotation.dart';
part 'movie_tvshow_videos.g.dart';



@JsonSerializable()
class MovieList {
  bool? success;
  String? message;
  List<MovieListData>? data;

  MovieList({this.success, this.message, this.data});

  factory MovieList.fromJson(Map<String, dynamic> json) => _$MovieListFromJson(json);
  Map<String, dynamic> toJson() => _$MovieListToJson(this);
}

@JsonSerializable()
class MovieListData {
  int? id;
  int? category;
  String? title;
  String? link;
  String? video_thumb;
  String? description;
  int? status;
  String? updated_at;

  MovieListData(
      {this.id,
        this.category,
        this.title,
        this.link,
        this.video_thumb,
        this.description,
        this.status,
        this.updated_at});

  factory MovieListData.fromJson(Map<String, dynamic> json) => _$MovieListDataFromJson(json);
  Map<String, dynamic> toJson() => _$MovieListDataToJson(this);
}




@JsonSerializable()
class TvShowList {
  bool? success;
  String? message;
  List<TvShowListData>? data;

  TvShowList({this.success, this.message, this.data});

  factory TvShowList.fromJson(Map<String, dynamic> json) => _$TvShowListFromJson(json);
  Map<String, dynamic> toJson() => _$TvShowListToJson(this);
}

@JsonSerializable()
class TvShowListData {
  int? id;
  int? category;
  String? title;
  String? link;
  String? video_thumb;
  String? description;
  int? status;
  String? updated_at;

  TvShowListData(
      {this.id,
        this.category,
        this.title,
        this.link,
        this.video_thumb,
        this.description,
        this.status,
        this.updated_at});

  factory TvShowListData.fromJson(Map<String, dynamic> json) => _$TvShowListDataFromJson(json);
  Map<String, dynamic> toJson() => _$TvShowListDataToJson(this);

}










@JsonSerializable()
class VideoList {
  bool? success;
  String? message;
  List<VideoListData>? data;

  VideoList({this.success, this.message, this.data});

  factory VideoList.fromJson(Map<String, dynamic> json) => _$VideoListFromJson(json);
  Map<String, dynamic> toJson() => _$VideoListToJson(this);

}

@JsonSerializable()
class VideoListData {
  int? id;
  int? category;
  String? title;
  String? link;
  String? video_thumb;
  String? description;
  int? status;
  String? updated_at;

  VideoListData(
      {this.id,
        this.category,
        this.title,
        this.link,
        this.video_thumb,
        this.description,
        this.status,
        this.updated_at});

  factory VideoListData.fromJson(Map<String, dynamic> json) => _$VideoListDataFromJson(json);
  Map<String, dynamic> toJson() => _$VideoListDataToJson(this);

}
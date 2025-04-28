import 'package:json_annotation/json_annotation.dart';
part 'genre_videos_list.g.dart';


@JsonSerializable()
class GenreVideosList {
  bool? success;
  String? message;
  List<Data>? data;

  GenreVideosList({this.success, this.message, this.data});

  factory GenreVideosList.fromJson(Map<String, dynamic> json) => _$GenreVideosListFromJson(json);
  Map<String, dynamic> toJson() => _$GenreVideosListToJson(this);
}


@JsonSerializable()
class Data {
  int? id;
  int? video_id;
  int? genre_id;
  String? genre_name;
  int? category;
  String? title;
  String? link;
  String? video_thumb;
  String? description;
  int? status;
  int? subcategory_id;
  String? subcategory_name;

  Data(
      {this.id,
        this.video_id,
        this.genre_id,
        this.genre_name,
        this.category,
        this.title,
        this.link,
        this.video_thumb,
        this.description,
        this.status,
        this.subcategory_id,
        this.subcategory_name});

  factory Data.fromJson(Map<String, dynamic> json) => _$DataFromJson(json);
  Map<String, dynamic> toJson() => _$DataToJson(this);
}

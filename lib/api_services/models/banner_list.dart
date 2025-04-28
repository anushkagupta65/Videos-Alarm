import 'package:json_annotation/json_annotation.dart';
part 'banner_list.g.dart';

@JsonSerializable()
class BannerList {
  bool? success;
  String? message;
  List<Data>? data;

  BannerList({this.success, this.message, this.data});

  factory BannerList.fromJson(Map<String, dynamic> json) => _$BannerListFromJson(json);
  Map<String, dynamic> toJson() => _$BannerListToJson(this);
}

@JsonSerializable()
class Data {
  int? id;
  String? banner;
  String? video_id;
  int? status;
  String? link;
  String? title;
  String? video_thumb;
  String? description;

  Data(
      {this.id,
        this.banner,
        this.video_id,
        this.status,
        this.link,
        this.title,
        this.video_thumb,
        this.description});

  factory Data.fromJson(Map<String, dynamic> json) => _$DataFromJson(json);
  Map<String, dynamic> toJson() => _$DataToJson(this);
}

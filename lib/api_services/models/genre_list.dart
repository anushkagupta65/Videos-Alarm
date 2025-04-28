import 'package:json_annotation/json_annotation.dart';
part 'genre_list.g.dart';


@JsonSerializable()
class GenreList {
  bool? success;
  String? message;
  List<Data>? data;

  GenreList({this.success, this.message, this.data});

  factory GenreList.fromJson(Map<String, dynamic> json) => _$GenreListFromJson(json);
  Map<String, dynamic> toJson() => _$GenreListToJson(this);
}


@JsonSerializable()
class Data {
  int? id;
  String? genre_name;
  String? thumbnail;

  Data({this.id, this.genre_name, this.thumbnail});

  factory Data.fromJson(Map<String, dynamic> json) => _$DataFromJson(json);
  Map<String, dynamic> toJson() => _$DataToJson(this);

}

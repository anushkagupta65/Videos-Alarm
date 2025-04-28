import 'package:json_annotation/json_annotation.dart';
part 'news_list.g.dart';

@JsonSerializable()
class NewsList {
  String? status;
  int? totalResults;
  List<Articles>? articles;

  NewsList({this.status, this.totalResults, this.articles});

  factory NewsList.fromJson(Map<String, dynamic> json) =>
      _$NewsListFromJson(json);
  Map<String, dynamic> toJson() => _$NewsListToJson(this);
}

@JsonSerializable()
class Articles {
  Sources? source;
  String? author;
  String? title;
  String? description;
  String? url;
  String? urlToImage;
  String? publishedAt;
  String? content;

  Articles(
      {this.source,
      this.author,
      this.title,
      this.description,
      this.url,
      this.urlToImage,
      this.publishedAt,
      this.content});

  factory Articles.fromJson(Map<String, dynamic> json) =>
      _$ArticlesFromJson(json);
  Map<String, dynamic> toJson() => _$ArticlesToJson(this);
}

@JsonSerializable()
class Sources {
  String? id;
  String? name;

  Sources({this.id, this.name});

  factory Sources.fromJson(Map<String, dynamic> json) =>
      _$SourcesFromJson(json);
  Map<String, dynamic> toJson() => _$SourcesToJson(this);
}

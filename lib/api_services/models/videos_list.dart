// class VideosList {
//   bool? success;
//   String? message;
//   List<Data>? data;

//   VideosList({this.success, this.message, this.data});

//   // From JSON factory constructor
//   factory VideosList.fromJson(Map<String, dynamic> json) {
//     return VideosList(
//       success: json['success'] as bool?,
//       message: json['message'] as String?,
//       data: json['data'] != null
//           ? (json['data'] as List).map((i) => Data.fromJson(i)).toList()
//           : null,
//     );
//   }

//   // To JSON method
//   Map<String, dynamic> toJson() {
//     return {
//       'success': success,
//       'message': message,
//       'data': data?.map((e) => e.toJson()).toList(),
//     };
//   }
// }

// class Data {
//   String? title;
//   List<Details>? details;

//   Data({this.title, this.details});

//   // From JSON factory constructor
//   factory Data.fromJson(Map<String, dynamic> json) {
//     return Data(
//       title: json['title'] as String?,
//       details: json['details'] != null
//           ? (json['details'] as List).map((i) => Details.fromJson(i)).toList()
//           : null,
//     );
//   }

//   // To JSON method
//   Map<String, dynamic> toJson() {
//     return {
//       'title': title,
//       'details': details?.map((e) => e.toJson()).toList(),
//     };
//   }
// }

// class Details {
//   String? title;
//   String? link;
//   String? video_thumb;
//   String? description;

//   Details({this.title, this.link, this.video_thumb, this.description});

//   // From JSON factory constructor
//   factory Details.fromJson(Map<String, dynamic> json) {
//     return Details(
//       title: json['title'] as String?,
//       link: json['link'] as String?,
//       video_thumb: json['video_thumb'] as String?,
//       description: json['description'] as String?,
//     );
//   }

//   // To JSON method
//   Map<String, dynamic> toJson() {
//     return {
//       'title': title,
//       'link': link,
//       'video_thumb': video_thumb,
//       'description': description,
//     };
//   }
// }

// import 'package:json_annotation/json_annotation.dart';
// part 'videos_list.g.dart';

// @JsonSerializable()
// class VideosList {
//   bool? success;
//   String? message;
//   List<Data>? data;

//   VideosList({this.success, this.message, this.data});

//   factory VideosList.fromJson(Map<String, dynamic> json) =>
//       _$VideosListFromJson(json);
//   Map<String, dynamic> toJson() => _$VideosListToJson(this);
// }

// @JsonSerializable()
// class Data {
//   String? title;
//   List<Details>? details;

//   Data({this.title, this.details});

//   factory Data.fromJson(Map<String, dynamic> json) => _$DataFromJson(json);
//   Map<String, dynamic> toJson() => _$DataToJson(this);
// }

// @JsonSerializable()
// class Details {
//   String? title;
//   String? link;
//   String? video_thumb;
//   String? description;

//   Details({this.title, this.link, this.video_thumb, this.description});

//   factory Details.fromJson(Map<String, dynamic> json) =>
//       _$DetailsFromJson(json);
//   Map<String, dynamic> toJson() => _$DetailsToJson(this);
// }

import 'package:json_annotation/json_annotation.dart';

part 'videos_list.g.dart';

@JsonSerializable()
class VideosList {
  final bool? success; // Indicates if the operation was successful
  final String? message; // Message from the server
  final List<VideoModel>? data; // List of video data

  VideosList({
    this.success,
    this.message,
    this.data,
  });

  // Factory method to parse JSON
  factory VideosList.fromJson(Map<String, dynamic> json) =>
      _$VideosListFromJson(json);

  // Method to convert object to JSON
  Map<String, dynamic> toJson() => _$VideosListToJson(this);
}

@JsonSerializable()
class VideoModel {
  final String? title; // Video title
  final String? category; // Category, e.g., "Music Videos"
  final String? description; // Video description
  final String? thumbnailUrl; // Thumbnail image URL
  final String? videoUrl; // Video URL

  VideoModel({
    this.title,
    this.category,
    this.description,
    this.thumbnailUrl,
    this.videoUrl,
  });

  // Factory method to parse JSON
  factory VideoModel.fromJson(Map<String, dynamic> json) =>
      _$VideoModelFromJson(json);

  // Method to convert object to JSON
  Map<String, dynamic> toJson() => _$VideoModelToJson(this);
}

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'movie_tvshow_videos.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MovieList _$MovieListFromJson(Map<String, dynamic> json) => MovieList(
      success: json['success'] as bool?,
      message: json['message'] as String?,
      data: (json['data'] as List<dynamic>?)
          ?.map((e) => MovieListData.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$MovieListToJson(MovieList instance) => <String, dynamic>{
      'success': instance.success,
      'message': instance.message,
      'data': instance.data,
    };

MovieListData _$MovieListDataFromJson(Map<String, dynamic> json) =>
    MovieListData(
      id: (json['id'] as num?)?.toInt(),
      category: (json['category'] as num?)?.toInt(),
      title: json['title'] as String?,
      link: json['link'] as String?,
      video_thumb: json['video_thumb'] as String?,
      description: json['description'] as String?,
      status: (json['status'] as num?)?.toInt(),
      updated_at: json['updated_at'] as String?,
    );

Map<String, dynamic> _$MovieListDataToJson(MovieListData instance) =>
    <String, dynamic>{
      'id': instance.id,
      'category': instance.category,
      'title': instance.title,
      'link': instance.link,
      'video_thumb': instance.video_thumb,
      'description': instance.description,
      'status': instance.status,
      'updated_at': instance.updated_at,
    };

TvShowList _$TvShowListFromJson(Map<String, dynamic> json) => TvShowList(
      success: json['success'] as bool?,
      message: json['message'] as String?,
      data: (json['data'] as List<dynamic>?)
          ?.map((e) => TvShowListData.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$TvShowListToJson(TvShowList instance) =>
    <String, dynamic>{
      'success': instance.success,
      'message': instance.message,
      'data': instance.data,
    };

TvShowListData _$TvShowListDataFromJson(Map<String, dynamic> json) =>
    TvShowListData(
      id: (json['id'] as num?)?.toInt(),
      category: (json['category'] as num?)?.toInt(),
      title: json['title'] as String?,
      link: json['link'] as String?,
      video_thumb: json['video_thumb'] as String?,
      description: json['description'] as String?,
      status: (json['status'] as num?)?.toInt(),
      updated_at: json['updated_at'] as String?,
    );

Map<String, dynamic> _$TvShowListDataToJson(TvShowListData instance) =>
    <String, dynamic>{
      'id': instance.id,
      'category': instance.category,
      'title': instance.title,
      'link': instance.link,
      'video_thumb': instance.video_thumb,
      'description': instance.description,
      'status': instance.status,
      'updated_at': instance.updated_at,
    };

VideoList _$VideoListFromJson(Map<String, dynamic> json) => VideoList(
      success: json['success'] as bool?,
      message: json['message'] as String?,
      data: (json['data'] as List<dynamic>?)
          ?.map((e) => VideoListData.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$VideoListToJson(VideoList instance) => <String, dynamic>{
      'success': instance.success,
      'message': instance.message,
      'data': instance.data,
    };

VideoListData _$VideoListDataFromJson(Map<String, dynamic> json) =>
    VideoListData(
      id: (json['id'] as num?)?.toInt(),
      category: (json['category'] as num?)?.toInt(),
      title: json['title'] as String?,
      link: json['link'] as String?,
      video_thumb: json['video_thumb'] as String?,
      description: json['description'] as String?,
      status: (json['status'] as num?)?.toInt(),
      updated_at: json['updated_at'] as String?,
    );

Map<String, dynamic> _$VideoListDataToJson(VideoListData instance) =>
    <String, dynamic>{
      'id': instance.id,
      'category': instance.category,
      'title': instance.title,
      'link': instance.link,
      'video_thumb': instance.video_thumb,
      'description': instance.description,
      'status': instance.status,
      'updated_at': instance.updated_at,
    };

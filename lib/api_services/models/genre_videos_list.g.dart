// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'genre_videos_list.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GenreVideosList _$GenreVideosListFromJson(Map<String, dynamic> json) =>
    GenreVideosList(
      success: json['success'] as bool?,
      message: json['message'] as String?,
      data: (json['data'] as List<dynamic>?)
          ?.map((e) => Data.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$GenreVideosListToJson(GenreVideosList instance) =>
    <String, dynamic>{
      'success': instance.success,
      'message': instance.message,
      'data': instance.data,
    };

Data _$DataFromJson(Map<String, dynamic> json) => Data(
      id: (json['id'] as num?)?.toInt(),
      video_id: (json['video_id'] as num?)?.toInt(),
      genre_id: (json['genre_id'] as num?)?.toInt(),
      genre_name: json['genre_name'] as String?,
      category: (json['category'] as num?)?.toInt(),
      title: json['title'] as String?,
      link: json['link'] as String?,
      video_thumb: json['video_thumb'] as String?,
      description: json['description'] as String?,
      status: (json['status'] as num?)?.toInt(),
      subcategory_id: (json['subcategory_id'] as num?)?.toInt(),
      subcategory_name: json['subcategory_name'] as String?,
    );

Map<String, dynamic> _$DataToJson(Data instance) => <String, dynamic>{
      'id': instance.id,
      'video_id': instance.video_id,
      'genre_id': instance.genre_id,
      'genre_name': instance.genre_name,
      'category': instance.category,
      'title': instance.title,
      'link': instance.link,
      'video_thumb': instance.video_thumb,
      'description': instance.description,
      'status': instance.status,
      'subcategory_id': instance.subcategory_id,
      'subcategory_name': instance.subcategory_name,
    };

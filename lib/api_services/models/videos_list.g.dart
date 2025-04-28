// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'videos_list.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

VideosList _$VideosListFromJson(Map<String, dynamic> json) => VideosList(
      success: json['success'] as bool?,
      message: json['message'] as String?,
      data: (json['data'] as List<dynamic>?)
          ?.map((e) => VideoModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$VideosListToJson(VideosList instance) =>
    <String, dynamic>{
      'success': instance.success,
      'message': instance.message,
      'data': instance.data,
    };

VideoModel _$VideoModelFromJson(Map<String, dynamic> json) => VideoModel(
      title: json['title'] as String?,
      category: json['category'] as String?,
      description: json['description'] as String?,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      videoUrl: json['videoUrl'] as String?,
    );

Map<String, dynamic> _$VideoModelToJson(VideoModel instance) =>
    <String, dynamic>{
      'title': instance.title,
      'category': instance.category,
      'description': instance.description,
      'thumbnailUrl': instance.thumbnailUrl,
      'videoUrl': instance.videoUrl,
    };

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'banner_list.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BannerList _$BannerListFromJson(Map<String, dynamic> json) => BannerList(
      success: json['success'] as bool?,
      message: json['message'] as String?,
      data: (json['data'] as List<dynamic>?)
          ?.map((e) => Data.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$BannerListToJson(BannerList instance) =>
    <String, dynamic>{
      'success': instance.success,
      'message': instance.message,
      'data': instance.data,
    };

Data _$DataFromJson(Map<String, dynamic> json) => Data(
      id: (json['id'] as num?)?.toInt(),
      banner: json['banner'] as String?,
      video_id: json['video_id'] as String?,
      status: (json['status'] as num?)?.toInt(),
      link: json['link'] as String?,
      title: json['title'] as String?,
      video_thumb: json['video_thumb'] as String?,
      description: json['description'] as String?,
    );

Map<String, dynamic> _$DataToJson(Data instance) => <String, dynamic>{
      'id': instance.id,
      'banner': instance.banner,
      'video_id': instance.video_id,
      'status': instance.status,
      'link': instance.link,
      'title': instance.title,
      'video_thumb': instance.video_thumb,
      'description': instance.description,
    };

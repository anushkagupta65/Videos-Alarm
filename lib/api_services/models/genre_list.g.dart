// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'genre_list.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GenreList _$GenreListFromJson(Map<String, dynamic> json) => GenreList(
      success: json['success'] as bool?,
      message: json['message'] as String?,
      data: (json['data'] as List<dynamic>?)
          ?.map((e) => Data.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$GenreListToJson(GenreList instance) => <String, dynamic>{
      'success': instance.success,
      'message': instance.message,
      'data': instance.data,
    };

Data _$DataFromJson(Map<String, dynamic> json) => Data(
      id: (json['id'] as num?)?.toInt(),
      genre_name: json['genre_name'] as String?,
      thumbnail: json['thumbnail'] as String?,
    );

Map<String, dynamic> _$DataToJson(Data instance) => <String, dynamic>{
      'id': instance.id,
      'genre_name': instance.genre_name,
      'thumbnail': instance.thumbnail,
    };

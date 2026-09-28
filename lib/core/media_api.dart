// DDE-Mart driver app — generic media API (uploads + public stories).
//
// POST /driver/uploads (multipart `file` field, optional `folder`) backs
// generic photos such as the edit-profile avatar. Document verification
// keeps its own flow (POST /driver/documents multipart front/back).
// GET /stories is public promo content rendered on the Jobs tab.

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';

class DriverStory {
  DriverStory({
    required this.id,
    this.storeName,
    this.videoUrl,
    this.thumbnail,
  });

  factory DriverStory.fromJson(Map<String, dynamic> json) {
    final store = json['store'] as Map?;
    return DriverStory(
      id: json['id'] as int? ?? 0,
      storeName: store?['name']?.toString(),
      videoUrl: json['video_url']?.toString(),
      thumbnail: json['thumbnail']?.toString(),
    );
  }

  final int id;
  final String? storeName;
  final String? videoUrl;
  final String? thumbnail;
}

class DriverMediaApi {
  DriverMediaApi(this._dio);

  final Dio _dio;

  /// Uploads a generic photo (avatar, etc.) to POST /driver/uploads.
  /// Returns {'path', 'url'} from the backend.
  Future<Map<String, String>> uploadFile(
    String path, {
    String folder = 'avatars',
  }) async {
    final filename = path
        .split(RegExp(r'[/\\]'))
        .lastWhere((s) => s.isNotEmpty, orElse: () => 'upload.jpg');
    final form = FormData.fromMap({
      'folder': folder,
      'file': await MultipartFile.fromFile(path, filename: filename),
    });
    final response = await _dio.post('/driver/uploads', data: form);
    final data =
        Map<String, dynamic>.from((response.data as Map)['data'] as Map);
    return {'path': '${data['path']}', 'url': '${data['url']}'};
  }

  /// Public promo stories feed.
  Future<List<DriverStory>> fetchStories() async {
    final response = await _dio.get('/stories');
    return (((response.data as Map)['data'] as List?) ?? [])
        .map((e) => DriverStory.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }
}

final driverMediaApiProvider = Provider<DriverMediaApi>(
  (ref) => DriverMediaApi(ref.watch(dioProvider)),
);

final storiesProvider = FutureProvider<List<DriverStory>>((ref) async {
  return ref.watch(driverMediaApiProvider).fetchStories();
});

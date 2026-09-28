// DDE-Mart driver app — media API client tests.
//
// Covers DriverMediaApi.uploadFile (POST /driver/uploads multipart `file`)
// and fetchStories (GET /stories) with a stubbed Dio.

import 'dart:io';

import 'package:dde_driver/core/media_api.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

Dio stubDio(Future<Response> Function(RequestOptions options) handler) {
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, h) async {
        h.resolve(await handler(options));
      },
    ),
  );
  return dio;
}

void main() {
  group('DriverMediaApi.uploadFile', () {
    test('posts multipart file field to /driver/uploads', () async {
      final tmp =
          await File('${Directory.systemTemp.path}/avatar_test.jpg').create();
      await tmp.writeAsBytes(List<int>.filled(16, 7));

      RequestOptions? seen;
      final api = DriverMediaApi(
        stubDio((options) async {
          seen = options;
          return Response(
            requestOptions: options,
            statusCode: 201,
            data: {
              'data': {'path': 'avatars/a.jpg', 'url': 'http://x/avatars/a.jpg'}
            },
          );
        }),
      );

      final result = await api.uploadFile(tmp.path);
      expect(result['path'], 'avatars/a.jpg');
      expect(result['url'], 'http://x/avatars/a.jpg');
      expect(seen?.path, '/driver/uploads');
      final form = seen?.data as FormData;
      final names = form.files.map((f) => f.key).toList();
      expect(names, contains('file'));
      final fields =
          Map<String, String>.fromEntries(form.fields.map((f) => f));
      expect(fields['folder'], 'avatars');

      await tmp.delete();
    });
  });

  group('DriverMediaApi.fetchStories', () {
    test('parses public stories feed', () async {
      RequestOptions? seen;
      final api = DriverMediaApi(
        stubDio((options) async {
          seen = options;
          return Response(
            requestOptions: options,
            statusCode: 200,
            data: {
              'data': [
                {
                  'id': 1,
                  'store': {'id': 9, 'name': 'Fresh Mart'},
                  'video_url': 'http://x/v1.mp4',
                  'thumbnail': 'http://x/t1.jpg',
                },
                {'id': 2},
              ],
            },
          );
        }),
      );

      final stories = await api.fetchStories();
      expect(seen?.path, '/stories');
      expect(stories, hasLength(2));
      expect(stories.first.storeName, 'Fresh Mart');
      expect(stories.first.thumbnail, 'http://x/t1.jpg');
      expect(stories.last.storeName, isNull);
    });

    test('empty feed parses to empty list', () async {
      final api = DriverMediaApi(
        stubDio((options) async => Response(
          requestOptions: options,
          statusCode: 200,
          data: {'data': []},
        )),
      );
      expect(await api.fetchStories(), isEmpty);
    });
  });
}

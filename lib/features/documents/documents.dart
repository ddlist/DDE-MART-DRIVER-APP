// DDE-Mart driver app — verification documents (original).
//
// GET /driver/documents shows required doc types (front/back rules) plus
// submitted verifications with review status. Submit uploads photo(s) as
// multipart to POST /driver/documents.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api_client.dart';

class DocumentsApi {
  DocumentsApi(this._dio);

  final Dio _dio;

  Future<Map<String, List<Map<String, dynamic>>>> documents() async {
    final response = await _dio.get('/driver/documents');
    final data = (response.data as Map)['data'] as Map;

    List<Map<String, dynamic>> listOf(String key) =>
        (((data[key] as List?) ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList());

    return {'required': listOf('required'), 'submitted': listOf('submitted')};
  }

  Future<void> submit({
    required int documentTypeId,
    XFile? front,
    XFile? back,
  }) async {
    final form = FormData.fromMap({
      'document_type_id': documentTypeId,
      if (front != null)
        'front': await MultipartFile.fromFile(front.path, filename: front.name),
      if (back != null)
        'back': await MultipartFile.fromFile(back.path, filename: back.name),
    });
    await _dio.post('/driver/documents', data: form);
  }
}

final documentsApiProvider = Provider<DocumentsApi>(
  (ref) => DocumentsApi(ref.watch(dioProvider)),
);

final documentsProvider =
    FutureProvider<Map<String, List<Map<String, dynamic>>>>((ref) async {
  return ref.watch(documentsApiProvider).documents();
});

class DocumentsScreen extends ConsumerStatefulWidget {
  const DocumentsScreen({super.key});

  @override
  ConsumerState<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends ConsumerState<DocumentsScreen> {
  final _picker = ImagePicker();
  bool _busy = false;

  Future<void> _submit(
    Map<String, dynamic> type,
    XFile? front,
    XFile? back,
  ) async {
    setState(() => _busy = true);
    try {
      await ref.read(documentsApiProvider).submit(
            documentTypeId: type['id'] as int,
            front: front,
            back: back,
          );
      ref.invalidate(documentsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document submitted for review.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(apiMessage(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickAndSubmit(Map<String, dynamic> type) async {
    // Front photo is always collected as proof; back only when required.
    final front = await _picker.pickImage(source: ImageSource.gallery);
    if (front == null) return;

    XFile? back;
    if ((type['back_required'] ?? false) == true) {
      back = await _picker.pickImage(source: ImageSource.gallery);
      if (back == null) return;
    }
    await _submit(type, front, back);
  }

  @override
  Widget build(BuildContext context) {
    final docs = ref.watch(documentsProvider);

    return docs.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(apiMessage(e)),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => ref.invalidate(documentsProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (data) {
        final required = data['required'] ?? [];
        final submitted = data['submitted'] ?? [];

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(documentsProvider),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Required documents',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (required.isEmpty) const Text('Nothing required.'),
              for (final type in required)
                Card(
                  child: ListTile(
                    title: Text('${type['title']}'),
                    subtitle: Text(
                      'Front: ${type['front_required'] == true ? 'yes' : 'no'} · '
                      'Back: ${type['back_required'] == true ? 'yes' : 'no'}',
                    ),
                    trailing: FilledButton.tonal(
                      onPressed: _busy ? null : () => _pickAndSubmit(type),
                      child: const Text('Upload'),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              Text('Submitted', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (submitted.isEmpty) const Text('Nothing submitted.'),
              for (final row in submitted)
                Card(
                  child: ListTile(
                    title: Text('${row['document'] ?? 'Document'}'),
                    subtitle: Text('${row['note'] ?? ''}'),
                    trailing: Text('${row['status']}'),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

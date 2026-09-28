// DDE-Mart driver app — verification documents.
//
// GET /driver/documents shows required doc types (front/back rules) plus
// submitted verifications with review status. Submit uploads photo(s) as
// multipart to POST /driver/documents.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api_client.dart';
import '../../core/widgets.dart';

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

    return Column(
      children: [
        GradientHeader(
          title: 'Documents',
          subtitle: 'Verify your identity to stay active.',
          icon: Icons.badge_outlined,
        ),
        Expanded(
          child: docs.when(
            loading: () => ListView(
              padding: const EdgeInsets.all(16),
              children: const [
                ShimmerBox(height: 120, borderRadius: 24),
                SizedBox(height: 12),
                ShimmerBox(height: 76, borderRadius: 20),
                SizedBox(height: 8),
                ShimmerBox(height: 76, borderRadius: 20),
              ],
            ),
            error: (e, _) => ErrorRetry(
              error: e,
              onRetry: () => ref.invalidate(documentsProvider),
            ),
            data: (data) {
              final required = data['required'] ?? [];
              final submitted = data['submitted'] ?? [];

              return RefreshIndicator(
                onRefresh: () async => ref.invalidate(documentsProvider),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Row(
                      children: [
                        StatCard(
                          icon: Icons.assignment_outlined,
                          value: '${required.length}',
                          label: 'Required',
                        ),
                        const SizedBox(width: 12),
                        StatCard(
                          icon: Icons.verified_outlined,
                          value: '${submitted.length}',
                          label: 'Submitted',
                          success: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text('Required documents',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    if (required.isEmpty)
                      const EmptyState(
                        message: 'Nothing required.',
                        icon: Icons.verified_outlined,
                      ),
                    for (final type in required)
                      SleekCard(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primaryContainer,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                Icons.description_outlined,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onPrimaryContainer,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${type['title']}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall,
                                  ),
                                  Text(
                                    'Front: ${type['front_required'] == true ? 'yes' : 'no'} · '
                                    'Back: ${type['back_required'] == true ? 'yes' : 'no'}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            FilledButton.tonal(
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                              ),
                              onPressed:
                                  _busy ? null : () => _pickAndSubmit(type),
                              child: const Text('Upload'),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 16),
                    Text('Submitted',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    if (submitted.isEmpty)
                      const EmptyState(
                        message: 'Nothing submitted yet.',
                        icon: Icons.upload_file_outlined,
                      ),
                    for (final row in submitted)
                      SleekCard(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${row['document'] ?? 'Document'}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall,
                                  ),
                                  if ('${row['note'] ?? ''}'.isNotEmpty)
                                    Text(
                                      '${row['note']}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                ],
                              ),
                            ),
                            StatusChip(status: '${row['status']}'),
                          ],
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

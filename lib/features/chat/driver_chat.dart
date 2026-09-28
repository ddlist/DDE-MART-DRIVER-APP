// DDE-Mart driver app — support chat inbox.
//
// Threads linked to this driver (customer opened from an order number),
// with reply. Matches GET|POST /driver/chat/threads*.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/nav.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

Map<String, dynamic> _item(Map e) => Map<String, dynamic>.from(e);

List<Map<String, dynamic>> _list(Object? data) =>
    ((data as List?) ?? []).map((e) => _item(e as Map)).toList();

class DriverChatApi {
  DriverChatApi(this._dio);

  final Dio _dio;

  Future<List<Map<String, dynamic>>> threads() async {
    final r = await _dio.get('/driver/chat/threads');
    return _list((r.data as Map)['data']);
  }

  Future<Map<String, dynamic>> thread(int id) async {
    final r = await _dio.get('/driver/chat/threads/$id');
    return _item((r.data as Map)['data'] as Map);
  }

  Future<void> reply({required int threadId, required String message}) async {
    await _dio.post('/driver/chat/threads/$threadId/reply', data: {
      'message': message,
    });
  }
}

final driverChatApiProvider = Provider<DriverChatApi>(
  (ref) => DriverChatApi(ref.watch(dioProvider)),
);

void _fail(BuildContext context, Object e) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(apiMessage(e))),
  );
}

class DriverChatThreadsScreen extends ConsumerWidget {
  const DriverChatThreadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        const GradientHeader(
          title: 'Messages',
          subtitle: 'Customer conversations on your jobs.',
          icon: Icons.chat_outlined,
        ),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: ref.watch(driverChatApiProvider).threads(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: const [
                    ShimmerBox(height: 76, borderRadius: 20),
                    SizedBox(height: 8),
                    ShimmerBox(height: 76, borderRadius: 20),
                    SizedBox(height: 8),
                    ShimmerBox(height: 76, borderRadius: 20),
                  ],
                );
              }
              if (snapshot.hasError) {
                return ErrorRetry(
                  error: snapshot.error!,
                  onRetry: () => (context as Element).markNeedsBuild(),
                );
              }
              final rows = snapshot.data!;
              if (rows.isEmpty) {
                return const EmptyState(
                  message: 'No messages from customers.',
                  icon: Icons.chat_bubble_outline,
                );
              }
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (final row in rows)
                    SleekCard(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      onTap: () =>
                          context.safePush('/chat/${row['id']}'),
                      child: Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration:
                                DdeTheme.iconTile(context, radius: 15),
                            child: const Icon(
                              Icons.person_outline,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${row['subject'] ?? 'Conversation'}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall,
                                ),
                                Text(
                                  '${row['last_message'] ?? ''}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
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
                          Icon(
                            Icons.chevron_right,
                            color:
                                Theme.of(context).colorScheme.outline,
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class DriverChatThreadScreen extends ConsumerStatefulWidget {
  const DriverChatThreadScreen({super.key, required this.threadId});

  final int threadId;

  @override
  ConsumerState<DriverChatThreadScreen> createState() =>
      _DriverChatThreadScreenState();
}

class _DriverChatThreadScreenState
    extends ConsumerState<DriverChatThreadScreen> {
  final _message = TextEditingController();
  Map<String, dynamic>? _thread;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _thread = await ref.read(driverChatApiProvider).thread(widget.threadId);
    } catch (e) {
      if (mounted) _fail(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final text = _message.text.trim();
    if (text.isEmpty) return;

    setState(() => _busy = true);
    try {
      await ref.read(driverChatApiProvider).reply(
            threadId: widget.threadId,
            message: text,
          );
      _message.clear();
      await _load();
    } catch (e) {
      if (mounted) _fail(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final messages = _thread == null ? [] : _list(_thread!['messages']);

    return Scaffold(
      appBar: AppBar(title: Text('${_thread?['subject'] ?? 'Conversation'}')),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? ListView(
                    padding: const EdgeInsets.all(16),
                    children: const [
                      ShimmerBox(height: 56, borderRadius: 18),
                      SizedBox(height: 8),
                      ShimmerBox(height: 56, borderRadius: 18),
                      SizedBox(height: 8),
                      ShimmerBox(height: 56, borderRadius: 18),
                    ],
                  )
                : messages.isEmpty
                    ? const EmptyState(
                        message: 'No messages yet. Say hello!',
                        icon: Icons.chat_bubble_outline,
                      )
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          for (final message in messages)
                            Align(
                              alignment:
                                  (message['from_me'] ?? false) == true
                                      ? Alignment.centerRight
                                      : Alignment.centerLeft,
                              child: Container(
                                margin:
                                    const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                constraints: BoxConstraints(
                                  maxWidth:
                                      MediaQuery.of(context).size.width *
                                          0.75,
                                ),
                                decoration: BoxDecoration(
                                  gradient: (message['from_me'] ??
                                              false) ==
                                          true
                                      ? LinearGradient(
                                          colors: [
                                            scheme.primary,
                                            DdeTheme.primaryDark,
                                          ],
                                        )
                                      : null,
                                  color: (message['from_me'] ?? false) ==
                                          true
                                      ? null
                                      : scheme.surfaceContainerHighest
                                          .withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(18),
                                  boxShadow: DdeTheme.softShadow(context),
                                ),
                                child: Text(
                                  '${message['body']}',
                                  style: TextStyle(
                                    color: (message['from_me'] ??
                                                false) ==
                                            true
                                        ? Colors.white
                                        : scheme.onSurface,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _message,
                      decoration: const InputDecoration(
                        labelText: 'Reply',
                        prefixIcon: Icon(Icons.message_outlined),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration:
                        DdeTheme.headerGradient(context).copyWith(
                      shape: BoxShape.circle,
                      boxShadow: DdeTheme.softShadow(context),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white),
                      onPressed: _busy ? null : _send,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

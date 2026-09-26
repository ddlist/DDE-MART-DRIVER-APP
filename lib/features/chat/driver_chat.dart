// DDE-Mart driver app — support chat inbox (original).
//
// Threads linked to this driver (customer opened from an order number),
// with reply. Matches GET|POST /driver/chat/threads*.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';

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
    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: ref.watch(driverChatApiProvider).threads(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(apiMessage(snapshot.error!)));
          }
          final rows = snapshot.data!;
          if (rows.isEmpty) {
            return const Center(child: Text('No messages from customers.'));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final row in rows)
                Card(
                  child: ListTile(
                    title: Text('${row['subject'] ?? 'Conversation'}'),
                    subtitle: Text('${row['last_message'] ?? ''}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/chat/${row['id']}'),
                  ),
                ),
            ],
          );
        },
      ),
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
    final messages = _thread == null ? [] : _list(_thread!['messages']);

    return Scaffold(
      appBar: AppBar(title: Text('${_thread?['subject'] ?? 'Conversation'}')),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : messages.isEmpty
                    ? const Center(child: Text('No messages yet.'))
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          for (final message in messages)
                            Align(
                              alignment: (message['from_me'] ?? false) == true
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Card(
                                color: (message['from_me'] ?? false) == true
                                    ? Colors.blue.shade100
                                    : null,
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Text('${message['body']}'),
                                ),
                              ),
                            ),
                        ],
                      ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _message,
                    decoration: const InputDecoration(labelText: 'Reply'),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _busy ? null : _send,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

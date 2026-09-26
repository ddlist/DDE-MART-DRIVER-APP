// DDE-Mart driver app — jobs API + screens (original).
//
// GET /driver/jobs returns {mine, pool} of parcel/rental/ride jobs shaped as
// {type, id, number, status, total}. Accept claims a pool job; transition
// advances an owned job (accepted → ongoing → completed).

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';

class DriverJob {
  DriverJob({
    required this.type,
    required this.id,
    required this.number,
    required this.status,
    required this.total,
  });

  factory DriverJob.fromJson(Map<String, dynamic> json) => DriverJob(
        type: '${json['type']}',
        id: json['id'] as int,
        number: '${json['number'] ?? ''}',
        status: '${json['status']}',
        total: (json['total'] as num?)?.toDouble() ?? 0,
      );

  final String type;
  final int id;
  final String number;
  final String status;
  final double total;
}

class JobsBundle {
  JobsBundle({required this.mine, required this.pool});

  final List<DriverJob> mine;
  final List<DriverJob> pool;
}

class JobsApi {
  JobsApi(this._dio);

  final Dio _dio;

  Future<JobsBundle> jobs() async {
    final response = await _dio.get('/driver/jobs');
    final data = (response.data as Map)['data'] as Map;
    List<DriverJob> listOf(String key) => ((data[key] as List?) ?? [])
        .map((e) => DriverJob.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    return JobsBundle(mine: listOf('mine'), pool: listOf('pool'));
  }

  Future<void> accept({required String type, required int id}) async {
    await _dio.post('/driver/jobs/accept', data: {'type': type, 'id': id});
  }

  Future<void> transition({
    required String type,
    required int id,
    required String to,
  }) async {
    await _dio.post(
      '/driver/jobs/transition',
      data: {'type': type, 'id': id, 'to': to},
    );
  }

  Future<void> availability(bool online) async {
    await _dio.post('/driver/availability', data: {'is_online': online});
  }

  Future<void> location({required double latitude, required double longitude}) async {
    await _dio.post('/driver/location', data: {
      'latitude': latitude,
      'longitude': longitude,
    });
  }

  Future<Map<String, dynamic>> profile() async {
    final response = await _dio.get('/driver/profile');
    return Map<String, dynamic>.from((response.data as Map)['data'] as Map);
  }
}

final jobsApiProvider = Provider<JobsApi>(
  (ref) => JobsApi(ref.watch(dioProvider)),
);

final jobsProvider = FutureProvider<JobsBundle>((ref) async {
  return ref.watch(jobsApiProvider).jobs();
});

/// Next legal move shown per job: pool jobs can be accepted; owned jobs move
/// along their own machine (food/parcel ship, rental/rides go ongoing).
String? nextMove(DriverJob job, {required bool owned}) {
  if (!owned) return 'accepted';
  return switch ((job.type, job.status)) {
    ('food', 'accepted') || ('parcel', 'accepted') => 'shipped',
    ('rental', 'accepted') || ('ride', 'accepted') => 'ongoing',
    ('food', 'shipped') ||
    ('parcel', 'shipped') ||
    ('rental', 'ongoing') ||
    ('ride', 'ongoing') =>
      'completed',
    _ => null,
  };
}

class JobsScreen extends ConsumerStatefulWidget {
  const JobsScreen({super.key});

  @override
  ConsumerState<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends ConsumerState<JobsScreen> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() call) async {
    setState(() => _busy = true);
    try {
      await call();
      ref.invalidate(jobsProvider);
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

  Widget _tile(DriverJob job, {required bool owned}) {
    final move = _busy ? null : nextMove(job, owned: owned);
    final icon = switch (job.type) {
      'parcel' => Icons.local_shipping_outlined,
      'rental' => Icons.car_rental_outlined,
      'ride' => Icons.local_taxi_outlined,
      _ => Icons.fastfood_outlined,
    };
    final statusColor = switch (job.status) {
      'placed' => Colors.orange,
      'accepted' => Colors.blue,
      'ongoing' => Colors.purple,
      'completed' => Colors.green,
      _ => Colors.grey,
    };

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(icon, color: Theme.of(context).colorScheme.onPrimaryContainer),
        ),
        title: Text(
          '${job.type.toUpperCase()} · ${job.number}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                job.status.toUpperCase(),
                style: TextStyle(
                  color: statusColor,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(job.total.toStringAsFixed(2)),
          ],
        ),
        trailing: move == null
            ? null
            : FilledButton(
                onPressed: () => owned
                    ? _run(
                        () => ref.read(jobsApiProvider).transition(
                              type: job.type,
                              id: job.id,
                              to: move,
                            ),
                      )
                    : _run(
                        () => ref.read(jobsApiProvider).accept(
                              type: job.type,
                              id: job.id,
                            ),
                      ),
                child: Text(owned ? move : 'Accept'),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final jobs = ref.watch(jobsProvider);

    return jobs.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(apiMessage(e)),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => ref.invalidate(jobsProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (bundle) => RefreshIndicator(
        onRefresh: () async => ref.invalidate(jobsProvider),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('My jobs', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (bundle.mine.isEmpty) const Text('Nothing assigned.'),
            for (final job in bundle.mine) _tile(job, owned: true),
            const SizedBox(height: 16),
            Text('Available', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (bundle.pool.isEmpty) const Text('No open jobs right now.'),
            for (final job in bundle.pool) _tile(job, owned: false),
          ],
        ),
      ),
    );
  }
}

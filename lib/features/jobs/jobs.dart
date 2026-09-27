// DDE-Mart driver app — jobs API + screens (original).
//
// GET /driver/jobs returns {mine, pool} of parcel/rental/ride jobs shaped as
// {type, id, number, status, total}. Accept claims a pool job; transition
// advances an owned job (accepted → ongoing → completed).

// ignore_for_file: use_null_aware_elements

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/nav.dart';
import '../../core/widgets.dart';

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

  Future<Map<String, dynamic>> detail(
      {required String type, required int id}) async {
    final response = await _dio.get('/driver/jobs/$type/$id');
    return Map<String, dynamic>.from((response.data as Map)['data'] as Map);
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

  Future<void> updateProfile({String? name, String? vehicleInfo}) async {
    await _dio.put('/driver/profile', data: {
      if (name case final n?) 'name': n,
      if (vehicleInfo case final v?) 'vehicle_info': v,
    });
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
            StatusChip(status: job.status),
            const SizedBox(width: 8),
            Text(job.total.toStringAsFixed(2)),
          ],
        ),
        trailing: move == null
            ? const Icon(Icons.chevron_right)
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
        onTap: () => context.safePush('/job-detail', extra: (job, owned)),
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
            if (bundle.mine.isEmpty)
              const EmptyState(
                message: 'Nothing assigned. Stay online for offers.',
                icon: Icons.work_outline,
              ),
            for (final job in bundle.mine) _tile(job, owned: true),
            const SizedBox(height: 16),
            Text('Available nearby',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (bundle.pool.isEmpty)
              const EmptyState(
                message: 'No open jobs right now.',
                icon: Icons.search_outlined,
              ),
            for (final job in bundle.pool) _tile(job, owned: false),
          ],
        ),
      ),
    );
  }
}

/// Job detail: big status, fare, and the single next action.
/// Route addresses land with the tracking upgrade; until then the list
/// assignment plus these moves cover the whole driver flow.
class JobDetailScreen extends ConsumerStatefulWidget {
  const JobDetailScreen({super.key, required this.job, required this.owned});

  final DriverJob job;
  final bool owned;

  @override
  ConsumerState<JobDetailScreen> createState() => _JobDetailScreenState();
}

final jobDetailProvider = FutureProvider.family<Map<String, dynamic>,
    ({String type, int id})>((ref, args) async {
  return ref.watch(jobsApiProvider).detail(type: args.type, id: args.id);
});

class _JobDetailScreenState extends ConsumerState<JobDetailScreen> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() call,
      {bool popAfter = false}) async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await call();
      ref.invalidate(jobsProvider);
      ref.invalidate(jobDetailProvider(
          (type: widget.job.type, id: widget.job.id)));
      if (popAfter && mounted) GoRouter.of(context).pop();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(apiMessage(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final owned = widget.owned;
    final detail =
        ref.watch(jobDetailProvider((type: widget.job.type, id: widget.job.id)));

    return Scaffold(
      appBar: AppBar(title: Text(widget.job.number)),
      body: detail.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(apiMessage(e))),
        data: (data) {
          final status = '${data['status'] ?? widget.job.status}';
          final move = _busy
              ? null
              : nextMove(
                  DriverJob(
                    type: widget.job.type,
                    id: widget.job.id,
                    number: widget.job.number,
                    status: status,
                    total: ((data['total'] as num?) ??
                            widget.job.total)
                        .toDouble(),
                  ),
                  owned: owned,
                );
          final items = ((data['items'] as List?) ?? [])
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          final timeline = ((data['timeline'] as List?) ?? [])
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(jobDetailProvider(
                  (type: widget.job.type, id: widget.job.id)));
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${data['number'] ?? widget.job.number}',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge,
                              ),
                            ),
                            StatusChip(status: status),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${widget.job.type.toUpperCase()} · Fare ${((data['total'] as num?) ?? widget.job.total).toDouble().toStringAsFixed(2)}',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall,
                        ),
                        if (data['payment_method'] != null)
                          Text(
                            'Pay via ${data['payment_method']}',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall,
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _partyCard(context, data),
                if (items.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                                8, 8, 8, 0),
                            child: Text('Items',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium),
                          ),
                          for (final item in items)
                            ListTile(
                              title: Text(
                                  '${item['name']} × ${item['quantity']}'),
                              trailing: Text(
                                  '${item['subtotal'] ?? ''}'),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
                if (timeline.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text('Progress',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium),
                          const SizedBox(height: 8),
                          for (var i = 0;
                              i < timeline.length;
                              i++)
                            ListTile(
                              contentPadding:
                                  EdgeInsets.zero,
                              leading: Icon(
                                Icons.circle,
                                size: 10,
                                color: StatusChip.colorFor(
                                    '${timeline[i]['to'] ?? ''}'),
                              ),
                              title: Text(
                                  '${timeline[i]['to'] ?? ''}'),
                              subtitle:
                                  timeline[i]['at'] == null
                                      ? null
                                      : Text(
                                          '${timeline[i]['at']}'),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                if (move != null)
                  FilledButton(
                    onPressed: _busy
                        ? null
                        : () => owned
                            ? _run(
                                () => ref
                                    .read(jobsApiProvider)
                                    .transition(
                                      type: widget.job.type,
                                      id: widget.job.id,
                                      to: move,
                                    ),
                                popAfter:
                                    move == 'completed',
                              )
                            : _run(
                                () => ref
                                    .read(jobsApiProvider)
                                    .accept(
                                      type: widget.job.type,
                                      id: widget.job.id,
                                    ),
                                popAfter: true,
                              ),
                    child: Text(
                      _busy
                          ? 'Working…'
                          : owned
                              ? 'Mark $move'
                              : 'Accept job',
                    ),
                  )
                else
                  const Text(
                    'Nothing to do — this job is finished or locked.',
                    textAlign: TextAlign.center,
                  ),
                const SizedBox(height: 80),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Customer / pickup / drop-off card, shaped per job vertical.
  Widget _partyCard(BuildContext context, Map<String, dynamic> data) {
    final type = widget.job.type;
    if (type == 'parcel') {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _partyRow(context, Icons.store_outlined, 'Pickup',
                  '${data['sender_name'] ?? ''}',
                  '${data['sender_address'] ?? ''}',
                  phone: '${data['sender_phone'] ?? ''}'),
              const Divider(height: 24),
              _partyRow(context, Icons.home_outlined, 'Drop-off',
                  '${data['receiver_name'] ?? ''}',
                  '${data['receiver_address'] ?? ''}',
                  phone: '${data['receiver_phone'] ?? ''}'),
              if (data['distance_km'] != null) ...[
                const SizedBox(height: 8),
                Text('Distance: ${data['distance_km']} km',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ],
          ),
        ),
      );
    }
    if (type == 'rental' || type == 'ride') {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _partyRow(context, Icons.person_outline, 'Customer',
                  '${data['customer_name'] ?? ''}', null,
                  phone: '${data['customer_phone'] ?? ''}'),
              const Divider(height: 24),
              _partyRow(context, Icons.trip_origin, 'From',
                  '${data['source'] ?? ''}', null),
              const SizedBox(height: 8),
              _partyRow(context, Icons.place_outlined, 'To',
                  '${data['destination'] ?? ''}', null),
              if (data['distance_km'] != null) ...[
                const SizedBox(height: 8),
                Text('Distance: ${data['distance_km']} km',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ],
          ),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _partyRow(context, Icons.person_outline, 'Customer',
                '${data['customer_name'] ?? ''}', '${data['address'] ?? ''}',
                phone: '${data['customer_phone'] ?? ''}'),
            if (data['notes'] != null &&
                '${data['notes']}'.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Note: ${data['notes']}',
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }

  Widget _partyRow(BuildContext context, IconData icon, String label,
      String title, String? subtitle,
      {String phone = ''}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: Theme.of(context).textTheme.bodySmall),
              Text(title,
                  style:
                      const TextStyle(fontWeight: FontWeight.w700)),
              if (subtitle != null && subtitle.isNotEmpty)
                Text(subtitle),
              if (phone.isNotEmpty)
                Text(phone,
                    style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

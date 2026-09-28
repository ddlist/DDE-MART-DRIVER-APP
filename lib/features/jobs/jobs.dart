// DDE-Mart driver app — jobs API + screens.
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
import '../../core/media_api.dart';
import '../../core/nav.dart';
import '../../core/theme.dart';
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

IconData jobIcon(String type) => switch (type) {
      'parcel' => Icons.local_shipping_outlined,
      'rental' => Icons.car_rental_outlined,
      'ride' => Icons.local_taxi_outlined,
      _ => Icons.fastfood_outlined,
    };

class JobsScreen extends ConsumerStatefulWidget {
  const JobsScreen({super.key});

  @override
  ConsumerState<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends ConsumerState<JobsScreen> {
  bool _busy = false;
  bool _online = true;

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

    return SleekCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      onTap: () => context.safePush('/job-detail', extra: (job, owned)),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: DdeTheme.iconTile(context),
            child: Icon(jobIcon(job.type), color: Colors.white, size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${job.type.toUpperCase()} · ${job.number}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    StatusChip(status: job.status),
                    const SizedBox(width: 8),
                    Text(
                      job.total.toStringAsFixed(2),
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(
                            color:
                                Theme.of(context).colorScheme.primary,
                          ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (move == null)
            Icon(
              Icons.chevron_right,
              color: Theme.of(context).colorScheme.outline,
            )
          else
            FilledButton(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
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
        ],
      ),
    );
  }

  Widget _shimmerList() => Column(
        children: [
          for (var i = 0; i < 4; i++)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: ShimmerBox(height: 84, borderRadius: 24),
            ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final jobs = ref.watch(jobsProvider);
    final stories = ref.watch(storiesProvider);

    return Column(
      children: [
        GradientHeader(
          title: 'Jobs',
          subtitle: _online
              ? 'You are online — offers are coming in.'
              : 'You are offline — go online for offers.',
          icon: Icons.work_outline,
          trailing: Switch(
            value: _online,
            activeThumbColor: Colors.white,
            activeTrackColor: Colors.white.withValues(alpha: 0.35),
            onChanged: (value) async {
              setState(() => _online = value);
              try {
                await ref.read(jobsApiProvider).availability(value);
                ref.invalidate(jobsProvider);
              } catch (e) {
                if (context.mounted) {
                  setState(() => _online = !value);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(apiMessage(e))),
                  );
                }
              }
            },
          ),
        ),
        Expanded(
          child: jobs.when(
            loading: () => ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const ShimmerBox(height: 88, borderRadius: 60),
                const SizedBox(height: 12),
                _shimmerList(),
              ],
            ),
            error: (e, _) => ErrorRetry(
              error: e,
              onRetry: () => ref.invalidate(jobsProvider),
            ),
            data: (bundle) => RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(jobsProvider);
                ref.invalidate(storiesProvider);
              },
              child: ListView(
                padding: const EdgeInsets.only(bottom: 16),
                children: [
                  stories.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: ShimmerBox(height: 88, borderRadius: 60),
                    ),
                    error: (_, _) => const SizedBox.shrink(),
                    data: (rows) => rows.isEmpty
                        ? const SizedBox.shrink()
                        : StoryStrip(stories: rows),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Row(
                      children: [
                        StatCard(
                          icon: Icons.assignment_turned_in_outlined,
                          value: '${bundle.mine.length}',
                          label: 'My jobs',
                        ),
                        const SizedBox(width: 12),
                        StatCard(
                          icon: Icons.explore_outlined,
                          value: '${bundle.pool.length}',
                          label: 'Nearby pool',
                          accent: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'My jobs',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        if (bundle.mine.isEmpty)
                          const EmptyState(
                            message:
                                'Nothing assigned. Stay online for offers.',
                            icon: Icons.work_outline,
                          ),
                        for (final job in bundle.mine)
                          _tile(job, owned: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Available nearby',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        if (bundle.pool.isEmpty)
                          const EmptyState(
                            message: 'No open jobs right now.',
                            icon: Icons.search_outlined,
                          ),
                        for (final job in bundle.pool)
                          _tile(job, owned: false),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Job detail: fare hero, parties, items, timeline and the next action.
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
        loading: () => ListView(
          padding: const EdgeInsets.all(16),
          children: const [
            ShimmerBox(height: 150, borderRadius: 24),
            SizedBox(height: 12),
            ShimmerBox(height: 110, borderRadius: 24),
            SizedBox(height: 12),
            ShimmerBox(height: 110, borderRadius: 24),
          ],
        ),
        error: (e, _) => ErrorRetry(
          error: e,
          onRetry: () => ref.invalidate(
            jobDetailProvider((type: widget.job.type, id: widget.job.id)),
          ),
        ),
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
          final fare =
              (((data['total'] as num?) ?? widget.job.total)).toDouble();

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(jobDetailProvider(
                  (type: widget.job.type, id: widget.job.id)));
            },
            child: ListView(
              padding: const EdgeInsets.only(bottom: 16),
              children: [
                _FareHero(
                  number: '${data['number'] ?? widget.job.number}',
                  type: widget.job.type,
                  status: status,
                  fare: fare,
                  paymentMethod: data['payment_method']?.toString(),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _partyCard(context, data),
                ),
                if (items.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SleekCard(
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
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SleekCard(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text('Progress',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium),
                          const SizedBox(height: 12),
                          TimelineDots(
                            steps: [
                              for (final entry in timeline)
                                TimelineStep(
                                  label: '${entry['to'] ?? ''}',
                                  detail: entry['at'] == null
                                      ? null
                                      : '${entry['at']}',
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SleekCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Fare breakdown',
                          style:
                              Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        BillRow(
                          label: '${widget.job.type.toUpperCase()} job',
                          value: fare.toStringAsFixed(2),
                          icon: Icons.receipt_long_outlined,
                        ),
                        if (data['payment_method'] != null)
                          BillRow(
                            label: 'Payment',
                            value: '${data['payment_method']}',
                            icon: Icons.payments_outlined,
                          ),
                        const Divider(height: 20),
                        BillRow(
                          label: 'You earn',
                          value: fare.toStringAsFixed(2),
                          bold: true,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: move != null
                      ? FilledButton(
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
                      : const EmptyState(
                          message:
                              'Nothing to do — this job is finished or locked.',
                          icon: Icons.check_circle_outline,
                        ),
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
      return SleekCard(
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
      );
    }
    if (type == 'rental' || type == 'ride') {
      return SleekCard(
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
      );
    }
    return SleekCard(
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
    );
  }

  Widget _partyRow(BuildContext context, IconData icon, String label,
      String title, String? subtitle,
      {String phone = ''}) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: DdeTheme.iconTile(context, radius: 12),
          child: Icon(icon, size: 20, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      )),
              Text(title,
                  style:
                      const TextStyle(fontWeight: FontWeight.w700)),
              if (subtitle != null && subtitle.isNotEmpty)
                Text(subtitle),
              if (phone.isNotEmpty)
                Text(phone,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        )),
            ],
          ),
        ),
      ],
    );
  }
}

/// Gradient fare hero card on the job detail screen.
class _FareHero extends StatelessWidget {
  const _FareHero({
    required this.number,
    required this.type,
    required this.status,
    required this.fare,
    this.paymentMethod,
  });

  final String number;
  final String type;
  final String status;
  final double fare;
  final String? paymentMethod;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: DdeTheme.headerGradient(context).copyWith(
        borderRadius: BorderRadius.circular(DdeTheme.radiusCardLg),
        boxShadow: DdeTheme.softShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  jobIcon(type),
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      number,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(color: Colors.white),
                    ),
                    Text(
                      type.toUpperCase(),
                      style: Theme.of(context)
                          .textTheme
                          .labelLarge
                          ?.copyWith(
                            color:
                                Colors.white.withValues(alpha: 0.8),
                            letterSpacing: 2,
                          ),
                    ),
                  ],
                ),
              ),
              StatusChip(status: status),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'FARE',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.75),
                  letterSpacing: 2,
                ),
          ),
          Text(
            fare.toStringAsFixed(2),
            style: Theme.of(context)
                .textTheme
                .displayLarge
                ?.copyWith(color: Colors.white),
          ),
          if (paymentMethod != null)
            Text(
              'Pay via $paymentMethod',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
            ),
        ],
      ),
    );
  }
}

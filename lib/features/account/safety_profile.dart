// DDE-Mart driver app — SOS + profile (original).
//
// POST /driver/sos {latitude, longitude, order_ref?} raises an alert the
// admin safety inbox triages. Coordinates come from the device GPS once the
// location plugin lands — until then the driver can type or paste them.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import 'package:package_info_plus/package_info_plus.dart';

import '../../core/api_client.dart';
import '../../core/auth_store.dart';
import '../../core/nav.dart';
import '../../core/push.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../auth/driver_auth_api.dart';
import '../jobs/jobs.dart';

class SosApi {
  SosApi(this._dio);

  final Dio _dio;

  Future<void> raise({
    required double latitude,
    required double longitude,
    String? orderRef,
  }) async {
    await _dio.post('/driver/sos', data: {
      'latitude': latitude,
      'longitude': longitude,
      if (orderRef != null && orderRef.isNotEmpty) 'order_ref': orderRef,
    });
  }
}

final sosApiProvider = Provider<SosApi>(
  (ref) => SosApi(ref.watch(dioProvider)),
);

class SosScreen extends ConsumerStatefulWidget {
  const SosScreen({super.key});

  @override
  ConsumerState<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends ConsumerState<SosScreen> {
  final _lat = TextEditingController();
  final _lng = TextEditingController();
  final _order = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _lat.dispose();
    _lng.dispose();
    _order.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Emergency SOS. Sends your location to DDE-Mart safety staff.',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _lat,
          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
          decoration: const InputDecoration(labelText: 'Latitude'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _lng,
          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
          decoration: const InputDecoration(labelText: 'Longitude'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _order,
          decoration: const InputDecoration(labelText: 'Order ref (optional)'),
        ),
        const SizedBox(height: 20),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
          onPressed: _busy
              ? null
              : () async {
                  final lat = double.tryParse(_lat.text.trim());
                  final lng = double.tryParse(_lng.text.trim());
                  if (lat == null || lng == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Enter valid coordinates.')),
                    );
                    return;
                  }
                  setState(() => _busy = true);
                  try {
                    await ref.read(sosApiProvider).raise(
                          latitude: lat,
                          longitude: lng,
                          orderRef: _order.text.trim(),
                        );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('SOS sent. Help is on the way.')),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(apiMessage(e))),
                      );
                    }
                  } finally {
                    if (mounted) setState(() => _busy = false);
                  }
                },
          child: Text(_busy ? 'Sending…' : 'SEND SOS'),
        ),
      ],
    );
  }
}

class DriverProfileScreen extends ConsumerWidget {
  const DriverProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStoreProvider);
    final themeMode = ref.watch(themeModeProvider);

    return FutureBuilder<Map<String, dynamic>>(
      future: ref.watch(jobsApiProvider).profile(),
      builder: (context, snapshot) {
        final profile = snapshot.data;
        final online = (profile?['is_online'] ?? false) == true;
        final name = '${profile?['name'] ?? auth.name ?? 'Driver'}';
        final initial =
            name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (snapshot.hasError) Text(apiMessage(snapshot.error!)),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      child: Text(initial,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(name,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge),
                          Text(
                              '${profile?['phone'] ?? auth.phone ?? ''}'),
                          Row(
                            children: [
                              StatusChip(
                                  status:
                                      '${profile?['status'] ?? '…'}'),
                              const SizedBox(width: 6),
                              StatusChip(
                                  status: online
                                      ? 'online'
                                      : 'offline'),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      tooltip: 'Edit profile',
                      onPressed: () =>
                          context.safePush('/profile/edit'),
                    ),
                  ],
                ),
              ),
            ),
            if ('${profile?['vehicle_info'] ?? ''}'.isNotEmpty)
              Card(
                child: ListTile(
                  leading:
                      const Icon(Icons.two_wheeler_outlined),
                  title: const Text('Vehicle'),
                  subtitle:
                      Text('${profile?['vehicle_info']}'),
                ),
              ),
            Card(
              child: SwitchListTile(
                title: const Text('Online for jobs'),
                subtitle: const Text(
                    'Offers only arrive while online'),
                value: online,
                onChanged: snapshot.hasData
                    ? (value) async {
                        try {
                          await ref
                              .read(jobsApiProvider)
                              .availability(value);
                          ref.invalidate(jobsProvider);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context)
                                .showSnackBar(
                              SnackBar(
                                content: Text(value
                                    ? 'You are online.'
                                    : 'You are offline.'),
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context)
                                .showSnackBar(
                              SnackBar(
                                  content:
                                      Text(apiMessage(e))),
                            );
                          }
                        }
                      }
                    : null,
              ),
            ),
            const SizedBox(height: 4),
            const _LocationPing(),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text('Appearance',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall),
                    const SizedBox(height: 8),
                    SegmentedButton<ThemeMode>(
                      segments: const [
                        ButtonSegment(
                            value: ThemeMode.system,
                            label: Text('Auto')),
                        ButtonSegment(
                            value: ThemeMode.light,
                            label: Text('Light')),
                        ButtonSegment(
                            value: ThemeMode.dark,
                            label: Text('Dark')),
                      ],
                      selected: {themeMode},
                      onSelectionChanged: (set) => ref
                          .read(themeModeProvider.notifier)
                          .set(set.first),
                    ),
                  ],
                ),
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.help_outline),
                title: const Text('Help & policies'),
                trailing:
                    const Icon(Icons.chevron_right),
                onTap: () => context.safePush('/pages'),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Sign out?'),
                    actions: [
                      TextButton(
                        onPressed: () =>
                            Navigator.pop(context, false),
                        child: const Text('Stay'),
                      ),
                      FilledButton(
                        onPressed: () =>
                            Navigator.pop(context, true),
                        child: const Text('Sign out'),
                      ),
                    ],
                  ),
                );
                if (confirm != true || !context.mounted) return;
                try {
                  await ref.read(driverAuthApiProvider).logout();
                } finally {
                  await ref.read(pushServiceProvider).unregister();
                  await ref.read(authStoreProvider.notifier).signOut();
                  if (context.mounted) context.go('/login');
                }
              },
              child: const Text('Sign out'),
            ),
            const SizedBox(height: 16),
            const _VersionFooter(),
          ],
        );
      },
    );
  }
}

class _VersionFooter extends StatelessWidget {
  const _VersionFooter();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        final version = snapshot.data?.version ?? '';
        return Center(
          child: Text(
            version.isEmpty ? '' : 'v$version',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        );
      },
    );
  }
}

/// Edit name + vehicle info (PUT /driver/profile).
class EditDriverProfileScreen extends ConsumerStatefulWidget {
  const EditDriverProfileScreen({super.key});

  @override
  ConsumerState<EditDriverProfileScreen> createState() =>
      _EditDriverProfileScreenState();
}

class _EditDriverProfileScreenState
    extends ConsumerState<EditDriverProfileScreen> {
  final _name = TextEditingController();
  final _vehicle = TextEditingController();
  bool _busy = false;
  bool _loaded = false;

  @override
  void dispose() {
    _name.dispose();
    _vehicle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: ref.watch(jobsApiProvider).profile(),
        builder: (context, snapshot) {
          if (snapshot.hasData && !_loaded) {
            _name.text = '${snapshot.data!['name'] ?? ''}';
            _vehicle.text = '${snapshot.data!['vehicle_info'] ?? ''}';
            _loaded = true;
          }
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  prefixIcon: Icon(Icons.person_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _vehicle,
                decoration: const InputDecoration(
                  labelText: 'Vehicle (e.g. Honda CD70 · KHI-1234)',
                  prefixIcon: Icon(Icons.two_wheeler_outlined),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _busy
                    ? null
                    : () async {
                        setState(() => _busy = true);
                        final messenger = ScaffoldMessenger.of(context);
                        final router = GoRouter.of(context);
                        try {
                          await ref.read(jobsApiProvider).updateProfile(
                                name: _name.text.trim(),
                                vehicleInfo: _vehicle.text.trim(),
                              );
                          router.pop();
                        } catch (e) {
                          messenger.showSnackBar(
                            SnackBar(content: Text(apiMessage(e))),
                          );
                        } finally {
                          if (mounted) setState(() => _busy = false);
                        }
                      },
                child: Text(_busy ? 'Saving…' : 'Save changes'),
              ),
],
          );
        },
      ),
    );
  }
}

/// Manual position ping (GPS auto-fill lands with the location plugin).
/// Fresh coordinates keep auto-dispatch offers coming.
class _LocationPing extends ConsumerStatefulWidget {
  const _LocationPing();

  @override
  ConsumerState<_LocationPing> createState() => _LocationPingState();
}

class _LocationPingState extends ConsumerState<_LocationPing> {
  final _lat = TextEditingController();
  final _lng = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _lat.dispose();
    _lng.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('My position', style: Theme.of(context).textTheme.titleSmall),
            OutlinedButton.icon(
              icon: const Icon(Icons.my_location_outlined),
              label: const Text('Fill from GPS'),
              onPressed: _busy
                  ? null
                  : () async {
                      var permission = await Geolocator.checkPermission();
                      if (permission == LocationPermission.denied) {
                        permission = await Geolocator.requestPermission();
                      }
                      if (permission == LocationPermission.denied ||
                          permission == LocationPermission.deniedForever) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Location permission denied.'),
                            ),
                          );
                        }
                        return;
                      }
                      try {
                        final position = await Geolocator.getCurrentPosition();
                        _lat.text = '${position.latitude}';
                        _lng.text = '${position.longitude}';
                      } catch (_) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Could not fix location.')),
                          );
                        }
                      }
                    },
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _lat,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Lat'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _lng,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Lng'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed: _busy
                  ? null
                  : () async {
                      final lat = double.tryParse(_lat.text.trim());
                      final lng = double.tryParse(_lng.text.trim());
                      if (lat == null || lng == null) return;
                      setState(() => _busy = true);
                      try {
                        await ref.read(jobsApiProvider).location(
                              latitude: lat,
                              longitude: lng,
                            );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Position updated.')),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(apiMessage(e))),
                          );
                        }
                      } finally {
                        if (mounted) setState(() => _busy = false);
                      }
                    },
              child: Text(_busy ? 'Sending…' : 'Update position'),
            ),
          ],
        ),
      ),
    );
  }
}

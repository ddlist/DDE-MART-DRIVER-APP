// DDE-Mart driver app — SOS + profile.
//
// POST /driver/sos {latitude, longitude, order_ref?} raises an alert the
// admin safety inbox triages. Coordinates come from the device GPS once the
// location plugin lands — until then the driver can type or paste them.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:package_info_plus/package_info_plus.dart';

import '../../core/api_client.dart';
import '../../core/auth_store.dart';
import '../../core/media_api.dart';
import '../../core/nav.dart';
import '../../core/permissions.dart';
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
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        GradientHeader(
          title: 'Emergency SOS',
          subtitle: 'Sends your location to DDE-Mart safety staff.',
          icon: Icons.sos_outlined,
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SleekCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: scheme.errorContainer,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            Icons.location_on_outlined,
                            color: scheme.onErrorContainer,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Your location',
                            style:
                                Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _lat,
                      keyboardType:
                          const TextInputType.numberWithOptions(
                              decimal: true, signed: true),
                      decoration: const InputDecoration(
                        labelText: 'Latitude',
                        prefixIcon: Icon(Icons.explore_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _lng,
                      keyboardType:
                          const TextInputType.numberWithOptions(
                              decimal: true, signed: true),
                      decoration: const InputDecoration(
                        labelText: 'Longitude',
                        prefixIcon: Icon(Icons.explore_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _order,
                      decoration: const InputDecoration(
                        labelText: 'Order ref (optional)',
                        prefixIcon:
                            Icon(Icons.receipt_long_outlined),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: DdeTheme.softShadow(context),
                ),
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: DdeTheme.danger,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(vertical: 18),
                  ),
                  onPressed: _busy
                      ? null
                      : () async {
                          final lat =
                              double.tryParse(_lat.text.trim());
                          final lng =
                              double.tryParse(_lng.text.trim());
                          if (lat == null || lng == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'Enter valid coordinates.')),
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
                                const SnackBar(
                                    content: Text(
                                        'SOS sent. Help is on the way.')),
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
              ),
            ],
          ),
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
        final photo = '${profile?['photo'] ?? ''}';

        return ListView(
          padding: const EdgeInsets.only(bottom: 16),
          children: [
            _ProfileHero(
              name: name,
              initial: initial,
              photo: photo,
              phone: '${profile?['phone'] ?? auth.phone ?? ''}',
              status: '${profile?['status'] ?? '…'}',
              online: online,
              hasError: snapshot.hasError,
              error: snapshot.error,
            ),
            if (snapshot.connectionState == ConnectionState.waiting &&
                profile == null)
              const Padding(
                padding: EdgeInsets.all(16),
                child: ShimmerBox(height: 120, borderRadius: 24),
              ),
            if ('${profile?['vehicle_info'] ?? ''}'.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: SleekCard(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: DdeTheme.iconTile(context),
                        child: const Icon(
                          Icons.two_wheeler_outlined,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Vehicle',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          '${profile?['vehicle_info']}',
                          textAlign: TextAlign.end,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: SleekCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
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
            ),
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: _LocationPing(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: SleekCard(
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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: SleekCard(
                padding: EdgeInsets.zero,
                child: ListTile(
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: DdeTheme.iconTile(
                      context,
                      accent: true,
                      radius: 14,
                    ),
                    child: const Icon(
                      Icons.help_outline,
                      color: Colors.white,
                    ),
                  ),
                  title: const Text('Help & policies'),
                  trailing: Icon(
                    Icons.chevron_right,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  onTap: () => context.safePush('/pages'),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: FilledButton.tonal(
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
            ),
            const SizedBox(height: 16),
            const _VersionFooter(),
          ],
        );
      },
    );
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.name,
    required this.initial,
    required this.photo,
    required this.phone,
    required this.status,
    required this.online,
    required this.hasError,
    this.error,
  });

  final String name;
  final String initial;
  final String photo;
  final String phone;
  final String status;
  final bool online;
  final bool hasError;
  final Object? error;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      decoration: DdeTheme.headerGradient(context).copyWith(
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(DdeTheme.radiusSheet),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  padding: const EdgeInsets.all(2.5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.35),
                  ),
                  child: ClipOval(
                    child: photo.isNotEmpty
                        ? Image.network(
                            photo,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                _InitialTile(initial: initial),
                          )
                        : _InitialTile(initial: initial),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(color: Colors.white),
                      ),
                      Text(
                        phone,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(
                              color: Colors.white
                                  .withValues(alpha: 0.85),
                            ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          StatusChip(status: status),
                          const SizedBox(width: 6),
                          StatusChip(
                              status:
                                  online ? 'online' : 'offline'),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.edit_outlined,
                      color: Colors.white,
                    ),
                    tooltip: 'Edit profile',
                    onPressed: () =>
                        context.safePush('/profile/edit'),
                  ),
                ),
              ],
            ),
            if (hasError && error != null) ...[
              const SizedBox(height: 8),
              Text(
                apiMessage(error!),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InitialTile extends StatelessWidget {
  const _InitialTile({required this.initial});

  final String initial;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      alignment: Alignment.center,
      child: Text(
        initial,
        style: Theme.of(context).textTheme.headlineSmall,
      ),
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

/// Edit name + vehicle info (PUT /driver/profile accepts only
/// `name` + `vehicle_info`) with avatar photo upload via
/// POST /driver/uploads (multipart `file`).
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
  final _picker = ImagePicker();
  bool _busy = false;
  bool _loaded = false;
  bool _uploading = false;
  String? _photoUrl;

  @override
  void dispose() {
    _name.dispose();
    _vehicle.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final allowed = await ref
        .read(permissionServiceProvider)
        .ensure(context, AppPermission.photos);
    if (!allowed || !mounted) return;
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    setState(() => _uploading = true);
    try {
      final result =
          await ref.read(driverMediaApiProvider).uploadFile(picked.path);
      setState(() => _photoUrl = result['url']);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo uploaded.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(apiMessage(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
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
            _photoUrl ??= '${snapshot.data!['photo'] ?? ''}'.isEmpty
                ? null
                : '${snapshot.data!['photo']}';
            _loaded = true;
          }
          if (snapshot.connectionState == ConnectionState.waiting &&
              !_loaded) {
            return ListView(
              padding: const EdgeInsets.all(20),
              children: const [
                ShimmerBox(height: 96, borderRadius: 48),
                SizedBox(height: 12),
                ShimmerBox(height: 56, borderRadius: 14),
                SizedBox(height: 12),
                ShimmerBox(height: 56, borderRadius: 14),
              ],
            );
          }
          if (snapshot.hasError && !_loaded) {
            return ErrorRetry(
              error: snapshot.error!,
              onRetry: () => setState(() {}),
            );
          }
          final uploaded = _photoUrl ?? '';
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Center(
                child: Stack(
                  children: [
                    Container(
                      width: 104,
                      height: 104,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            DdeTheme.accent,
                            Theme.of(context).colorScheme.primary,
                          ],
                        ),
                        boxShadow:
                            DdeTheme.softShadow(context),
                      ),
                      child: ClipOval(
                        child: uploaded.isNotEmpty
                            ? Image.network(
                                uploaded,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) =>
                                    const Icon(
                                  Icons.person_outline,
                                  size: 48,
                                ),
                              )
                            : Container(
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
                                child: const Icon(
                                  Icons.person_outline,
                                  size: 48,
                                ),
                              ),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        decoration: DdeTheme.headerGradient(
                          context,
                        ).copyWith(shape: BoxShape.circle),
                        child: IconButton(
                          icon: _uploading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child:
                                      CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(
                                  Icons.camera_alt_outlined,
                                  color: Colors.white,
                                  size: 20,
                                ),
                          tooltip: 'Change photo',
                          onPressed:
                              _uploading ? null : _pickAvatar,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Photo uploads via /driver/uploads',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant,
                      ),
                ),
              ),
              const SizedBox(height: 16),
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
    return SleekCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('My position',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
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
                      final position =
                          await Geolocator.getCurrentPosition();
                      _lat.text = '${position.latitude}';
                      _lng.text = '${position.longitude}';
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Could not fix location.')),
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
    );
  }
}

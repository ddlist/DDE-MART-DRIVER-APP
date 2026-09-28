// DDE-Mart driver app — shell, router + launch gate (original).

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'core/api_client.dart';
import 'core/auth_store.dart';
import 'core/config.dart';
import 'core/gate.dart';
import 'core/widgets.dart';
import 'features/account/safety_profile.dart';
import 'features/auth/driver_login_screen.dart';
import 'features/chat/driver_chat.dart';
import 'features/documents/documents.dart';
import 'features/info/driver_info.dart';
import 'features/jobs/jobs.dart';
import 'features/payouts/payouts.dart';

final launchGateProvider = FutureProvider<GateDecision>((ref) async {
  final dio = ref.watch(dioProvider);
  final info = await PackageInfo.fromPlatform();

  try {
    final response = await dio.get('/app-config');
    final config = LaunchConfig.fromJson(
      Map<String, dynamic>.from((response.data as Map)['data'] as Map),
    );
    return gateStatus(
      current: info.version,
      minimum: config.minVersions[AppConfig.audience] ?? '1.0.0',
      maintenance: config.maintenance,
    );
  } on DioException {
    return GateDecision.ok;
  }
});

/// Bumps when auth or the launch gate changes so the router re-runs its
/// redirect without ever recreating the [GoRouter] itself. Recreating the
/// router mid-session swaps Navigator delegates under live pages and
/// corrupts the tree with duplicate keys.
final _routerRefreshProvider = Provider<ValueNotifier<int>>((ref) {
  final bump = ValueNotifier(0);
  ref.listen<AuthState>(authStoreProvider, (prev, next) {
    if (prev?.signedIn != next.signedIn) bump.value++;
  });
  ref.listen<AsyncValue<GateDecision>>(
      launchGateProvider, (prev, next) {
    if (prev?.valueOrNull != next.valueOrNull) bump.value++;
  });
  ref.onDispose(bump.dispose);
  return bump;
});

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/jobs',
    refreshListenable: ref.watch(_routerRefreshProvider),
    onException: (context, state, router) {
      router.go('/jobs');
    },
    redirect: (context, state) {
      final auth = ref.read(authStoreProvider);
      final gate = ref.read(launchGateProvider);
      final location = state.matchedLocation;

      if (gate.valueOrNull == GateDecision.maintenance && location != '/maintenance') {
        return '/maintenance';
      }
      if (gate.valueOrNull == GateDecision.updateRequired && location != '/update') {
        return '/update';
      }

      const public = ['/login', '/maintenance', '/update'];
      if (!auth.signedIn && !public.any(location.startsWith)) {
        return '/login';
      }
      if (auth.signedIn && (location == '/login' || location == '/')) {
        return '/jobs';
      }
      return null;
    },
    routes: [
      ShellRoute(
        builder: (context, state, child) => DriverShell(child: child),
        routes: [
          GoRoute(path: '/jobs', builder: (context, state) => const JobsScreen()),
          GoRoute(
            path: '/job-detail',
            builder: (context, state) {
              final args = state.extra! as (DriverJob, bool);
              return JobDetailScreen(job: args.$1, owned: args.$2);
            },
          ),
          GoRoute(path: '/payouts', builder: (context, state) => const PayoutsScreen()),
          GoRoute(path: '/documents', builder: (context, state) => const DocumentsScreen()),
          GoRoute(path: '/chat', builder: (context, state) => const DriverChatThreadsScreen()),
          GoRoute(
            path: '/chat/:id',
            builder: (context, state) => DriverChatThreadScreen(
              threadId: int.parse(state.pathParameters['id']!),
            ),
          ),
          GoRoute(path: '/sos', builder: (context, state) => const SosScreen()),
          GoRoute(path: '/profile', builder: (context, state) => const DriverProfileScreen()),
        ],
      ),
      GoRoute(path: '/login', builder: (context, state) => const DriverLoginScreen()),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const DriverOnboardingScreen(),
      ),
      GoRoute(
        path: '/profile/edit',
        builder: (context, state) => const EditDriverProfileScreen(),
      ),
      GoRoute(path: '/pages', builder: (context, state) => const DriverPagesScreen()),
      GoRoute(
        path: '/page/:slug',
        builder: (context, state) => DriverPageDetailScreen(
          slug: state.pathParameters['slug']!,
        ),
      ),
      GoRoute(path: '/maintenance', builder: (context, state) => const MaintenanceScreen()),
      GoRoute(path: '/update', builder: (context, state) => const UpdateScreen()),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

class DriverShell extends StatelessWidget {
  const DriverShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;

    int index = 0;
    if (location.startsWith('/payouts')) {
      index = 1;
    } else if (location.startsWith('/documents')) {
      index = 2;
    } else if (location.startsWith('/chat')) {
      index = 3;
    } else if (location.startsWith('/sos')) {
      index = 4;
    } else if (location.startsWith('/profile')) {
      index = 5;
    }

    return Scaffold(
      body: SafeArea(child: child),
      bottomNavigationBar: DdeBottomBar(
        index: index,
        onTap: (value) {
          switch (value) {
            case 0:
              context.go('/jobs');
            case 1:
              context.go('/payouts');
            case 2:
              context.go('/documents');
            case 3:
              context.go('/chat');
            case 4:
              context.go('/sos');
            case 5:
              context.go('/profile');
          }
        },
        items: [
          DdeBarItem(icon: Icons.work_outline, label: 'Jobs'),
          DdeBarItem(icon: Icons.payments_outlined, label: 'Payouts'),
          DdeBarItem(icon: Icons.badge_outlined, label: 'Docs'),
          DdeBarItem(icon: Icons.chat_outlined, label: 'Chat'),
          DdeBarItem(icon: Icons.sos_outlined, label: 'SOS'),
          DdeBarItem(icon: Icons.person_outline, label: 'Profile'),
        ],
      ),
    );
  }
}

class MaintenanceScreen extends ConsumerWidget {
  const MaintenanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: SleekCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primaryContainer,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Icon(
                    Icons.construction_outlined,
                    size: 38,
                    color: Theme.of(context)
                        .colorScheme
                        .onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'DDE-Mart is under maintenance',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => ref.invalidate(launchGateProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class UpdateScreen extends StatelessWidget {
  const UpdateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: SleekCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primaryContainer,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Icon(
                    Icons.system_update_outlined,
                    size: 38,
                    color: Theme.of(context)
                        .colorScheme
                        .onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Please update DDE Driver to continue.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

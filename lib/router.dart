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

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authStoreProvider);
  final gate = ref.watch(launchGateProvider);

  return GoRouter(
    initialLocation: '/jobs',
    redirect: (context, state) {
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
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) {
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
        destinations: const [
          NavigationDestination(icon: Icon(Icons.work_outline), label: 'Jobs'),
          NavigationDestination(icon: Icon(Icons.payments_outlined), label: 'Payouts'),
          NavigationDestination(icon: Icon(Icons.badge_outlined), label: 'Docs'),
          NavigationDestination(icon: Icon(Icons.chat_outlined), label: 'Chat'),
          NavigationDestination(icon: Icon(Icons.sos_outlined), label: 'SOS'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profile'),
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.construction_outlined, size: 64),
              const SizedBox(height: 16),
              const Text('DDE-Mart is under maintenance', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.invalidate(launchGateProvider),
                child: const Text('Retry'),
              ),
            ],
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
    return const Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.system_update_outlined, size: 64),
              SizedBox(height: 16),
              Text('Please update DDE Driver to continue.', textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

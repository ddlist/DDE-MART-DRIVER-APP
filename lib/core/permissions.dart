// DDE-Mart driver app — runtime permissions (original).
//
// Industry-standard flow: check first, explain on first denial via the
// system dialog, and route permanently-denied users to app settings with
// an explicit dialog (never a dead end).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

/// App-level permission needs.
enum AppPermission { notifications, photos, camera }

extension on AppPermission {
  Permission get system {
    switch (this) {
      case AppPermission.notifications:
        return Permission.notification;
      case AppPermission.photos:
        return Permission.photos;
      case AppPermission.camera:
        return Permission.camera;
    }
  }

  String get label {
    switch (this) {
      case AppPermission.notifications:
        return 'notifications';
      case AppPermission.photos:
        return 'photos';
      case AppPermission.camera:
        return 'camera';
    }
  }
}

class PermissionService {
  const PermissionService();

  Future<bool> isGranted(AppPermission permission) async {
    final status = await permission.system.status;
    return status.isGranted || status.isLimited;
  }

  /// Requests [permission], guiding permanently-denied users to settings.
  /// Returns true when usable afterwards.
  Future<bool> ensure(BuildContext context, AppPermission permission) async {
    if (await isGranted(permission)) return true;

    final status = await permission.system.request();
    if (status.isGranted || status.isLimited) return true;
    if (!context.mounted) return false;

    if (status.isPermanentlyDenied) {
      final open = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('${_cap(permission.label)} disabled'),
          content: Text(
            'DDE Driver needs ${permission.label} access for this feature. '
            'Open settings to allow it.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Not now'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Open settings'),
            ),
          ],
        ),
      );
      if (open == true) {
        await openAppSettings();
        return isGranted(permission);
      }
    }
    return false;
  }

  String _cap(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}

final permissionServiceProvider = Provider<PermissionService>(
  (ref) => const PermissionService(),
);

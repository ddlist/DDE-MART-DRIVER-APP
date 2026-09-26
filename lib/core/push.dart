// DDE-Mart driver app — push notifications (original).
//
// Subscribes to `drivers` (new-job broadcasts from WorkforceNotifier) and
// registers the token at POST /driver/push-tokens after sign-in.
// Native config files stay out of git — see FIREBASE_SETUP.md. Without
// them init throws and push silently stays off.

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';
import 'auth_store.dart';

/// Must stay top-level for the background isolate.
@pragma('vm:entry-point')
Future<void> _backgroundMessage(RemoteMessage message) async {
  debugPrint('push(background): ${message.messageId}');
}

class PushService {
  PushService(this._ref);

  final Ref _ref;
  bool _synced = false;

  static const topic = 'drivers';

  Future<void> syncOnSignIn() async {
    if (_synced) return;
    _synced = true;

    try {
      await Firebase.initializeApp();
    } catch (e) {
      debugPrint('push: Firebase not configured, skipping ($e)');
      return;
    }

    final messaging = FirebaseMessaging.instance;

    await messaging.requestPermission();

    try {
      await messaging.subscribeToTopic(topic);
    } catch (e) {
      debugPrint('push: topic subscribe failed ($e)');
    }

    try {
      final token = await messaging.getToken();
      if (token != null) {
        await _ref.read(dioProvider).post('/driver/push-tokens', data: {
          'token': token,
          'platform': defaultTargetPlatform.name,
        });
      }
    } catch (e) {
      debugPrint('push: token register failed ($e)');
    }

    FirebaseMessaging.onBackgroundMessage(_backgroundMessage);

    const channel = AndroidNotificationChannel(
      'dde_driver',
      'DDE Driver updates',
      importance: Importance.high,
    );
    final local = FlutterLocalNotificationsPlugin();
    await local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      if (notification == null) return;
      local.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channel.id,
            channel.name,
            importance: Importance.high,
          ),
        ),
      );
    });
  }

  Future<void> unregister() async {
    _synced = false;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await _ref.read(dioProvider).delete('/driver/push-tokens', data: {
          'token': token,
        });
      }
      await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
    } catch (e) {
      debugPrint('push: unregister skipped ($e)');
    }
  }
}

final pushServiceProvider = Provider<PushService>(
  (ref) => PushService(ref),
);

final pushSyncProvider = StateNotifierProvider<PushSync, bool>((ref) {
  final sync = PushSync(ref);
  ref.listen<AuthState>(authStoreProvider, (_, auth) {
    if (auth.signedIn) {
      sync.sync();
    } else {
      sync.reset();
    }
  });
  return sync;
});

class PushSync extends StateNotifier<bool> {
  PushSync(this._ref) : super(false);

  final Ref _ref;

  Future<void> sync() async {
    if (state) return;
    state = true;
    await _ref.read(pushServiceProvider).syncOnSignIn();
  }

  void reset() => state = false;
}

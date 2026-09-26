// DDE-Mart driver app — token storage + session state (original).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _storage = FlutterSecureStorage();

class AuthState {
  const AuthState({this.token, this.name, this.phone});

  bool get signedIn => token != null;

  final String? token;
  final String? name;
  final String? phone;
}

class AuthStore extends StateNotifier<AuthState> {
  AuthStore() : super(const AuthState()) {
    _restore();
  }

  Future<void> _restore() async {
    final values = await _storage.readAll();
    state = AuthState(
      token: values['auth.token'],
      name: values['auth.name'],
      phone: values['auth.phone'],
    );
  }

  Future<String?> token() async {
    if (state.token != null) return state.token;
    return _storage.read(key: 'auth.token');
  }

  Future<void> signIn({
    required String token,
    required String name,
    required String phone,
  }) async {
    await _storage.write(key: 'auth.token', value: token);
    await _storage.write(key: 'auth.name', value: name);
    await _storage.write(key: 'auth.phone', value: phone);
    state = AuthState(token: token, name: name, phone: phone);
  }

  Future<void> signOut() async {
    await _storage.deleteAll();
    state = const AuthState();
  }
}

final authStoreProvider = StateNotifierProvider<AuthStore, AuthState>(
  (ref) => AuthStore(),
);

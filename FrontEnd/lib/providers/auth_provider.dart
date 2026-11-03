import 'package:flutter/foundation.dart';

import '../core/network/api_exception.dart';
import '../core/storage/token_storage.dart';
import '../data/models/app_user.dart';
import '../data/repositories/auth_repository.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider(this._repository, this._tokenStorage);

  final AuthRepository _repository;
  final TokenStorage _tokenStorage;

  AppUser? user;
  Object? sessionRestoreError;
  bool isReady = false;
  bool isBusy = false;
  bool isRestoring = false;

  bool get isSignedIn => user != null;

  Future<void> restoreSession() async {
    if (isRestoring) return;
    isRestoring = true;
    notifyListeners();
    try {
      final hasSavedSession = await _tokenStorage.readSignedIn();
      final token = await _tokenStorage.readToken();
      if (!hasSavedSession || token == null || token.isEmpty) {
        await _tokenStorage.clearToken();
        user = null;
      } else {
        user = await _repository.currentUser();
      }
      sessionRestoreError = null;
    } catch (error) {
      if (error is ApiException && error.statusCode == 401) {
        await _tokenStorage.clearToken();
        user = null;
      } else {
        sessionRestoreError = error;
      }
    } finally {
      isReady = true;
      isRestoring = false;
      notifyListeners();
    }
  }

  Future<void> login(String email, String password) async {
    isBusy = true;
    notifyListeners();
    try {
      final session = await _repository.login(email.trim(), password);
      await _saveSession(session.token, session.user);
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
    String? phone,
  }) async {
    isBusy = true;
    notifyListeners();
    try {
      final session = await _repository.register(
        name: name.trim(),
        email: email.trim(),
        password: password,
        phone: phone,
      );
      await _saveSession(session.token, session.user);
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    user = null;
    sessionRestoreError = null;
    await _tokenStorage.clearToken();
    notifyListeners();
  }

  Future<void> updateProfile({required String name, String? phone}) async {
    isBusy = true;
    notifyListeners();
    try {
      user = await _repository.updateProfile(
        name: name.trim(),
        phone: phone?.trim(),
      );
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) => _repository.changePassword(
    currentPassword: currentPassword,
    newPassword: newPassword,
  );

  void handleUnauthorized() {
    user = null;
    sessionRestoreError = null;
    isReady = true;
    notifyListeners();
  }

  Future<void> _saveSession(String token, AppUser currentUser) async {
    await _tokenStorage.saveToken(token);
    sessionRestoreError = null;
    user = currentUser;
    isReady = true;
  }
}

import '../datasources/auth_remote_data_source.dart';
import '../models/app_user.dart';
import '../models/auth_session.dart';

class AuthRepository {
  AuthRepository(this._remote);

  final AuthRemoteDataSource _remote;

  Future<AuthSession> login(String email, String password) =>
      _remote.login(email, password);

  Future<AuthSession> register({
    required String name,
    required String email,
    required String password,
    String? phone,
  }) => _remote.register(
    name: name,
    email: email,
    password: password,
    phone: phone,
  );

  Future<AppUser> currentUser() => _remote.currentUser();

  Future<AppUser> updateProfile({required String name, String? phone}) =>
      _remote.updateProfile(name: name, phone: phone);

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) => _remote.changePassword(
    currentPassword: currentPassword,
    newPassword: newPassword,
  );
}

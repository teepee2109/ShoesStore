import '../../core/dio_client.dart';
import '../../core/network/api_exception.dart';
import '../models/app_user.dart';
import '../models/auth_session.dart';
import 'api_payload.dart';

class AuthRemoteDataSource {
  AuthRemoteDataSource(this._client);

  final DioClient _client;

  Future<AuthSession> login(String email, String password) async {
    final response = await _client.post(
      'auth/login',
      data: {'email': email, 'password': password},
    );
    return _sessionFrom(responseData(response.data));
  }

  Future<AuthSession> register({
    required String name,
    required String email,
    required String password,
    String? phone,
  }) async {
    final response = await _client.post(
      'auth/register',
      data: {
        'name': name,
        'email': email,
        'password': password,
        if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
      },
    );
    return _sessionFrom(responseData(response.data));
  }

  Future<AppUser> currentUser() async {
    final response = await _client.get('auth/me');
    return AppUser.fromJson(asJsonMap(responseData(response.data)));
  }

  Future<AppUser> updateProfile({required String name, String? phone}) async {
    final response = await _client.put(
      'auth/me',
      data: {'name': name, 'phone': phone ?? ''},
    );
    return AppUser.fromJson(asJsonMap(responseData(response.data)));
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _client.put(
      'auth/password',
      data: {'current_password': currentPassword, 'new_password': newPassword},
    );
  }

  AuthSession _sessionFrom(Object? value) {
    final json = asJsonMap(value);
    final token = json['token']?.toString() ?? '';
    if (token.isEmpty) {
      throw const ApiException('Máy chủ không trả về access token hợp lệ.');
    }
    return AuthSession(
      user: AppUser.fromJson(asJsonMap(json['user'])),
      token: token,
    );
  }
}

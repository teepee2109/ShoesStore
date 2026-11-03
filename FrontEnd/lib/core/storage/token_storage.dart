import 'package:shared_preferences/shared_preferences.dart';

class TokenStorage {
  TokenStorage(this._preferences);

  static const _tokenKey = 'access_token';
  static const _signedInKey = 'is_signed_in';
  final SharedPreferencesAsync _preferences;

  Future<String?> readToken() => _preferences.getString(_tokenKey);

  Future<bool> readSignedIn() async =>
      await _preferences.getBool(_signedInKey) ?? false;

  Future<void> saveToken(String token) async {
    await _preferences.setString(_tokenKey, token);
    await _preferences.setBool(_signedInKey, true);
  }

  Future<void> clearToken() async {
    await _preferences.remove(_tokenKey);
    await _preferences.remove(_signedInKey);
  }
}

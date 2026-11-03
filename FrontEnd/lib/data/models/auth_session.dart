import 'app_user.dart';

class AuthSession {
  const AuthSession({required this.user, required this.token});

  final AppUser user;
  final String token;
}

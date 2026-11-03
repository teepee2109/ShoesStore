class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.phone,
    this.avatar,
  });

  final int id;
  final String name;
  final String email;
  final String role;
  final String? phone;
  final String? avatar;

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    id: _toInt(json['id']),
    name: json['name']?.toString() ?? '',
    email: json['email']?.toString() ?? '',
    role: json['role']?.toString() ?? 'customer',
    phone: json['phone']?.toString(),
    avatar: json['avatar']?.toString(),
  );
}

int _toInt(Object? value) => value is int ? value : int.tryParse('$value') ?? 0;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    if (user == null) return const Center(child: CircularProgressIndicator());
    final initial = user.name.trim().isEmpty
        ? '?'
        : user.name.trim()[0].toUpperCase();
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My account',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            onPressed: () => context.push('/chat'),
            icon: const Icon(Icons.chat_bubble_outline_rounded),
            tooltip: 'Chat hỗ trợ',
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFD7F542),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: Colors.white,
                  child: Text(
                    initial,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user.email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _editProfile(context, user.name, user.phone),
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Chỉnh sửa hồ sơ',
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),
          const Text(
            'ORDERS & SUPPORT',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: Colors.black54,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 9),
          _ProfileMenuTile(
            icon: Icons.receipt_long_outlined,
            title: 'Đơn hàng của tôi',
            subtitle: 'Theo dõi và xem lịch sử mua hàng',
            onTap: () => context.push('/orders'),
          ),
          _ProfileMenuTile(
            icon: Icons.chat_bubble_outline_rounded,
            title: 'Trò chuyện với cửa hàng',
            subtitle: 'Chúng tôi sẵn sàng hỗ trợ bạn',
            onTap: () => context.push('/chat'),
          ),
          const SizedBox(height: 20),
          const Text(
            'ACCOUNT SETTINGS',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: Colors.black54,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 9),
          _ProfileMenuTile(
            icon: Icons.location_on_outlined,
            title: 'Địa chỉ giao hàng',
            subtitle: 'Quản lý địa chỉ nhận đơn',
            onTap: () => context.push('/addresses'),
          ),
          _ProfileMenuTile(
            icon: Icons.notifications_none_rounded,
            title: 'Thông báo',
            subtitle: 'Ưu đãi và cập nhật đơn hàng',
            onTap: () => context.push('/notifications'),
          ),
          _ProfileMenuTile(
            icon: Icons.lock_outline_rounded,
            title: 'Đổi mật khẩu',
            subtitle: 'Cập nhật mật khẩu đăng nhập',
            onTap: () => _changePassword(context),
          ),
          _ProfileMenuTile(
            icon: Icons.help_outline_rounded,
            title: 'Trợ giúp',
            subtitle: 'Câu hỏi thường gặp và liên hệ',
            onTap: () => context.push('/chat'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () async {
              await context.read<AuthProvider>().logout();
              if (context.mounted) context.go('/login');
            },
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Đăng xuất'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.black,
              side: const BorderSide(color: Colors.black12),
              minimumSize: const Size.fromHeight(50),
            ),
          ),
          const SizedBox(height: 18),
          Center(
            child: Text(
              'ADIDAS MEMBER · ${user.role.toUpperCase()}',
              style: const TextStyle(
                fontSize: 9,
                letterSpacing: 1.3,
                color: Colors.black38,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> _editProfile(
    BuildContext context,
    String name,
    String? phone,
  ) async {
    final nameController = TextEditingController(text: name);
    final phoneController = TextEditingController(text: phone ?? '');
    final formKey = GlobalKey<FormState>();
    final draft = await showDialog<(String, String)?>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Chỉnh sửa hồ sơ'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Họ và tên'),
                validator: (value) => value == null || value.trim().length < 2
                    ? 'Tên cần có ít nhất 2 ký tự.'
                    : null,
              ),
              TextFormField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Số điện thoại'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(dialogContext, (
                nameController.text.trim(),
                phoneController.text.trim(),
              ));
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
    nameController.dispose();
    phoneController.dispose();
    if (draft == null || !context.mounted) return;
    try {
      await context.read<AuthProvider>().updateProfile(
        name: draft.$1,
        phone: draft.$2,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Đã cập nhật hồ sơ.')));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_friendly(error))));
      }
    }
  }

  static Future<void> _changePassword(BuildContext context) async {
    final current = TextEditingController();
    final next = TextEditingController();
    final confirm = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final draft = await showDialog<(String, String)?>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Đổi mật khẩu'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: current,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Mật khẩu hiện tại',
                ),
                validator: (value) => value == null || value.isEmpty
                    ? 'Nhập mật khẩu hiện tại.'
                    : null,
              ),
              TextFormField(
                controller: next,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Mật khẩu mới'),
                validator: (value) => value == null || value.length < 6
                    ? 'Mật khẩu mới cần ít nhất 6 ký tự.'
                    : null,
              ),
              TextFormField(
                controller: confirm,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Nhập lại mật khẩu mới',
                ),
                validator: (value) =>
                    value != next.text ? 'Mật khẩu nhập lại chưa khớp.' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(dialogContext, (current.text, next.text));
            },
            child: const Text('Đổi mật khẩu'),
          ),
        ],
      ),
    );
    current.dispose();
    next.dispose();
    confirm.dispose();
    if (draft == null || !context.mounted) return;
    try {
      await context.read<AuthProvider>().changePassword(
        currentPassword: draft.$1,
        newPassword: draft.$2,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Đã đổi mật khẩu.')));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_friendly(error))));
      }
    }
  }

  static String _friendly(Object error) =>
      error.toString().replaceFirst('Exception: ', '');
}

class _ProfileMenuTile extends StatelessWidget {
  const _ProfileMenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: ListTile(
      onTap: onTap,
      leading: Icon(icon),
      title: Text(
        title,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      ),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 10)),
      trailing: const Icon(Icons.chevron_right_rounded, size: 20),
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 4),
    ),
  );
}

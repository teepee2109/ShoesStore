import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/notification_provider.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text(
        'Thông báo',
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
      actions: [
        Consumer<NotificationProvider>(
          builder: (context, provider, child) => TextButton(
            onPressed: provider.unreadCount == 0 || provider.isMutating
                ? null
                : () => _markAll(context, provider),
            child: const Text('Đọc tất cả'),
          ),
        ),
      ],
    ),
    body: Consumer<NotificationProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading && provider.notifications.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (provider.error != null && provider.notifications.isEmpty) {
          return _LoadError(
            message: _friendly(provider.error!),
            onRetry: () => provider.load(force: true),
          );
        }
        if (provider.notifications.isEmpty) {
          return const Center(child: Text('Bạn chưa có thông báo nào.'));
        }
        return RefreshIndicator(
          onRefresh: () => provider.load(force: true),
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: provider.notifications.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = provider.notifications[index];
              return Card(
                margin: EdgeInsets.zero,
                color: item.isRead ? Colors.white : const Color(0xFFF4F6E8),
                child: ListTile(
                  onTap: item.isRead
                      ? null
                      : () => _markOne(context, provider, item.id),
                  leading: CircleAvatar(
                    backgroundColor: item.isRead
                        ? Colors.black12
                        : const Color(0xFFD7F542),
                    child: Icon(
                      item.isRead
                          ? Icons.notifications_none
                          : Icons.notifications_active_outlined,
                      color: Colors.black87,
                    ),
                  ),
                  title: Text(
                    item.title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Text(
                      item.body?.isNotEmpty == true
                          ? item.body!
                          : 'Có cập nhật mới từ cửa hàng.',
                    ),
                  ),
                  trailing: item.isRead
                      ? null
                      : const Icon(
                          Icons.circle,
                          size: 9,
                          color: Color(0xFF738600),
                        ),
                ),
              );
            },
          ),
        );
      },
    ),
  );

  static Future<void> _markOne(
    BuildContext context,
    NotificationProvider provider,
    int id,
  ) async {
    try {
      await provider.markRead(id);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_friendly(error))));
      }
    }
  }

  static Future<void> _markAll(
    BuildContext context,
    NotificationProvider provider,
  ) async {
    try {
      await provider.markAllRead();
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

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 42),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Thử lại')),
        ],
      ),
    ),
  );
}

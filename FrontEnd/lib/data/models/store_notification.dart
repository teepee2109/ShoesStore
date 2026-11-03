class StoreNotificationPage {
  const StoreNotificationPage({required this.items, required this.unreadCount});

  final List<StoreNotification> items;
  final int unreadCount;

  factory StoreNotificationPage.fromJson(Map<String, dynamic> json) =>
      StoreNotificationPage(
        items: (json['items'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map(
              (item) =>
                  StoreNotification.fromJson(item.cast<String, dynamic>()),
            )
            .toList(),
        unreadCount: _toInt(json['unread_count']),
      );
}

class StoreNotification {
  const StoreNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.isRead,
    required this.createdAt,
  });

  final int id;
  final String title;
  final String? body;
  final bool isRead;
  final String createdAt;

  StoreNotification copyWith({bool? isRead}) => StoreNotification(
    id: id,
    title: title,
    body: body,
    isRead: isRead ?? this.isRead,
    createdAt: createdAt,
  );

  factory StoreNotification.fromJson(Map<String, dynamic> json) =>
      StoreNotification(
        id: _toInt(json['id']),
        title: json['title']?.toString() ?? '',
        body: json['body']?.toString(),
        isRead: json['is_read'] == true || json['is_read'] == 1,
        createdAt: json['created_at']?.toString() ?? '',
      );
}

int _toInt(Object? value) => value is int ? value : int.tryParse('$value') ?? 0;

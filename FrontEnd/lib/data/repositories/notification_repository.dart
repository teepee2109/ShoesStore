import '../datasources/notification_remote_data_source.dart';
import '../models/store_notification.dart';

class NotificationRepository {
  NotificationRepository(this._remote);

  final NotificationRemoteDataSource _remote;

  Future<StoreNotificationPage> getNotifications({
    int page = 1,
    int limit = 50,
  }) => _remote.getNotifications(page: page, limit: limit);

  Future<void> markRead(int id) => _remote.markRead(id);

  Future<void> markAllRead() => _remote.markAllRead();
}

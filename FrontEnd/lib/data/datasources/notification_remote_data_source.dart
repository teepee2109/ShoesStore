import '../../core/dio_client.dart';
import '../models/store_notification.dart';
import 'api_payload.dart';

class NotificationRemoteDataSource {
  NotificationRemoteDataSource(this._client);

  final DioClient _client;

  Future<StoreNotificationPage> getNotifications({
    int page = 1,
    int limit = 50,
  }) async {
    final response = await _client.get(
      'notifications',
      queryParameters: {'page': page, 'limit': limit},
    );
    return StoreNotificationPage.fromJson(
      asJsonMap(responseData(response.data)),
    );
  }

  Future<void> markRead(int id) async {
    await _client.patch('notifications/$id/read');
  }

  Future<void> markAllRead() async {
    await _client.patch('notifications/read-all');
  }
}

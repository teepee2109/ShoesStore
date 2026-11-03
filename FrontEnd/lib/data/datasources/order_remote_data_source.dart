import '../../core/dio_client.dart';
import '../models/store_order.dart';
import 'api_payload.dart';

class OrderRemoteDataSource {
  OrderRemoteDataSource(this._client);

  final DioClient _client;

  Future<OrderPage> getOrders({
    String? status,
    int page = 1,
    int limit = 20,
  }) async {
    final response = await _client.get(
      'orders',
      queryParameters: {
        if (status != null && status.isNotEmpty) 'status': status,
        'page': page,
        'limit': limit,
      },
    );
    return OrderPage.fromJson(asJsonMap(responseData(response.data)));
  }

  Future<StoreOrder> getOrder(int orderId) async {
    final response = await _client.get('orders/$orderId');
    return StoreOrder.fromJson(asJsonMap(responseData(response.data)));
  }

  Future<StoreOrder> createOrder({
    required int addressId,
    String paymentMethod = 'cod',
  }) async {
    final response = await _client.post(
      'orders',
      data: {'address_id': addressId, 'payment_method': paymentMethod},
    );
    return StoreOrder.fromJson(asJsonMap(responseData(response.data)));
  }

  Future<StoreOrder> cancelOrder(int orderId) async {
    final response = await _client.put('orders/$orderId/cancel');
    return StoreOrder.fromJson(asJsonMap(responseData(response.data)));
  }
}

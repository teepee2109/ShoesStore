import '../datasources/order_remote_data_source.dart';
import '../models/store_order.dart';

class OrderRepository {
  OrderRepository(this._remote);

  final OrderRemoteDataSource _remote;

  Future<OrderPage> getOrders({String? status, int page = 1, int limit = 20}) =>
      _remote.getOrders(status: status, page: page, limit: limit);

  Future<StoreOrder> getOrder(int orderId) => _remote.getOrder(orderId);

  Future<StoreOrder> createOrder({
    required int addressId,
    String paymentMethod = 'cod',
  }) => _remote.createOrder(addressId: addressId, paymentMethod: paymentMethod);

  Future<StoreOrder> cancelOrder(int orderId) => _remote.cancelOrder(orderId);
}

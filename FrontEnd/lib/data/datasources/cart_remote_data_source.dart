import '../../core/dio_client.dart';
import '../models/cart.dart';
import 'api_payload.dart';

class CartRemoteDataSource {
  CartRemoteDataSource(this._client);

  final DioClient _client;

  Future<Cart> getCart() async {
    final response = await _client.get('cart');
    return Cart.fromJson(asJsonMap(responseData(response.data)));
  }

  Future<Cart> addItem({required int variantId, int quantity = 1}) async {
    final response = await _client.post(
      'cart/items',
      data: {'variant_id': variantId, 'quantity': quantity},
    );
    return Cart.fromJson(asJsonMap(responseData(response.data)));
  }

  Future<Cart> updateItem({required int itemId, required int quantity}) async {
    final response = await _client.put(
      'cart/items/$itemId',
      data: {'quantity': quantity},
    );
    return Cart.fromJson(asJsonMap(responseData(response.data)));
  }

  Future<Cart> removeItem(int itemId) async {
    final response = await _client.delete('cart/items/$itemId');
    return Cart.fromJson(asJsonMap(responseData(response.data)));
  }

  Future<Cart> clearCart() async {
    final response = await _client.delete('cart/items');
    return Cart.fromJson(asJsonMap(responseData(response.data)));
  }
}

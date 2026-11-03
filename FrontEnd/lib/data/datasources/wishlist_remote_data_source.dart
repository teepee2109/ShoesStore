import '../../core/dio_client.dart';
import '../models/product.dart';
import 'api_payload.dart';

class WishlistRemoteDataSource {
  WishlistRemoteDataSource(this._client);

  final DioClient _client;

  Future<List<Product>> getWishlist() async {
    final response = await _client.get('wishlist');
    return _productsFrom(response.data);
  }

  Future<List<Product>> addItem(int productId) async {
    final response = await _client.post(
      'wishlist/items',
      data: {'product_id': productId},
    );
    return _productsFrom(response.data);
  }

  Future<List<Product>> removeItem(int productId) async {
    final response = await _client.delete('wishlist/items/$productId');
    return _productsFrom(response.data);
  }

  List<Product> _productsFrom(Object? response) => responseList(response)
      .whereType<Map>()
      .map((value) {
        final json = asJsonMap(value);
        return Product.fromJson({
          ...json,
          'id': json['product_id'] ?? json['id'],
        });
      })
      .toList();
}

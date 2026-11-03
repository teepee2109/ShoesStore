import '../datasources/cart_remote_data_source.dart';
import '../models/cart.dart';

class CartRepository {
  CartRepository(this._remote);

  final CartRemoteDataSource _remote;

  Future<Cart> getCart() => _remote.getCart();

  Future<Cart> addItem({required int variantId, int quantity = 1}) =>
      _remote.addItem(variantId: variantId, quantity: quantity);

  Future<Cart> updateItem({required int itemId, required int quantity}) =>
      _remote.updateItem(itemId: itemId, quantity: quantity);

  Future<Cart> removeItem(int itemId) => _remote.removeItem(itemId);

  Future<Cart> clearCart() => _remote.clearCart();
}

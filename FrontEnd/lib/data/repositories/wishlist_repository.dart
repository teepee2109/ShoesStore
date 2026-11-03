import '../datasources/wishlist_remote_data_source.dart';
import '../models/product.dart';

class WishlistRepository {
  WishlistRepository(this._remote);

  final WishlistRemoteDataSource _remote;

  Future<List<Product>> getWishlist() => _remote.getWishlist();

  Future<List<Product>> addItem(int productId) => _remote.addItem(productId);

  Future<List<Product>> removeItem(int productId) =>
      _remote.removeItem(productId);
}

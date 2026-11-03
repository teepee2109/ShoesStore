import '../datasources/product_remote_data_source.dart';
import '../models/category.dart';
import '../models/product.dart';

class ProductRepository {
  ProductRepository(this._remote);

  final ProductRemoteDataSource _remote;

  Future<List<Category>> getCategories() => _remote.getCategories();

  Future<ProductPage> getProducts({
    String? query,
    String? category,
    double? minPrice,
    double? maxPrice,
    String? size,
    String? color,
    String sort = 'latest',
    int page = 1,
    int limit = 20,
  }) => _remote.getProducts(
    query: query,
    category: category,
    minPrice: minPrice,
    maxPrice: maxPrice,
    size: size,
    color: color,
    sort: sort,
    page: page,
    limit: limit,
  );

  Future<Product> getProduct(String id) => _remote.getProduct(id);
}

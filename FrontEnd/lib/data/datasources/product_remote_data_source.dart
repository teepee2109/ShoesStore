import 'package:dio/dio.dart';

import '../../core/dio_client.dart';
import '../models/category.dart';
import '../models/product.dart';
import 'api_payload.dart';

class ProductRemoteDataSource {
  ProductRemoteDataSource(this._client);

  final DioClient _client;

  Future<List<Category>> getCategories() async {
    final response = await _client.get('categories');
    return responseList(response.data)
        .whereType<Map>()
        .map((json) => Category.fromJson(asJsonMap(json)))
        .toList();
  }

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
    CancelToken? cancelToken,
  }) async {
    final queryParameters = <String, dynamic>{
      if (category != null && category.isNotEmpty) 'category': category,
      if (size != null && size.isNotEmpty) 'size': size,
      if (color != null && color.isNotEmpty) 'color': color,
      'sort': sort,
      'page': page,
      'limit': limit,
    };
    if (minPrice case final priceFloor?) {
      queryParameters['minPrice'] = priceFloor;
    }
    if (maxPrice case final priceCeiling?) {
      queryParameters['maxPrice'] = priceCeiling;
    }
    final trimmedQuery = query?.trim();
    if (trimmedQuery?.isNotEmpty == true) queryParameters['q'] = trimmedQuery;
    final response = await _client.get(
      'products',
      cancelToken: cancelToken,
      queryParameters: queryParameters,
    );
    final data = asJsonMap(responseData(response.data));
    return ProductPage.fromJson(data);
  }

  Future<Product> getProduct(String id) async {
    final response = await _client.get('products/$id');
    return Product.fromJson(asJsonMap(responseData(response.data)));
  }
}

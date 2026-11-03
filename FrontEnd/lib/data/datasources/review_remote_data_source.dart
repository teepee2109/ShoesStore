import '../../core/dio_client.dart';
import '../models/product_review.dart';
import 'api_payload.dart';

class ReviewRemoteDataSource {
  ReviewRemoteDataSource(this._client);

  final DioClient _client;

  Future<ProductReviewPage> list(int productId) async {
    final response = await _client.get(
      'products/$productId/reviews',
      queryParameters: const {'page': 1, 'limit': 20},
    );
    return ProductReviewPage.fromJson(asJsonMap(responseData(response.data)));
  }

  Future<ProductReview> create({
    required int productId,
    required int rating,
    String? comment,
  }) async {
    final response = await _client.post(
      'products/$productId/reviews',
      data: {'rating': rating, 'comment': comment},
    );
    return ProductReview.fromJson(asJsonMap(responseData(response.data)));
  }
}

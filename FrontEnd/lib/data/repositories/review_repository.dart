import '../datasources/review_remote_data_source.dart';
import '../models/product_review.dart';

class ReviewRepository {
  ReviewRepository(this._remote);

  final ReviewRemoteDataSource _remote;

  Future<ProductReviewPage> list(int productId) => _remote.list(productId);

  Future<ProductReview> create({
    required int productId,
    required int rating,
    String? comment,
  }) => _remote.create(productId: productId, rating: rating, comment: comment);
}

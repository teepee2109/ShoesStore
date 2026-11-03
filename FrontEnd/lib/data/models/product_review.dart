class ProductReviewPage {
  const ProductReviewPage({
    required this.items,
    required this.total,
    required this.ratingAverage,
  });

  final List<ProductReview> items;
  final int total;
  final double ratingAverage;

  factory ProductReviewPage.fromJson(Map<String, dynamic> json) =>
      ProductReviewPage(
        items: (json['items'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((item) => ProductReview.fromJson(item.cast<String, dynamic>()))
            .toList(),
        total: _toInt(json['total']),
        ratingAverage: _toDouble(json['rating_average']),
      );
}

class ProductReview {
  const ProductReview({
    required this.id,
    required this.userName,
    required this.rating,
    required this.createdAt,
    this.comment,
  });

  final int id;
  final String userName;
  final int rating;
  final String createdAt;
  final String? comment;

  factory ProductReview.fromJson(Map<String, dynamic> json) => ProductReview(
    id: _toInt(json['id']),
    userName: json['user_name']?.toString() ?? 'Khách hàng',
    rating: _toInt(json['rating']),
    createdAt: json['created_at']?.toString() ?? '',
    comment: json['comment']?.toString(),
  );
}

int _toInt(Object? value) => value is int ? value : int.tryParse('$value') ?? 0;
double _toDouble(Object? value) =>
    value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

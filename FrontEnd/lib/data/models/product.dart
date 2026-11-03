import '../../core/config/app_config.dart';

class Product {
  const Product({
    required this.id,
    required this.name,
    required this.price,
    required this.stock,
    this.ratingAverage = 0,
    this.reviewCount = 0,
    this.description,
    this.discountPrice,
    this.mainImage,
    this.categoryName,
    this.categorySlug,
    this.images = const [],
    this.variants = const [],
  });

  final int id;
  final String name;
  final String? description;
  final double price;
  final double? discountPrice;
  final String? mainImage;
  final String? categoryName;
  final String? categorySlug;
  final int stock;
  final double ratingAverage;
  final int reviewCount;
  final List<String> images;
  final List<ProductVariant> variants;

  double get currentPrice => discountPrice ?? price;

  String? get imageUrl {
    final path = mainImage ?? (images.isEmpty ? null : images.first);
    if (path == null || path.isEmpty) return null;
    if (Uri.tryParse(path)?.hasScheme ?? false) return path;
    return '${AppConfig.serverOrigin}${path.startsWith('/') ? '' : '/'}$path';
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    final images =
        (json['images'] as List<dynamic>?)
            ?.map(
              (item) => item is Map<String, dynamic>
                  ? item['url']?.toString()
                  : item.toString(),
            )
            .whereType<String>()
            .toList() ??
        const <String>[];
    final variants =
        (json['variants'] as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .map(ProductVariant.fromJson)
            .toList() ??
        const <ProductVariant>[];

    return Product(
      id: _toInt(json['id']),
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      price: _toDouble(json['price']),
      discountPrice: json['discount_price'] == null
          ? null
          : _toDouble(json['discount_price']),
      mainImage: json['main_image']?.toString(),
      categoryName: json['category_name']?.toString(),
      categorySlug: json['category_slug']?.toString(),
      stock: json.containsKey('stock')
          ? _toInt(json['stock'])
          : variants.fold<int>(0, (sum, variant) => sum + variant.stock),
      ratingAverage: _toDouble(json['rating_average']),
      reviewCount: _toInt(json['review_count']),
      images: images,
      variants: variants,
    );
  }
}

class ProductPage {
  const ProductPage({
    required this.items,
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
  });

  final List<Product> items;
  final int page;
  final int limit;
  final int total;
  final int totalPages;

  factory ProductPage.fromJson(Map<String, dynamic> json) {
    final pagination = json['pagination'] is Map
        ? (json['pagination'] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};
    return ProductPage(
      items: (json['items'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((item) => Product.fromJson(item.cast<String, dynamic>()))
          .toList(),
      page: _toInt(pagination['page']),
      limit: _toInt(pagination['limit']),
      total: _toInt(pagination['total']),
      totalPages: _toInt(pagination['total_pages']),
    );
  }
}

class ProductVariant {
  const ProductVariant({
    required this.id,
    required this.size,
    required this.color,
    required this.stock,
  });

  final int id;
  final String size;
  final String color;
  final int stock;

  factory ProductVariant.fromJson(Map<String, dynamic> json) => ProductVariant(
    id: _toInt(json['id']),
    size: json['size']?.toString() ?? '',
    color: json['color']?.toString() ?? '',
    stock: _toInt(json['stock']),
  );
}

int _toInt(Object? value) => value is int ? value : int.tryParse('$value') ?? 0;

double _toDouble(Object? value) =>
    value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

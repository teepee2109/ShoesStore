class Category {
  const Category({
    required this.id,
    required this.name,
    required this.slug,
    required this.productCount,
    this.image,
  });

  final int id;
  final String name;
  final String slug;
  final int productCount;
  final String? image;

  factory Category.fromJson(Map<String, dynamic> json) => Category(
    id: _toInt(json['id']),
    name: json['name']?.toString() ?? '',
    slug: json['slug']?.toString() ?? '',
    productCount: _toInt(json['product_count']),
    image: json['image']?.toString(),
  );
}

int _toInt(Object? value) => value is int ? value : int.tryParse('$value') ?? 0;

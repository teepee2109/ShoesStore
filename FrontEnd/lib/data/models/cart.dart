import '../../core/config/app_config.dart';

class Cart {
  const Cart({required this.items, required this.subtotal});

  final List<CartItem> items;
  final double subtotal;

  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity);

  Cart withItems(List<CartItem> nextItems) => Cart(
    items: nextItems,
    subtotal: nextItems.fold<double>(0, (sum, item) => sum + item.lineTotal),
  );

  factory Cart.fromJson(Map<String, dynamic> json) => Cart(
    items: (json['items'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((item) => CartItem.fromJson(item.cast<String, dynamic>()))
        .toList(),
    subtotal: _toDouble(json['subtotal']),
  );
}

class CartItem {
  const CartItem({
    required this.id,
    required this.variantId,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.size,
    required this.color,
    required this.stock,
    required this.unitPrice,
    required this.lineTotal,
    this.mainImage,
  });

  final int id;
  final int variantId;
  final int productId;
  final String productName;
  final int quantity;
  final String size;
  final String color;
  final int stock;
  final double unitPrice;
  final double lineTotal;
  final String? mainImage;

  String? get imageUrl {
    if (mainImage == null || mainImage!.isEmpty) return null;
    if (Uri.tryParse(mainImage!)?.hasScheme ?? false) return mainImage;
    return '${AppConfig.serverOrigin}${mainImage!.startsWith('/') ? '' : '/'}$mainImage';
  }

  CartItem withQuantity(int nextQuantity) => CartItem(
    id: id,
    variantId: variantId,
    productId: productId,
    productName: productName,
    quantity: nextQuantity,
    size: size,
    color: color,
    stock: stock,
    unitPrice: unitPrice,
    lineTotal: unitPrice * nextQuantity,
    mainImage: mainImage,
  );

  factory CartItem.fromJson(Map<String, dynamic> json) => CartItem(
    id: _toInt(json['item_id'] ?? json['id']),
    variantId: _toInt(json['variant_id']),
    productId: _toInt(json['product_id']),
    productName: json['product_name']?.toString() ?? '',
    quantity: _toInt(json['quantity']),
    size: json['size']?.toString() ?? '',
    color: json['color']?.toString() ?? '',
    stock: _toInt(json['stock']),
    unitPrice: _toDouble(json['unit_price']),
    lineTotal: _toDouble(json['line_total']),
    mainImage: json['main_image']?.toString(),
  );
}

int _toInt(Object? value) => value is int ? value : int.tryParse('$value') ?? 0;
double _toDouble(Object? value) =>
    value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

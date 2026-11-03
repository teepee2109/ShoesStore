class OrderPage {
  const OrderPage({
    required this.items,
    required this.page,
    required this.totalPages,
    required this.total,
  });

  final List<StoreOrder> items;
  final int page;
  final int totalPages;
  final int total;

  factory OrderPage.fromJson(Map<String, dynamic> json) {
    final pagination = _asMap(json['pagination']);
    return OrderPage(
      items: (json['items'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((item) => StoreOrder.fromJson(item.cast<String, dynamic>()))
          .toList(),
      page: _toInt(pagination['page']),
      totalPages: _toInt(pagination['total_pages']),
      total: _toInt(pagination['total']),
    );
  }
}

class StoreOrder {
  const StoreOrder({
    required this.id,
    required this.totalAmount,
    required this.status,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.createdAt,
    this.addressId,
    this.shippingName,
    this.shippingPhone,
    this.shippingAddress,
    this.itemCount = 0,
    this.items = const [],
  });

  final int id;
  final int? addressId;
  final String? shippingName;
  final String? shippingPhone;
  final String? shippingAddress;
  final double totalAmount;
  final String status;
  final String paymentMethod;
  final String paymentStatus;
  final String createdAt;
  final int itemCount;
  final List<OrderItem> items;

  factory StoreOrder.fromJson(Map<String, dynamic> json) => StoreOrder(
    id: _toInt(json['id']),
    addressId: json['address_id'] == null ? null : _toInt(json['address_id']),
    shippingName: json['shipping_name']?.toString(),
    shippingPhone: json['shipping_phone']?.toString(),
    shippingAddress: json['shipping_address']?.toString(),
    totalAmount: _toDouble(json['total_amount']),
    status: json['status']?.toString() ?? 'pending',
    paymentMethod: json['payment_method']?.toString() ?? 'cod',
    paymentStatus: json['payment_status']?.toString() ?? 'unpaid',
    createdAt: json['created_at']?.toString() ?? '',
    itemCount: _toInt(json['item_count']),
    items: (json['items'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((item) => OrderItem.fromJson(item.cast<String, dynamic>()))
        .toList(),
  );
}

class OrderItem {
  const OrderItem({
    required this.id,
    required this.variantId,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
    required this.size,
    required this.color,
    this.mainImage,
  });

  final int id;
  final int variantId;
  final int productId;
  final String productName;
  final int quantity;
  final double unitPrice;
  final double lineTotal;
  final String size;
  final String color;
  final String? mainImage;

  factory OrderItem.fromJson(Map<String, dynamic> json) => OrderItem(
    id: _toInt(json['id']),
    variantId: _toInt(json['variant_id']),
    productId: _toInt(json['product_id']),
    productName: json['product_name']?.toString() ?? '',
    quantity: _toInt(json['quantity']),
    unitPrice: _toDouble(json['unit_price']),
    lineTotal: _toDouble(json['line_total']),
    size: json['size']?.toString() ?? '',
    color: json['color']?.toString() ?? '',
    mainImage: json['main_image']?.toString(),
  );
}

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.cast<String, dynamic>();
  return const {};
}

int _toInt(Object? value) => value is int ? value : int.tryParse('$value') ?? 0;
double _toDouble(Object? value) =>
    value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

class ShippingAddress {
  const ShippingAddress({
    required this.id,
    required this.receiverName,
    required this.phone,
    required this.addressLine,
    required this.city,
    required this.isDefault,
  });

  final int id;
  final String receiverName;
  final String phone;
  final String addressLine;
  final String city;
  final bool isDefault;

  factory ShippingAddress.fromJson(Map<String, dynamic> json) =>
      ShippingAddress(
        id: _toInt(json['id']),
        receiverName: json['receiver_name']?.toString() ?? '',
        phone: json['phone']?.toString() ?? '',
        addressLine: json['address_line']?.toString() ?? '',
        city: json['city']?.toString() ?? '',
        isDefault: json['is_default'] == true || json['is_default'] == 1,
      );
}

int _toInt(Object? value) => value is int ? value : int.tryParse('$value') ?? 0;

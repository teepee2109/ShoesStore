import '../../core/dio_client.dart';
import '../models/shipping_address.dart';
import 'api_payload.dart';

class AddressRemoteDataSource {
  AddressRemoteDataSource(this._client);

  final DioClient _client;

  Future<List<ShippingAddress>> getAddresses() async {
    final response = await _client.get('addresses');
    return responseList(response.data)
        .whereType<Map>()
        .map((item) => ShippingAddress.fromJson(asJsonMap(item)))
        .toList();
  }

  Future<ShippingAddress> createAddress({
    required String receiverName,
    required String phone,
    required String addressLine,
    required String city,
    bool isDefault = true,
  }) async {
    final response = await _client.post(
      'addresses',
      data: {
        'receiver_name': receiverName,
        'phone': phone,
        'address_line': addressLine,
        'city': city,
        'is_default': isDefault,
      },
    );
    return ShippingAddress.fromJson(asJsonMap(responseData(response.data)));
  }

  Future<ShippingAddress> updateAddress({
    required int id,
    required String receiverName,
    required String phone,
    required String addressLine,
    required String city,
    required bool isDefault,
  }) async {
    final response = await _client.put(
      'addresses/$id',
      data: {
        'receiver_name': receiverName,
        'phone': phone,
        'address_line': addressLine,
        'city': city,
        'is_default': isDefault,
      },
    );
    return ShippingAddress.fromJson(asJsonMap(responseData(response.data)));
  }

  Future<void> deleteAddress(int id) async {
    await _client.delete('addresses/$id');
  }
}

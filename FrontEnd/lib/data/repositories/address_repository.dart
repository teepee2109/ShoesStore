import '../datasources/address_remote_data_source.dart';
import '../models/shipping_address.dart';

class AddressRepository {
  AddressRepository(this._remote);

  final AddressRemoteDataSource _remote;

  Future<List<ShippingAddress>> getAddresses() => _remote.getAddresses();

  Future<ShippingAddress> createAddress({
    required String receiverName,
    required String phone,
    required String addressLine,
    required String city,
    bool isDefault = true,
  }) => _remote.createAddress(
    receiverName: receiverName,
    phone: phone,
    addressLine: addressLine,
    city: city,
    isDefault: isDefault,
  );

  Future<ShippingAddress> updateAddress({
    required int id,
    required String receiverName,
    required String phone,
    required String addressLine,
    required String city,
    required bool isDefault,
  }) => _remote.updateAddress(
    id: id,
    receiverName: receiverName,
    phone: phone,
    addressLine: addressLine,
    city: city,
    isDefault: isDefault,
  );

  Future<void> deleteAddress(int id) => _remote.deleteAddress(id);
}

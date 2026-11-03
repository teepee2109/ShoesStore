import { AppError } from '../utils/app-error.js';
import { withTransaction } from '../utils/with-transaction.js';
import { addressSchema } from '../validators/commerce.validators.js';
import * as addressModel from '../models/address.model.js';

function parseId(value) {
  const id = Number(value);
  if (!Number.isSafeInteger(id) || id <= 0) throw new AppError('Mã địa chỉ không hợp lệ.', 400);
  return id;
}

export async function listAddresses(userId) {
  return addressModel.findAddresses(userId);
}

export async function createAddress(userId, input) {
  const address = addressSchema.parse(input);
  const addressId = await withTransaction(async (connection) => {
    if (!(await addressModel.lockUserAddresses(connection, userId))) {
      throw new AppError('Không tìm thấy tài khoản.', 404);
    }
    const count = await addressModel.countAddresses(connection, userId);
    address.is_default = address.is_default ?? count === 0;
    if (address.is_default) await addressModel.unsetDefaultAddresses(connection, userId);
    return addressModel.insertAddress(connection, userId, address);
  });
  return (await addressModel.findAddresses(userId)).find((item) => Number(item.id) === Number(addressId));
}

export async function updateAddress(userId, addressIdValue, input) {
  const addressId = parseId(addressIdValue);
  const address = addressSchema.parse(input);
  await withTransaction(async (connection) => {
    if (!(await addressModel.lockUserAddresses(connection, userId))) {
      throw new AppError('Không tìm thấy tài khoản.', 404);
    }
    const existing = await addressModel.findAddress(connection, userId, addressId, true);
    if (!existing) {
      throw new AppError('Không tìm thấy địa chỉ.', 404);
    }
    address.is_default = address.is_default ?? Boolean(existing.is_default);
    if (address.is_default) await addressModel.unsetDefaultAddresses(connection, userId);
    await addressModel.updateAddress(connection, userId, addressId, address);
  });
  return (await addressModel.findAddresses(userId)).find((item) => Number(item.id) === addressId);
}

export async function removeAddress(userId, addressIdValue) {
  const addressId = parseId(addressIdValue);
  const result = await withTransaction(async (connection) => {
    if (!(await addressModel.lockUserAddresses(connection, userId))) {
      throw new AppError('Không tìm thấy tài khoản.', 404);
    }
    const address = await addressModel.findAddress(connection, userId, addressId, true);
    if (!address) throw new AppError('Không tìm thấy địa chỉ.', 404);
    await addressModel.deleteAddress(connection, userId, addressId);
    if (address.is_default) {
      const nextAddressId = await addressModel.findNextAddress(connection, userId);
      if (nextAddressId) await addressModel.setAddressDefault(connection, userId, nextAddressId);
    }
    return true;
  });
  return { id: addressId, deleted: result };
}

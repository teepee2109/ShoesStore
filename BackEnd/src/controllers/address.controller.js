import * as addressService from '../services/address.service.js';

export async function list(req, res) {
  const data = await addressService.listAddresses(req.auth.sub);
  res.json({ success: true, data, message: 'Lấy địa chỉ thành công.' });
}

export async function create(req, res) {
  const data = await addressService.createAddress(req.auth.sub, req.body);
  res.status(201).json({ success: true, data, message: 'Tạo địa chỉ thành công.' });
}

export async function update(req, res) {
  const data = await addressService.updateAddress(req.auth.sub, req.params.id, req.body);
  res.json({ success: true, data, message: 'Cập nhật địa chỉ thành công.' });
}

export async function remove(req, res) {
  const data = await addressService.removeAddress(req.auth.sub, req.params.id);
  res.json({ success: true, data, message: 'Đã xóa địa chỉ.' });
}

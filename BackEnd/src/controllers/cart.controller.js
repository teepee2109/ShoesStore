import * as cartService from '../services/cart.service.js';

export async function getCart(req, res) {
  const data = await cartService.getCart(req.auth.sub);
  res.json({ success: true, data, message: 'Lấy giỏ hàng thành công.' });
}

export async function addItem(req, res) {
  const data = await cartService.addItem(req.auth.sub, req.body);
  res.status(201).json({ success: true, data, message: 'Đã thêm sản phẩm vào giỏ.' });
}

export async function updateItem(req, res) {
  const data = await cartService.updateItem(req.auth.sub, req.params.itemId, req.body);
  res.json({ success: true, data, message: 'Đã cập nhật giỏ hàng.' });
}

export async function removeItem(req, res) {
  const data = await cartService.removeItem(req.auth.sub, req.params.itemId);
  res.json({ success: true, data, message: 'Đã xóa sản phẩm khỏi giỏ.' });
}

export async function removeAllItems(req, res) {
  const data = await cartService.removeAllItems(req.auth.sub);
  res.json({ success: true, data, message: 'Đã xóa giỏ hàng.' });
}

import * as orderService from '../services/order.service.js';

export async function create(req, res) {
  const data = await orderService.createOrder(req.auth.sub, req.body);
  res.status(201).json({ success: true, data, message: 'Tạo đơn hàng thành công.' });
}

export async function list(req, res) {
  const data = await orderService.listOrders(req.auth.sub, req.query);
  res.json({ success: true, data, message: 'Lấy danh sách đơn hàng thành công.' });
}

export async function detail(req, res) {
  const data = await orderService.getOrder(req.auth.sub, req.params.id);
  res.json({ success: true, data, message: 'Lấy chi tiết đơn hàng thành công.' });
}

export async function cancel(req, res) {
  const data = await orderService.cancelOrder(req.auth.sub, req.params.id);
  res.json({ success: true, data, message: 'Đã hủy đơn hàng và hoàn tồn kho.' });
}

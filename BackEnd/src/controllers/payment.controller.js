import * as paymentService from '../services/payment.service.js';

export async function createSePay(req, res) {
  const data = await paymentService.createSePayPayment(req.auth.sub, req.body.order_id);
  res.status(201).json({ success: true, data, message: 'Đã tạo phiên thanh toán SePay.' });
}

export async function sepayReturn(_req, res) {
  res.json({ success: true, message: 'Đã quay lại từ SePay. Trạng thái đơn hàng được xác nhận qua IPN.' });
}

export async function sepayStatus(req, res) {
  const data = await paymentService.getSePayPaymentStatus(req.auth.sub, req.params.order_id);
  res.json({ success: true, data, message: 'Đã tải trạng thái thanh toán.' });
}

export async function sepayIpn(req, res) {
  const data = await paymentService.processSePayIpn(req.body, req.get('x-secret-key'));
  res.json(data);
}

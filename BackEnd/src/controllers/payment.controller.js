import * as paymentService from '../services/payment.service.js';

export async function createVnpay(req, res) {
  const data = await paymentService.createVnpayPayment(
    req.auth.sub,
    req.body.order_id,
    req.ip,
  );
  res.status(201).json({ success: true, data, message: 'Đã tạo URL thanh toán VNPay.' });
}

export async function vnpayReturn(req, res) {
  const data = await paymentService.inspectVnpayReturn(req.query);
  res.json({ success: true, data, message: 'Đã xác thực kết quả trả về VNPay.' });
}

export async function vnpayIpn(req, res) {
  res.json(await paymentService.processVnpayIpn(req.query));
}

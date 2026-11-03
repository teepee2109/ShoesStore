import { randomBytes } from 'node:crypto';

import { env } from '../config/env.js';
import * as paymentModel from '../models/payment.model.js';
import { AppError } from '../utils/app-error.js';
import {
  buildVnpayUrl,
  formatVnpayDate,
  verifyVnpaySignature,
} from '../utils/vnpay.js';
import { withTransaction } from '../utils/with-transaction.js';

const pendingAttemptLifetimeMs = 15 * 60 * 1000;

function parseOrderId(value) {
  const id = Number(value);
  if (!Number.isSafeInteger(id) || id <= 0) {
    throw new AppError('Mã đơn hàng không hợp lệ.', 400);
  }
  return id;
}

function validateVnpayConfiguration() {
  const { tmnCode, hashSecret, paymentUrl, returnUrl, ipnUrl } = env.vnpay;
  if (!tmnCode || !hashSecret || !returnUrl || !ipnUrl) {
    throw new AppError('Chưa cấu hình đầy đủ VNPay sandbox.', 503);
  }
  try {
    const gateway = new URL(paymentUrl);
    const callback = new URL(returnUrl);
    const ipn = new URL(ipnUrl);
    const privateHosts = new Set(['localhost', '127.0.0.1', '::1']);
    if (gateway.protocol !== 'https:' || gateway.hostname !== 'sandbox.vnpayment.vn') {
      throw new Error('The gateway must be the VNPay sandbox URL.');
    }
    if (
      callback.protocol !== 'https:' || ipn.protocol !== 'https:' ||
      privateHosts.has(callback.hostname) || privateHosts.has(ipn.hostname)
    ) {
      throw new Error('VNPay return and IPN URLs must be public HTTPS URLs.');
    }
  } catch {
    throw new AppError('Cấu hình URL VNPay sandbox không hợp lệ.', 503);
  }
}

function clientIp(value) {
  const first = String(value ?? '').split(',')[0].trim();
  const normalized = first.startsWith('::ffff:') ? first.slice(7) : first;
  return normalized || '127.0.0.1';
}

export async function createVnpayPayment(userId, orderIdValue, ipAddress) {
  validateVnpayConfiguration();
  const orderId = parseOrderId(orderIdValue);
  const now = new Date();
  const expiresAt = new Date(now.getTime() + pendingAttemptLifetimeMs);
  const createdAt = formatVnpayDate(now);
  const expireDate = formatVnpayDate(expiresAt);
  const transactionRef = `P${orderId}${Date.now()}${randomBytes(6).toString('hex')}`;

  const attempt = await withTransaction(async (connection) => {
    const order = await paymentModel.lockOrderForPayment(connection, userId, orderId);
    if (!order) throw new AppError('Không tìm thấy đơn hàng.', 404);
    if (order.payment_method !== 'vnpay') {
      throw new AppError('Đơn hàng không dùng phương thức VNPay.', 409);
    }
    if (order.status !== 'pending' || order.payment_status === 'paid') {
      throw new AppError('Đơn hàng không còn ở trạng thái chờ thanh toán.', 409);
    }
    const staleBefore = new Date(now.getTime() - pendingAttemptLifetimeMs);
    await paymentModel.markExpiredPaymentAttemptsFailed(connection, orderId, staleBefore);
    if (await paymentModel.countRecentPendingPayments(connection, orderId, staleBefore)) {
      throw new AppError('Đơn hàng đang có giao dịch VNPay chờ xử lý.', 409);
    }

    const amount = Number(order.total_amount);
    if (!Number.isSafeInteger(amount) || amount <= 0 || amount * 100 > 999999999999) {
      throw new AppError('Số tiền đơn hàng không hợp lệ cho VNPay.', 400);
    }
    const paymentId = await paymentModel.insertPayment(connection, {
      orderId,
      transactionRef,
      amount,
    });
    return { paymentId, amount };
  });

  const params = {
    vnp_Version: '2.1.0',
    vnp_Command: 'pay',
    vnp_TmnCode: env.vnpay.tmnCode,
    vnp_Amount: String(attempt.amount * 100),
    vnp_CurrCode: 'VND',
    vnp_TxnRef: transactionRef,
    vnp_OrderInfo: `Thanh toan don hang ${orderId}`,
    vnp_OrderType: 'other',
    vnp_Locale: 'vn',
    vnp_ReturnUrl: env.vnpay.returnUrl,
    vnp_IpAddr: clientIp(ipAddress),
    vnp_CreateDate: createdAt,
    vnp_ExpireDate: expireDate,
  };

  return {
    payment_id: attempt.paymentId,
    order_id: orderId,
    payment_url: buildVnpayUrl(env.vnpay.paymentUrl, params, env.vnpay.hashSecret),
    return_url: env.vnpay.returnUrl,
    expires_at: expiresAt.toISOString(),
  };
}

function verifyCallback(params) {
  try {
    return Boolean(env.vnpay.tmnCode && env.vnpay.hashSecret) &&
      params.vnp_TmnCode === env.vnpay.tmnCode &&
      verifyVnpaySignature(params, env.vnpay.hashSecret);
  } catch {
    return false;
  }
}

export async function inspectVnpayReturn(params) {
  if (!verifyCallback(params)) {
    throw new AppError('Chữ ký trả về từ VNPay không hợp lệ.', 400);
  }
  const transactionRef = String(params.vnp_TxnRef ?? '');
  if (!transactionRef) throw new AppError('Thiếu mã giao dịch VNPay.', 400);
  const payment = await paymentModel.findPaymentByRef(transactionRef);
  if (!payment) throw new AppError('Không tìm thấy giao dịch VNPay.', 404);
  if (Number(params.vnp_Amount) !== Number(payment.amount) * 100) {
    throw new AppError('Số tiền trả về từ VNPay không khớp.', 400);
  }
  if (params.vnp_CurrCode !== 'VND') {
    throw new AppError('Đơn vị tiền tệ trả về từ VNPay không hợp lệ.', 400);
  }
  return {
    valid: true,
    order_id: Number(payment.order_id),
    payment_id: Number(payment.payment_id),
    payment_status: payment.payment_status,
    attempt_status: payment.payment_attempt_status,
    successful: params.vnp_ResponseCode === '00' &&
      params.vnp_TransactionStatus === '00',
    response_code: String(params.vnp_ResponseCode ?? ''),
    transaction_status: String(params.vnp_TransactionStatus ?? ''),
  };
}

export async function processVnpayIpn(params) {
  if (!verifyCallback(params)) {
    return { RspCode: '97', Message: 'Invalid Checksum' };
  }
  const transactionRef = String(params.vnp_TxnRef ?? '');
  if (!transactionRef) return { RspCode: '01', Message: 'Order not found' };

  try {
    const result = await withTransaction(async (connection) => {
      const payment = await paymentModel.findPaymentByRefForUpdate(connection, transactionRef);
      if (!payment) return { RspCode: '01', Message: 'Order not found' };
      if (Number(params.vnp_Amount) !== Number(payment.amount) * 100 || params.vnp_CurrCode !== 'VND') {
        return { RspCode: '04', Message: 'Invalid amount' };
      }
      if (payment.payment_attempt_status !== 'pending') {
        return { RspCode: '00', Message: 'Confirm Success' };
      }
      if (payment.order_status === 'cancelled' || payment.payment_status === 'paid') {
        return { RspCode: '02', Message: 'Order already confirmed' };
      }

      const successful = params.vnp_ResponseCode === '00' &&
        params.vnp_TransactionStatus === '00';
      const rawResponse = JSON.stringify(params);
      await paymentModel.settlePayment(connection, {
        paymentId: payment.payment_id,
        orderId: payment.order_id,
        userId: payment.user_id,
        successful,
        rawResponse,
      });
      return { RspCode: '00', Message: 'Confirm Success' };
    });
    return result;
  } catch {
    return { RspCode: '99', Message: 'Unknown error' };
  }
}

import { createHmac, randomBytes, timingSafeEqual } from 'node:crypto';

import { env } from '../config/env.js';
import * as paymentModel from '../models/payment.model.js';
import { AppError } from '../utils/app-error.js';
import { withTransaction } from '../utils/with-transaction.js';

const pendingAttemptLifetimeMs = 15 * 60 * 1000;
const signedFields = [
  'order_amount',
  'merchant',
  'currency',
  'operation',
  'order_description',
  'order_invoice_number',
  'customer_id',
  'payment_method',
  'success_url',
  'error_url',
  'cancel_url',
];

function parseOrderId(value) {
  const id = Number(value);
  if (!Number.isSafeInteger(id) || id <= 0) {
    throw new AppError('Mã đơn hàng không hợp lệ.', 400);
  }
  return id;
}

function isPublicHttpsUrl(value) {
  try {
    const url = new URL(value);
    const hostname = url.hostname.toLowerCase().replace(/^\[|\]$/g, '');
    return url.protocol === 'https:' &&
      hostname !== 'localhost' && !hostname.endsWith('.localhost') &&
      !['::1', '0.0.0.0'].includes(hostname) &&
      !/^10\./.test(hostname) &&
      !/^127\./.test(hostname) &&
      !/^169\.254\./.test(hostname) &&
      !/^192\.168\./.test(hostname) &&
      !/^172\.(1[6-9]|2\d|3[01])\./.test(hostname);
  } catch {
    return false;
  }
}

function validateSePayConfiguration() {
  const {
    environment,
    merchantId,
    merchantSecretKey,
    ipnSecretKey,
    returnUrl,
    ipnUrl,
  } = env.sepay;
  if (
    !['sandbox', 'production'].includes(environment) || !merchantId ||
    !merchantSecretKey || !ipnSecretKey || !returnUrl || !ipnUrl
  ) {
    throw new AppError('Chưa cấu hình đầy đủ SePay.', 503);
  }
  if (!isPublicHttpsUrl(returnUrl) || !isPublicHttpsUrl(ipnUrl)) {
    throw new AppError('URL return và IPN của SePay phải là HTTPS công khai.', 503);
  }
}

export function createSePaySignature(fields, secretKey) {
  const signed = signedFields
    .filter((field) =>
      fields[field] !== undefined &&
      fields[field] !== null &&
      String(fields[field]) !== '' &&
      String(fields[field]) !== '0',
    )
    .map((field) => `${field}=${fields[field]}`)
    .join(',');
  return createHmac('sha256', secretKey).update(signed, 'utf8').digest('base64');
}

function callbackUrl(result, orderId) {
  const url = new URL(env.sepay.returnUrl);
  url.searchParams.set('order_id', String(orderId));
  url.searchParams.set('result', result);
  return url.toString();
}

export async function createSePayPayment(userId, orderIdValue) {
  validateSePayConfiguration();
  const orderId = parseOrderId(orderIdValue);
  const now = new Date();
  const invoiceNumber = `P${orderId}${Date.now()}${randomBytes(8).toString('hex')}`;

  const attempt = await withTransaction(async (connection) => {
    const order = await paymentModel.lockOrderForPayment(connection, userId, orderId);
    if (!order) throw new AppError('Không tìm thấy đơn hàng.', 404);
    if (order.payment_method !== 'sepay') {
      throw new AppError('Đơn hàng không dùng phương thức SePay.', 409);
    }
    if (order.status !== 'pending' || order.payment_status === 'paid') {
      throw new AppError('Đơn hàng không còn ở trạng thái chờ thanh toán.', 409);
    }
    const staleBefore = new Date(now.getTime() - pendingAttemptLifetimeMs);
    await paymentModel.markExpiredPaymentAttemptsFailed(connection, orderId, staleBefore);
    if (await paymentModel.countRecentPendingPayments(connection, orderId, staleBefore)) {
      throw new AppError('Đơn hàng đang có giao dịch SePay chờ xử lý.', 409);
    }

    const amount = Number(order.total_amount);
    if (!Number.isSafeInteger(amount) || amount <= 0) {
      throw new AppError('Số tiền đơn hàng không hợp lệ cho SePay.', 400);
    }
    const paymentId = await paymentModel.insertPayment(connection, {
      orderId,
      transactionRef: invoiceNumber,
      amount,
    });
    return { paymentId, amount };
  });

  const fields = {
    order_amount: String(attempt.amount),
    merchant: env.sepay.merchantId,
    currency: 'VND',
    operation: 'PURCHASE',
    order_description: `Thanh toan don hang #${orderId}`,
    order_invoice_number: invoiceNumber,
    payment_method: 'BANK_TRANSFER',
    success_url: callbackUrl('success', orderId),
    error_url: callbackUrl('error', orderId),
    cancel_url: callbackUrl('cancel', orderId),
    lang: 'vi',
  };

  return {
    payment_id: attempt.paymentId,
    order_id: orderId,
    checkout_url: env.sepay.environment === 'production'
      ? 'https://pay.sepay.vn/v1/checkout/init'
      : 'https://pay-sandbox.sepay.vn/v1/checkout/init',
    form_fields: {
      ...fields,
      signature: createSePaySignature(fields, env.sepay.merchantSecretKey),
    },
    return_url: env.sepay.returnUrl,
  };
}

function secretMatches(received, expected) {
  const receivedBuffer = Buffer.from(String(received ?? ''), 'utf8');
  const expectedBuffer = Buffer.from(String(expected ?? ''), 'utf8');
  return receivedBuffer.length > 0 && receivedBuffer.length === expectedBuffer.length &&
    timingSafeEqual(receivedBuffer, expectedBuffer);
}

export async function processSePayIpn(payload, receivedSecret) {
  if (!env.sepay.ipnSecretKey || !secretMatches(receivedSecret, env.sepay.ipnSecretKey)) {
    throw new AppError('Xác thực IPN SePay không hợp lệ.', 401);
  }

  const notificationType = String(payload?.notification_type ?? '');
  if (!['ORDER_PAID', 'TRANSACTION_VOID'].includes(notificationType)) {
    return { success: true, ignored: true };
  }
  const invoiceNumber = String(payload?.order?.order_invoice_number ?? '');
  if (!invoiceNumber) throw new AppError('Thiếu mã hóa đơn trong IPN SePay.', 400);

  return withTransaction(async (connection) => {
    const payment = await paymentModel.findPaymentByRefForUpdate(connection, invoiceNumber);
    if (!payment) throw new AppError('Không tìm thấy giao dịch SePay.', 404);
    if (payment.payment_attempt_status === 'success') {
      return { success: true, duplicate: true };
    }
    if (payment.payment_attempt_status !== 'pending' && notificationType !== 'ORDER_PAID') {
      return { success: true, duplicate: true };
    }
    if (payment.payment_method !== 'sepay') {
      throw new AppError('Đơn hàng không sử dụng SePay.', 409);
    }

    const orderAmount = Number(payload.order?.order_amount);
    const transactionAmount = Number(payload.transaction?.transaction_amount);
    const currenciesMatch = payload.order?.order_currency === 'VND' &&
      payload.transaction?.transaction_currency === 'VND';
    if (
      !Number.isSafeInteger(orderAmount) || !Number.isSafeInteger(transactionAmount) ||
      orderAmount !== Number(payment.amount) || transactionAmount !== Number(payment.amount) ||
      !currenciesMatch
    ) {
      throw new AppError('Số tiền hoặc đơn vị tiền tệ IPN SePay không khớp.', 400);
    }

    const successful = notificationType === 'ORDER_PAID' &&
      payload.order?.order_status === 'CAPTURED' &&
      payload.transaction?.transaction_status === 'APPROVED';
    if (notificationType === 'ORDER_PAID' && !successful) {
      throw new AppError('Trạng thái giao dịch SePay không hợp lệ.', 400);
    }

    await paymentModel.settlePayment(connection, {
      paymentId: payment.payment_id,
      orderId: payment.order_id,
      userId: payment.user_id,
      successful,
      orderCancelled: payment.order_status === 'cancelled',
      orderAlreadyPaid: payment.payment_status === 'paid',
      rawResponse: JSON.stringify(payload),
    });
    return { success: true, duplicate: payment.payment_status === 'paid' && successful };
  });
}

export async function getSePayPaymentStatus(userId, orderIdValue) {
  const orderId = parseOrderId(orderIdValue);
  const payment = await paymentModel.findLatestPaymentForOrder(userId, orderId);
  if (!payment) throw new AppError('Không tìm thấy giao dịch SePay của đơn hàng.', 404);
  return {
    order_id: orderId,
    payment_status: payment.payment_status,
    attempt_status: payment.payment_attempt_status,
  };
}

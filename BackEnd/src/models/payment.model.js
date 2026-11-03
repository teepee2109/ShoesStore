import { pool } from '../config/database.js';

export async function lockOrderForPayment(connection, userId, orderId) {
  const [rows] = await connection.execute(
    `SELECT id, user_id, total_amount, status, payment_method, payment_status
     FROM orders WHERE id = ? AND user_id = ? LIMIT 1 FOR UPDATE`,
    [orderId, userId],
  );
  return rows[0] ?? null;
}

export async function countRecentPendingPayments(connection, orderId, createdAfter) {
  const [rows] = await connection.execute(
    `SELECT COUNT(*) AS total FROM payments
     WHERE order_id = ? AND provider = 'vnpay' AND status = 'pending' AND created_at > ?`,
    [orderId, createdAfter],
  );
  return Number(rows[0].total);
}

export async function markExpiredPaymentAttemptsFailed(connection, orderId, createdBefore) {
  await connection.execute(
    `UPDATE payments SET status = 'failed'
     WHERE order_id = ? AND provider = 'vnpay' AND status = 'pending' AND created_at <= ?`,
    [orderId, createdBefore],
  );
}

export async function insertPayment(connection, { orderId, transactionRef, amount }) {
  const [result] = await connection.execute(
    `INSERT INTO payments (order_id, provider, transaction_id, amount, status)
     VALUES (?, 'vnpay', ?, ?, 'pending')`,
    [orderId, transactionRef, amount],
  );
  return result.insertId;
}

export async function findPaymentByRefForUpdate(connection, transactionRef) {
  const [rows] = await connection.execute(
    `SELECT pay.id AS payment_id, pay.order_id, pay.transaction_id,
            pay.amount, pay.status AS payment_attempt_status,
            o.user_id, o.total_amount, o.status AS order_status,
            o.payment_method, o.payment_status
     FROM payments pay JOIN orders o ON o.id = pay.order_id
     WHERE pay.provider = 'vnpay' AND pay.transaction_id = ?
     LIMIT 1 FOR UPDATE`,
    [transactionRef],
  );
  return rows[0] ?? null;
}

export async function findPaymentByRef(transactionRef) {
  const [rows] = await pool.execute(
    `SELECT pay.id AS payment_id, pay.order_id, pay.amount,
            pay.status AS payment_attempt_status,
            o.status AS order_status, o.payment_status
     FROM payments pay JOIN orders o ON o.id = pay.order_id
     WHERE pay.provider = 'vnpay' AND pay.transaction_id = ?
     LIMIT 1`,
    [transactionRef],
  );
  return rows[0] ?? null;
}

export async function settlePayment(connection, {
  paymentId,
  orderId,
  userId,
  successful,
  rawResponse,
}) {
  const paymentStatus = successful ? 'success' : 'failed';
  const orderPaymentStatus = successful ? 'paid' : 'failed';
  await connection.execute(
    `UPDATE payments SET status = ?, raw_response = ? WHERE id = ?`,
    [paymentStatus, rawResponse, paymentId],
  );
  await connection.execute(
    `UPDATE orders SET payment_status = ? WHERE id = ?`,
    [orderPaymentStatus, orderId],
  );
  await connection.execute(
    `INSERT INTO notifications (user_id, title, body) VALUES (?, ?, ?)`,
    [
      userId,
      successful ? 'Thanh toán thành công' : 'Thanh toán chưa thành công',
      successful
        ? `Đơn hàng #${orderId} đã được thanh toán qua VNPay.`
        : `Thanh toán VNPay cho đơn hàng #${orderId} thất bại. Bạn có thể thử lại.`,
    ],
  );
}

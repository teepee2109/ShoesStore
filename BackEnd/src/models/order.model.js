import { pool } from '../config/database.js';

export async function findOrders(userId, { status, limit, offset }) {
  const conditions = ['o.user_id = ?'];
  const values = [userId];
  if (status) {
    conditions.push('o.status = ?');
    values.push(status);
  }
  const whereClause = conditions.join(' AND ');
  const [countRows] = await pool.execute(
    `SELECT COUNT(*) AS total FROM orders o WHERE ${whereClause}`,
    values,
  );
  const [rows] = await pool.execute(
    `SELECT o.id, o.total_amount, o.status, o.payment_method,
            o.payment_status, o.created_at,
            (SELECT COUNT(*) FROM order_items oi WHERE oi.order_id = o.id) AS item_count
     FROM orders o WHERE ${whereClause}
     ORDER BY o.created_at DESC, o.id DESC LIMIT ? OFFSET ?`,
    [...values, limit, offset],
  );
  return { items: rows, total: Number(countRows[0].total) };
}

export async function findOrderById(userId, orderId) {
  const [rows] = await pool.execute(
    `SELECT id, user_id, address_id, shipping_name, shipping_phone,
            shipping_address, total_amount, status, payment_method,
            payment_status, created_at
     FROM orders WHERE user_id = ? AND id = ? LIMIT 1`,
    [userId, orderId],
  );
  if (!rows[0]) return null;

  const [items] = await pool.execute(
    `SELECT oi.id, oi.variant_id, oi.quantity, oi.unit_price,
            oi.quantity * oi.unit_price AS line_total,
            pv.size, pv.color, p.id AS product_id, p.name AS product_name,
            p.main_image
     FROM order_items oi
     JOIN product_variants pv ON pv.id = oi.variant_id
     JOIN products p ON p.id = pv.product_id
     WHERE oi.order_id = ? ORDER BY oi.id`,
    [orderId],
  );
  const [payments] = await pool.execute(
    `SELECT id, provider, transaction_id, amount, status, created_at
     FROM payments WHERE order_id = ? ORDER BY id DESC`,
    [orderId],
  );
  return { ...rows[0], items, payments };
}

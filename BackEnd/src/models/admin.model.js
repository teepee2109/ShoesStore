import { pool } from '../config/database.js';

export async function findAdminOrders({ status, q, limit, offset }) {
  const conditions = [];
  const values = [];
  if (status) {
    conditions.push('o.status = ?');
    values.push(status);
  }
  if (q) {
    conditions.push('(CAST(o.id AS CHAR) = ? OR u.name LIKE ? OR u.email LIKE ?)');
    values.push(q, `%${q}%`, `%${q}%`);
  }
  const where = conditions.length ? `WHERE ${conditions.join(' AND ')}` : '';
  const [countRows] = await pool.execute(
    `SELECT COUNT(*) AS total FROM orders o JOIN users u ON u.id = o.user_id ${where}`,
    values,
  );
  const [items] = await pool.execute(
    `SELECT o.id, o.user_id, u.name AS customer_name, u.email AS customer_email,
            o.shipping_name, o.shipping_phone, o.shipping_address,
            o.total_amount, o.status, o.payment_method, o.payment_status, o.created_at,
            (SELECT COUNT(*) FROM order_items oi WHERE oi.order_id = o.id) AS item_count
     FROM orders o JOIN users u ON u.id = o.user_id ${where}
     ORDER BY o.created_at DESC, o.id DESC LIMIT ? OFFSET ?`,
    [...values, limit, offset],
  );
  return { items, total: Number(countRows[0].total) };
}

export async function findAdminOrder(orderId, executor = pool) {
  const [rows] = await executor.execute(
    `SELECT o.id, o.user_id, u.name AS customer_name, u.email AS customer_email,
            o.address_id, o.shipping_name, o.shipping_phone, o.shipping_address,
            o.total_amount, o.status, o.payment_method, o.payment_status, o.created_at
     FROM orders o JOIN users u ON u.id = o.user_id WHERE o.id = ? LIMIT 1`,
    [orderId],
  );
  if (!rows[0]) return null;
  const [items] = await executor.execute(
    `SELECT oi.id, oi.variant_id, oi.quantity, oi.unit_price,
            oi.quantity * oi.unit_price AS line_total,
            pv.size, pv.color, p.id AS product_id, p.name AS product_name, p.main_image
     FROM order_items oi JOIN product_variants pv ON pv.id = oi.variant_id
     JOIN products p ON p.id = pv.product_id
     WHERE oi.order_id = ? ORDER BY oi.id`,
    [orderId],
  );
  return { ...rows[0], items };
}

export async function findAdminUsers({ q, role, limit, offset }) {
  const conditions = [];
  const values = [];
  if (role) {
    conditions.push('u.role = ?');
    values.push(role);
  }
  if (q) {
    conditions.push('(u.name LIKE ? OR u.email LIKE ? OR u.phone LIKE ? OR CAST(u.id AS CHAR) = ?)');
    values.push(`%${q}%`, `%${q}%`, `%${q}%`, q);
  }
  const where = conditions.length ? `WHERE ${conditions.join(' AND ')}` : '';
  const [countRows] = await pool.execute(`SELECT COUNT(*) AS total FROM users u ${where}`, values);
  const [items] = await pool.execute(
    `SELECT u.id, u.name, u.email, u.phone, u.role, u.avatar, u.created_at,
            (SELECT COUNT(*) FROM orders o WHERE o.user_id = u.id) AS order_count
     FROM users u ${where} ORDER BY u.created_at DESC, u.id DESC LIMIT ? OFFSET ?`,
    [...values, limit, offset],
  );
  return { items, total: Number(countRows[0].total) };
}

export async function findAdminUser(userId) {
  const [rows] = await pool.execute(
    `SELECT u.id, u.name, u.email, u.phone, u.role, u.avatar, u.created_at,
            (SELECT COUNT(*) FROM orders o WHERE o.user_id = u.id) AS order_count
     FROM users u WHERE u.id = ? LIMIT 1`,
    [userId],
  );
  return rows[0] ?? null;
}

export async function lockUser(connection, userId) {
  const [rows] = await connection.execute(
    'SELECT id, role FROM users WHERE id = ? LIMIT 1 FOR UPDATE',
    [userId],
  );
  return rows[0] ?? null;
}

export async function lockAdminIds(connection) {
  const [rows] = await connection.execute('SELECT id FROM users WHERE role = \'admin\' ORDER BY id FOR UPDATE');
  return rows.map((row) => Number(row.id));
}

export async function updateAdminUser(connection, userId, changes) {
  await connection.execute(
    'UPDATE users SET name = COALESCE(?, name), phone = IF(?, ?, phone), role = COALESCE(?, role) WHERE id = ?',
    [changes.name ?? null, Object.hasOwn(changes, 'phone') ? 1 : 0, changes.phone ?? null, changes.role ?? null, userId],
  );
}

export async function countUserOrders(connection, userId) {
  const [rows] = await connection.execute('SELECT COUNT(*) AS total FROM orders WHERE user_id = ?', [userId]);
  return Number(rows[0].total);
}

export async function deleteAdminUser(connection, userId) {
  const [result] = await connection.execute('DELETE FROM users WHERE id = ?', [userId]);
  return result.affectedRows;
}

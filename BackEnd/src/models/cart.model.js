import { pool } from '../config/database.js';

export async function lockOrCreateCart(connection, userId) {
  const [users] = await connection.execute(
    'SELECT id FROM users WHERE id = ? FOR UPDATE',
    [userId],
  );
  if (!users[0]) return null;

  const [carts] = await connection.execute(
    'SELECT id FROM carts WHERE user_id = ? LIMIT 1 FOR UPDATE',
    [userId],
  );
  if (carts[0]) return carts[0].id;

  const [result] = await connection.execute(
    'INSERT INTO carts (user_id) VALUES (?)',
    [userId],
  );
  return result.insertId;
}

export async function findCartItems(userId) {
  const [rows] = await pool.execute(
    `SELECT ci.id AS item_id, ci.variant_id, ci.quantity,
            p.id AS product_id, p.name AS product_name, p.main_image,
            pv.size, pv.color, pv.stock,
            COALESCE(p.discount_price, p.price) AS unit_price,
            ci.quantity * COALESCE(p.discount_price, p.price) AS line_total
     FROM carts c
     JOIN cart_items ci ON ci.cart_id = c.id
     JOIN product_variants pv ON pv.id = ci.variant_id
     JOIN products p ON p.id = pv.product_id
     WHERE c.user_id = ?
     ORDER BY ci.id DESC`,
    [userId],
  );
  return rows;
}

export async function findVariantForUpdate(connection, variantId) {
  const [rows] = await connection.execute(
    `SELECT pv.id, pv.product_id, pv.size, pv.color, pv.stock, p.is_active
     FROM product_variants pv
     JOIN products p ON p.id = pv.product_id
     WHERE pv.id = ? LIMIT 1 FOR UPDATE`,
    [variantId],
  );
  return rows[0] ?? null;
}

export async function findCartItem(connection, cartId, variantId, lock = false) {
  const lockClause = lock ? ' FOR UPDATE' : '';
  const [rows] = await connection.execute(
    `SELECT id, variant_id, quantity FROM cart_items
     WHERE cart_id = ? AND variant_id = ? LIMIT 1${lockClause}`,
    [cartId, variantId],
  );
  return rows[0] ?? null;
}

export async function insertCartItem(connection, cartId, variantId, quantity) {
  const [result] = await connection.execute(
    'INSERT INTO cart_items (cart_id, variant_id, quantity) VALUES (?, ?, ?)',
    [cartId, variantId, quantity],
  );
  return result.insertId;
}

export async function updateCartItemQuantity(connection, itemId, quantity) {
  await connection.execute(
    'UPDATE cart_items SET quantity = ? WHERE id = ?',
    [quantity, itemId],
  );
}

export async function findCartItemById(connection, cartId, itemId, lock = false) {
  const lockClause = lock ? ' FOR UPDATE' : '';
  const [rows] = await connection.execute(
    `SELECT id, variant_id, quantity FROM cart_items
     WHERE cart_id = ? AND id = ? LIMIT 1${lockClause}`,
    [cartId, itemId],
  );
  return rows[0] ?? null;
}

export async function deleteCartItem(connection, cartId, itemId) {
  const [result] = await connection.execute(
    'DELETE FROM cart_items WHERE cart_id = ? AND id = ?',
    [cartId, itemId],
  );
  return result.affectedRows;
}

export async function clearCart(connection, cartId) {
  await connection.execute('DELETE FROM cart_items WHERE cart_id = ?', [cartId]);
}

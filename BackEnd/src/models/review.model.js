import { pool } from '../config/database.js';

export async function productExists(productId) {
  const [rows] = await pool.execute(
    'SELECT id FROM products WHERE id = ? AND is_active = 1 LIMIT 1',
    [productId],
  );
  return Boolean(rows[0]);
}

export async function findReviews(productId, { limit, offset }) {
  const [countRows] = await pool.execute(
    `SELECT COUNT(*) AS total, COALESCE(AVG(rating), 0) AS rating_average
     FROM reviews WHERE product_id = ?`,
    [productId],
  );
  const [items] = await pool.execute(
    `SELECT r.id, r.rating, r.comment, r.created_at, u.id AS user_id, u.name AS user_name
     FROM reviews r JOIN users u ON u.id = r.user_id
     WHERE r.product_id = ? ORDER BY r.created_at DESC, r.id DESC
     LIMIT ? OFFSET ?`,
    [productId, limit, offset],
  );
  return {
    items,
    total: Number(countRows[0].total),
    rating_average: Number(countRows[0].rating_average),
  };
}

export async function hasDeliveredPurchase(userId, productId) {
  const [rows] = await pool.execute(
    `SELECT o.id
     FROM orders o
     JOIN order_items oi ON oi.order_id = o.id
     JOIN product_variants pv ON pv.id = oi.variant_id
     WHERE o.user_id = ? AND o.status = 'delivered' AND pv.product_id = ?
     LIMIT 1`,
    [userId, productId],
  );
  return Boolean(rows[0]);
}

export async function insertReview(userId, productId, review) {
  const [result] = await pool.execute(
    'INSERT INTO reviews (product_id, user_id, rating, comment) VALUES (?, ?, ?, ?)',
    [productId, userId, review.rating, review.comment ?? null],
  );
  const [rows] = await pool.execute(
    `SELECT r.id, r.rating, r.comment, r.created_at, u.id AS user_id, u.name AS user_name
     FROM reviews r JOIN users u ON u.id = r.user_id WHERE r.id = ?`,
    [result.insertId],
  );
  return rows[0];
}

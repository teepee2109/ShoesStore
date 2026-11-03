import { pool } from '../config/database.js';

export async function findWishlist(userId) {
  const [rows] = await pool.execute(
    `SELECT w.id AS wishlist_id, p.id AS product_id, p.name,
            p.description, p.price, p.discount_price, p.main_image,
            c.name AS category_name, c.slug AS category_slug
     FROM wishlists w
     JOIN products p ON p.id = w.product_id
     JOIN categories c ON c.id = p.category_id
     WHERE w.user_id = ? AND p.is_active = 1
     ORDER BY w.id DESC`,
    [userId],
  );
  return rows;
}

export async function productIsActive(productId) {
  const [rows] = await pool.execute(
    'SELECT id FROM products WHERE id = ? AND is_active = 1 LIMIT 1',
    [productId],
  );
  return rows.length > 0;
}

export async function addWishlistProduct(userId, productId) {
  await pool.execute(
    `INSERT INTO wishlists (user_id, product_id) VALUES (?, ?)
     ON DUPLICATE KEY UPDATE id = LAST_INSERT_ID(id)`,
    [userId, productId],
  );
}

export async function removeWishlistProduct(userId, productId) {
  const [result] = await pool.execute(
    'DELETE FROM wishlists WHERE user_id = ? AND product_id = ?',
    [userId, productId],
  );
  return result.affectedRows;
}

import { pool } from '../config/database.js';

export async function findCategories() {
  const [rows] = await pool.execute(
    `SELECT c.id, c.name, c.slug, c.image, COUNT(p.id) AS product_count
     FROM categories c
     LEFT JOIN products p ON p.category_id = c.id AND p.is_active = 1
     GROUP BY c.id
     ORDER BY c.name`,
  );
  return rows;
}

export async function findProducts({ filters, sort, limit, offset }) {
  const conditions = ['p.is_active = 1'];
  const values = [];

  if (filters.q) {
    conditions.push('(p.name LIKE ? OR p.description LIKE ?)');
    values.push(`%${filters.q}%`, `%${filters.q}%`);
  }
  if (filters.category) {
    conditions.push('c.slug = ?');
    values.push(filters.category);
  }
  if (filters.minPrice !== undefined) {
    conditions.push('COALESCE(p.discount_price, p.price) >= ?');
    values.push(filters.minPrice);
  }
  if (filters.maxPrice !== undefined) {
    conditions.push('COALESCE(p.discount_price, p.price) <= ?');
    values.push(filters.maxPrice);
  }
  if (filters.size || filters.color) {
    const variantConditions = ['v.product_id = p.id'];
    if (filters.size) {
      variantConditions.push('v.size = ?');
      values.push(filters.size);
    }
    if (filters.color) {
      variantConditions.push('v.color LIKE ?');
      values.push(`%${filters.color}%`);
    }
    conditions.push(`EXISTS (SELECT 1 FROM product_variants v WHERE ${variantConditions.join(' AND ')})`);
  }

  const whereClause = conditions.join(' AND ');
  const orderBy = {
    latest: 'p.created_at DESC, p.id DESC',
    price_asc: 'COALESCE(p.discount_price, p.price) ASC, p.id DESC',
    price_desc: 'COALESCE(p.discount_price, p.price) DESC, p.id DESC',
  }[sort];

  const [countRows] = await pool.execute(
    `SELECT COUNT(*) AS total
     FROM products p JOIN categories c ON c.id = p.category_id
     WHERE ${whereClause}`,
    values,
  );
  const [rows] = await pool.execute(
    `SELECT p.id, p.name, p.description, p.price, p.discount_price,
            p.main_image, p.created_at, c.name AS category_name,
            c.slug AS category_slug, COALESCE(SUM(pv.stock), 0) AS stock
     FROM products p
     JOIN categories c ON c.id = p.category_id
     LEFT JOIN product_variants pv ON pv.product_id = p.id
     WHERE ${whereClause}
     GROUP BY p.id, c.id
     ORDER BY ${orderBy}
     LIMIT ? OFFSET ?`,
    [...values, limit, offset],
  );

  return { items: rows, total: Number(countRows[0].total) };
}

export async function findProductById(id) {
  const [rows] = await pool.execute(
    `SELECT p.id, p.name, p.description, p.price, p.discount_price,
            p.main_image, p.created_at, c.id AS category_id,
            c.name AS category_name, c.slug AS category_slug,
            COALESCE(review_summary.rating_average, 0) AS rating_average,
            COALESCE(review_summary.review_count, 0) AS review_count
     FROM products p
     JOIN categories c ON c.id = p.category_id
     LEFT JOIN (
       SELECT product_id, AVG(rating) AS rating_average, COUNT(*) AS review_count
       FROM reviews GROUP BY product_id
     ) AS review_summary ON review_summary.product_id = p.id
     WHERE p.id = ? AND p.is_active = 1 LIMIT 1`,
    [id],
  );
  if (!rows[0]) return null;

  const [images] = await pool.execute(
    'SELECT id, url FROM product_images WHERE product_id = ? ORDER BY id',
    [id],
  );
  const [variants] = await pool.execute(
    `SELECT id, size, color, stock
     FROM product_variants WHERE product_id = ? ORDER BY size, color`,
    [id],
  );
  const [reviews] = await pool.execute(
    `SELECT r.id, r.rating, r.comment, r.created_at, u.name AS user_name
     FROM reviews r JOIN users u ON u.id = r.user_id
     WHERE r.product_id = ? ORDER BY r.created_at DESC LIMIT 10`,
    [id],
  );

  return { ...rows[0], images, variants, reviews };
}

import { pool } from '../config/database.js';

export async function insertCategory(category) {
  const [result] = await pool.execute(
    'INSERT INTO categories (name, slug, image) VALUES (?, ?, ?)',
    [category.name, category.slug, category.image ?? null],
  );
  return result.insertId;
}

export async function findCategory(id) {
  const [rows] = await pool.execute(
    `SELECT c.id, c.name, c.slug, c.image, COUNT(p.id) AS product_count
     FROM categories c LEFT JOIN products p ON p.category_id = c.id
     WHERE c.id = ? GROUP BY c.id LIMIT 1`,
    [id],
  );
  return rows[0] ?? null;
}

export async function updateCategory(id, category) {
  const [result] = await pool.execute(
    'UPDATE categories SET name = ?, slug = ?, image = ? WHERE id = ?',
    [category.name, category.slug, category.image ?? null, id],
  );
  return result.affectedRows;
}

export async function deleteCategory(id) {
  const [result] = await pool.execute('DELETE FROM categories WHERE id = ?', [id]);
  return result.affectedRows;
}

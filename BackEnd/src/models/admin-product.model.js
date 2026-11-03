import { pool } from '../config/database.js';

export async function categoryExists(categoryId, connection = pool) {
  const [rows] = await connection.execute(
    'SELECT id FROM categories WHERE id = ? LIMIT 1',
    [categoryId],
  );
  return rows.length > 0;
}

export async function insertProduct(product) {
  const [result] = await pool.execute(
    `INSERT INTO products
       (category_id, name, description, price, discount_price)
     VALUES (?, ?, ?, ?, ?)`,
    [
      product.category_id,
      product.name,
      product.description ?? null,
      product.price,
      product.discount_price ?? null,
    ],
  );
  return result.insertId;
}

export async function updateProductById(productId, product) {
  const [result] = await pool.execute(
    `UPDATE products
     SET category_id = ?, name = ?, description = ?, price = ?,
         discount_price = ?
     WHERE id = ?`,
    [
      product.category_id,
      product.name,
      product.description ?? null,
      product.price,
      product.discount_price ?? null,
      productId,
    ],
  );
  return result.affectedRows;
}

export async function deactivateProductById(productId) {
  const [result] = await pool.execute(
    'UPDATE products SET is_active = 0 WHERE id = ?',
    [productId],
  );
  return result.affectedRows;
}

export async function productExists(productId, connection = pool) {
  const lockClause = connection === pool ? '' : ' FOR UPDATE';
  const [rows] = await connection.execute(
    `SELECT id, main_image FROM products WHERE id = ? LIMIT 1${lockClause}`,
    [productId],
  );
  return rows[0] ?? null;
}

export async function insertProductImages(connection, productId, images) {
  for (const image of images) {
    await connection.execute(
      'INSERT INTO product_images (product_id, url) VALUES (?, ?)',
      [productId, image.url],
    );
  }
}

export async function setMainImageIfEmpty(connection, productId, url) {
  await connection.execute(
    'UPDATE products SET main_image = ? WHERE id = ? AND main_image IS NULL',
    [url, productId],
  );
}

export async function findProductImage(connection, productId, imageId) {
  const [rows] = await connection.execute(
    `SELECT id, url FROM product_images
     WHERE product_id = ? AND id = ? LIMIT 1 FOR UPDATE`,
    [productId, imageId],
  );
  return rows[0] ?? null;
}

export async function findNextProductImage(connection, productId, excludedImageId) {
  const [rows] = await connection.execute(
    `SELECT url FROM product_images
     WHERE product_id = ? AND id <> ? ORDER BY id LIMIT 1`,
    [productId, excludedImageId],
  );
  return rows[0]?.url ?? null;
}

export async function setMainImage(connection, productId, url) {
  await connection.execute(
    'UPDATE products SET main_image = ? WHERE id = ?',
    [url, productId],
  );
}

export async function deleteProductImage(connection, productId, imageId) {
  await connection.execute(
    'DELETE FROM product_images WHERE product_id = ? AND id = ?',
    [productId, imageId],
  );
}

export async function findProductVariant(connection, productId, variantId) {
  const [rows] = await connection.execute(
    `SELECT id, product_id, size, color, stock
     FROM product_variants WHERE product_id = ? AND id = ? LIMIT 1 FOR UPDATE`,
    [productId, variantId],
  );
  return rows[0] ?? null;
}

export async function insertProductVariant(productId, variant) {
  const [result] = await pool.execute(
    `INSERT INTO product_variants (product_id, size, color, stock)
     VALUES (?, ?, ?, ?)`,
    [productId, variant.size, variant.color, variant.stock],
  );
  return result.insertId;
}

export async function updateProductVariant(productId, variantId, variant, connection = pool) {
  const [result] = await connection.execute(
    `UPDATE product_variants SET size = ?, color = ?, stock = ?
     WHERE product_id = ? AND id = ?`,
    [variant.size, variant.color, variant.stock, productId, variantId],
  );
  return result.affectedRows;
}

export async function countVariantReferences(connection, variantId) {
  const [rows] = await connection.execute(
    `SELECT
       (SELECT COUNT(*) FROM order_items WHERE variant_id = ?) AS order_count,
       (SELECT COUNT(*) FROM cart_items WHERE variant_id = ?) AS cart_count`,
    [variantId, variantId],
  );
  return rows[0];
}

export async function deleteProductVariant(productId, variantId, connection = pool) {
  const [result] = await connection.execute(
    'DELETE FROM product_variants WHERE product_id = ? AND id = ?',
    [productId, variantId],
  );
  return result.affectedRows;
}

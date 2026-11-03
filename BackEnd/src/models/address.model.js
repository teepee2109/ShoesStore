import { pool } from '../config/database.js';

export async function lockUserAddresses(connection, userId) {
  const [rows] = await connection.execute(
    'SELECT id FROM users WHERE id = ? FOR UPDATE',
    [userId],
  );
  return rows.length > 0;
}

export async function findAddresses(userId) {
  const [rows] = await pool.execute(
    `SELECT id, receiver_name, phone, address_line, city, is_default
     FROM addresses WHERE user_id = ?
     ORDER BY is_default DESC, id DESC`,
    [userId],
  );
  return rows;
}

export async function findAddress(connection, userId, addressId, lock = false) {
  const lockClause = lock ? ' FOR UPDATE' : '';
  const [rows] = await connection.execute(
    `SELECT id, user_id, receiver_name, phone, address_line, city, is_default
     FROM addresses WHERE user_id = ? AND id = ? LIMIT 1${lockClause}`,
    [userId, addressId],
  );
  return rows[0] ?? null;
}

export async function unsetDefaultAddresses(connection, userId) {
  await connection.execute(
    'UPDATE addresses SET is_default = 0 WHERE user_id = ?',
    [userId],
  );
}

export async function countAddresses(connection, userId) {
  const [rows] = await connection.execute(
    'SELECT COUNT(*) AS total FROM addresses WHERE user_id = ?',
    [userId],
  );
  return Number(rows[0].total);
}

export async function insertAddress(connection, userId, address) {
  const [result] = await connection.execute(
    `INSERT INTO addresses
       (user_id, receiver_name, phone, address_line, city, is_default)
     VALUES (?, ?, ?, ?, ?, ?)`,
    [
      userId,
      address.receiver_name,
      address.phone,
      address.address_line,
      address.city,
      address.is_default,
    ],
  );
  return result.insertId;
}

export async function updateAddress(connection, userId, addressId, address) {
  await connection.execute(
    `UPDATE addresses
     SET receiver_name = ?, phone = ?, address_line = ?, city = ?, is_default = ?
     WHERE user_id = ? AND id = ?`,
    [
      address.receiver_name,
      address.phone,
      address.address_line,
      address.city,
      address.is_default,
      userId,
      addressId,
    ],
  );
}

export async function deleteAddress(connection, userId, addressId) {
  const [result] = await connection.execute(
    'DELETE FROM addresses WHERE user_id = ? AND id = ?',
    [userId, addressId],
  );
  return result.affectedRows;
}

export async function findNextAddress(connection, userId) {
  const [rows] = await connection.execute(
    'SELECT id FROM addresses WHERE user_id = ? ORDER BY id DESC LIMIT 1 FOR UPDATE',
    [userId],
  );
  return rows[0]?.id ?? null;
}

export async function setAddressDefault(connection, userId, addressId) {
  await connection.execute(
    'UPDATE addresses SET is_default = 1 WHERE user_id = ? AND id = ?',
    [userId, addressId],
  );
}

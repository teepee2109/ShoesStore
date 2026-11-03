import { pool } from '../config/database.js';

export async function findUserByEmail(email) {
  const [rows] = await pool.execute(
    `SELECT id, name, email, password_hash, phone, role
     FROM users WHERE email = ? LIMIT 1`,
    [email],
  );
  return rows[0] ?? null;
}

export async function findPublicUserById(id) {
  const [rows] = await pool.execute(
    `SELECT id, name, email, phone, role, avatar, created_at
     FROM users WHERE id = ? LIMIT 1`,
    [id],
  );
  return rows[0] ?? null;
}

export async function findUserWithPasswordById(id) {
  const [rows] = await pool.execute(
    'SELECT id, password_hash FROM users WHERE id = ? LIMIT 1',
    [id],
  );
  return rows[0] ?? null;
}

export async function updateProfile(id, { name, phone }) {
  if (phone === undefined) {
    await pool.execute('UPDATE users SET name = ? WHERE id = ?', [name, id]);
  } else {
    await pool.execute(
      'UPDATE users SET name = ?, phone = ? WHERE id = ?',
      [name, phone || null, id],
    );
  }
  return findPublicUserById(id);
}

export async function updatePassword(id, passwordHash) {
  const [result] = await pool.execute(
    'UPDATE users SET password_hash = ? WHERE id = ?',
    [passwordHash, id],
  );
  return result.affectedRows > 0;
}

export async function createCustomer({ name, email, passwordHash, phone }) {
  const connection = await pool.getConnection();
  try {
    await connection.beginTransaction();
    const [result] = await connection.execute(
      `INSERT INTO users (name, email, password_hash, phone, role)
       VALUES (?, ?, ?, ?, 'customer')`,
      [name, email, passwordHash, phone || null],
    );
    await connection.execute('INSERT INTO carts (user_id) VALUES (?)', [result.insertId]);
    await connection.commit();
    return findPublicUserById(result.insertId);
  } catch (error) {
    await connection.rollback();
    throw error;
  } finally {
    connection.release();
  }
}

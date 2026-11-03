import { pool } from '../config/database.js';

export async function findSupportAdmin() {
  const [rows] = await pool.execute(
    `SELECT id, name FROM users WHERE role = 'admin' ORDER BY id LIMIT 1`,
  );
  return rows[0] ?? null;
}

export async function findCustomer(customerId) {
  const [rows] = await pool.execute(
    `SELECT id, name, email FROM users WHERE id = ? AND role = 'customer' LIMIT 1`,
    [customerId],
  );
  return rows[0] ?? null;
}

export async function listConversationMessages(customerId, limit = 100) {
  const [rows] = await pool.execute(
    `SELECT m.id, m.sender_id, m.receiver_id, m.content, m.is_read, m.created_at,
            sender.name AS sender_name, sender.role AS sender_role
     FROM messages m
     JOIN users sender ON sender.id = m.sender_id
     WHERE (m.sender_id = ? AND EXISTS (
              SELECT 1 FROM users receiver WHERE receiver.id = m.receiver_id AND receiver.role = 'admin'
            ))
        OR (m.receiver_id = ? AND EXISTS (
              SELECT 1 FROM users source WHERE source.id = m.sender_id AND source.role = 'admin'
            ))
     ORDER BY m.id DESC LIMIT ?`,
    [customerId, customerId, limit],
  );
  return rows.reverse();
}

export async function markAdminMessagesRead(customerId) {
  await pool.execute(
    `UPDATE messages SET is_read = 1
     WHERE receiver_id = ? AND is_read = 0 AND EXISTS (
       SELECT 1 FROM users sender WHERE sender.id = messages.sender_id AND sender.role = 'admin'
     )`,
    [customerId],
  );
}

export async function markCustomerMessagesRead(customerId) {
  await pool.execute(
    `UPDATE messages SET is_read = 1
     WHERE sender_id = ? AND is_read = 0 AND EXISTS (
       SELECT 1 FROM users receiver WHERE receiver.id = messages.receiver_id AND receiver.role = 'admin'
     )`,
    [customerId],
  );
}

export async function insertMessage(senderId, receiverId, content) {
  const [result] = await pool.execute(
    `INSERT INTO messages (sender_id, receiver_id, content) VALUES (?, ?, ?)`,
    [senderId, receiverId, content],
  );
  const [rows] = await pool.execute(
    `SELECT m.id, m.sender_id, m.receiver_id, m.content, m.is_read, m.created_at,
            sender.name AS sender_name, sender.role AS sender_role
     FROM messages m JOIN users sender ON sender.id = m.sender_id
     WHERE m.id = ? LIMIT 1`,
    [result.insertId],
  );
  return rows[0];
}

export async function listAdminConversations(limit = 100) {
  const [rows] = await pool.execute(
    `SELECT u.id AS customer_id, u.name AS customer_name, u.email AS customer_email,
            (SELECT m.content FROM messages m
             WHERE (m.sender_id = u.id AND EXISTS (
                      SELECT 1 FROM users r WHERE r.id = m.receiver_id AND r.role = 'admin'
                    ))
                OR (m.receiver_id = u.id AND EXISTS (
                      SELECT 1 FROM users s WHERE s.id = m.sender_id AND s.role = 'admin'
                    ))
             ORDER BY m.id DESC LIMIT 1) AS last_message,
            (SELECT m.created_at FROM messages m
             WHERE (m.sender_id = u.id AND EXISTS (
                      SELECT 1 FROM users r WHERE r.id = m.receiver_id AND r.role = 'admin'
                    ))
                OR (m.receiver_id = u.id AND EXISTS (
                      SELECT 1 FROM users s WHERE s.id = m.sender_id AND s.role = 'admin'
                    ))
             ORDER BY m.id DESC LIMIT 1) AS last_message_at,
            (SELECT COUNT(*) FROM messages m
             WHERE m.sender_id = u.id AND m.is_read = 0 AND EXISTS (
               SELECT 1 FROM users r WHERE r.id = m.receiver_id AND r.role = 'admin'
             )) AS unread_count
     FROM users u
     WHERE u.role = 'customer' AND EXISTS (
       SELECT 1 FROM messages m
       WHERE (m.sender_id = u.id AND EXISTS (
                SELECT 1 FROM users r WHERE r.id = m.receiver_id AND r.role = 'admin'
             ))
          OR (m.receiver_id = u.id AND EXISTS (
                SELECT 1 FROM users s WHERE s.id = m.sender_id AND s.role = 'admin'
             ))
     )
     ORDER BY last_message_at DESC, u.id DESC LIMIT ?`,
    [limit],
  );
  return rows;
}

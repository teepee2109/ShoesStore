import { pool } from '../config/database.js';

export async function findNotifications(userId, { unread, limit, offset }) {
  const conditions = ['user_id = ?'];
  const values = [userId];
  if (unread !== undefined) {
    conditions.push('is_read = ?');
    values.push(unread ? 0 : 1);
  }
  const where = conditions.join(' AND ');
  const [countRows] = await pool.execute(`SELECT COUNT(*) AS total FROM notifications WHERE ${where}`, values);
  const [unreadRows] = await pool.execute(
    'SELECT COUNT(*) AS total FROM notifications WHERE user_id = ? AND is_read = 0',
    [userId],
  );
  const [items] = await pool.execute(
    `SELECT id, title, body, is_read, created_at FROM notifications
     WHERE ${where} ORDER BY created_at DESC, id DESC LIMIT ? OFFSET ?`,
    [...values, limit, offset],
  );
  return { items, total: Number(countRows[0].total), unread_count: Number(unreadRows[0].total) };
}

export async function markNotificationRead(userId, notificationId) {
  const [result] = await pool.execute(
    'UPDATE notifications SET is_read = 1 WHERE id = ? AND user_id = ?',
    [notificationId, userId],
  );
  return result.affectedRows;
}

export async function markAllNotificationsRead(userId) {
  const [result] = await pool.execute(
    'UPDATE notifications SET is_read = 1 WHERE user_id = ? AND is_read = 0',
    [userId],
  );
  return result.affectedRows;
}

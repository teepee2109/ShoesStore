import { AppError } from '../utils/app-error.js';
import * as notificationModel from '../models/notification.model.js';
import { notificationQuerySchema } from '../validators/admin.validators.js';

function parseId(value) {
  const id = Number(value);
  if (!Number.isSafeInteger(id) || id <= 0) throw new AppError('Mã thông báo không hợp lệ.', 400);
  return id;
}

export async function list(userId, query) {
  const { page, limit, unread } = notificationQuerySchema.parse(query);
  const result = await notificationModel.findNotifications(userId, {
    unread: unread === undefined ? undefined : unread === 'true',
    limit,
    offset: (page - 1) * limit,
  });
  return { ...result, pagination: { page, limit, total: result.total, total_pages: Math.ceil(result.total / limit) } };
}

export async function markRead(userId, value) {
  const affectedRows = await notificationModel.markNotificationRead(userId, parseId(value));
  if (!affectedRows) throw new AppError('Không tìm thấy thông báo.', 404);
  return { id: Number(value), is_read: true };
}

export async function markAllRead(userId) {
  const updated = await notificationModel.markAllNotificationsRead(userId);
  return { updated };
}

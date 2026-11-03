import * as notificationService from '../services/notification.service.js';

export async function list(req, res) {
  const data = await notificationService.list(req.auth.sub, req.query);
  res.json({ success: true, data, message: 'Lấy thông báo thành công.' });
}

export async function markRead(req, res) {
  const data = await notificationService.markRead(req.auth.sub, req.params.id);
  res.json({ success: true, data, message: 'Đã đánh dấu thông báo đã đọc.' });
}

export async function markAllRead(req, res) {
  const data = await notificationService.markAllRead(req.auth.sub);
  res.json({ success: true, data, message: 'Đã đánh dấu tất cả thông báo đã đọc.' });
}

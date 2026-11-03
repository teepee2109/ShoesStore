import * as adminService from '../services/admin.service.js';
import * as chatService from '../services/chat.service.js';

export async function orders(req, res) {
  const data = await adminService.listOrders(req.query);
  res.json({ success: true, data, message: 'Lấy danh sách đơn hàng thành công.' });
}

export async function updateOrderStatus(req, res) {
  const data = await adminService.updateOrderStatus(req.params.id, req.body);
  res.json({ success: true, data, message: 'Cập nhật trạng thái đơn hàng thành công.' });
}

export async function users(req, res) {
  const data = await adminService.listUsers(req.query);
  res.json({ success: true, data, message: 'Lấy danh sách người dùng thành công.' });
}

export async function user(req, res) {
  const data = await adminService.getUser(req.params.id);
  res.json({ success: true, data, message: 'Lấy người dùng thành công.' });
}

export async function updateUser(req, res) {
  const data = await adminService.updateUser(req.auth.sub, req.params.id, req.body);
  res.json({ success: true, data, message: 'Cập nhật người dùng thành công.' });
}

export async function deleteUser(req, res) {
  const data = await adminService.deleteUser(req.auth.sub, req.params.id);
  res.json({ success: true, data, message: 'Đã xóa người dùng.' });
}

export async function createCategory(req, res) {
  const data = await adminService.createCategory(req.body);
  res.status(201).json({ success: true, data, message: 'Tạo danh mục thành công.' });
}

export async function updateCategory(req, res) {
  const data = await adminService.updateCategory(req.params.id, req.body);
  res.json({ success: true, data, message: 'Cập nhật danh mục thành công.' });
}

export async function deleteCategory(req, res) {
  const data = await adminService.deleteCategory(req.params.id);
  res.json({ success: true, data, message: 'Đã xóa danh mục.' });
}

export async function chats(_req, res) {
  const data = await chatService.listAdminConversations();
  res.json({ success: true, data, message: 'Lấy danh sách cuộc trò chuyện thành công.' });
}

export async function chatMessages(req, res) {
  const data = await chatService.getAdminConversation(req.params.customerId);
  res.json({ success: true, data, message: 'Lấy tin nhắn thành công.' });
}

import * as authService from '../services/auth.service.js';

export async function register(req, res) {
  const data = await authService.register(req.body);
  res.status(201).json({ success: true, data, message: 'Đăng ký thành công.' });
}

export async function login(req, res) {
  const data = await authService.login(req.body);
  res.json({ success: true, data, message: 'Đăng nhập thành công.' });
}

export async function me(req, res) {
  const user = await authService.getCurrentUser(req.auth.sub);
  res.json({ success: true, data: user, message: 'Lấy thông tin tài khoản thành công.' });
}

export async function updateMe(req, res) {
  const user = await authService.updateCurrentUser(req.auth.sub, req.body);
  res.json({ success: true, data: user, message: 'Cập nhật hồ sơ thành công.' });
}

export async function changePassword(req, res) {
  const data = await authService.changePassword(req.auth.sub, req.body);
  res.json({ success: true, data, message: 'Đổi mật khẩu thành công.' });
}

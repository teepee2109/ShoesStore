import jwt from 'jsonwebtoken';
import { env } from '../config/env.js';
import { AppError } from '../utils/app-error.js';

export function auth(req, _res, next) {
  const authorization = req.headers.authorization ?? '';
  const match = /^Bearer\s+([^\s]+)$/i.exec(authorization);
  if (!match) {
    return next(new AppError('Vui lòng đăng nhập để tiếp tục.', 401));
  }

  try {
    req.auth = jwt.verify(match[1], env.jwtSecret);
    return next();
  } catch {
    return next(new AppError('Phiên đăng nhập không hợp lệ hoặc đã hết hạn.', 401));
  }
}

export const requireAuth = auth;

export function requireRole(role) {
  return (req, _res, next) => {
    if (!req.auth) {
      return next(new AppError('Vui lòng đăng nhập để tiếp tục.', 401));
    }
    if (req.auth.role !== role) {
      return next(new AppError('Bạn không có quyền thực hiện thao tác này.', 403));
    }
    return next();
  };
}

export const requireAdmin = requireRole('admin');

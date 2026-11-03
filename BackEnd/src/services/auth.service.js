import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { env } from '../config/env.js';
import { AppError } from '../utils/app-error.js';
import * as authModel from '../models/auth.model.js';
import {
  loginSchema,
  passwordChangeSchema,
  profileUpdateSchema,
  registerSchema,
} from '../validators/auth.validators.js';

function issueToken(user) {
  return jwt.sign({ role: user.role }, env.jwtSecret, {
    subject: String(user.id),
    expiresIn: env.jwtExpiresIn,
  });
}

export async function register(input) {
  const data = registerSchema.parse(input);
  const email = data.email.toLowerCase();
  if (await authModel.findUserByEmail(email)) {
    throw new AppError('Email đã được sử dụng.', 409);
  }

  const passwordHash = await bcrypt.hash(data.password, 10);
  const user = await authModel.createCustomer({ ...data, email, passwordHash });
  return { user, token: issueToken(user) };
}

export async function login(input) {
  const data = loginSchema.parse(input);
  const user = await authModel.findUserByEmail(data.email.toLowerCase());
  if (!user || !(await bcrypt.compare(data.password, user.password_hash))) {
    throw new AppError('Email hoặc mật khẩu không đúng.', 401);
  }

  const { password_hash: _passwordHash, ...publicUser } = user;
  return { user: publicUser, token: issueToken(user) };
}

export async function getCurrentUser(id) {
  const user = await authModel.findPublicUserById(id);
  if (!user) throw new AppError('Không tìm thấy tài khoản.', 404);
  return user;
}

export async function updateCurrentUser(id, input) {
  const data = profileUpdateSchema.parse(input);
  const user = await authModel.updateProfile(id, data);
  if (!user) throw new AppError('Không tìm thấy tài khoản.', 404);
  return user;
}

export async function changePassword(id, input) {
  const data = passwordChangeSchema.parse(input);
  const user = await authModel.findUserWithPasswordById(id);
  if (!user) throw new AppError('Không tìm thấy tài khoản.', 404);
  if (!(await bcrypt.compare(data.current_password, user.password_hash))) {
    throw new AppError('Mật khẩu hiện tại không đúng.', 400);
  }
  await authModel.updatePassword(id, await bcrypt.hash(data.new_password, 10));
  return { changed: true };
}

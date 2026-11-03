import { z } from 'zod';

export const registerSchema = z.object({
  name: z.string().trim().min(2, 'Tên phải có ít nhất 2 ký tự.').max(100),
  email: z.string().trim().email('Email không hợp lệ.').max(150),
  password: z.string().min(6, 'Mật khẩu phải có ít nhất 6 ký tự.').max(72),
  phone: z.string().trim().max(20).optional().or(z.literal('')),
});

export const loginSchema = z.object({
  email: z.string().trim().email('Email không hợp lệ.').max(150),
  password: z.string().min(1, 'Vui lòng nhập mật khẩu.'),
});

export const profileUpdateSchema = z.object({
  name: z.string().trim().min(2, 'Tên phải có ít nhất 2 ký tự.').max(100),
  phone: z.string().trim().max(20).optional().or(z.literal('')),
});

export const passwordChangeSchema = z.object({
  current_password: z.string().min(1, 'Vui lòng nhập mật khẩu hiện tại.'),
  new_password: z.string().min(6, 'Mật khẩu mới phải có ít nhất 6 ký tự.').max(72),
}).refine((data) => data.current_password !== data.new_password, {
  message: 'Mật khẩu mới cần khác mật khẩu hiện tại.',
  path: ['new_password'],
});

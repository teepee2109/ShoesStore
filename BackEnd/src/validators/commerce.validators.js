import { z } from 'zod';

const id = z.coerce.number().int().positive();

export const cartItemSchema = z.object({
  variant_id: id,
  quantity: z.coerce.number().int().min(1).max(100).default(1),
});

export const quantitySchema = z.object({
  quantity: z.coerce.number().int().min(1).max(100),
});

export const wishlistSchema = z.object({ product_id: id });

export const addressSchema = z.object({
  receiver_name: z.string().trim().min(2).max(100),
  phone: z.string().trim().regex(/^\+?[0-9\s-]{9,20}$/, 'Số điện thoại không hợp lệ.'),
  address_line: z.string().trim().min(5).max(255),
  city: z.string().trim().min(2).max(100),
  is_default: z.boolean().optional(),
});

export const orderCreateSchema = z.object({
  address_id: id,
  payment_method: z.enum(['cod', 'vnpay', 'momo', 'paypal']).default('cod'),
});

export const orderListQuerySchema = z.object({
  status: z.enum(['pending', 'confirmed', 'shipping', 'delivered', 'cancelled']).optional(),
  page: z.coerce.number().int().min(1).default(1),
  limit: z.coerce.number().int().min(1).max(50).default(20),
});

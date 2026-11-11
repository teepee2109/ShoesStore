import { z } from 'zod';

const statuses = ['pending', 'confirmed', 'shipping', 'delivered', 'cancelled'];

export const pageQuerySchema = z.object({
  page: z.coerce.number().int().min(1).default(1),
  limit: z.coerce.number().int().min(1).max(50).default(20),
});

export const adminOrderQuerySchema = pageQuerySchema.extend({
  status: z.enum(statuses).optional(),
  q: z.string().trim().max(100).optional(),
});

export const orderStatusSchema = z.object({ status: z.enum(statuses) });

export const adminUserQuerySchema = pageQuerySchema.extend({
  q: z.string().trim().max(100).optional(),
  role: z.enum(['customer', 'admin']).optional(),
});

export const adminUserUpdateSchema = z.object({
  name: z.string().trim().min(2).max(100).optional(),
  phone: z.string().trim().max(20).nullable().optional(),
  role: z.enum(['customer', 'admin']).optional(),
}).refine((value) => Object.keys(value).length > 0, 'Hãy cung cấp ít nhất một trường cần cập nhật.');

export const categorySchema = z.object({
  name: z.string().trim().min(2).max(100),
  slug: z.string().trim().min(2).max(120).optional(),
  image: z.string().trim().max(255).nullable().optional(),
});

export const reviewSchema = z.object({
  rating: z.coerce.number().int().min(1).max(5),
  comment: z.string().trim().max(2000).nullable().optional(),
});

export const reviewQuerySchema = pageQuerySchema;

export const notificationQuerySchema = pageQuerySchema.extend({
  unread: z.enum(['true', 'false']).optional(),
});

const dateString = z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional();
const dateRangeShape = { from: dateString, to: dateString };
const validDateRange = ({ from, to }) => !from || !to || from <= to;
export const revenueQuerySchema = z.object({
  ...dateRangeShape,
  group: z.enum(['day', 'month']).default('day'),
}).refine(validDateRange, {
  message: 'Ngày bắt đầu phải trước hoặc bằng ngày kết thúc.',
});
export const topProductsQuerySchema = z.object({
  ...dateRangeShape,
  limit: z.coerce.number().int().min(1).max(50).default(10),
}).refine(validDateRange, {
  message: 'Ngày bắt đầu phải trước hoặc bằng ngày kết thúc.',
});
export const orderStatusQuerySchema = z.object({
  ...dateRangeShape,
}).refine(validDateRange, {
  message: 'Ngày bắt đầu phải trước hoặc bằng ngày kết thúc.',
});
export const lowStockQuerySchema = z.object({
  threshold: z.coerce.number().int().min(0).max(100000).default(5),
  limit: z.coerce.number().int().min(1).max(100).default(50),
});

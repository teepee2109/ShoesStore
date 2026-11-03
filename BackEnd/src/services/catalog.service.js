import { z } from 'zod';
import { AppError } from '../utils/app-error.js';
import { findCategories, findProductById, findProducts } from '../models/catalog.model.js';

const listQuerySchema = z.object({
  q: z.string().trim().max(100).optional(),
  category: z.string().trim().max(120).optional(),
  minPrice: z.coerce.number().nonnegative().optional(),
  maxPrice: z.coerce.number().nonnegative().optional(),
  size: z.string().trim().max(10).optional(),
  color: z.string().trim().max(50).optional(),
  sort: z.enum(['latest', 'price_asc', 'price_desc']).default('latest'),
  page: z.coerce.number().int().min(1).default(1),
  limit: z.coerce.number().int().min(1).max(50).default(20),
});

export async function listCategories() {
  return findCategories();
}

export async function listProducts(query) {
  const parsed = listQuerySchema.safeParse(query);
  if (!parsed.success) throw parsed.error;
  const { page, limit, sort, ...filters } = parsed.data;
  if (filters.minPrice !== undefined && filters.maxPrice !== undefined && filters.minPrice > filters.maxPrice) {
    throw new AppError('Giá thấp nhất không được lớn hơn giá cao nhất.', 400);
  }

  const { items, total } = await findProducts({ filters, sort, limit, offset: (page - 1) * limit });
  return { items, pagination: { page, limit, total, total_pages: Math.ceil(total / limit) } };
}

export async function getProduct(id) {
  const productId = Number(id);
  if (!Number.isSafeInteger(productId) || productId <= 0) {
    throw new AppError('Mã sản phẩm không hợp lệ.', 400);
  }
  const product = await findProductById(productId);
  if (!product) throw new AppError('Không tìm thấy sản phẩm.', 404);
  return product;
}

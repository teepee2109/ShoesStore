import { z } from 'zod';

export const productSchema = z
  .object({
    category_id: z.coerce.number().int().positive(),
    name: z.string().trim().min(2).max(200),
    description: z.string().trim().max(10000).nullable().optional(),
    price: z.coerce.number().int().nonnegative(),
    discount_price: z.coerce.number().int().nonnegative().nullable().optional(),
  })
  .superRefine((product, context) => {
    if (product.discount_price != null && product.discount_price > product.price) {
      context.addIssue({
        code: 'custom',
        path: ['discount_price'],
        message: 'Giá khuyến mãi không được lớn hơn giá gốc.',
      });
    }
  });

export const variantSchema = z.object({
  size: z.string().trim().min(1).max(10),
  color: z.string().trim().min(1).max(50),
  stock: z.coerce.number().int().min(0).max(100000),
});

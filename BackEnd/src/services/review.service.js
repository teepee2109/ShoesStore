import { AppError } from '../utils/app-error.js';
import * as reviewModel from '../models/review.model.js';
import { reviewQuerySchema, reviewSchema } from '../validators/admin.validators.js';

function parseProductId(value) {
  const id = Number(value);
  if (!Number.isSafeInteger(id) || id <= 0) throw new AppError('Mã sản phẩm không hợp lệ.', 400);
  return id;
}

export async function listReviews(productIdValue, query) {
  const productId = parseProductId(productIdValue);
  const { page, limit } = reviewQuerySchema.parse(query);
  if (!(await reviewModel.productExists(productId))) throw new AppError('Không tìm thấy sản phẩm.', 404);
  const result = await reviewModel.findReviews(productId, { limit, offset: (page - 1) * limit });
  return {
    ...result,
    pagination: { page, limit, total: result.total, total_pages: Math.ceil(result.total / limit) },
  };
}

export async function createReview(userId, productIdValue, input) {
  const productId = parseProductId(productIdValue);
  const review = reviewSchema.parse(input);
  if (!(await reviewModel.productExists(productId))) throw new AppError('Không tìm thấy sản phẩm.', 404);
  if (!(await reviewModel.hasDeliveredPurchase(userId, productId))) {
    throw new AppError('Chỉ khách hàng đã nhận sản phẩm mới được đánh giá.', 403);
  }
  try {
    return await reviewModel.insertReview(userId, productId, review);
  } catch (error) {
    if (error?.code === 'ER_DUP_ENTRY') {
      throw new AppError('Bạn đã gửi đánh giá cho sản phẩm này rồi.', 409);
    }
    throw error;
  }
}

import { AppError } from '../utils/app-error.js';
import { wishlistSchema } from '../validators/commerce.validators.js';
import * as wishlistModel from '../models/wishlist.model.js';

function parseId(value) {
  const id = Number(value);
  if (!Number.isSafeInteger(id) || id <= 0) throw new AppError('Mã sản phẩm không hợp lệ.', 400);
  return id;
}

export async function getWishlist(userId) {
  return wishlistModel.findWishlist(userId);
}

export async function addWishlistItem(userId, input) {
  const { product_id: productId } = wishlistSchema.parse(input);
  if (!(await wishlistModel.productIsActive(productId))) {
    throw new AppError('Không tìm thấy sản phẩm.', 404);
  }
  await wishlistModel.addWishlistProduct(userId, productId);
  return wishlistModel.findWishlist(userId);
}

export async function removeWishlistItem(userId, productIdValue) {
  const productId = parseId(productIdValue);
  if (!(await wishlistModel.removeWishlistProduct(userId, productId))) {
    throw new AppError('Sản phẩm không có trong danh sách yêu thích.', 404);
  }
  return wishlistModel.findWishlist(userId);
}

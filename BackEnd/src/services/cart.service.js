import * as cartModel from '../models/cart.model.js';
import { AppError } from '../utils/app-error.js';
import { withTransaction } from '../utils/with-transaction.js';
import { cartItemSchema, quantitySchema } from '../validators/commerce.validators.js';

function parseId(value, label) {
  const id = Number(value);
  if (!Number.isSafeInteger(id) || id <= 0) throw new AppError(`${label} không hợp lệ.`, 400);
  return id;
}

export async function getCart(userId) {
  await withTransaction(async (connection) => {
    const cartId = await cartModel.lockOrCreateCart(connection, userId);
    if (!cartId) throw new AppError('Không tìm thấy tài khoản.', 404);
  });
  const items = await cartModel.findCartItems(userId);
  const subtotal = items.reduce((total, item) => total + Number(item.line_total), 0);
  return { items, subtotal };
}

export async function addItem(userId, input) {
  const data = cartItemSchema.parse(input);
  await withTransaction(async (connection) => {
    const cartId = await cartModel.lockOrCreateCart(connection, userId);
    if (!cartId) throw new AppError('Không tìm thấy tài khoản.', 404);

    const variant = await cartModel.findVariantForUpdate(connection, data.variant_id);
    if (!variant || !variant.is_active) throw new AppError('Biến thể không tồn tại hoặc đã ngừng bán.', 404);
    const current = await cartModel.findCartItem(connection, cartId, data.variant_id, true);
    const nextQuantity = (current?.quantity ?? 0) + data.quantity;
    if (nextQuantity > variant.stock) {
      throw new AppError(`Chỉ còn ${variant.stock} sản phẩm trong kho.`, 409);
    }

    if (current) {
      await cartModel.updateCartItemQuantity(connection, current.id, nextQuantity);
    } else {
      await cartModel.insertCartItem(connection, cartId, data.variant_id, data.quantity);
    }
  });
  return getCart(userId);
}

export async function updateItem(userId, itemIdValue, input) {
  const itemId = parseId(itemIdValue, 'Mã sản phẩm trong giỏ');
  const { quantity } = quantitySchema.parse(input);
  await withTransaction(async (connection) => {
    const cartId = await cartModel.lockOrCreateCart(connection, userId);
    if (!cartId) throw new AppError('Không tìm thấy tài khoản.', 404);
    const initialItem = await cartModel.findCartItemById(connection, cartId, itemId);
    if (!initialItem) throw new AppError('Không tìm thấy sản phẩm trong giỏ.', 404);

    const variant = await cartModel.findVariantForUpdate(connection, initialItem.variant_id);
    if (!variant || !variant.is_active) throw new AppError('Biến thể không còn được bán.', 409);
    const item = await cartModel.findCartItemById(connection, cartId, itemId, true);
    if (!item) throw new AppError('Sản phẩm trong giỏ đã thay đổi.', 409);
    if (quantity > variant.stock) {
      throw new AppError(`Chỉ còn ${variant.stock} sản phẩm trong kho.`, 409);
    }
    await cartModel.updateCartItemQuantity(connection, itemId, quantity);
  });
  return getCart(userId);
}

export async function removeItem(userId, itemIdValue) {
  const itemId = parseId(itemIdValue, 'Mã sản phẩm trong giỏ');
  await withTransaction(async (connection) => {
    const cartId = await cartModel.lockOrCreateCart(connection, userId);
    if (!cartId) throw new AppError('Không tìm thấy tài khoản.', 404);
    if (!(await cartModel.deleteCartItem(connection, cartId, itemId))) {
      throw new AppError('Không tìm thấy sản phẩm trong giỏ.', 404);
    }
  });
  return getCart(userId);
}

export async function removeAllItems(userId) {
  await withTransaction(async (connection) => {
    const cartId = await cartModel.lockOrCreateCart(connection, userId);
    if (!cartId) throw new AppError('Không tìm thấy tài khoản.', 404);
    await cartModel.clearCart(connection, cartId);
  });
  return getCart(userId);
}

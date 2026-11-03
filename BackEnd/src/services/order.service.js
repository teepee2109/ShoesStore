import { pool } from '../config/database.js';
import * as addressModel from '../models/address.model.js';
import * as cartModel from '../models/cart.model.js';
import * as orderModel from '../models/order.model.js';
import { AppError } from '../utils/app-error.js';
import { withTransaction } from '../utils/with-transaction.js';
import { orderCreateSchema, orderListQuerySchema } from '../validators/commerce.validators.js';

function parseId(value, label = 'Mã đơn hàng') {
  const id = Number(value);
  if (!Number.isSafeInteger(id) || id <= 0) throw new AppError(`${label} không hợp lệ.`, 400);
  return id;
}

export async function listOrders(userId, query) {
  const { status, page, limit } = orderListQuerySchema.parse(query);
  const { items, total } = await orderModel.findOrders(userId, {
    status,
    limit,
    offset: (page - 1) * limit,
  });
  return {
    items,
    pagination: { page, limit, total, total_pages: Math.ceil(total / limit) },
  };
}

export async function getOrder(userId, orderIdValue) {
  const orderId = parseId(orderIdValue);
  const order = await orderModel.findOrderById(userId, orderId);
  if (!order) throw new AppError('Không tìm thấy đơn hàng.', 404);
  return order;
}

export async function createOrder(userId, input) {
  const data = orderCreateSchema.parse(input);
  const orderId = await withTransaction(async (connection) => {
    const cartId = await cartModel.lockOrCreateCart(connection, userId);
    if (!cartId) throw new AppError('Không tìm thấy tài khoản.', 404);

    const address = await addressModel.findAddress(connection, userId, data.address_id, true);
    if (!address) throw new AppError('Địa chỉ giao hàng không tồn tại.', 404);

    const [cartItems] = await connection.execute(
      `SELECT id, variant_id, quantity FROM cart_items
       WHERE cart_id = ? ORDER BY variant_id FOR UPDATE`,
      [cartId],
    );
    if (cartItems.length === 0) throw new AppError('Giỏ hàng đang trống.', 400);

    const variantIds = cartItems.map((item) => item.variant_id);
    const placeholders = variantIds.map(() => '?').join(', ');
    const [variants] = await connection.execute(
      `SELECT pv.id, pv.product_id, pv.size, pv.color, pv.stock,
              p.name AS product_name, p.main_image, p.price,
              p.discount_price, p.is_active
       FROM product_variants pv
       JOIN products p ON p.id = pv.product_id
       WHERE pv.id IN (${placeholders})
       ORDER BY pv.id FOR UPDATE`,
      variantIds,
    );
    const variantById = new Map(variants.map((variant) => [String(variant.id), variant]));

    let totalAmount = 0;
    const orderLines = cartItems.map((item) => {
      const variant = variantById.get(String(item.variant_id));
      if (!variant || !variant.is_active) {
        throw new AppError('Một sản phẩm trong giỏ không còn được bán.', 409);
      }
      if (item.quantity > variant.stock) {
        throw new AppError(
          `${variant.product_name} size ${variant.size} chỉ còn ${variant.stock} sản phẩm.`,
          409,
        );
      }

      const unitPrice = Number(variant.discount_price ?? variant.price);
      const lineTotal = unitPrice * Number(item.quantity);
      totalAmount += lineTotal;
      if (!Number.isSafeInteger(totalAmount)) {
        throw new AppError('Tổng tiền đơn hàng vượt giới hạn xử lý.', 400);
      }
      return { ...item, variant, unitPrice };
    });

    const [orderResult] = await connection.execute(
      `INSERT INTO orders
         (user_id, address_id, shipping_name, shipping_phone, shipping_address,
          total_amount, status, payment_method, payment_status)
       VALUES (?, ?, ?, ?, ?, ?, 'pending', ?, 'unpaid')`,
      [
        userId,
        address.id,
        address.receiver_name,
        address.phone,
        `${address.address_line}, ${address.city}`,
        totalAmount,
        data.payment_method,
      ],
    );
    const createdOrderId = orderResult.insertId;

    for (const line of orderLines) {
      const [stockResult] = await connection.execute(
        `UPDATE product_variants SET stock = stock - ?
         WHERE id = ? AND stock >= ?`,
        [line.quantity, line.variant_id, line.quantity],
      );
      if (stockResult.affectedRows !== 1) {
        throw new AppError('Tồn kho vừa thay đổi. Hãy tải lại giỏ hàng.', 409);
      }
      await connection.execute(
        `INSERT INTO order_items (order_id, variant_id, quantity, unit_price)
         VALUES (?, ?, ?, ?)`,
        [createdOrderId, line.variant_id, line.quantity, line.unitPrice],
      );
    }

    await cartModel.clearCart(connection, cartId);
    await connection.execute(
      `INSERT INTO notifications (user_id, title, body)
       VALUES (?, ?, ?)`,
      [userId, 'Đặt hàng thành công', `Đơn hàng #${createdOrderId} đang chờ xác nhận.`],
    );
    return createdOrderId;
  });

  return getOrder(userId, orderId);
}

export async function cancelOrder(userId, orderIdValue) {
  const orderId = parseId(orderIdValue);
  await withTransaction(async (connection) => {
    const [orders] = await connection.execute(
      `SELECT id, status, payment_status FROM orders
       WHERE id = ? AND user_id = ? LIMIT 1 FOR UPDATE`,
      [orderId, userId],
    );
    const order = orders[0];
    if (!order) throw new AppError('Không tìm thấy đơn hàng.', 404);
    if (order.status !== 'pending' || !['unpaid', 'failed'].includes(order.payment_status)) {
      throw new AppError('Chỉ có thể hủy đơn đang chờ và chưa thanh toán.', 409);
    }

    const [items] = await connection.execute(
      `SELECT variant_id, quantity FROM order_items
       WHERE order_id = ? ORDER BY variant_id FOR UPDATE`,
      [orderId],
    );
    if (items.length === 0) throw new AppError('Đơn hàng không có sản phẩm.', 409);

    const variantIds = items.map((item) => item.variant_id);
    const placeholders = variantIds.map(() => '?').join(', ');
    const [lockedVariants] = await connection.execute(
      `SELECT id FROM product_variants
       WHERE id IN (${placeholders}) ORDER BY id FOR UPDATE`,
      variantIds,
    );
    if (lockedVariants.length !== variantIds.length) {
      throw new AppError('Không thể khôi phục tồn kho của đơn hàng.', 409);
    }

    for (const item of items) {
      await connection.execute(
        'UPDATE product_variants SET stock = stock + ? WHERE id = ?',
        [item.quantity, item.variant_id],
      );
    }
    await connection.execute(
      `UPDATE orders SET status = 'cancelled'
       WHERE id = ? AND user_id = ?`,
      [orderId, userId],
    );
    await connection.execute(
      `INSERT INTO notifications (user_id, title, body)
       VALUES (?, ?, ?)`,
      [userId, 'Đơn hàng đã hủy', `Đơn hàng #${orderId} đã được hủy và tồn kho đã hoàn lại.`],
    );
  });
  return getOrder(userId, orderId);
}

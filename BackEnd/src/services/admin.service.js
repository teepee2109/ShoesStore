import { AppError } from '../utils/app-error.js';
import { withTransaction } from '../utils/with-transaction.js';
import * as adminModel from '../models/admin.model.js';
import * as categoryModel from '../models/category-admin.model.js';
import {
  adminOrderQuerySchema,
  adminUserQuerySchema,
  adminUserUpdateSchema,
  categorySchema,
  orderStatusSchema,
} from '../validators/admin.validators.js';

function parseId(value, label) {
  const id = Number(value);
  if (!Number.isSafeInteger(id) || id <= 0) throw new AppError(`${label} không hợp lệ.`, 400);
  return id;
}

function paginated(result, page, limit) {
  return { ...result, pagination: { page, limit, total: result.total, total_pages: Math.ceil(result.total / limit) } };
}

export async function listOrders(query) {
  const { page, limit, ...filters } = adminOrderQuerySchema.parse(query);
  return paginated(await adminModel.findAdminOrders({ ...filters, limit, offset: (page - 1) * limit }), page, limit);
}

export async function updateOrderStatus(orderIdValue, input) {
  const orderId = parseId(orderIdValue, 'Mã đơn hàng');
  const { status: nextStatus } = orderStatusSchema.parse(input);
  await withTransaction(async (connection) => {
    const [rows] = await connection.execute(
      'SELECT id, user_id, status, payment_status, payment_method FROM orders WHERE id = ? LIMIT 1 FOR UPDATE',
      [orderId],
    );
    const order = rows[0];
    if (!order) throw new AppError('Không tìm thấy đơn hàng.', 404);
    if (order.status === nextStatus) return;

    const allowed = {
      pending: ['confirmed', 'cancelled'],
      confirmed: ['shipping', 'cancelled'],
      shipping: ['delivered'],
      delivered: [],
      cancelled: [],
    };
    if (!allowed[order.status]?.includes(nextStatus)) {
      throw new AppError(`Không thể chuyển đơn từ ${order.status} sang ${nextStatus}.`, 409);
    }

    if (nextStatus === 'cancelled') {
      if (!['unpaid', 'failed'].includes(order.payment_status)) {
        throw new AppError('Đơn đã thanh toán cần được hoàn tiền trước khi hủy.', 409);
      }
      const [items] = await connection.execute(
        'SELECT variant_id, quantity FROM order_items WHERE order_id = ? ORDER BY variant_id FOR UPDATE',
        [orderId],
      );
      if (!items.length) throw new AppError('Đơn hàng không có sản phẩm.', 409);
      const ids = items.map((item) => item.variant_id);
      const placeholders = ids.map(() => '?').join(', ');
      const [variants] = await connection.execute(
        `SELECT id FROM product_variants WHERE id IN (${placeholders}) ORDER BY id FOR UPDATE`,
        ids,
      );
      if (variants.length !== ids.length) throw new AppError('Không thể khôi phục tồn kho của đơn hàng.', 409);
      for (const item of items) {
        await connection.execute('UPDATE product_variants SET stock = stock + ? WHERE id = ?', [item.quantity, item.variant_id]);
      }
    }

    if (nextStatus === 'delivered' && order.payment_method === 'cod' && order.payment_status === 'unpaid') {
      await connection.execute(
        "UPDATE orders SET status = ?, payment_status = 'paid' WHERE id = ?",
        [nextStatus, orderId],
      );
    } else {
      await connection.execute('UPDATE orders SET status = ? WHERE id = ?', [nextStatus, orderId]);
    }
    const messages = {
      confirmed: 'đã được xác nhận',
      shipping: 'đang được giao',
      delivered: 'đã giao thành công',
      cancelled: 'đã bị hủy và tồn kho đã được hoàn lại',
    };
    await connection.execute(
      'INSERT INTO notifications (user_id, title, body) VALUES (?, ?, ?)',
      [order.user_id, 'Cập nhật đơn hàng', `Đơn hàng #${orderId} ${messages[nextStatus]}.`],
    );
  });
  const order = await adminModel.findAdminOrder(orderId);
  return order;
}

export async function listUsers(query) {
  const { page, limit, ...filters } = adminUserQuerySchema.parse(query);
  return paginated(await adminModel.findAdminUsers({ ...filters, limit, offset: (page - 1) * limit }), page, limit);
}

export async function getUser(userIdValue) {
  const userId = parseId(userIdValue, 'Mã người dùng');
  const user = await adminModel.findAdminUser(userId);
  if (!user) throw new AppError('Không tìm thấy người dùng.', 404);
  return user;
}

export async function updateUser(actorIdValue, userIdValue, input) {
  const actorId = parseId(actorIdValue, 'Mã quản trị viên');
  const userId = parseId(userIdValue, 'Mã người dùng');
  const changes = adminUserUpdateSchema.parse(input);
  await withTransaction(async (connection) => {
    const target = await adminModel.lockUser(connection, userId);
    if (!target) throw new AppError('Không tìm thấy người dùng.', 404);
    if (actorId === userId && changes.role === 'customer') {
      throw new AppError('Bạn không thể tự hạ quyền quản trị viên của mình.', 409);
    }
    if (target.role === 'admin' && changes.role === 'customer') {
      const admins = await adminModel.lockAdminIds(connection);
      if (admins.length <= 1) throw new AppError('Không thể hạ quyền quản trị viên cuối cùng.', 409);
    }
    await adminModel.updateAdminUser(connection, userId, changes);
  });
  return getUser(userId);
}

export async function deleteUser(actorIdValue, userIdValue) {
  const actorId = parseId(actorIdValue, 'Mã quản trị viên');
  const userId = parseId(userIdValue, 'Mã người dùng');
  await withTransaction(async (connection) => {
    if (actorId === userId) throw new AppError('Bạn không thể xóa tài khoản đang đăng nhập.', 409);
    const target = await adminModel.lockUser(connection, userId);
    if (!target) throw new AppError('Không tìm thấy người dùng.', 404);
    if (target.role === 'admin' && (await adminModel.lockAdminIds(connection)).length <= 1) {
      throw new AppError('Không thể xóa quản trị viên cuối cùng.', 409);
    }
    if (await adminModel.countUserOrders(connection, userId)) {
      throw new AppError('Người dùng có lịch sử đơn hàng và không thể xóa.', 409);
    }
    await adminModel.deleteAdminUser(connection, userId);
  });
  return { id: userId, deleted: true };
}

function slugify(value) {
  return value.normalize('NFD').replace(/[\u0300-\u036f]/g, '').replace(/đ/g, 'd').replace(/Đ/g, 'D')
    .toLowerCase().trim().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');
}

function parseCategory(input) {
  const category = categorySchema.parse(input);
  return { ...category, slug: slugify(category.slug || category.name) };
}

export async function createCategory(input) {
  const category = parseCategory(input);
  const id = await categoryModel.insertCategory(category);
  return categoryModel.findCategory(id);
}

export async function updateCategory(idValue, input) {
  const id = parseId(idValue, 'Mã danh mục');
  const category = parseCategory(input);
  const existing = await categoryModel.findCategory(id);
  if (!existing) throw new AppError('Không tìm thấy danh mục.', 404);
  await categoryModel.updateCategory(id, {
    ...category,
    image: category.image === undefined ? existing.image : category.image,
  });
  return categoryModel.findCategory(id);
}

export async function deleteCategory(idValue) {
  const id = parseId(idValue, 'Mã danh mục');
  if (!(await categoryModel.findCategory(id))) throw new AppError('Không tìm thấy danh mục.', 404);
  await categoryModel.deleteCategory(id);
  return { id, deleted: true };
}

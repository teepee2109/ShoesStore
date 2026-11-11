import { pool } from '../config/database.js';
import { AppError } from '../utils/app-error.js';
import {
  lowStockQuerySchema,
  orderStatusQuerySchema,
  revenueQuerySchema,
  topProductsQuerySchema,
} from '../validators/admin.validators.js';

const orderStatuses = ['pending', 'confirmed', 'shipping', 'delivered', 'cancelled'];

function createdAtConditions(filters) {
  for (const date of [filters.from, filters.to]) {
    if (date) {
      const parsed = new Date(`${date}T00:00:00Z`);
      if (Number.isNaN(parsed.getTime()) || parsed.toISOString().slice(0, 10) !== date) {
        throw new AppError('Ngày lọc báo cáo không hợp lệ.', 400);
      }
    }
  }
  const conditions = [];
  const values = [];
  if (filters.from) {
    conditions.push('created_at >= ?');
    values.push(`${filters.from} 00:00:00`);
  }
  if (filters.to) {
    conditions.push('created_at < DATE_ADD(?, INTERVAL 1 DAY)');
    values.push(`${filters.to} 00:00:00`);
  }
  return { conditions, values };
}

export async function revenue(query) {
  const filters = revenueQuerySchema.parse(query);
  const dateRange = createdAtConditions(filters);
  const conditions = ["payment_status = 'paid'", "status <> 'cancelled'", ...dateRange.conditions];
  const values = dateRange.values;
  const format = filters.group === 'month' ? '%Y-%m' : '%Y-%m-%d';
  const [items] = await pool.execute(
    `SELECT DATE_FORMAT(created_at, '${format}') AS period,
            SUM(total_amount) AS revenue, COUNT(*) AS order_count
     FROM orders WHERE ${conditions.join(' AND ')}
     GROUP BY period ORDER BY period`,
    values,
  );
  return { group: filters.group, items };
}

export async function topProducts(query) {
  const filters = topProductsQuerySchema.parse(query);
  const dateRange = createdAtConditions(filters);
  const conditions = ["o.status <> 'cancelled'", "o.payment_status = 'paid'", ...dateRange.conditions.map((condition) => condition.replaceAll('created_at', 'o.created_at'))];
  const [items] = await pool.execute(
    `SELECT p.id AS product_id, p.name AS product_name,
            SUM(oi.quantity) AS quantity_sold,
            SUM(oi.quantity * oi.unit_price) AS revenue
     FROM order_items oi
     JOIN orders o ON o.id = oi.order_id
     JOIN product_variants pv ON pv.id = oi.variant_id
     JOIN products p ON p.id = pv.product_id
     WHERE ${conditions.join(' AND ')}
     GROUP BY p.id, p.name
     ORDER BY quantity_sold DESC, revenue DESC
     LIMIT ?`,
    [...dateRange.values, filters.limit],
  );
  return items;
}

export async function lowStock(query) {
  const { threshold, limit } = lowStockQuerySchema.parse(query);
  const [items] = await pool.execute(
    `SELECT p.id AS product_id, p.name AS product_name,
            pv.id AS variant_id, pv.size, pv.color, pv.stock
     FROM product_variants pv
     JOIN products p ON p.id = pv.product_id
     WHERE p.is_active = 1 AND pv.stock <= ?
     ORDER BY pv.stock ASC, p.name ASC, pv.size ASC
     LIMIT ?`,
    [threshold, limit],
  );
  return { threshold, items };
}

export async function orderCounts(query = {}) {
  const filters = orderStatusQuerySchema.parse(query);
  const dateRange = createdAtConditions(filters);
  const where = dateRange.conditions.length ? `WHERE ${dateRange.conditions.join(' AND ')}` : '';
  const [rows] = await pool.execute(
    `SELECT status, COUNT(*) AS total FROM orders ${where} GROUP BY status`,
    dateRange.values,
  );
  const counts = Object.fromEntries(orderStatuses.map((status) => [status, 0]));
  for (const row of rows) counts[row.status] = Number(row.total);
  return counts;
}

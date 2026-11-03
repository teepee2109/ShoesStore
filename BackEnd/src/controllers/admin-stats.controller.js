import * as adminStatsService from '../services/admin-stats.service.js';

export async function revenue(req, res) {
  res.json({ success: true, data: await adminStatsService.revenue(req.query), message: 'Lấy thống kê doanh thu thành công.' });
}

export async function topProducts(req, res) {
  res.json({ success: true, data: await adminStatsService.topProducts(req.query), message: 'Lấy sản phẩm bán chạy thành công.' });
}

export async function lowStock(req, res) {
  res.json({ success: true, data: await adminStatsService.lowStock(req.query), message: 'Lấy danh sách sắp hết hàng thành công.' });
}

export async function orderCounts(_req, res) {
  res.json({ success: true, data: await adminStatsService.orderCounts(), message: 'Lấy số đơn theo trạng thái thành công.' });
}

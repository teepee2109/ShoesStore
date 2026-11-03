import * as catalogService from '../services/catalog.service.js';

export async function categories(_req, res) {
  const data = await catalogService.listCategories();
  res.json({ success: true, data, message: 'Lấy danh mục thành công.' });
}

export async function products(req, res) {
  const data = await catalogService.listProducts(req.query);
  res.json({ success: true, data, message: 'Lấy sản phẩm thành công.' });
}

export async function productDetail(req, res) {
  const data = await catalogService.getProduct(req.params.id);
  res.json({ success: true, data, message: 'Lấy chi tiết sản phẩm thành công.' });
}

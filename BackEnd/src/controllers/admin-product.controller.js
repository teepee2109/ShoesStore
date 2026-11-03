import * as adminProductService from '../services/admin-product.service.js';
import * as adminService from '../services/admin.service.js';

export async function createProduct(req, res) {
  const data = await adminProductService.createProduct(req.body);
  res.status(201).json({ success: true, data, message: 'Tạo sản phẩm thành công.' });
}

export async function updateProduct(req, res) {
  const data = await adminProductService.updateProduct(req.params.id, req.body);
  res.json({ success: true, data, message: 'Cập nhật sản phẩm thành công.' });
}

export async function deactivateProduct(req, res) {
  const data = await adminProductService.deactivateProduct(req.params.id);
  res.json({ success: true, data, message: 'Đã ẩn sản phẩm.' });
}

export async function uploadImages(req, res) {
  const data = await adminProductService.addProductImages(req.params.id, req.files ?? []);
  res.status(201).json({ success: true, data, message: 'Tải ảnh sản phẩm thành công.' });
}

export async function deleteImage(req, res) {
  const data = await adminProductService.removeProductImage(
    req.params.id,
    req.params.imageId,
  );
  res.json({ success: true, data, message: 'Đã xóa ảnh sản phẩm.' });
}

export async function createVariant(req, res) {
  const data = await adminProductService.addVariant(req.params.id, req.body);
  res.status(201).json({ success: true, data, message: 'Tạo biến thể thành công.' });
}

export async function updateVariant(req, res) {
  const data = await adminProductService.updateVariant(
    req.params.id,
    req.params.variantId,
    req.body,
  );
  res.json({ success: true, data, message: 'Cập nhật biến thể thành công.' });
}

export async function deleteVariant(req, res) {
  const data = await adminProductService.removeVariant(
    req.params.id,
    req.params.variantId,
  );
  res.json({ success: true, data, message: 'Đã xóa biến thể.' });
}

export async function createCategory(req, res) {
  const data = await adminService.createCategory(req.body);
  res.status(201).json({ success: true, data, message: 'Tạo danh mục thành công.' });
}

export async function updateCategory(req, res) {
  const data = await adminService.updateCategory(req.params.id, req.body);
  res.json({ success: true, data, message: 'Cập nhật danh mục thành công.' });
}

export async function deleteCategory(req, res) {
  const data = await adminService.deleteCategory(req.params.id);
  res.json({ success: true, data, message: 'Đã xóa danh mục.' });
}

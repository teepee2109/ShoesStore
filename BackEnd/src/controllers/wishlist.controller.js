import * as wishlistService from '../services/wishlist.service.js';

export async function getWishlist(req, res) {
  const data = await wishlistService.getWishlist(req.auth.sub);
  res.json({ success: true, data, message: 'Lấy danh sách yêu thích thành công.' });
}

export async function addItem(req, res) {
  const data = await wishlistService.addWishlistItem(req.auth.sub, req.body);
  res.status(201).json({ success: true, data, message: 'Đã thêm vào danh sách yêu thích.' });
}

export async function removeItem(req, res) {
  const data = await wishlistService.removeWishlistItem(req.auth.sub, req.params.productId);
  res.json({ success: true, data, message: 'Đã bỏ yêu thích sản phẩm.' });
}

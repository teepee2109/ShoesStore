import * as reviewService from '../services/review.service.js';

export async function list(req, res) {
  const data = await reviewService.listReviews(req.params.id, req.query);
  res.json({ success: true, data, message: 'Lấy đánh giá thành công.' });
}

export async function create(req, res) {
  const data = await reviewService.createReview(req.auth.sub, req.params.id, req.body);
  res.status(201).json({ success: true, data, message: 'Gửi đánh giá thành công.' });
}

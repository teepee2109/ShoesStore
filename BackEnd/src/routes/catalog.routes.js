import { Router } from 'express';
import * as adminProductController from '../controllers/admin-product.controller.js';
import * as catalogController from '../controllers/catalog.controller.js';
import { auth, requireRole } from '../middlewares/auth.middleware.js';
import { uploadProductImages } from '../middlewares/upload.middleware.js';
import reviewRouter from './review.routes.js';

export const categoryRouter = Router();
categoryRouter.get('/', catalogController.categories);
categoryRouter.post('/', auth, requireRole('admin'), adminProductController.createCategory);
categoryRouter.put('/:id', auth, requireRole('admin'), adminProductController.updateCategory);
categoryRouter.delete('/:id', auth, requireRole('admin'), adminProductController.deleteCategory);

export const productRouter = Router();
productRouter.get('/', catalogController.products);
productRouter.use('/:id/reviews', reviewRouter);
productRouter.get('/:id', catalogController.productDetail);
productRouter.post('/', auth, requireRole('admin'), adminProductController.createProduct);
productRouter.put('/:id', auth, requireRole('admin'), adminProductController.updateProduct);
productRouter.delete('/:id', auth, requireRole('admin'), adminProductController.deactivateProduct);
productRouter.post(
  '/:id/images',
  auth,
  requireRole('admin'),
  uploadProductImages,
  adminProductController.uploadImages,
);
productRouter.delete(
  '/:id/images/:imageId',
  auth,
  requireRole('admin'),
  adminProductController.deleteImage,
);
productRouter.post(
  '/:id/variants',
  auth,
  requireRole('admin'),
  adminProductController.createVariant,
);
productRouter.put(
  '/:id/variants/:variantId',
  auth,
  requireRole('admin'),
  adminProductController.updateVariant,
);
productRouter.delete(
  '/:id/variants/:variantId',
  auth,
  requireRole('admin'),
  adminProductController.deleteVariant,
);

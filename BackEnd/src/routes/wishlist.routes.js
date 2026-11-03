import { Router } from 'express';
import * as wishlistController from '../controllers/wishlist.controller.js';
import { auth, requireRole } from '../middlewares/auth.middleware.js';

const router = Router();
router.use(auth, requireRole('customer'));
router.get('/', wishlistController.getWishlist);
router.post('/items', wishlistController.addItem);
router.delete('/items/:productId', wishlistController.removeItem);

export default router;

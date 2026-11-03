import { Router } from 'express';
import * as cartController from '../controllers/cart.controller.js';
import { auth, requireRole } from '../middlewares/auth.middleware.js';

const router = Router();
router.use(auth, requireRole('customer'));
router.get('/', cartController.getCart);
router.post('/items', cartController.addItem);
router.put('/items/:itemId', cartController.updateItem);
router.delete('/items/:itemId', cartController.removeItem);
router.delete('/items', cartController.removeAllItems);

export default router;

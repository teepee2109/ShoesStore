import { Router } from 'express';
import * as orderController from '../controllers/order.controller.js';
import { auth, requireRole } from '../middlewares/auth.middleware.js';

const router = Router();
router.use(auth, requireRole('customer'));
router.post('/', orderController.create);
router.get('/', orderController.list);
router.get('/:id', orderController.detail);
router.put('/:id/cancel', orderController.cancel);

export default router;

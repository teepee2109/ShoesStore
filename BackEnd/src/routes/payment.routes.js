import { Router } from 'express';

import * as paymentController from '../controllers/payment.controller.js';
import { auth, requireRole } from '../middlewares/auth.middleware.js';

const router = Router();
router.post('/sepay/create', auth, requireRole('customer'), paymentController.createSePay);
router.get('/sepay/return', paymentController.sepayReturn);
router.get('/sepay/status/:order_id', auth, requireRole('customer'), paymentController.sepayStatus);
router.post('/sepay/ipn', paymentController.sepayIpn);

export default router;

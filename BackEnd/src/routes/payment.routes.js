import { Router } from 'express';

import * as paymentController from '../controllers/payment.controller.js';
import { auth, requireRole } from '../middlewares/auth.middleware.js';

const router = Router();
router.post('/vnpay/create', auth, requireRole('customer'), paymentController.createVnpay);
router.get('/vnpay/return', paymentController.vnpayReturn);
router.get('/vnpay/ipn', paymentController.vnpayIpn);

export default router;

import { Router } from 'express';
import * as reviewController from '../controllers/review.controller.js';
import { auth, requireRole } from '../middlewares/auth.middleware.js';

const router = Router({ mergeParams: true });
router.get('/', reviewController.list);
router.post('/', auth, requireRole('customer'), reviewController.create);

export default router;

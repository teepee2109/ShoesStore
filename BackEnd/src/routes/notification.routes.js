import { Router } from 'express';
import * as notificationController from '../controllers/notification.controller.js';
import { auth } from '../middlewares/auth.middleware.js';

const router = Router();
router.use(auth);
router.get('/', notificationController.list);
router.patch('/read-all', notificationController.markAllRead);
router.patch('/:id/read', notificationController.markRead);

export default router;

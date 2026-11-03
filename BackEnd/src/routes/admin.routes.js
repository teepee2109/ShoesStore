import { Router } from 'express';
import * as adminController from '../controllers/admin.controller.js';
import * as adminStatsController from '../controllers/admin-stats.controller.js';
import { auth, requireRole } from '../middlewares/auth.middleware.js';

const router = Router();
router.use(auth, requireRole('admin'));
router.get('/stats/revenue', adminStatsController.revenue);
router.get('/stats/top-products', adminStatsController.topProducts);
router.get('/stats/low-stock', adminStatsController.lowStock);
router.get('/stats/orders-by-status', adminStatsController.orderCounts);
router.get('/orders', adminController.orders);
router.put('/orders/:id/status', adminController.updateOrderStatus);
router.get('/users', adminController.users);
router.get('/users/:id', adminController.user);
router.put('/users/:id', adminController.updateUser);
router.delete('/users/:id', adminController.deleteUser);
router.get('/chats', adminController.chats);
router.get('/chats/:customerId/messages', adminController.chatMessages);

export default router;

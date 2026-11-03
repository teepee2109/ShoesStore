import { Router } from 'express';
import * as authController from '../controllers/auth.controller.js';
import { auth } from '../middlewares/auth.middleware.js';

const router = Router();
router.post('/register', authController.register);
router.post('/login', authController.login);
router.get('/me', auth, authController.me);
router.put('/me', auth, authController.updateMe);
router.put('/password', auth, authController.changePassword);

export default router;

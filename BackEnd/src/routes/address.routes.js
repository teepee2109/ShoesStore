import { Router } from 'express';
import * as addressController from '../controllers/address.controller.js';
import { auth, requireRole } from '../middlewares/auth.middleware.js';

const router = Router();
router.use(auth, requireRole('customer'));
router.get('/', addressController.list);
router.post('/', addressController.create);
router.put('/:id', addressController.update);
router.delete('/:id', addressController.remove);

export default router;

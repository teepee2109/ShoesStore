import cors from 'cors';
import express from 'express';
import helmet from 'helmet';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import swaggerUi from 'swagger-ui-express';
import { env } from './config/env.js';
import { openapiSpec } from './docs/openapi.js';
import { errorHandler, notFoundHandler } from './middlewares/error.middleware.js';
import adminRouter from './routes/admin.routes.js';
import addressRouter from './routes/address.routes.js';
import authRouter from './routes/auth.routes.js';
import cartRouter from './routes/cart.routes.js';
import { categoryRouter, productRouter } from './routes/catalog.routes.js';
import orderRouter from './routes/order.routes.js';
import paymentRouter from './routes/payment.routes.js';
import notificationRouter from './routes/notification.routes.js';
import wishlistRouter from './routes/wishlist.routes.js';

const app = express();
const allowedOrigins = env.corsOrigins.includes('*') ? true : env.corsOrigins;
const uploadsDirectory = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../uploads');
const adminDirectory = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../admin');

app.use(helmet());
app.use(cors({ origin: allowedOrigins }));
app.use(express.json({ limit: '1mb' }));
app.use('/uploads', express.static(uploadsDirectory, { dotfiles: 'deny', index: false }));
app.use('/admin-ui', (_req, res, next) => {
  res.setHeader(
    'Content-Security-Policy',
    "default-src 'self'; img-src 'self' data: blob:; style-src 'self' https://cdn.jsdelivr.net https://fonts.googleapis.com 'unsafe-inline'; script-src 'self' https://cdn.jsdelivr.net; font-src 'self' https://fonts.gstatic.com; connect-src 'self' ws: wss:;",
  );
  next();
});
app.use('/admin-ui', express.static(adminDirectory, { index: 'index.html' }));
app.get('/openapi.json', (_req, res) => res.json(openapiSpec));
app.use('/api-docs', (req, res, next) => {
  res.setHeader(
    'Content-Security-Policy',
    "default-src 'self'; img-src 'self' data:; style-src 'self' 'unsafe-inline'; script-src 'self' 'unsafe-inline'; connect-src 'self';",
  );
  next();
}, swaggerUi.serve, swaggerUi.setup(openapiSpec, { explorer: true, persistAuthorization: true }));

app.get('/health', (_req, res) => {
  res.json({ success: true, data: { status: 'ok' }, message: 'API is running.' });
});

const api = express.Router();
api.use('/auth', authRouter);
api.use('/categories', categoryRouter);
api.use('/products', productRouter);
api.use('/cart', cartRouter);
api.use('/wishlist', wishlistRouter);
api.use('/addresses', addressRouter);
api.use('/orders', orderRouter);
api.use('/payments', paymentRouter);
api.use('/notifications', notificationRouter);
api.use('/admin', adminRouter);
app.use('/api/v1', api);

app.use(notFoundHandler);
app.use(errorHandler);

export default app;

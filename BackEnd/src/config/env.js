import 'dotenv/config';

if (!process.env.JWT_SECRET || process.env.JWT_SECRET.length < 32) {
  throw new Error('JWT_SECRET is required and must contain at least 32 characters.');
}

const port = Number(process.env.PORT ?? 3000);

export const env = {
  port,
  nodeEnv: process.env.NODE_ENV ?? 'development',
  jwtSecret: process.env.JWT_SECRET,
  jwtExpiresIn: process.env.JWT_EXPIRES_IN ?? '7d',
  corsOrigins: (process.env.CORS_ORIGINS ?? '*')
    .split(',')
    .map((origin) => origin.trim())
    .filter(Boolean),
  database: {
    host: process.env.DB_HOST ?? '127.0.0.1',
    port: Number(process.env.DB_PORT ?? 3306),
    user: process.env.DB_USER ?? 'root',
    password: process.env.DB_PASSWORD ?? 'admin',
    database: process.env.DB_NAME ?? 'adidas_shop',
  },
  sepay: {
    environment: process.env.SEPAY_ENVIRONMENT ?? 'sandbox',
    merchantId: process.env.SEPAY_MERCHANT_ID ?? '',
    merchantSecretKey: process.env.SEPAY_MERCHANT_SECRET_KEY ?? '',
    ipnSecretKey: process.env.SEPAY_IPN_SECRET_KEY ?? '',
    returnUrl: process.env.SEPAY_RETURN_URL ?? '',
    ipnUrl: process.env.SEPAY_IPN_URL ?? '',
  },
};

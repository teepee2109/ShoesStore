import { mkdirSync } from 'node:fs';
import path from 'node:path';
import { randomUUID } from 'node:crypto';
import { fileURLToPath } from 'node:url';
import multer from 'multer';
import { AppError } from '../utils/app-error.js';

const uploadDirectory = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  '../../uploads',
);
mkdirSync(uploadDirectory, { recursive: true });

const extensionsByMimeType = new Map([
  ['image/jpeg', '.jpg'],
  ['image/png', '.png'],
  ['image/webp', '.webp'],
]);

const storage = multer.diskStorage({
  destination: (_req, _file, callback) => callback(null, uploadDirectory),
  filename: (_req, file, callback) => {
    const extension = extensionsByMimeType.get(file.mimetype);
    callback(null, `${randomUUID()}${extension ?? ''}`);
  },
});

export const uploadProductImages = multer({
  storage,
  limits: {
    files: 8,
    fileSize: 5 * 1024 * 1024,
    fields: 8,
    fieldSize: 16 * 1024,
  },
  fileFilter: (_req, file, callback) => {
    if (!extensionsByMimeType.has(file.mimetype)) {
      return callback(new AppError('Chỉ chấp nhận ảnh JPEG, PNG hoặc WebP.', 400));
    }
    return callback(null, true);
  },
}).array('images', 8);

export { uploadDirectory };

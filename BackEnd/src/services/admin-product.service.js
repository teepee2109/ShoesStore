import { open, unlink } from 'node:fs/promises';
import path from 'node:path';
import { AppError } from '../utils/app-error.js';
import { uploadDirectory } from '../middlewares/upload.middleware.js';
import { withTransaction } from '../utils/with-transaction.js';
import { getProduct } from './catalog.service.js';
import { productSchema, variantSchema } from '../validators/product.validators.js';
import * as productModel from '../models/admin-product.model.js';

function parseId(value, label) {
  const id = Number(value);
  if (!Number.isSafeInteger(id) || id <= 0) {
    throw new AppError(`${label} không hợp lệ.`, 400);
  }
  return id;
}

function parseProduct(input) {
  const product = productSchema.parse(input);
  if (product.discount_price != null && product.discount_price > product.price) {
    throw new AppError('Giá khuyến mãi không được lớn hơn giá gốc.', 400);
  }
  return product;
}

export async function createProduct(input) {
  const product = parseProduct(input);
  if (!(await productModel.categoryExists(product.category_id))) {
    throw new AppError('Danh mục không tồn tại.', 400);
  }
  const productId = await productModel.insertProduct(product);
  return getProduct(productId);
}

export async function updateProduct(idValue, input) {
  const productId = parseId(idValue, 'Mã sản phẩm');
  const product = parseProduct(input);
  if (!(await productModel.categoryExists(product.category_id))) {
    throw new AppError('Danh mục không tồn tại.', 400);
  }
  const exists = await productModel.productExists(productId);
  if (!exists) throw new AppError('Không tìm thấy sản phẩm.', 404);
  await productModel.updateProductById(productId, product);
  return getProduct(productId);
}

export async function deactivateProduct(idValue) {
  const productId = parseId(idValue, 'Mã sản phẩm');
  if (!(await productModel.productExists(productId))) {
    throw new AppError('Không tìm thấy sản phẩm.', 404);
  }
  await productModel.deactivateProductById(productId);
  return { id: productId, is_active: false };
}

async function assertImageSignature(file) {
  const handle = await open(file.path, 'r');
  const header = Buffer.alloc(12);
  try {
    const { bytesRead } = await handle.read(header, 0, header.length, 0);
    const bytes = header.subarray(0, bytesRead);
    const isJpeg = bytes.length >= 3 && bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff;
    const isPng = bytes.length >= 8 && bytes.subarray(0, 8).equals(Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]));
    const isWebp = bytes.length >= 12 && bytes.toString('ascii', 0, 4) === 'RIFF' && bytes.toString('ascii', 8, 12) === 'WEBP';
    const matchesMime =
      (isJpeg && file.mimetype === 'image/jpeg') ||
      (isPng && file.mimetype === 'image/png') ||
      (isWebp && file.mimetype === 'image/webp');
    if (!matchesMime) {
      throw new AppError('Nội dung file không đúng định dạng ảnh khai báo.', 400);
    }
  } finally {
    await handle.close();
  }
}

async function removeUploadedFiles(files) {
  await Promise.all(files.map((file) => unlink(file.path).catch(() => {})));
}

export async function addProductImages(idValue, files = []) {
  try {
    const productId = parseId(idValue, 'Mã sản phẩm');
    if (files.length === 0) throw new AppError('Hãy chọn ít nhất một ảnh.', 400);
    for (const file of files) await assertImageSignature(file);

    const images = files.map((file) => ({
      url: `/uploads/${file.filename}`,
    }));

    await withTransaction(async (connection) => {
      const product = await productModel.productExists(productId, connection);
      if (!product) throw new AppError('Không tìm thấy sản phẩm.', 404);
      await productModel.insertProductImages(connection, productId, images);
      if (!product.main_image && images[0]) {
        await productModel.setMainImageIfEmpty(connection, productId, images[0].url);
      }
    });

    return getProduct(productId);
  } catch (error) {
    await removeUploadedFiles(files);
    throw error;
  }
}

export async function removeProductImage(productIdValue, imageIdValue) {
  const productId = parseId(productIdValue, 'Mã sản phẩm');
  const imageId = parseId(imageIdValue, 'Mã ảnh');
  const image = await withTransaction(async (connection) => {
    const product = await productModel.productExists(productId, connection);
    if (!product) throw new AppError('Không tìm thấy sản phẩm.', 404);
    const current = await productModel.findProductImage(connection, productId, imageId);
    if (!current) throw new AppError('Không tìm thấy ảnh sản phẩm.', 404);
    if (product.main_image === current.url) {
      const nextUrl = await productModel.findNextProductImage(connection, productId, imageId);
      await productModel.setMainImage(connection, productId, nextUrl);
    }
    await productModel.deleteProductImage(connection, productId, imageId);
    return current;
  });

  const filename = path.basename(image.url);
  if (filename) {
    await unlink(path.join(uploadDirectory, filename)).catch(() => {});
  }
  return getProduct(productId);
}

export async function addVariant(productIdValue, input) {
  const productId = parseId(productIdValue, 'Mã sản phẩm');
  const variant = variantSchema.parse(input);
  if (!(await productModel.productExists(productId))) {
    throw new AppError('Không tìm thấy sản phẩm.', 404);
  }
  const variantId = await productModel.insertProductVariant(productId, variant);
  return { id: variantId, product_id: productId, ...variant };
}

export async function updateVariant(productIdValue, variantIdValue, input) {
  const productId = parseId(productIdValue, 'Mã sản phẩm');
  const variantId = parseId(variantIdValue, 'Mã biến thể');
  const variant = variantSchema.parse(input);
  await withTransaction(async (connection) => {
    const existing = await productModel.findProductVariant(connection, productId, variantId);
    if (!existing) throw new AppError('Không tìm thấy biến thể của sản phẩm.', 404);
    const references = await productModel.countVariantReferences(connection, variantId);
    if (
      Number(references.order_count) > 0 &&
      (existing.size !== variant.size || existing.color !== variant.color)
    ) {
      throw new AppError('Không thể đổi size/màu của biến thể đã có trong đơn hàng.', 409);
    }
    await productModel.updateProductVariant(productId, variantId, variant, connection);
  });
  return { id: variantId, product_id: productId, ...variant };
}

export async function removeVariant(productIdValue, variantIdValue) {
  const productId = parseId(productIdValue, 'Mã sản phẩm');
  const variantId = parseId(variantIdValue, 'Mã biến thể');
  const references = await withTransaction(async (connection) => {
    const variant = await productModel.findProductVariant(connection, productId, variantId);
    if (!variant) throw new AppError('Không tìm thấy biến thể của sản phẩm.', 404);
    const counts = await productModel.countVariantReferences(connection, variantId);
    if (Number(counts.order_count) > 0 || Number(counts.cart_count) > 0) {
      throw new AppError('Biến thể đang được dùng trong đơn hàng hoặc giỏ hàng.', 409);
    }
    await productModel.deleteProductVariant(productId, variantId, connection);
    return variant;
  });
  return { id: references.id, deleted: true };
}

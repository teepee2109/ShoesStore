import { AppError } from '../utils/app-error.js';
import { env } from '../config/env.js';

export function notFoundHandler(_req, _res, next) {
  next(new AppError('Không tìm thấy API.', 404));
}

export function errorHandler(error, _req, res, _next) {
  let statusCode = error.statusCode ?? 500;
  let message = error.message ?? 'Đã xảy ra lỗi trên máy chủ.';

  if (error.name === 'ZodError') {
    statusCode = 400;
    message = error.issues?.[0]?.message ?? 'Dữ liệu gửi lên không hợp lệ.';
  } else if (error.name === 'MulterError') {
    statusCode = 400;
    message = error.code === 'LIMIT_FILE_SIZE'
      ? 'Ảnh tải lên không được lớn hơn 5 MB.'
      : 'Yêu cầu tải ảnh không hợp lệ hoặc vượt quá giới hạn.';
  } else if (error.code === 'ER_DUP_ENTRY') {
    statusCode = 409;
    message = 'Dữ liệu đã tồn tại.';
  } else if (error.code === 'ER_ROW_IS_REFERENCED_2' || error.code === 'ER_ROW_IS_REFERENCED') {
    statusCode = 409;
    message = 'Bản ghi đang được sử dụng và không thể xóa.';
  } else if (error.code === 'ER_NO_SUCH_TABLE' || error.code === 'ECONNREFUSED') {
    statusCode = 503;
    message = 'Không kết nối được cơ sở dữ liệu. Hãy kiểm tra MySQL và cấu hình .env.';
  }

  if (statusCode >= 500 && env.nodeEnv !== 'development') {
    message = 'Đã xảy ra lỗi trên máy chủ.';
  }

  if (statusCode >= 500) {
    console.error(error);
  }

  res.status(statusCode).json({ success: false, data: null, message });
}

import 'package:dio/dio.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  factory ApiException.fromDio(DioException error) {
    final responseData = error.response?.data;
    final message = responseData is Map<String, dynamic>
        ? responseData['message']?.toString()
        : null;
    return ApiException(
      message ?? 'Không thể kết nối máy chủ. Vui lòng thử lại.',
      statusCode: error.response?.statusCode,
    );
  }

  @override
  String toString() => message;
}

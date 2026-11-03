import 'dart:async';

import 'package:dio/dio.dart';

import 'config/app_config.dart';
import 'network/api_exception.dart';
import 'storage/token_storage.dart';

class DioClient {
  DioClient({
    required this.tokenStorage,
    this.onUnauthorized,
    String baseUrl = AppConfig.apiBaseUrl,
  }) : dio = Dio(
         BaseOptions(
           baseUrl: baseUrl.endsWith('/') ? baseUrl : '$baseUrl/',
           connectTimeout: const Duration(seconds: 10),
           receiveTimeout: const Duration(seconds: 15),
           sendTimeout: const Duration(seconds: 15),
           headers: const {'Accept': 'application/json'},
         ),
       ) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await tokenStorage.readToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          final path = error.requestOptions.path;
          final isLoginRequest = path.endsWith('auth/login');
          if (error.response?.statusCode == 401 && !isLoginRequest) {
            await tokenStorage.clearToken();
            await onUnauthorized?.call();
          }
          handler.next(error);
        },
      ),
    );
  }

  final Dio dio;
  final TokenStorage tokenStorage;
  final FutureOr<void> Function()? onUnauthorized;

  Future<Response<dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
  }) => _request(
    () => dio.get(
      path,
      queryParameters: queryParameters,
      cancelToken: cancelToken,
    ),
  );

  Future<Response<dynamic>> post(String path, {Object? data}) =>
      _request(() => dio.post(path, data: data));

  Future<Response<dynamic>> put(String path, {Object? data}) =>
      _request(() => dio.put(path, data: data));

  Future<Response<dynamic>> patch(String path, {Object? data}) =>
      _request(() => dio.patch(path, data: data));

  Future<Response<dynamic>> delete(String path, {Object? data}) =>
      _request(() => dio.delete(path, data: data));

  Future<Response<dynamic>> _request(
    Future<Response<dynamic>> Function() request,
  ) async {
    try {
      return await request();
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}

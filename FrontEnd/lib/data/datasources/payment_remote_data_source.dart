import '../../core/dio_client.dart';
import '../models/vnpay_payment.dart';
import 'api_payload.dart';

class PaymentRemoteDataSource {
  PaymentRemoteDataSource(this._client);

  final DioClient _client;

  Future<VnpayPaymentSession> createVnpay(int orderId) async {
    final response = await _client.post(
      'payments/vnpay/create',
      data: {'order_id': orderId},
    );
    return VnpayPaymentSession.fromJson(asJsonMap(responseData(response.data)));
  }

  Future<VnpayPaymentResult> verifyVnpayReturn(
    Map<String, String> queryParameters,
  ) async {
    final response = await _client.get(
      'payments/vnpay/return',
      queryParameters: queryParameters,
    );
    return VnpayPaymentResult.fromJson(asJsonMap(responseData(response.data)));
  }
}

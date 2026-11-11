import '../../core/dio_client.dart';
import '../models/sepay_payment.dart';
import 'api_payload.dart';

class PaymentRemoteDataSource {
  PaymentRemoteDataSource(this._client);

  final DioClient _client;

  Future<SePayPaymentSession> createSePay(int orderId) async {
    final response = await _client.post(
      'payments/sepay/create',
      data: {'order_id': orderId},
    );
    return SePayPaymentSession.fromJson(asJsonMap(responseData(response.data)));
  }

  Future<SePayPaymentResult> getSePayStatus(
    int orderId, {
    required String returnStatus,
  }) async {
    final response = await _client.get(
      'payments/sepay/status/$orderId',
    );
    return SePayPaymentResult.fromJson(
      asJsonMap(responseData(response.data)),
      returnStatus: returnStatus,
    );
  }
}

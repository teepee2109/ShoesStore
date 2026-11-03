import '../datasources/payment_remote_data_source.dart';
import '../models/vnpay_payment.dart';

class PaymentRepository {
  PaymentRepository(this._remote);

  final PaymentRemoteDataSource _remote;

  Future<VnpayPaymentSession> createVnpay(int orderId) =>
      _remote.createVnpay(orderId);

  Future<VnpayPaymentResult> verifyVnpayReturn(
    Map<String, String> queryParameters,
  ) => _remote.verifyVnpayReturn(queryParameters);
}

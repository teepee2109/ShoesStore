import '../datasources/payment_remote_data_source.dart';
import '../models/sepay_payment.dart';

class PaymentRepository {
  PaymentRepository(this._remote);

  final PaymentRemoteDataSource _remote;

  Future<SePayPaymentSession> createSePay(int orderId) =>
      _remote.createSePay(orderId);

  Future<SePayPaymentResult> getSePayStatus(
    int orderId, {
    required String returnStatus,
  }) => _remote.getSePayStatus(orderId, returnStatus: returnStatus);
}
